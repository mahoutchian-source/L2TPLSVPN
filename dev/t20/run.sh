export PATH=$PWD/bin:$PATH CONF_DIR=$PWD/c IPSEC_CONF=$PWD/ipsec.conf IPSEC_D=$PWD/ipd PPP_DIR=$PWD/ppp XL2TPD_CONF=$PWD/x/x.conf SECRETS=$PWD/sec NO_RESTART=1 STATE_DIR=$PWD/st UNIT_DIR=$PWD/units
GW=$PWD/../build/l2tp-gw
rm -rf c ipd ppp x st units ipt calls sec ipsec.conf curl.log
mkdir -p c ipd ppp/ip-up.d x st units
printf '#!/bin/sh\nrun-parts /etc/ppp/ip-up.d\n' > ppp/ip-up; printf '#!/bin/sh\nrun-parts /etc/ppp/ip-down.d\n' > ppp/ip-down
sed -i 's#run-parts /etc/ppp/ip-up.d#for f in ip-up.d; do :; done#' ppp/ip-up
echo "include $IPSEC_D/*.conf" > ipsec.conf
ip link set lo up
ip tuntap add dev ens5 mode tun; ip addr add 172.26.2.106/20 dev ens5; ip link set ens5 up
ok(){ if eval "$2"; then echo "PASS $1"; else echo "FAIL $1"; fi; }
echo "Security Associations (0 up, 0 connecting):" > ipsec.status
# ---- an existing client site (must be untouched by dial-in)
cat > c/sites.conf <<'S'
[cl]
host = 9.9.9.9
psk = clientpsk
user = cu
pass = cp
routes = 172.30.0.0/16 metric 2
nat = yes
[hm]
host = 8.8.8.8
psk = hp
user = hu
pass = hp
ipsec_mode = require
S
bash $GW apply >/dev/null 2>&1; echo "client-only apply rc=$?"
cp ipd/cl.conf cl.before; cp x/x.conf x.before; cp sec sec.before
ok "dial-in off: no dial-in files" "[ ! -f ipd/l2tp-gw-dialin.conf ] && [ ! -f ppp/options.l2tpd.dialin ] && ! grep -q 'lns default' x/x.conf"
ok "dial-in off: no firewall change at all" "! grep -q L2TPGW-IN ipt/rules"
ok "dial-in off: no chap-secrets block" "! grep -q 'BEGIN l2tp-gw' ppp/chap-secrets"

# ---- enable dial-in
cat > c/dialin.conf <<'S'
enabled = yes
public_ip = 3.4.5.6
psk = SharedPsk12345
pool = 10.99.99.0/24
S
cat >> c/sites.conf <<'S'
[office]
mode = server
user = office
pass = officepass1
ip = 10.99.99.11
routes = 192.168.50.0/24 metric 2, 192.168.51.0/24
nat = yes
[shop]
mode = server
user = shop
pass = shop-pass-2
ip = 10.99.99.12
disabled = yes
S
bash $GW apply 2>&1 | tail -2; echo "apply rc=$?"
ok "ipsec conn written" "grep -q 'conn l2tp-gw-dialin' ipd/l2tp-gw-dialin.conf && grep -q 'right=%any' ipd/l2tp-gw-dialin.conf && grep -q 'leftid=3.4.5.6' ipd/l2tp-gw-dialin.conf && grep -q 'auto=add' ipd/l2tp-gw-dialin.conf"
ok "shared PSK in ipsec.secrets, client PSK still there" "grep -q '%any %any : PSK \"SharedPsk12345\"' sec && grep -q 'PSK \"clientpsk\"' sec"
ok "xl2tpd [lns default] with assign ip = no and the local ip" "grep -q '^\[lns default\]' x/x.conf && grep -q 'assign ip = no' x/x.conf && grep -q 'local ip = 10.99.99.1' x/x.conf && grep -q '^\[lac cl\]' x/x.conf"
ok "pppd options for the server side" "grep -q '^auth$' ppp/options.l2tpd.dialin && grep -q 'refuse-pap' ppp/options.l2tpd.dialin && [ \$(stat -c %a ppp/options.l2tpd.dialin) = 600 ]"
ok "chap-secrets: enabled site only, fixed address, 600" "grep -q '\"office\" \* \"officepass1\" 10.99.99.11' ppp/chap-secrets && ! grep -q shop ppp/chap-secrets && [ \$(stat -c %a ppp/chap-secrets) = 600 ]"
ok "route file + address file for dial-in site" "grep -q '192.168.50.0/24 2' c/routes.d/office && grep -q '192.168.51.0/24 100' c/routes.d/office && [ \$(sed -n 1p c/dialin-ip.d/office) = 10.99.99.11 ]"
ok "client site files unchanged" "cmp -s ipd/cl.conf cl.before"
ok "firewall: ipsec accept, plain accept for cl only (hm is require), then drop" "grep -q '^A L2TPGW-IN -p udp --dport 1701 -m policy --dir in --pol ipsec -j ACCEPT' ipt/rules && grep -q '^A L2TPGW-IN -s 9.9.9.9 -p udp --dport 1701 -j ACCEPT' ipt/rules && ! grep -q '^A L2TPGW-IN .*8.8.8.8' ipt/rules && grep -q '^A L2TPGW-REQ -s 8.8.8.8 -p udp --dport 1701 -m policy --dir in --pol ipsec -j ACCEPT' ipt/rules && grep -q '^A L2TPGW-REQ -s 8.8.8.8 -p udp --dport 1701 -j DROP' ipt/rules && ! grep -q 'L2TPGW-REQ.*9.9.9.9' ipt/rules && grep -q 'L2TPGW-IN -p udp --dport 1701 -j DROP' ipt/rules"
ok "NAT toward the networks behind the dial-in router" "grep -q '^A L2TPGW-NAT -d 192.168.50.0/24 -o ppp+ -j MASQUERADE' ipt/rules && grep -q '^A L2TPGW-NAT -o ppp-cl -j MASQUERADE' ipt/rules"
ok "applied hash stored" "[ -s st/dialin.applied ]"

# ---- a dial-in session comes up (a tun device playing ppp0 with the fixed peer address)
ip tuntap add dev ppp0 mode tun; ip addr add 10.99.99.1 peer 10.99.99.11 dev ppp0; ip link set ppp0 up
bash $GW routes-sync ppp0 up
ok "routes of the dial-in site go to ppp0" "ip route show 192.168.50.0/24 | grep -q 'dev ppp0 .*metric 2' && ip route show 192.168.51.0/24 | grep -q 'dev ppp0'"
bash $GW check 2>&1 | grep -E "office|shop|dial-in|l2tp-gw-dialin|1701" 
ok "check: connected + route lines" "bash $GW check 2>&1 | grep -q 'office: dial-in connected (ppp0, router address 10.99.99.11)'"
bash $GW check 2>&1 | grep -q "shop: dial-in site is switched off"; ok "check: switched-off site" "[ \$? = 0 ]"
# session ends
ip link set ppp0 down; ip tuntap del dev ppp0 mode tun
bash $GW routes-sync ppp0 down
ok "routes removed when the session is gone" "! ip route show 192.168.50.0/24 | grep -q ppp0"
bash $GW check 2>&1 | grep -q "office: dial-in site is not connected"; ok "check: not connected is only a warning" "[ \$? = 0 ] && ! bash $GW check 2>&1 | grep -q '^FAIL.*office'"
echo "--- list / validate"
bash $GW list | head -8
