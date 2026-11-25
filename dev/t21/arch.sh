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
python3 -I ../build/l2tp-gw-web run & W=$!; sleep 1.5
B=http://127.0.0.1:18082; J=cj; rm -f $J; C=/usr/bin/curl
$C -s -c $J -b $J -L -d 'password=pw123456' $B/login > main.html
printf '[cl]\nhost = 9.9.9.9\npsk = clientpsk\nuser = cu\npass = cp\n' > c/sites.conf
bash $GW apply >/dev/null 2>&1
mkdir -p st/traffic/daily
echo "2026-11-01,100,200" > st/traffic/daily/gone.csv
echo "2026-11-01,1,2" > st/traffic/daily/cl.csv
python3 -I ../build/l2tp-gw-web collect >/dev/null 2>&1 & K=$!; sleep 14; kill $K
ls st/traffic st/traffic/daily
python3 -I ../build/l2tp-gw-web run & W=$!; sleep 1.5
B=http://127.0.0.1:18082; J=cj; rm -f $J; C=/usr/bin/curl
$C -s -c $J -b $J -L -d 'password=pw123456' $B/login > main.html
get(){ $C -s -b $J -c $J "$@"; }
get $B/traffic/archive > ar.html; grep -o "gone</td><td>[^<]*" ar.html; grep -o "traffic/archive/csv[^']*" ar.html
d=$(ls st/traffic | grep archive- | head -1)
get "$B/traffic/archive/csv?d=$d&n=gone"
get "$B/traffic/archive/csv?d=../x&n=gone" -w ' code=%{http_code}\n'
get "$B/traffic/archive/csv?d=$d&n=../../etc/passwd" -w ' code=%{http_code}\n'
get $B/traffic | grep -o "(outgoing)\|>Archive<"
kill $W
