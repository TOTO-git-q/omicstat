"""Write one shared offline fixture and Python outcomes for R parity checks."""
import json,pathlib,sys,warnings
from test_idmap import fixture
from ospy.idmap import os_idmap
root=pathlib.Path(sys.argv[1]);root.mkdir(parents=True,exist_ok=True)
reg,_=fixture(root)
for policy in ("first","drop","expand"):
    with warnings.catch_warnings():
        warnings.simplefilter("ignore")
        result=os_idmap(["A","B","missing","A"],"SYMBOL","ENTREZID","Homo sapiens","test_human",policy=policy,registry=reg)
    (root/(policy+".json")).write_text(json.dumps(result))
