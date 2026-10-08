#!/usr/bin/env python3
"""Check the integrated reference config against its historical sources and code.

The original builder is the immutable overlay baseline. The integration adds
current router hashes, availability labels and explicit display-module extensions.
All 38 historical targets and their discovery profiles remain exact. No config
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
    router = (ROOT / 'skills/omicstat/SKILL.md').read_bytes()
    routed = set(re.findall(r'\|\s*`([a-z0-9-]+)`\s*\|\s*`scripts/run_[A-Za-z0-9_]+\.(?:R|py)`\s*\|', router.decode()))
    expected = json.loads(built['method_map.json'])
    expected['modules'].extend({k: e[k] for k in ('module', 'entry_script')} for e in extensions)
    expected['source_path'] = 'skills/omicstat/SKILL.md section 1; docs/handoff/ENGINEERING_PLAN.md sections 1.2 and 10.2'
    expected['source_sha256'] = build_config.sha(router)
    expected['plan_sha256'] = build_config.sha((ROOT / 'docs/handoff/ENGINEERING_PLAN.md').read_bytes())
    expected['order_rule'] = ("Preserves the overlay's 38-target order for reference-store compatibility. "
                              'Router section 1 is the execution registry; entry_status explicitly separates '
                              'available source from unimplemented planned targets. Display/curation modules are appended after the historical targets.')
    for entry in expected['modules']:
        module = entry['module']
        exists = (ROOT / 'skills' / module / entry['entry_script']).is_file()
        if module in routed and not exists:
            raise RuntimeError('reference/execution registry disagree: ' + module)
        entry['entry_status'] = ('source_built_pending_locked_acceptance' if exists and module not in routed
                                 else 'implemented_routed' if exists else 'planned_unimplemented')
    built['method_map.json'] = build_config.dump(expected)
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
