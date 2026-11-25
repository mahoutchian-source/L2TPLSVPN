export PATH=$PWD/bin:$PATH CONF_DIR=$PWD/c STATE_DIR=$PWD/st UNIT_DIR=$PWD/units NO_RESTART=1 IPSEC_GRACE=0
GW=$PWD/../build/l2tp-gw
ip link set lo up
ip tuntap add dev ppp-only mode tun; ip addr add 172.17.218.3 peer 172.17.192.3 dev ppp-only; ip link set dev ppp-only up
ok(){ if eval "$2"; then echo "PASS $1"; else echo "FAIL $1"; fi; }
n_alerts(){ grep -c "$1" curl.log 2>/dev/null || true; }
: > curl.log
echo "Security Associations (0 up, 0 connecting):" > ipsec.status
bash $GW watch; ok "first run only starts the timer (grace 0 alerts immediately)" "[ -f st/noipsec-only ]"
ok "alert sent: WITHOUT IPsec" "[ \$(n_alerts 'WITHOUT IPsec') = 1 ]"
bash $GW watch; ok "no duplicate alert" "[ \$(n_alerts 'WITHOUT IPsec') = 1 ]"
echo "           only[1]: ESTABLISHED 5 minutes ago, x[x]...y[y]" >> ipsec.status
bash $GW watch; ok "recovery message sent" "[ \$(n_alerts 'has IPsec again') = 1 ]"
ok "state files removed after recovery" "[ ! -f st/noipsec-only ] && [ ! -f st/noipsec-alerted-only ]"
bash $GW watch; ok "no second recovery message" "[ \$(n_alerts 'has IPsec again') = 1 ]"
# strongSwan not answering: no guess, no alert
echo "Security Associations (0 up, 0 connecting):" > ipsec.status; touch ipsec.fail; : > curl.log
bash $GW watch; ok "ipsec status failing -> no alert and no state" "[ \$(n_alerts 'WITHOUT') = 0 ] && [ ! -f st/noipsec-only ]"
rm -f ipsec.fail
# grace period respected
: > curl.log; ( export IPSEC_GRACE=3600; bash $GW watch ); ok "inside grace: timer starts, no alert" "[ -f st/noipsec-only ] && [ \$(n_alerts 'WITHOUT') = 0 ]"
# PPP goes down: state cleared
ip link set dev ppp-only down; bash $GW watch; ok "ppp down clears noipsec state" "[ ! -f st/noipsec-only ]"
ip link set dev ppp-only up
# check output
bash $GW check 2>&1 | grep -E "WITHOUT|NOT established|IPsec is not" 
bash $GW check 2>&1 | grep -q "PPP is up but IPsec is NOT established" ; ok "check prints the new FAIL line" "[ \$? = 0 ]"
# removed site -> its noipsec files are cleaned by apply
touch st/noipsec-gone st/noipsec-alerted-gone st/down-gone
printf '[only]\nhost = 9.9.9.9\npsk = k\nuser = u\npass = p\n' > c/sites.conf
IPSEC_CONF=$PWD/ipsec.conf IPSEC_D=$PWD/ipd PPP_DIR=$PWD/ppp XL2TPD_CONF=$PWD/x/x.conf SECRETS=$PWD/sec bash -c 'mkdir -p ipd ppp x; printf "config setup\n\ninclude %s/ipd/*.conf\n" "$PWD" > ipsec.conf; bash '$GW' apply >/dev/null 2>&1'
ok "apply removes state of deleted sites" "[ ! -f st/noipsec-gone ] && [ ! -f st/noipsec-alerted-gone ] && [ ! -f st/down-gone ]"
