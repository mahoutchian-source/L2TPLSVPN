cd "$(dirname "$0")"; bash lab.sh 2>&1 | grep -v "^$" | head
GW=$PWD/../build/l2tp-gw; C=$PWD/conf; rm -rf $C; mkdir -p $C/dialin-ip.d $C/site-acc.d
printf 'enabled = yes\npublic_ip = 1.2.3.4\npsk = x\npool = 10.99.99.0/24\nlocal = 10.99.99.1\n' > $C/dialin.conf
setflags() { printf '10.99.99.2\n%s\n' "$1" > $C/dialin-ip.d/A; printf '10.99.99.3\n%s\n' "$2" > $C/dialin-ip.d/B; }
sync() { ip netns exec srv env CONF_DIR=$C bash $GW access-sync "$@" 2>&1; }
png() { ip netns exec "$1" ping -c1 -W1 "$2" >/dev/null 2>&1 && echo yes || echo no; }
chk() { if [ "$2" = "$3" ]; then echo "PASS $1"; else echo "FAIL $1 (got $3, want $2)"; fi; }
setflags "yes yes yes" "yes yes yes"; sync
chk "default: A->internet" yes "$(png cA 8.8.8.8)"
chk "default: A->B" yes "$(png cA 10.99.99.3)"
chk "default: A->site" yes "$(png cA 172.17.1.3)"
chk "default: site->A" yes "$(png site1 10.99.99.2)"
echo "--- A: internet=no"
setflags "no yes yes" "yes yes yes"; sync
chk "A cannot reach internet" no "$(png cA 8.8.8.8)"
chk "A still reaches B" yes "$(png cA 10.99.99.3)"
chk "A still reaches site" yes "$(png cA 172.17.1.3)"
chk "B still reaches internet" yes "$(png cB 8.8.8.8)"
echo "--- A: clients=no"
setflags "yes no yes" "yes yes yes"; sync
chk "A->B blocked" no "$(png cA 10.99.99.3)"
chk "B->A blocked (both ways)" no "$(png cB 10.99.99.2)"
chk "A->internet ok" yes "$(png cA 8.8.8.8)"
chk "A->site ok" yes "$(png cA 172.17.1.3)"
chk "B->internet ok" yes "$(png cB 8.8.8.8)"
echo "--- A: sites=no"
setflags "yes yes no" "yes yes yes"; sync
chk "A->site blocked" no "$(png cA 172.17.1.3)"
chk "site->A blocked" no "$(png site1 10.99.99.2)"
chk "A->B ok" yes "$(png cA 10.99.99.3)"
chk "B->site ok" yes "$(png cB 172.17.1.3)"
echo "--- everything off for A"
setflags "no no no" "yes yes yes"; sync
chk "A->internet no" no "$(png cA 8.8.8.8)"; chk "A->B no" no "$(png cA 10.99.99.3)"; chk "A->site no" no "$(png cA 172.17.1.3)"
chk "B->internet ok" yes "$(png cB 8.8.8.8)"
echo "--- back to all yes: nothing left behind"
setflags "yes yes yes" "yes yes yes"; sync
chk "A->internet" yes "$(png cA 8.8.8.8)"; chk "A->B" yes "$(png cA 10.99.99.3)"; chk "A->site" yes "$(png cA 172.17.1.3)"
chk "chain empty" 0 "$(ip netns exec srv iptables -S L2TPGW-ACC | grep -c -- '^-A')"
echo "--- idempotent: same rules twice = no duplicates"
setflags "no no no" "yes yes yes"; sync; n1=$(ip netns exec srv iptables -S L2TPGW-ACC | grep -c -- '^-A'); sync; n2=$(ip netns exec srv iptables -S L2TPGW-ACC | grep -c -- '^-A'); chk "same count" "$n1" "$n2"
echo "--- client B disconnects (interface skipped) with A clients=no"
setflags "yes no yes" "yes yes yes"; sync ppp1
chk "rules do not mention ppp1" 0 "$(ip netns exec srv iptables -S L2TPGW-ACC | grep -c ppp1)"
echo "--- dial-in off: chain emptied"
sed -i 's/enabled = yes/enabled = no/' $C/dialin.conf; sync
chk "A->B open again" yes "$(png cA 10.99.99.3)"
echo "--- FORWARD jump present once"
sed -i 's/enabled = no/enabled = yes/' $C/dialin.conf; sync; sync
chk "one jump" 1 "$(ip netns exec srv iptables -S FORWARD | grep -c L2TPGW-ACC)"


echo "=== outgoing sites: site-acc.d/NAME = internet sites clients"
setflags "yes yes yes" "yes yes yes"
setsite() { printf '%s\n' "$1" > $C/site-acc.d/s1; printf '%s\n' "$2" > $C/site-acc.d/s2; }
setsite "yes yes yes" "yes yes yes"; sync
chk "site defaults: s1->internet" yes "$(png site1 8.8.8.8)"; chk "s1->s2" yes "$(png site1 172.17.2.3)"; chk "s1->A" yes "$(png site1 10.99.99.2)"
chk "chain empty with defaults" 0 "$(ip netns exec srv iptables -S L2TPGW-ACC | grep -c -- '^-A')"
echo "--- s1: internet=no"
setsite "no yes yes" "yes yes yes"; sync
chk "s1 cannot reach internet" no "$(png site1 8.8.8.8)"; chk "s1 still reaches s2" yes "$(png site1 172.17.2.3)"; chk "s1 still reaches A" yes "$(png site1 10.99.99.2)"
chk "s2 reaches internet" yes "$(png site2 8.8.8.8)"; chk "A still reaches internet" yes "$(png cA 8.8.8.8)"
echo "--- s1: sites=no"
setsite "yes no yes" "yes yes yes"; sync
chk "s1->s2 blocked" no "$(png site1 172.17.2.3)"; chk "s2->s1 blocked (both ways)" no "$(png site2 172.17.1.3)"
chk "s1->internet ok" yes "$(png site1 8.8.8.8)"; chk "s1->A ok" yes "$(png site1 10.99.99.2)"; chk "s2->internet ok" yes "$(png site2 8.8.8.8)"
echo "--- s1: clients=no"
setsite "yes yes no" "yes yes yes"; sync
chk "s1->A blocked" no "$(png site1 10.99.99.2)"; chk "B->s1 blocked (both ways)" no "$(png cB 172.17.1.3)"
chk "s1->s2 ok" yes "$(png site1 172.17.2.3)"; chk "s2->A ok" yes "$(png site2 10.99.99.2)"; chk "s1->internet ok" yes "$(png site1 8.8.8.8)"
echo "--- dial-in OFF: site rules still hold, client rules do not"
setflags "no no no" "yes yes yes"; sed -i 's/enabled = yes/enabled = no/' $C/dialin.conf; sync
chk "s1->A still blocked? (no: no dial-in interfaces counted)" yes "$(png site1 10.99.99.2)"
chk "A->internet open (client rules off)" yes "$(png cA 8.8.8.8)"
setsite "no yes yes" "yes yes yes"; sync
chk "s1 internet still blocked with dial-in off" no "$(png site1 8.8.8.8)"
sed -i 's/enabled = no/enabled = yes/' $C/dialin.conf; setflags "yes yes yes" "yes yes yes"
echo "--- back to defaults"
setsite "yes yes yes" "yes yes yes"; sync
chk "chain empty again" 0 "$(ip netns exec srv iptables -S L2TPGW-ACC | grep -c -- '^-A')"
for n in srv cA cB site1 site2 inet; do ip netns del $n; done
