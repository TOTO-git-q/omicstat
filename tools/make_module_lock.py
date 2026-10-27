#!/usr/bin/env python3
"""Generate or check a Python module lock after pinned-container acceptance.

A captured calls registry and nonempty generated golden manifest are mandatory.
Hashes bind full module sources, fixtures, documentation, shared runtime, tests,
and environment definitions. No fabricated/empty baseline can be sealed.
"""
from __future__ import annotations
import argparse
import ast
import csv
import hashlib
import json
import sys
from pathlib import Path
from seal_python import ROOT, require_locked_environment
sys.path.insert(0, str(ROOT / 'skills/_shared/py'))
from ospy import module_kit as K


def file_sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def version_of(module_dir):
    core, = module_dir.glob('scripts/*_core.py')
    for node in ast.parse(core.read_text()).body:
        if isinstance(node, ast.Assign) and any(isinstance(t, ast.Name) and t.id == 'MODULE_VERSION' for t in node.targets):
            return ast.literal_eval(node.value)
    raise RuntimeError('OS_INVALID_INPUT: MODULE_VERSION is missing')


def build(module):
    environment = require_locked_environment()
    directory = ROOT / 'skills' / module
    if directory.parent != ROOT / 'skills' or not directory.is_dir():
        raise RuntimeError('OS_INVALID_PARAMETER: invalid module directory')
    registry = json.loads((directory / 'scripts/calls_registry.json').read_text())
    if registry.get('default_capture_status') != 'captured_locked_container':
        raise RuntimeError('OS_LOCK_PENDING: export the installed API defaults first')
    manifest = directory / 'tests/golden_manifest.csv'
    if not manifest.is_file():
        raise RuntimeError('OS_LOCK_PENDING: generate a pinned-container golden baseline first')
    lines = manifest.read_text().splitlines()
    rows = list(csv.DictReader(line for line in lines if not line.startswith('#')))
    if not rows or any(len(r.get('sha256', '')) != 64 for r in rows):
        raise RuntimeError('OS_LOCK_PENDING: golden manifest has no complete computed hashes')
    if '# env: ' + K.env_signature_string() not in lines:
        raise RuntimeError('OS_ENVIRONMENT_MISMATCH: golden environment differs from this interpreter')
    verdict = K.golden_check(str(directory), str(directory))
    if verdict['status'] != 'PASS':
        raise RuntimeError('OS_LOCK_MISMATCH: stored golden files do not match their manifest: %s' % verdict)
    record = directory / 'tests/golden/acceptance.json'
    if not record.is_file() or json.loads(record.read_text()).get('numerical_smoke_passed') is not True:
        raise RuntimeError('OS_LOCK_PENDING: numerical smoke acceptance was not recorded')
    files = []
    for base in (directory, ROOT / 'skills/_shared/py/ospy', ROOT / 'skills/_shared/py/tests'):
        files.extend(p for p in base.rglob('*') if p.is_file() and p.name != 'module_lock.json'
                     and '__pycache__' not in p.parts and '.pytest_cache' not in p.parts)
    files += [ROOT / p for p in ('env/py/py-env.json', 'env/py/uv.lock', 'env/py_lock.txt',
              'tools/check_calls.py', 'tools/seal_python.py', 'tools/capture_locked_defaults.py',
              'tools/make_module_lock.py', 'skills/_shared/scripts/render_figure_request.R')]
    files.extend(p for p in (ROOT / 'skills/_shared/scripts').glob('fig_*.R') if p.is_file())
    unique = sorted(set(files), key=lambda p: p.relative_to(ROOT).as_posix())
    return {'schema': 'omicstat.module_lock.v1', 'module': module, 'module_version': version_of(directory),
            'files': {p.relative_to(ROOT).as_posix(): file_sha(p) for p in unique},
            'packages': registry['package_versions'], 'environment': environment}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('module')
    parser.add_argument('--check', action='store_true')
    args = parser.parse_args()
    value = build(args.module)
    path = ROOT / 'skills' / args.module / 'module_lock.json'
    if args.check:
        if not path.is_file():
            raise RuntimeError('OS_LOCK_PENDING: module_lock.json missing')
        old = json.loads(path.read_text())
        if any(old.get(k) != value[k] for k in ('schema', 'module', 'module_version', 'files', 'packages', 'environment')):
            raise RuntimeError('OS_LOCK_MISMATCH: module sources, baseline or environment changed')
        print('module_lock %s: OK (%d files)' % (args.module, len(value['files'])))
    else:
        path.write_text(json.dumps(value, indent=2, sort_keys=True) + '\n', encoding='utf-8')
        print('Generated %s from %d real files' % (path.relative_to(ROOT), len(value['files'])))


if __name__ == '__main__':
    main()
