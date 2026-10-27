from pathlib import Path
import sys,subprocess,json,hashlib,os
root=Path(__file__).resolve().parents[3];fx=Path(sys.argv[1]);out=Path(sys.argv[2]);args=['--input',str(fx/'input.h5ad'),'--species','Homo sapiens','--annotation','synthetic-v1','--sample-col','sample','--counts-layer','counts','--mito-prefix','MT-','--min-genes','1','--max-genes','10000','--min-counts','1','--max-counts','1000000','--max-mito-percent','100','--min-cells','1','--doublet-mode','skip','--study-contract',str(fx/'contract.json'),'--seed','7','--outdir',str(out)]
upstream_python=os.environ.get('OMICSTAT_NATIVE_UPSTREAM_PYTHON',sys.executable)
if not Path(upstream_python).is_absolute()or not Path(upstream_python).is_file():raise ValueError('Explicit upstream interpreter must be an existing absolute file')
print('Actual accepted-producer interpreter: '+upstream_python,flush=True)
r=subprocess.run([upstream_python,str(root/'skills/scanpy-qc/scripts/run_scanpy_qc.py'),*args]);
if r.returncode:raise SystemExit(r.returncode)
h=json.loads((out/'objects/handoff.json').read_text());objects=[v for v in h['objects']if v['type']=='AnnData'];assert len(objects)==1;p=Path(objects[0]['path']);p=p if p.is_absolute()else out/p
prov=json.loads((fx/'layers.json').read_text());prov['input_sha256']=hashlib.sha256(p.read_bytes()).hexdigest();prov['carrier_transformation']='Actual scanpy-qc output; original quantification fixture unchanged';(fx/'qc-layers.json').write_text(json.dumps(prov))
