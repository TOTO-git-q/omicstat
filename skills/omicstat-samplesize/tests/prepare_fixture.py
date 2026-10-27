"""Copy a synthetic design declaration for contract tests, never real owner data."""
import argparse,pathlib,shutil
p=argparse.ArgumentParser();p.add_argument('--outdir',required=True);a=p.parse_args()
out=pathlib.Path(a.outdir);out.mkdir(parents=True,exist_ok=True)
source=pathlib.Path(__file__).parent/'fixtures/study_contract.json'
dest=out/'study_contract.json'
if dest.exists() and dest.read_bytes()!=source.read_bytes():raise ValueError('refuse to replace a different study declaration')
if not dest.exists():shutil.copyfile(source,dest)
print('Synthetic a priori contract only; no real owner dataset or receipt created.')
