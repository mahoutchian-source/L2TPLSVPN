export CONF_DIR=$PWD/c AUTOBACKUP_DIR=$PWD/ab STATE_DIR=$PWD/st DIALIN=$PWD/c/dialin.conf SITES=$PWD/c/sites.conf
GW=$PWD/../build/l2tp-gw
printf '[x]\nhost = 1.1.1.1\npsk = k\nuser = u\npass = p\n' > c/sites.conf
bash $GW backup-auto; ls ab | wc -l
bash $GW backup-auto; ls ab | wc -l      # unchanged: still 1
printf '[y]\nhost = 2.2.2.2\npsk = k\nuser = u\npass = p\n' >> c/sites.conf
sleep 1; bash $GW backup-auto; ls ab | wc -l; grep -c '^\[' ab/*.conf   # changed same day: replaced, still 1 file with 2 sites
for d in 1 2 3 4 5 6 7 8 9; do touch -d "2020-01-0$d" ab/sites-2020010$d-000000.conf; done
bash $GW backup-auto; echo "after:"; ls ab | wc -l; stat -c %a ab ab/*.conf | sort -u | tr '\n' ' '
