from pathlib import Path
import sys,subprocess,json,hashlib
root=Path(__file__).resolve().parents[3];fx=Path(sys.argv[1]);out=Path(sys.argv[2]);args=['--input', '{fx}/counts-feature.csv', '--input-format', 'csv', '--metadata', '{fx}/metadata.csv', '--organism', 'Homo sapiens', '--feature-type', 'symbol', '--mito-pattern', '^MT-', '--missing-mito', 'zero', '--min-cells', '0', '--create-min-features', '0', '--min-features', '0', '--max-features', '10000', '--min-counts', '1', '--max-counts', '1000000', '--max-mito', '100', '--outdir', '{out}']
args=[x.replace('{fx}',str(fx)).replace('{out}',str(out))for x in args]
r=subprocess.run(['Rscript',str(root/'skills/seurat-qc/scripts/run_seurat_qc.R'),*args]);
if r.returncode:raise SystemExit(r.returncode)
h=json.loads((out/'objects/handoff.json').read_text());objects=[v for v in h['objects']if v['type']=='Seurat'];assert len(objects)==1;p=Path(objects[0]['path']);p=p if p.is_absolute()else out/p
j=json.loads((fx/'coordinate-provenance.json').read_text());j['input_sha256']=hashlib.sha256(p.read_bytes()).hexdigest();j['source']='Actual seurat-qc output; coordinates unchanged';(fx/'upstream-r.json').write_text(json.dumps(j))
