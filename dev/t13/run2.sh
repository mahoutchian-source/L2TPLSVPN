export PATH=$PWD/bin:$PATH CONF_DIR=$PWD/c STATE_DIR=$PWD/st UNIT_DIR=$PWD/units NO_RESTART=1 IPSEC_GRACE=0
GW=$PWD/../build/l2tp-gw
ip link set lo up
ip tuntap add dev ppp-only mode tun; ip addr add 172.17.218.3 peer 172.17.192.3 dev ppp-only; ip link set dev ppp-only up
ok(){ if eval "$2"; then echo "PASS $1"; else echo "FAIL $1"; fi; }
rm -f st/*; : > curl.log
# real output seen on the server: site "only" has NO IKE line, only a child SA under another site's IKE SA
cat > ipsec.status <<'EOT'
Security Associations (1 up, 0 connecting):
    first[48]: ESTABLISHED 2 hours ago, 172.26.2.106[172.26.2.106]...44.44.97.217[44.44.97.217]
    first{304}:  INSTALLED, TRANSPORT, reqid 3, ESP in UDP SPIs: c818da75_i db18bec4_o
    only{305}:  INSTALLED, TRANSPORT, reqid 3, ESP in UDP SPIs: cfafae39_i a45ea292_o
EOT
bash $GW watch; ok "child-SA-only site: no alert" "[ ! -f st/noipsec-only ] && ! grep -q WITHOUT curl.log"
bash $GW check 2>&1 | grep -q "only: IPsec established"; ok "check: child-SA-only site is OK" "[ \$? = 0 ]"
bash $GW check 2>&1 | grep -q "NOT established"; ok "check: no 'NOT established' line" "[ \$? != 0 ]"
# a different site's lines must not count: names are matched as whole words
cat > ipsec.status <<'EOT'
Security Associations (1 up, 0 connecting):
    onlyx[1]: ESTABLISHED 2 hours ago
    onlyx{9}:  INSTALLED, TRANSPORT
    first{304}:  INSTALLED, TRANSPORT
EOT
bash $GW watch; ok "name 'onlyx' does not count for site 'only'" "[ -f st/noipsec-only ] && grep -q WITHOUT curl.log"
# only the config line (like 'home' on the server): still detected
rm -f st/*; : > curl.log
printf 'Security Associations (0 up, 0 connecting):\n  none\n' > ipsec.status
bash $GW watch; ok "no SA at all -> alert" "grep -q WITHOUT curl.log"
