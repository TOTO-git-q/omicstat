#!/usr/bin/env python3
"""Prepare exactly reviewed source archives; default is offline, read-only check.

Never resolves latest versions, edits locks/manifests, installs packages, invokes
Docker or changes an image. Explicit --download is a separate authorized source
preparation step. Analysis and candidate builds remain offline.
"""
from __future__ import annotations
import argparse, csv, hashlib, io, json, pathlib, re, shutil, tarfile, tempfile
import urllib.parse, urllib.request
from common import ROOT, manifest, sources, sha, dump
from r_artifacts import candidate_policy, inspect_archive


def https_url(value):
    u = urllib.parse.urlsplit(value)
    if u.scheme != 'https' or not u.hostname or u.username or u.password or u.fragment:
        raise ValueError('source needs HTTPS without credentials or fragments')
    return value


class HTTPSRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        https_url(newurl)
        return super().redirect_request(req, fp, code, msg, headers, newurl)


def description(path, row=None, policy=None):
    """Read bounded source or explicitly allowed PPM metadata without extraction."""
    fields = inspect_archive(path, row, policy)
    deps = []
    for field in ('Depends', 'Imports', 'LinkingTo'):
        for value in fields.get(field, '').split(','):
            if not value.strip(): continue
            match = re.fullmatch(r'\s*([A-Za-z][A-Za-z0-9.]*)\s*(?:\(\s*(>=|<=|==|!=|>|<)\s*([0-9][0-9.-]*)\s*\))?\s*', value)
            if not match: raise ValueError('unsupported dependency metadata: ' + value)
            deps.append(dict(package=match[1], operator=match[2], version=match[3], field=field))
    return fields, deps


def compare_version(actual, required):
    def parts(v):
        if not re.fullmatch(r'[0-9]+(?:[.-][0-9]+)*', v): raise ValueError('unsupported R version: ' + v)
        return [int(x) for x in re.split(r'[.-]', v)]
    a, b = parts(actual), parts(required); n = max(len(a), len(b)); a += [0] * (n-len(a)); b += [0] * (n-len(b))
    return (a > b) - (a < b)


def dependency_check(metadata, base, order):
    available = dict(base); errors = []; graph = []
    for package in order:
        fields, deps = metadata[package]
        for dep in deps:
            name = dep['package']; actual = available.get(name); okay = actual is not None
            if okay and dep['operator']:
                c = compare_version(actual, dep['version'])
                okay = {'>=':c >= 0, '<=':c <= 0, '>':c > 0, '<':c < 0, '==':c == 0, '!=':c != 0}[dep['operator']]
            graph.append(dict(package=package, dependency=name, field=dep['field'], constraint=dep['operator'], required=dep['version'], actual=actual, satisfied=okay))
            if not okay: errors.append('unsatisfied dependency/order: ' + package + ' -> ' + name)
        available[package] = fields['Version']
    return graph, errors


