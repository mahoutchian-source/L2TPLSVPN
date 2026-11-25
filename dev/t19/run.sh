export CONF_DIR=$PWD/c STATE_DIR=$PWD/st NO_RESTART=1
mkdir -p c st
ip link set lo up
printf 'password = pw123456\nbind = 127.0.0.1\nport = 18083\ntls = on\n' > c/web.conf
python3 -I ../build/l2tp-gw-web run & W=$!; sleep 2
C=/usr/bin/curl; B=https://127.0.0.1:18083
ls -l c/web.key c/web.crt | awk '{print $1, $NF}'
echo "--- https works (self-signed, -k)"; $C -sk -o /dev/null -w '%{http_code}\n' $B/login
echo "--- certificate / protocol"; echo | openssl s_client -connect 127.0.0.1:18083 2>/dev/null | grep -E "Protocol|subject=" | head -2
echo "--- TLS 1.1 refused"; echo | openssl s_client -tls1_1 -connect 127.0.0.1:18083 2>&1 | grep -ci "alert\|handshake failure\|no protocols\|unsupported" 
echo "--- plain http to the https port does not hang the server"; $C -s -m 5 -o /dev/null -w 'plain http: %{http_code}\n' http://127.0.0.1:18083/login
echo "--- a stalled client does not block others"
python3 - <<'PY' &
import socket, time
s = socket.create_connection(("127.0.0.1", 18083)); time.sleep(8)
PY
sleep 1; $C -sk -m 5 -o /dev/null -w 'other client: %{http_code} in %{time_total}s\n' $B/login
echo "--- cookie has Secure + HttpOnly"
$C -sk -D - -o /dev/null -d 'password=pw123456' $B/login | grep -i "set-cookie"
echo "--- lockout: 5 wrong, then even the right password is refused"
for i in 1 2 3 4 5; do $C -sk -o /dev/null -w '%{http_code} ' -d 'password=wrong' $B/login; done; echo
$C -sk -w '\n%{http_code}\n' -d 'password=pw123456' $B/login | grep -o "Too many wrong passwords[^<]*\|^[0-9]*$"
kill $W
