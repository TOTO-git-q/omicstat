#!/usr/bin/env python3
"""Capture actual inspect.signature defaults inside the pinned image.

This operation does not select scientific values or fill results. It records
installed API facts and refuses to overwrite a previously captured baseline
unless --replace is explicit. Review any source/API discrepancy before sealing.
"""
from __future__ import annotations
import argparse
import inspect
import json
from pathlib import Path
from check_calls import check_calls, locked_default, resolve_object
from seal_python import ROOT, require_locked_environment


def capture(module: str, replace: bool = False):
    env = require_locked_environment()
    path = ROOT / 'skills' / module / 'scripts/calls_registry.json'
    if path.parent.parent.parent != ROOT / 'skills' or not path.is_file():
        raise RuntimeError('OS_INVALID_PARAMETER: unknown module')
    registry = json.loads(path.read_text())
    previous = json.loads(json.dumps(registry))
    checked = check_calls(sorted(path.parent.glob('*.py')), registry)
    if not checked['ok']:
        raise RuntimeError('OS_CALLS_MISMATCH: ' + '; '.join(checked['problems']))
    signatures = {}
    for call in registry['calls']:
        obj = resolve_object(call['fn'])
        signature = inspect.signature(obj.__init__ if inspect.isclass(obj) else obj)
        permits_kwargs = any(p.kind == inspect.Parameter.VAR_KEYWORD for p in signature.parameters.values())
        for name, entry in call['args'].items():
            value = locked_default(obj, name)
            if value == '<absent>' and not permits_kwargs:
                raise RuntimeError('OS_API_MISMATCH: %s does not accept %s' % (call['fn'], name))
            entry['function_default'] = value
            if value == '<absent>':
                entry['forwarded_argument'] = True
        signatures[call['fn']] = str(signature)
    registry['default_capture_status'] = 'captured_locked_container'
    registry['default_capture_environment'] = env
    registry['captured_signatures'] = signatures
    registry['note'] = ('Default formals were read from the pinned installed packages. '
                        'Explicit scientific choices remain those recorded by the source; '
                        'capturing signatures alone is not numerical acceptance.')
    if previous.get('default_capture_status') == 'captured_locked_container' and not replace:
        if previous != registry:
            raise RuntimeError('OS_OUTPUT_EXISTS: captured defaults changed; use --replace only after review')
        print('Verified %d unchanged installed API signatures for %s' % (len(signatures), module))
        return
    temporary = path.with_suffix('.json.tmp')
    temporary.write_text(json.dumps(registry, indent=2, sort_keys=True) + '\n', encoding='utf-8')
    temporary.replace(path)
    print('Captured %d installed API signatures for %s' % (len(signatures), module))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('module')
    parser.add_argument('--replace', action='store_true')
    a = parser.parse_args()
    capture(a.module, a.replace)


if __name__ == '__main__':
    main()
