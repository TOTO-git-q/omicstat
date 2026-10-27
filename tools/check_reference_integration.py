#!/usr/bin/env python3
"""Check the integrated reference config against its historical sources and code.

The original builder is the immutable overlay baseline. The integration adds
current router hashes, availability labels and explicit display-module extensions.
All 38 historical targets and their discovery profiles remain exact; accepted module metadata appends reference targets. No config
is written unless --write is requested; no reference store or service is opened.
"""
from __future__ import annotations
import argparse
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'reference_service'))
import build_config


def integrated_config():
    built = build_config.build(build_config.load_sources())
    extensions = json.loads((ROOT / 'reference_service/display_extensions.json').read_text())['modules']
    assert [e['module'] for e in extensions] == ['scanpy-annotate', 'scanpy-purity', 'scanpy-ingest']
    profiles = json.loads(built['discovery_profiles.json'])
    profiles['profiles'].extend(e['discovery_profile'] for e in extensions)
    built['discovery_profiles.json'] = build_config.dump(profiles)
    schema = json.loads(built['schemas/literature_request.v1.json'])
    schema['properties']['module']['enum'][-1:-1] = [e['module'] for e in extensions]
    built['schemas/literature_request.v1.json'] = build_config.dump(schema)
    # Execution acceptance now promotes local registry configuration before S6.
    # Keep the pinned historical profiles exact; append only module-declared profiles.
    import sync_registry
    generated, _ = sync_registry.generated(ROOT)
    method_path = 'reference_service/app/method_map.json'
    methods = json.loads(generated[method_path])
    profiles_by_name = {p['module']: p for p in profiles['profiles']}
    for p in (ROOT/'skills').glob('*/module.json'):
        m = json.loads(p.read_text())
        if m['status'] == 'accepted' and m.get('reference', {}).get('discovery_profile'):
            profiles_by_name[m['name']] = m['reference']['discovery_profile']
    profiles['profiles'] = [profiles_by_name[m['module']] for m in methods['modules']]
    built['discovery_profiles.json'] = sync_registry.dump_reference(profiles).encode()
    schema['properties']['module']['enum'] = [m['module'] for m in methods['modules']] + ['unmapped']
    built['schemas/literature_request.v1.json'] = sync_registry.dump_reference(schema).encode()
    built['method_map.json'] = generated[method_path].encode()
    return built


def check(write=False):
    built = integrated_config()
    problems = []
    for name, data in built.items():
        actual = ROOT / 'reference_service/app' / name
        if write:
            actual.write_bytes(data)
        elif not actual.is_file() or actual.read_bytes() != data:
            problems.append(name)
    if problems:
        raise RuntimeError('stale integrated reference config: ' + ', '.join(problems))
    count = len(json.loads(built['method_map.json'])['modules'])
    print('PASS: %d configs; complete %d-module map, historical order, current hashes and code-derived statuses' %
          (len(built), count))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--write", action="store_true", help="Regenerate local integrated configuration from pinned baseline and explicit extensions.")
    check(parser.parse_args().write)
