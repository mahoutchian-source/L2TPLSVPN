export PATH=$PWD/bin:$PATH CONF_DIR=$PWD/c STATE_DIR=$PWD/st
G=$PWD/../build/l2tp-gw
echo "-- a:"; bash $G logs a; echo "-- b:"; bash $G logs b
