#!/usr/bin/env python3
"""Check the integrated reference config against its historical sources and code.

The original builder is the immutable overlay baseline. The integration adds
current router hashes and availability labels to its method map only. No config
is written, and no reference store or service is opened.
"""
from __future__ import annotations
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'reference_service'))
import build_config


def check():
    built = build_config.build(build_config.load_sources())
    router = (ROOT / 'skills/omicstat/SKILL.md').read_bytes()
    routed = set(re.findall(r'\|\s*`([a-z0-9-]+)`\s*\|\s*`scripts/run_[A-Za-z0-9_]+\.(?:R|py)`\s*\|', router.decode()))
    expected = json.loads(built['method_map.json'])
    expected['source_path'] = 'skills/omicstat/SKILL.md section 1; docs/handoff/ENGINEERING_PLAN.md sections 1.2 and 10.2'
    expected['source_sha256'] = build_config.sha(router)
    expected['plan_sha256'] = build_config.sha((ROOT / 'docs/handoff/ENGINEERING_PLAN.md').read_bytes())
    expected['order_rule'] = ("Preserves the overlay's 38-target order for reference-store compatibility. "
                              'Router section 1 is the execution registry; entry_status explicitly separates '
                              'available source from unimplemented planned targets.')
    for entry in expected['modules']:
        module = entry['module']
        exists = (ROOT / 'skills' / module / entry['entry_script']).is_file()
        if module in routed and not exists:
            raise RuntimeError('reference/execution registry disagree: ' + module)
        entry['entry_status'] = ('source_built_pending_locked_acceptance' if exists and module not in routed
                                 else 'implemented_routed' if exists else 'planned_unimplemented')
    problems = []
    for name, data in built.items():
        actual = ROOT / 'reference_service/app' / name
        if name == 'method_map.json':
            if json.loads(actual.read_bytes()) != expected:
                problems.append(name)
        elif not actual.is_file() or actual.read_bytes() != data:
            problems.append(name)
    if problems:
        raise RuntimeError('stale integrated reference config: ' + ', '.join(problems))
    print('PASS: %d configs; complete %d-module map, historical order, current hashes and code-derived statuses' %
          (len(built), len(expected['modules'])))


if __name__ == '__main__':
    check()
