"""Copy only project-invented inputs. Real anchors and owner data stay separate."""
import argparse,hashlib,json,pathlib,shutil

def copy_fixture(out,source=None):
    source=source or pathlib.Path(__file__).parent/'fixtures'
    manifest=json.loads((source/'SOURCE.json').read_text())
    if manifest['real_owner_data'] is not False or 'Project-invented' not in manifest['data_origin']:
        raise ValueError('only the declared project-invented contract fixture is allowed')
    expected={r['path'] for r in manifest['files']}
    if expected != {p.name for p in source.iterdir() if p.name!='SOURCE.json'}:
        raise ValueError('synthetic source inventory differs')
    files=[]
    for row in manifest['files']:
        path=pathlib.PurePosixPath(row['path'])
        if len(path.parts)!=1 or path.name in ('.','..'):
            raise ValueError('unsafe synthetic fixture filename')
        src=source/path.name
        if src.is_symlink() or not src.is_file():raise ValueError('unsafe synthetic input')
        raw=src.read_bytes()
        if len(raw)!=row['bytes'] or hashlib.sha256(raw).hexdigest()!=row['sha256']:
            raise ValueError('synthetic fixture hash mismatch')
        files.append((src,raw))
    files.append((source/'SOURCE.json',(source/'SOURCE.json').read_bytes()))
    out=pathlib.Path(out);out.mkdir(parents=True,exist_ok=True)
    for src,raw in files:
        dest=out/src.name
        if dest.is_symlink() or (dest.exists() and dest.read_bytes()!=raw):
            raise ValueError('refuse to replace a different fixture')
    for src,raw in files:
        dest=out/src.name
        if not dest.exists():shutil.copyfile(src,dest)
    return manifest

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--outdir',required=True);a=p.parse_args()
    manifest=copy_fixture(a.outdir)
    print(f"Prepared {len(manifest['files'])} invented inputs; no official rows or owner receipt created.")