def prepare(candidate, root=ROOT, *, expected_lock_sha256=None, download=False, source_cache=None):
    root = pathlib.Path(root).resolve(); candidate = pathlib.Path(candidate).resolve()
    m = manifest(candidate, root)
    if m['lane'] != 'R': raise ValueError('this locked R source preparer does not resolve Python candidates')
    lock = candidate / 'sources.lock.json'; lock_hash = sha(lock); manifest_hash = sha(candidate/'manifest.json')
    if expected_lock_sha256 and lock_hash != expected_lock_sha256: raise ValueError('request source-lock SHA mismatch')
    rows = sources(candidate); names = [r['package'] for r in rows]
    if len(set(names)) != len(names) or set(names) != set(m['new_packages']) or not rows:
        raise ValueError('source lock must cover every additive package exactly once')
    order = m.get('install_order', [])
    if len(order) != len(names) or set(order) != set(names): raise ValueError('complete explicit install order required')
    if m.get('sources'):
        declared = {r['package']:r for r in m['sources']}
        if set(declared) != set(names) or any(any(declared[r['package']].get(k) != r[k] for k in r) for r in rows):
            raise ValueError('manifest and source lock identities differ')
    policy = candidate_policy(m, rows, root)
    for row in rows: https_url(row['url'])
    basepath = root/'env/pkg_lock.csv'; base = {}
    for row in csv.DictReader(io.StringIO(basepath.read_text())):
        base[row.get('package',row.get('Package'))] = row.get('version',row.get('Version'))
    config = json.loads((root/'env/r-env.json').read_text()); base['R'] = config['r_version']
    if any(p in base for p in names): raise ValueError('source lock would replace inherited package')
    if m['base_image'] != config['image']+':'+config['image_tag']:
        raise ValueError('candidate needs its actual parent inventory; cannot use unrelated baseline')
    folder = candidate/'sources'
    if folder.is_symlink(): raise ValueError('source cache symlink is forbidden')
    if download or source_cache: folder.mkdir(exist_ok=True)
    metadata = {}; errors = []; inventory = []
    for row in rows:
        path = folder/row['filename']; state = 'missing'
        if path.is_symlink(): raise ValueError('source archive symlink is forbidden')
        if not path.exists() and (download or source_cache):
            fd, temp = tempfile.mkstemp(prefix='locked-', suffix='.part', dir=folder)
            import os
            os.close(fd); tmp = pathlib.Path(temp)
            try:
                if source_cache:
                    cached = pathlib.Path(source_cache)/row['filename']
                    if not cached.is_file() or cached.is_symlink(): raise ValueError('external cache missing/unsafe: '+row['filename'])
                    shutil.copyfile(cached,tmp)
                else:
                    opener = urllib.request.build_opener(HTTPSRedirect())
                    with opener.open(row['url'], timeout=120) as response, tmp.open('wb') as target:
                        https_url(response.geturl()); total = 0
                        while block := response.read(1024*1024):
                            total += len(block)
                            if total > 256*1024**2: raise ValueError('source exceeds 256 MiB bound')
                            target.write(block)
                if sha(tmp) != row['sha256']: raise ValueError('download/cache source SHA mismatch: '+row['filename'])
                fields, deps = description(tmp, row, policy)
                if fields.get('Package') != row['package'] or fields.get('Version') != row['version']:
                    raise ValueError('source package/version mismatch')
                tmp.replace(path)
            finally:
                if tmp.exists(): tmp.unlink()
        if path.is_file():
            if sha(path) != row['sha256']: errors.append('source SHA mismatch: '+row['filename']); state = 'hash_mismatch'
            else:
                fields, deps = description(path, row, policy)
                if fields.get('Package') != row['package'] or fields.get('Version') != row['version']:
                    errors.append('source identity mismatch: '+row['filename']); state = 'identity_mismatch'
                else: metadata[row['package']] = (fields,deps); state = 'verified_binary' if row['kind'] == 'ppm_binary' else 'verified_source'
        else: errors.append('missing source: '+row['filename'])
        inventory.append({**row, 'state':state})
    graph = []
    if len(metadata) == len(rows):
        graph, dependency_errors = dependency_check(metadata,base,order); errors += dependency_errors
    if sha(lock) != lock_hash or sha(candidate/'manifest.json') != manifest_hash: raise ValueError('source preparation changed a reviewed lock/manifest')
    return dict(schema='omicstat.source-preparation.v1',candidate=m['id'],state='blocked' if errors else 'ready_for_offline_build',
                source_lock_sha256=lock_hash,manifest_sha256=manifest_hash,base_inventory_sha256=sha(basepath),
                sources=inventory,dependency_edges=graph,dependency_closure_verified=len(metadata)==len(rows) and not errors,
                errors=errors,artifact_policy=policy,actual_parent_runtime_verified=False,locks_unchanged=True,installed=False,image_built=False,network='explicit_download' if download else 'none')


def main():
    p = argparse.ArgumentParser(description=__doc__); p.add_argument('candidate',type=pathlib.Path); p.add_argument('--root',type=pathlib.Path,default=ROOT)
    p.add_argument('--lock-sha256',required=True); group=p.add_mutually_exclusive_group(); group.add_argument('--download',action='store_true'); group.add_argument('--source-cache',type=pathlib.Path); group.add_argument('--check',action='store_true')
    p.add_argument('--out',type=pathlib.Path); a=p.parse_args()
    try: result=prepare(a.candidate,a.root,expected_lock_sha256=a.lock_sha256,download=a.download,source_cache=a.source_cache)
    except (ValueError,OSError,tarfile.TarError) as error: result=dict(state='blocked',error=str(error),installed=False,image_built=False)
    if a.out: a.out.parent.mkdir(parents=True,exist_ok=True); a.out.write_text(dump(result))
    print(dump(result)); return int(result['state'] != 'ready_for_offline_build')
if __name__ == '__main__': raise SystemExit(main())
