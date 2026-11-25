for d in t8:run5.sh t13:runweb.sh t13:runweb2.sh t15:run.sh t16:run.sh t17:run.sh t18:run.sh t19:run.sh t21:run.sh t24:run.sh t20:run.sh t27:run.sh t28:run.sh t29:run.sh t31:run.sh; do
  dir=${d%%:*}; f=${d##*:}
  pkill -f "l2tp-gw-web" 2>/dev/null; sleep 1
  ( cd $dir && timeout 150 bash $f > out.new 2>&1 < /dev/null )
  echo "== $d pass=$(grep -c '^PASS\|^OK' $dir/out.new) fail=$(grep -c '^FAIL\|FAILED' $dir/out.new)"
  grep '^FAIL' $dir/out.new | head -4
done
pkill -f "l2tp-gw-web"
echo ALLDONE
