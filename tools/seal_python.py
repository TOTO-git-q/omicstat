"""Shared release guards. No lock or golden is created in an unpinned interpreter."""
from __future__ import annotations
import importlib.metadata as md
import json
import os
import platform
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def require_locked_environment():
    lane = json.loads((ROOT / 'env/py/py-env.json').read_text())
    problems = []
    if os.environ.get('OMICSTAT_PY_CONTAINER') != '1':
        problems.append('OMICSTAT_PY_CONTAINER=1 is required; use the supplied container image')
    if platform.python_version() != lane['python_version']:
        problems.append('Python %s != %s' % (platform.python_version(), lane['python_version']))
    actual = {}
    for name, expected in lane['pins'].items():
        try:
            actual[name] = md.version(name)
        except md.PackageNotFoundError:
            actual[name] = None
        if actual[name] != expected:
            problems.append('%s %s != %s' % (name, actual[name], expected))
    if problems:
        raise RuntimeError('OS_ENVIRONMENT_MISMATCH: ' + '; '.join(problems))
    return {'python': platform.python_version(), 'packages': actual,
            'platform': platform.platform(), 'image_id': os.environ.get('OMICSTAT_PY_IMAGE_ID'),
            'py_env_version': lane['py_env_version']}
