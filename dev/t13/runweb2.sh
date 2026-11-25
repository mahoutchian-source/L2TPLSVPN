export PATH=$PWD/bin:$PATH CONF_DIR=$PWD/c IPSEC_CONF=$PWD/ipsec.conf IPSEC_D=$PWD/ipd PPP_DIR=$PWD/ppp XL2TPD_CONF=$PWD/x/x.conf SECRETS=$PWD/sec NO_RESTART=1 STATE_DIR=$PWD/st UNIT_DIR=$PWD/units L2TP_GW=$PWD/../build/l2tp-gw
mkdir -p ipd ppp x; printf "config setup\n\ninclude %s/ipd/*.conf\n" "$PWD" > ipsec.conf
ip link set lo up
ip tuntap add dev ppp-only mode tun; ip addr add 172.17.218.3 peer 172.17.192.3 dev ppp-only; ip link set dev ppp-only up
printf '[only]\nhost = 9.9.9.9\npsk = k\nuser = u\npass = p\n' > c/sites.conf
echo "Security Associations (0 up, 0 connecting):" > ipsec.status
python3 -I ../build/l2tp-gw-web run & W=$!; sleep 1
B=http://127.0.0.1:18084; J=cj; rm -f $J; C=/usr/bin/curl
$C -s -c $J -b $J -L -d 'password=pw123456' $B/login > m.html
CS=$(grep -o "name=csrf value='[^']*'" m.html | head -1 | sed "s/.*value='//;s/'//")
post(){ $C -s -b $J -c $J -d "csrf=$CS" "$@"; }
st(){ $C -s -b $J $B/ | grep -o "state [a-z]*'>[^<]*" | head -1; }
echo "default (heal), plain L2TP:   $(st)"
save(){ post --data-urlencode 'name=only' --data-urlencode 'orig=only' --data-urlencode 'host=9.9.9.9' --data-urlencode 'user=u' --data-urlencode 'routes=' -d "ipsec_mode=$1&quota_gb=&reconnect_every=&reconnect_at=&reconnect_window=&nat=yes" -o /dev/null -w '%{http_code}' $B/save; }
echo "save allow:   http $(save allow)   file: $(grep ipsec_mode c/sites.conf)"
echo "allow:        $(st)  chip: $($C -s -b $J $B/ | grep -o "IPsec: [a-z]*" | head -1)"
echo "edit form:    $($C -s -b $J "$B/edit?name=only" | grep -o "<option value='allow' selected>")"
echo "save require: http $(save require)   file: $(grep ipsec_mode c/sites.conf)"
echo "require:      $(st)  chip: $($C -s -b $J $B/ | grep -o "IPsec: [a-z]*" | head -1)"
echo "save heal:    http $(save heal)   lines with ipsec_mode in file: $(grep -c ipsec_mode c/sites.conf)"
echo "heal again:   $(st)  chip: $($C -s -b $J $B/ | grep -c 'IPsec: ')"
echo "forged value: $(post -d 'name=only&orig=only&host=9.9.9.9&user=u&ipsec_mode=evil' $B/save | grep -o 'ipsec_mode must[^<]*')"
kill $W
