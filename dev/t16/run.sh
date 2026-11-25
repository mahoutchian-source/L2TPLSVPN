export PATH=$PWD/../t8/bin:$PATH CONF_DIR=$PWD/c IPSEC_CONF=$PWD/ipsec.conf IPSEC_D=$PWD/ipd PPP_DIR=$PWD/ppp XL2TPD_CONF=$PWD/x/x.conf SECRETS=$PWD/sec NO_RESTART=1 STATE_DIR=$PWD/st UNIT_DIR=$PWD/units L2TP_GW=$PWD/../build/l2tp-gw
mkdir -p c ipd ppp x units st
cp ../t8/c/web.conf c/ 2>/dev/null; ls ../t8/c >&2
printf '[a]\nhost = 9.9.9.9\npsk = k\nuser = u\npass = p\n' > c/sites.conf
ip link set lo up
ip tuntap add dev ppp-a mode tun; ip addr add 172.17.218.3 peer 172.17.192.3 dev ppp-a; ip link set dev ppp-a up
bash $L2TP_GW apply >/dev/null 2>&1
python3 -I ../build/l2tp-gw-web run & W=$!; sleep 1
B=http://127.0.0.1:18082; J=cj; rm -f $J
C=/usr/bin/curl
$C -s -c $J -b $J -L -d 'password=pw123456' $B/login > main.html
grep -o ">Routes<" main.html | head -1
CS=$(grep -o "name=csrf value='[^']*'" main.html | head -1 | sed "s/.*value='//;s/'//")
post(){ $C -s -b $J -c $J -d "csrf=$CS" "$@"; }
echo "--- routes empty"; $C -s -b $J $B/routes | grep -o "No rules yet\|No lists yet" 
echo "--- new list bad entry"; post -d name=iran2 --data-urlencode $'text=1.2.3.0/24\nnotanip\n0.0.0.0/0' -d new=1 $B/routes/list/save | grep -o "warnbox>[^/]*" | head -3
echo "--- new list good"; post --data-urlencode "name=iran" --data-urlencode $'text=# test\n10.20.0.0/16\n10.30.1.1-10.30.1.9\n10.40.5.5\nexample.com\n' -d new=1 $B/routes/list/save -o /dev/null -w '%{http_code} %{redirect_url}\n'
$C -s -b $J $B/routes/review | grep -o "Review: [^<]*\|Added</b>[0-9]*" | head
post -o /dev/null -w 'confirm %{http_code}\n' $B/routes/confirm
$C -s -b $J -c $J $B/routes | grep -o "iran</b>\|[0-9]* entries ([^)]*)" | head -3
echo "--- rule add (bad / good)"; post -d 'list=iran&via=nonsense&metric=2' -o /dev/null $B/routes/rule/add; $C -s -b $J -c $J $B/routes | grep -o "Next hop looks like[^<]*" | head -1
post -d 'list=iran&via=172.17.192.3&metric=2' -o /dev/null $B/routes/rule/add
$C -s -b $J $B/routes/review | grep -o "Added</b>[0-9]*\|Total after</b>[0-9]*" 
post -o /dev/null $B/routes/confirm
ip route show proto 98 | head
$C -s -b $J -c $J $B/routes | grep -o "Active\|iran via[^<]*\|172.17.192.3 metric 2[^<]*" | head -3
echo "--- toggle off"; post --data-urlencode "rule=iran via 172.17.192.3 metric 2" -o /dev/null $B/routes/rule/toggle; post -o /dev/null $B/routes/confirm; ip route show proto 98 | wc -l
post --data-urlencode "rule=iran via 172.17.192.3 metric 2 disabled" -o /dev/null $B/routes/rule/toggle; post -o /dev/null $B/routes/confirm; ip route show proto 98 | wc -l
echo "--- delete list in use refused"; post -d name=iran -o /dev/null $B/routes/list/delete; $C -s -b $J -c $J $B/routes | grep -o "is used by[^<]*"
echo "--- protect"; post --data-urlencode $'text=10.20.7.0/24\n' -o /dev/null $B/routes/protect; $C -s -b $J $B/routes/review | grep -o "Added</b>[0-9]*"; post -o /dev/null $B/routes/confirm; ip route show proto 98 | wc -l
post --data-urlencode $'text=zzz' -o /dev/null $B/routes/protect; $C -s -b $J -c $J $B/routes | grep -o "Not an IPv4[^<]*"
echo "--- cancel"; post --data-urlencode "rule=iran via 172.17.192.3 metric 2" -o /dev/null $B/routes/rule/delete; post -o /dev/null $B/routes/cancel; cat c/routing.conf
echo "--- delete rule then list"; post --data-urlencode "rule=iran via 172.17.192.3 metric 2" -o /dev/null $B/routes/rule/delete; post -o /dev/null $B/routes/confirm; ip route show proto 98 | wc -l
post -d name=iran -o /dev/null $B/routes/list/delete; post -o /dev/null $B/routes/confirm; ls c/lists.d
echo "--- big list (400KB)"; python3 -c "
import ipaddress
print('\n'.join(str(ipaddress.ip_network((0x0B000000+i*256,24))) for i in range(20000)))" > big.txt; wc -c big.txt
post --data-urlencode name=big --data-urlencode text@big.txt -d new=1 -o /dev/null -w '%{http_code}\n' $B/routes/list/save; $C -s -b $J $B/routes/review | grep -o "Review: [^<]*"
echo "--- csrf missing"; for r in routes/list/save routes/list/delete routes/rule/add routes/rule/delete routes/rule/toggle routes/protect routes/confirm routes/cancel; do $C -s -b $J -o /dev/null -w "$r %{http_code}\n" -d 'name=a' $B/$r; done
echo "--- unauth"; $C -s -o /dev/null -w '%{http_code}\n' $B/routes
echo "--- unknown list edit"; $C -s -b $J -c $J -L "$B/routes/list?name=zz" | grep -o "Unknown list"
kill $W
