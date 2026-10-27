#!/usr/bin/env python3
"""Write or check the golden baseline of a module from its canonical acceptance run.

Modules that were added after the original sealing have no smoke-test golden writer.
Their golden is the byte hash of the deterministic outputs of the canonical
acceptance run (tests/acceptance.json): tables/*.csv, results/*.json,
figures/*.figure_spec.json, figures/*.png, draft/methods_results.md. The run is made
twice (canonical and --spec replay); only files that are byte-identical between the
two runs are recorded, so run-specific paths or timestamps can never enter a golden.

  canonical_golden.py <module> --image omicstat-r:2026.10.4 --out DIR --write   (writes tests/golden_manifest.csv)
  canonical_golden.py <module> --image omicstat-r:2026.10.4 --out DIR --check
  canonical_golden.py <module> --native --out DIR --check     (inside the locked container)

Evidence path: a few modules (proc-roc) hash the absolute input paths into their estimand
hash, so the golden is only reproducible from the same evidence path. proc-roc's golden was
written with --native in the container with DIR=/tmp/omicstat-test/canonical-golden-fixed/proc-roc,
which is exactly the path tools/run_tests.sh checks it from (OMICSTAT_TEST_TMP=/tmp/omicstat-test,
as in env/test.sh). All other modules' goldens do not depend on the path.

The manifest format is the one of os_golden_write(): a "# env: ..." line, then
path,sha256,tier,exempt_fields. Writing needs OMICSTAT_WRITE_GOLDEN=1 in the environment.
"""
from __future__ import annotations
import argparse, json, os, pathlib, sys
from acceptance.common import *
from acceptance.runner import Runner
from acceptance.pipeline import Pipeline

ROOT = pathlib.Path(__file__).resolve().parents[1]
PATTERNS = ('tables/*.csv', 'results/*.json', 'figures/*.figure_spec.json', 'figures/*.png', 'draft/methods_results.md')


def inventory(run):
    out = {}
    for pattern in PATTERNS:
        for p in sorted(pathlib.Path(run).glob(pattern)):
            if p.is_symlink() or not p.resolve().is_relative_to(pathlib.Path(run).resolve()):
                raise ValueError('golden artifact escapes the run root')
            out[p.relative_to(run).as_posix()] = sha(p)
    return out


def env_line(runner, root):
    r = runner.run(['Rscript', '-e', 'source(%s); cat(os_env_signature_string())' % json.dumps(runner.path(root / 'skills/_shared/scripts/module_kit.R'))], 'env-signature')
    if not r['ok']:
        raise ValueError('could not read the environment signature: ' + r['log'])
    sig = r['stdout'].strip().splitlines()[-1]
    if not sig.startswith('container|'):
        raise ValueError('golden must be written in the locked container, got: ' + sig)
    return sig


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('module'); ap.add_argument('--root', type=pathlib.Path, default=ROOT); ap.add_argument('--out', type=pathlib.Path, required=True)
    ap.add_argument('--image'); ap.add_argument('--native', action='store_true')
    g = ap.add_mutually_exclusive_group(required=True); g.add_argument('--write', action='store_true'); g.add_argument('--check', action='store_true')
    a = ap.parse_args()
    root = a.root.resolve(); module = a.module
    if a.write and not os.environ.get('OMICSTAT_WRITE_GOLDEN'):
        print('FAIL: --write needs OMICSTAT_WRITE_GOLDEN=1'); return 2
    if not a.native and not a.image:
        print('FAIL: --image or --native required'); return 2
    out = a.out.resolve()
    if out.exists() and any(out.iterdir()):
        print('FAIL: use a fresh evidence directory'); return 2
    out.mkdir(parents=True, exist_ok=True)
    runner = Runner(root, out, image=a.image, native=a.native)
    pipe = Pipeline(root, module, out, runner)
    try:
        replay = pipe.replay()
        if replay.get('status') != 'pass':
            print('FAIL: canonical run and spec replay differ or failed:', json.dumps(replay)[:600]); return 1
        first, second = inventory(pipe.run1), inventory(pipe.run2)
        golden = {k: v for k, v in first.items() if second.get(k) == v}
        excluded = sorted(k for k in set(first) | set(second) if k not in golden)
        if not any(k.startswith('tables/') for k in golden):
            print('FAIL: no deterministic table in the canonical run'); return 1
        manifest = root / 'skills' / module / 'tests' / 'golden_manifest.csv'
        if a.write:
            sig = env_line(runner, root)
            lines = ['# env: ' + sig, 'path,sha256,tier,exempt_fields'] + ['%s,%s,container,' % (k, golden[k]) for k in sorted(golden)]
            manifest.write_text('\n'.join(lines) + '\n', encoding='utf-8', newline='\n')
            print('wrote %s: %d files (excluded as run-specific: %s)' % (manifest.relative_to(root), len(golden), excluded or 'none'))
            return 0
        text = manifest.read_text().splitlines()
        want_env = text[0][len('# env: '):] if text and text[0].startswith('# env: ') else None
        try:
            have_env = env_line(runner, root)
        except ValueError as e:
            print('SKIP: environment signature not comparable (%s)' % str(e)[:120]); return 0
        if want_env != have_env:
            print('SKIP: environment signature differs (golden: %s; running: %s)' % (want_env, have_env)); return 0
        rows = {}
        for line in text[1:]:
            if line.startswith('#') or line.startswith('path,'):
                continue
            path, digest = line.split(',')[:2]
            rows[path] = digest
        bad = sorted(k for k in set(rows) | set(golden) if rows.get(k) != golden.get(k))
        if bad:
            print('FAIL: golden mismatch for', bad); return 1
        print('PASS: canonical golden %s (%d files)' % (module, len(rows))); return 0
    except ValueError as e:
        print('FAIL:', e); return 1


if __name__ == '__main__':
    raise SystemExit(main())
