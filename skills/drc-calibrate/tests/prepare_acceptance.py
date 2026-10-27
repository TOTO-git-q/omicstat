import pathlib,runpy,sys
root=pathlib.Path(__file__).resolve().parents[3]
sys.argv=[str(root/'tests/candidate-models/prepare.py'),'drc-calibrate',*sys.argv[1:]]
runpy.run_path(sys.argv[0],run_name='__main__')

import csv,copy
out=pathlib.Path(sys.argv[-1])
with (out/'plate.csv').open() as f: reader=csv.DictReader(f);fields=reader.fieldnames+['bio'];rows=list(reader)
for row in rows:row['bio']=row['sample_id'] if row['role']=='unknown' else ''
for name,mutate in [('blank-unit.csv',''),('split-unit.csv','different_subject')]:
 data=copy.deepcopy(rows);next(row for row in data if row['role']=='unknown')['bio']=mutate
 with (out/name).open('w') as f:w=csv.DictWriter(f,fieldnames=fields);w.writeheader();w.writerows(data)
