import importlib.machinery, importlib.util, os, shutil
ROOT=os.path.abspath("work2"); shutil.rmtree(ROOT,ignore_errors=True)
os.makedirs(ROOT+"/conf"); os.makedirs(ROOT+"/state")
os.environ.update(CONF_DIR=ROOT+"/conf",STATE_DIR=ROOT+"/state",SYS_NET=ROOT+"/sys")
l=importlib.machinery.SourceFileLoader("gw",os.path.abspath("../build/l2tp-gw-web"))
sp=importlib.util.spec_from_loader("gw",l); m=importlib.util.module_from_spec(sp); l.exec_module(m)
c=m.Collector()
for n in("a","b"):
    c.daily[n]={"2026-11-01":[5,6]}; c.dirty_daily.add(n); c.state["quota"][n]={"down":9,"up":9,"reset_at":1,"warned":True,"over":True}
c.flush(1)
open(m.TRAFFIC_DIR+"/reset-site.a","w").close()
c.apply_resets([{"name":"a"},{"name":"b"}],100); c.flush(101)
d=m.TRAFFIC_DIR
assert not os.path.exists(d+"/daily/a.csv") and os.path.exists(d+"/daily/b.csv")
arch=[x for x in os.listdir(d) if x.startswith("archive-")]; assert arch and os.path.exists(d+"/"+arch[0]+"/a.csv")
assert c.state["quota"]["a"]["down"]==0 and c.state["quota"]["b"]["down"]==9
assert not os.path.exists(d+"/reset-site.a")
print("PASS")
