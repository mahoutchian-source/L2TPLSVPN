export PATH=$PWD/bin:$PATH CONF_DIR=$PWD/c STATE_DIR=$PWD/st NO_RESTART=1 L2TP_GW=$PWD/../build/l2tp-gw
ip link set lo up
printf '[only]\nhost = 9.9.9.9\npsk = k\nuser = u\npass = p\n' > c/sites.conf
python3 -I ../build/l2tp-gw-web run & W=$!; sleep 1
B=http://127.0.0.1:18084; J=cj; rm -f $J; C=/usr/bin/curl
$C -s -c $J -b $J -L -d 'password=pw123456' $B/login > m.html
CS=$(grep -o "name=csrf value='[^']*'" m.html | head -1 | sed "s/.*value='//;s/'//")
$C -s -b $J -c $J -d "csrf=$CS" --data-urlencode name=only --data-urlencode orig=only --data-urlencode host=9.9.9.9 --data-urlencode user=u -d "ipsec_mode=allow&nat=yes" $B/save > save.html
python3 - <<'PY'
import re,html
t=open('save.html').read()
t=re.sub(r'<style.*?</style>','',t,flags=re.S)
t=re.sub(r'<script.*?</script>','',t,flags=re.S)
print(re.sub(r'\s+',' ',html.unescape(re.sub(r'<[^>]+>',' ',t)))[:700])
PY
kill $W
