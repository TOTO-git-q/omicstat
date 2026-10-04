"""Read-only module-lock verification; never generates a scientific baseline."""
from __future__ import annotations
import hashlib
import json
import re
from pathlib import Path


def verify_module_seal(root: Path, module: str) -> dict:
    if not re.fullmatch(r'[a-z0-9-]+', module):
        return {'ok': False, 'problems': ['invalid module identifier']}
    folder = root / 'skills' / module
    if module.startswith('omicstat-selftest') or not folder.is_dir():
        return {'ok': True, 'status': 'not_analysis_module', 'problems': []}
    path = folder / 'module_lock.json'
    try:
        record = json.loads(path.read_text())
    except (OSError, ValueError):
        return {'ok': False, 'status': 'pending', 'problems': ['module_lock.json missing or invalid']}
    if not isinstance(record, dict):
        return {'ok': False, 'status': 'invalid', 'problems': ['module lock must be a JSON object']}
    problems = []
    if record.get('schema') != 'omicstat.module_lock.v1' or record.get('module') != module:
        problems.append('module lock schema/identity mismatch')
    files = record.get('files')
    if not isinstance(files, dict) or not files:
        return {'ok': False, 'status': 'invalid', 'problems': problems + ['empty file inventory']}
    expected = 'skills/%s/tests/golden_manifest.csv' % module
    if expected not in files:
        problems.append('golden manifest is not bound by the module lock')
    registry = 'skills/%s/scripts/calls_registry.json' % module
    if registry not in files:
        problems.append('calls registry is not bound by the module lock')
    entries = list((folder / 'scripts').glob('run_*.R')) + list((folder / 'scripts').glob('run_*.py'))
    if not entries or any(p.relative_to(root).as_posix() not in files for p in entries):
        problems.append('entry script is not bound by the module lock')
    for relative, want in files.items():
        candidate = root / relative
        if not isinstance(relative, str) or Path(relative).is_absolute() or '..' in Path(relative).parts or '\\' in relative:
            problems.append('invalid relative inventory path')
            continue
        if not candidate.resolve().is_relative_to(root.resolve()):
            problems.append('inventory path escapes the repository')
            continue
        if not candidate.is_file():
            problems.append('missing bound file: ' + relative)
            continue
        actual = hashlib.sha256(candidate.read_bytes()).hexdigest()
        if not isinstance(want, str) or actual != want:
            problems.append('changed bound file: ' + relative)
    return {'ok': not problems, 'status': 'verified' if not problems else 'invalid', 'problems': problems}
