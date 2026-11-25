GWNEW=$PWD/../build/l2tp-gw; GWOLD=$PWD/../build/l2tp-gw.v11
gen(){ # gen SCRIPT OUTDIR
  export PATH=$PWD/bin:$PATH CONF_DIR=$2/c IPSEC_CONF=$2/ipsec.conf IPSEC_D=$2/ipd PPP_DIR=$2/ppp XL2TPD_CONF=$2/x/x.conf SECRETS=$2/sec NO_RESTART=1 STATE_DIR=$2/st UNIT_DIR=$2/units
  rm -rf $2 ipt; mkdir -p $2/c $2/ipd $2/ppp/ip-up.d $2/x $2/st $2/units
  echo "include $2/ipd/*.conf" > $2/ipsec.conf
  cat > $2/c/sites.conf <<'S'
[nttlinka]
host = 44.44.97.217
psk = p1
user = u1
pass = w1
routes = 172.17.192.0/22 metric 2
nat = yes
reconnect_every = 6
quota_gb = 20
[home]
host = hf809bct9xp.sn.mynetname.net
psk = p2
user = u2
pass = w2
ipsec_mode = require
mppe = yes
routes = 172.17.248.0/24 metric 2, 10.0.0.0/8
S
  bash $1 apply >/dev/null 2>&1
  cp ipt/rules $2/ipt.rules
}
ip link set lo up
gen $GWOLD /tmp/claude-0/sameA; gen $GWNEW /tmp/claude-0/sameB
for f in sec x/x.conf ipd/nttlinka.conf ipd/home.conf ppp/options.l2tpd.nttlinka ppp/options.l2tpd.home c/routes.d/nttlinka c/routes.d/home ppp/ip-up.d/l2tp-gw ppp/ip-down.d/l2tp-gw; do
  if diff <(sed 's#/tmp/claude-0/same[AB]##g' /tmp/claude-0/sameA/$f) <(sed 's#/tmp/claude-0/same[AB]##g' /tmp/claude-0/sameB/$f) >/dev/null; then echo "SAME $f"; else echo "DIFF $f"; diff <(sed 's#/tmp/claude-0/same[AB]##g' /tmp/claude-0/sameA/$f) <(sed 's#/tmp/claude-0/same[AB]##g' /tmp/claude-0/sameB/$f) | head -5; fi
done
echo "--- iptables rules (only difference allowed: the new empty L2TPGW-IN chain)"
diff <(sed 's#/tmp/claude-0/same[AB]##g' /tmp/claude-0/sameA/ipt.rules) <(sed 's#/tmp/claude-0/same[AB]##g' /tmp/claude-0/sameB/ipt.rules)
