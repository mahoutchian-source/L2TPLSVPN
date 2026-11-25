export PATH=$PWD/bin:$PATH CONF_DIR=$PWD/c IPSEC_CONF=$PWD/ipsec.conf IPSEC_D=$PWD/ipd PPP_DIR=$PWD/ppp XL2TPD_CONF=$PWD/x/x.conf SECRETS=$PWD/sec NO_RESTART=1 STATE_DIR=$PWD/st UNIT_DIR=$PWD/units L2TP_GW=$PWD/../build/l2tp-gw SYS_NET=/sys/class/net
GW=$L2TP_GW
rm -rf c ipd ppp x st units ipt calls sec ipsec.conf run tr
mkdir -p c ipd ppp/ip-up.d x st units run
printf '#!/bin/sh\n' > ppp/ip-up; printf '#!/bin/sh\n' > ppp/ip-down
echo "include $IPSEC_D/*.conf" > ipsec.conf
cp ../t8/c/web.conf c/
ip link del ppp0 2>/dev/null; ip link set lo up
ip tuntap add dev ens5 mode tun; ip addr add 172.26.2.106/20 dev ens5; ip link set ens5 up
echo "Security Associations (0 up, 0 connecting):" > ipsec.status
ok(){ if eval "$2"; then echo "PASS $1"; else echo "FAIL $1"; fi; }
printf '[cl]\nhost = 9.9.9.9\npsk = clientpsk\nuser = cu\npass = cp\n' > c/sites.conf
bash $GW apply >/dev/null 2>&1
printf '[cl]\nhost = 9.9.9.9\npsk = clientpsk\nuser = cu\npass = cp\n' > c/sites.conf
printf 'enabled = yes\npublic_ip = 3.4.5.6\npsk = abcdefghij1234567890\npool = 10.99.99.0/24\nlocal = 10.99.99.1\n' > c/dialin.conf
bash $GW apply >/dev/null 2>&1
python3 -I ../build/l2tp-gw-web run >/dev/null 2>&1 & W=$!; sleep 1.5
B=http://127.0.0.1:18082; J=cj; rm -f $J; C=/usr/bin/curl
$C -s -c $J -b $J -L -d 'password=pw123456' $B/login > main.html
CS=$(grep -o "name=csrf value='[^']*'" main.html | head -1 | sed "s/.*value='//;s/'//")
post(){ $C -s -b $J -c $J -d "csrf=$CS" "$@"; }
get(){ $C -s -b $J -c $J "$@"; }
get "$B/dialin/edit" > e0.html; echo "new form boxes ticked: $(grep -o 'name=acc_[a-z]* value=yes checked' e0.html | wc -l)"
post -d name=office -d user=office1 -d pass=officepass1 -d ip=10.99.99.2 -d nat=yes -d acc_sites=yes $B/dialin/save -o /dev/null -w 'save %{http_code}\n'
grep -A12 '^\[office\]' c/sites.conf | grep -E 'access|nat'
cat c/dialin-ip.d/office
get "$B/dialin" | grep -o "no internet\|no other clients\|no outgoing sites"
get "$B/dialin/edit?name=office" > e1.html; echo "edit form: $(grep -o 'name=acc_[a-z]* value=yes checked' e1.html | tr '\n' ' ')"
post -d name=office -d user=office1 -d pass=officepass1 -d ip=10.99.99.2 -d acc_internet=yes -d acc_clients=yes -d acc_sites=yes -d orig=office $B/dialin/save -o /dev/null
grep -A12 '^\[office\]' c/sites.conf | grep -c access; cat c/dialin-ip.d/office
kill $W
