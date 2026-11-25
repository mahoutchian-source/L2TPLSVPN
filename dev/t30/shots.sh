# visual check: fixture with several sites, screenshots in dark and light (needs playwright + chromium)
export PATH=$PWD/bin:$PATH CONF_DIR=$PWD/c IPSEC_CONF=$PWD/ipsec.conf IPSEC_D=$PWD/ipd PPP_DIR=$PWD/ppp XL2TPD_CONF=$PWD/x/x.conf SECRETS=$PWD/sec NO_RESTART=1 STATE_DIR=$PWD/st UNIT_DIR=$PWD/units L2TP_GW=$PWD/../build/l2tp-gw SYS_NET=/sys/class/net IPSEC_RECHECK_WAIT=0
rm -rf c ipd ppp x st units ipt sec ipsec.conf run; mkdir -p c ipd ppp/ip-up.d x st units run
cp ../t8/c/web.conf c/; sed -i "s/^password = .*/password = testpass123/" c/web.conf
printf 'enabled = yes\npublic_ip = 198.51.100.10\npsk = SharedPsk12345\npool = 10.99.99.0/24\n' > c/dialin.conf
: > c/sites.conf
i=0; for n in nttlinka nttlinkb noapcolinka noapcolinkb setudalinka setudalinkb setudalink3; do i=$((i+1)); printf "[$n]\nhost = 9.9.9.$i\npsk = p$i\nuser = u$i\npass = pw$i\nroutes = 10.$i.0.0/24\n" >> c/sites.conf; [ $n = setudalinka ] && printf 'ipsec_mode = allow\nmtu = 1400\n' >> c/sites.conf; echo >> c/sites.conf; done
for n in home millionex hamidca; do i=$((i+1)); printf "[$n]\nmode = server\nuser = $n\npass = password$i\nip = 10.99.99.$i\n\n" >> c/sites.conf; done
ip link set lo up
for n in nttlinka nttlinkb noapcolinka noapcolinkb setudalinka setudalinkb home millionex; do
  ip link del ppp-$n 2>/dev/null; ip tuntap add dev ppp-$n mode tun; ip link set ppp-$n up; done
ip addr add 172.17.1.1 peer 172.17.1.2/32 dev ppp-nttlinka; ip addr add 172.17.2.1 peer 172.17.2.2/32 dev ppp-nttlinkb
ip addr add 172.17.3.1 peer 172.17.3.2/32 dev ppp-noapcolinka; ip addr add 172.17.4.1 peer 172.17.4.2/32 dev ppp-noapcolinkb
ip addr add 172.17.5.1 peer 172.17.5.2/32 dev ppp-setudalinka; ip addr add 172.17.6.1 peer 172.17.6.2/32 dev ppp-setudalinkb
ip addr add 10.99.99.1 peer 10.99.99.8/32 dev ppp-home
{ echo "Security Associations (5 up, 0 connecting):"; for n in nttlinka nttlinkb noapcolinka noapcolinkb setudalinkb; do echo "$n[1]: ESTABLISHED 2 hours ago"; done; } > ipsec.status
python3 -I ../build/l2tp-gw-web run >/dev/null 2>&1 & W=$!; sleep 1.5
python3 traffic.py 45 ppp-nttlinka,172.17.1.2,172.17.1.1,1100,300 ppp-nttlinkb,172.17.2.2,172.17.2.1,500,900 ppp-noapcolinka,172.17.3.2,172.17.3.1,200,200 ppp-setudalinkb,172.17.6.2,172.17.6.1,800,150 ppp-home,10.99.99.8,10.99.99.1,300,500 &
python3 shots.py
kill $W
for n in nttlinka nttlinkb noapcolinka noapcolinkb setudalinka setudalinkb home millionex; do ip link del ppp-$n 2>/dev/null; done
