export PATH=$PWD/bin:$PATH CONF_DIR=$PWD/c IPSEC_CONF=$PWD/ipsec.conf IPSEC_D=$PWD/ipd PPP_DIR=$PWD/ppp XL2TPD_CONF=$PWD/x/x.conf SECRETS=$PWD/sec NO_RESTART=1 STATE_DIR=$PWD/st UNIT_DIR=$PWD/units
G=$PWD/../build/l2tp-gw
ip link set lo up
mk(){ ip tuntap add dev ppp-$1 mode tun; ip addr add 172.17.218.3 peer 172.17.192.3 dev ppp-$1; ip link set dev ppp-$1 up; }
mk a
echo "--- no notify.conf: notify-test"; bash $G notify-test; echo "rc=$?"
bash $G watch; ls st; [ -f curl.log ] && echo "curl called (unexpected)" || echo "no curl call (expected)"
printf 'telegram_token = 111:SECRETTOKEN\ntelegram_chat = 42\ndown_after_min = 1\nserver_name = lab\n' > c/notify.conf
echo "--- notify-test"; bash $G notify-test; echo "rc=$?"; cat curl.log; grep -c SECRETTOKEN curl.log; grep ARGS curl.log | grep -c SECRETTOKEN
: > curl.log
echo "--- b is down, not long enough yet"; bash $G watch; ls st; wc -l < curl.log
echo "--- backdate: down for 2 min"; echo $(( $(date +%s) - 120 )) > st/down-b; bash $G watch; grep -c 'text=\[lab\] DOWN: tunnel b' curl.log; ls st
bash $G watch; echo "second run, alert count:"; grep -c 'DOWN: tunnel b' curl.log
echo "--- b comes up"; mk b; bash $G watch; grep -c 'RECOVERED: tunnel b' curl.log; ls st
ip link del ppp-b
echo "--- DDNS change while b down"; rm -f st/down-b st/alerted-b; echo 4.4.4.4 > st/ddns-b; : > curl.log
bash $G watch; cat st/watch.log; cat st/last-ddns-apply >/dev/null && echo "apply stamped"; grep -c 'DDNS address changed' curl.log
: > st/watch.log; bash $G watch; echo "second run within 10 min -> log lines:"; wc -l < st/watch.log
echo "--- DDNS change while b UP: no action"; mk b; echo 4.4.4.4 > st/ddns-b; rm -f st/last-ddns-apply; : > st/watch.log; bash $G watch; wc -l < st/watch.log
echo "--- notify send failure"; touch curl.fail; bash $G notify-test; echo "rc=$?"
