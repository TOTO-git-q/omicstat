#!/usr/bin/env python3
"""Offline source/launcher regression tests; no MCP SDK or R execution is implied.

The source-function tests compile selected unmodified function ASTs from server.py.
The Docker launcher test substitutes an argv-recording executable, not a container
or a scientific engine. End-to-end MCP/R acceptance remains a separate gate.
"""
from __future__ import annotations
import ast
import collections
import datetime
import hashlib
import json
import logging
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import typing
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'mcp'))
from module_seal import verify_module_seal
import capture_locked_defaults


def server_functions(*names):
    tree = ast.parse((ROOT / 'mcp/server.py').read_text())
    selected = [n for n in tree.body if isinstance(n, ast.FunctionDef) and n.name in names]
    assert {n.name for n in selected} == set(names)
    namespace = {'os': os, 'subprocess': subprocess, '_dt': datetime,
                 'Dict': typing.Dict, 'List': typing.List, 'Optional': typing.Optional,
                 'IS_WINDOWS': os.name == 'nt', 'NATIVE_ENV': '/unused/native.json',
                 'log': logging.getLogger('source-function-test')}
    exec(compile(ast.Module(body=selected, type_ignores=[]), 'server.py:selected-functions', 'exec'), namespace)
    return namespace


class DefaultCaptureTests(unittest.TestCase):
    def test_repeat_verifies_and_drift_requires_review(self):
        def original(x=3):
            pass
        def changed(x=4):
            pass
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            path = root / 'skills/x-test/scripts/calls_registry.json'
            path.parent.mkdir(parents=True)
            path.write_text(json.dumps({'calls': [{'fn': 'test.fn', 'args': {'x': {}}}]}))
            with patch.object(capture_locked_defaults, 'ROOT', root), \
                 patch.object(capture_locked_defaults, 'require_locked_environment', return_value={}), \
                 patch.object(capture_locked_defaults, 'check_calls', return_value={'ok': True}), \
                 patch.object(capture_locked_defaults, 'resolve_object', return_value=original) as resolve:
                capture_locked_defaults.capture('x-test')
                before, stamp = path.read_bytes(), path.stat().st_mtime_ns
                capture_locked_defaults.capture('x-test')
                self.assertEqual(path.read_bytes(), before)
                self.assertEqual(path.stat().st_mtime_ns, stamp)
                resolve.return_value = changed
                with self.assertRaisesRegex(RuntimeError, 'OS_OUTPUT_EXISTS'):
                    capture_locked_defaults.capture('x-test')
                self.assertEqual(path.read_bytes(), before)
                capture_locked_defaults.capture('x-test', replace=True)
                self.assertNotEqual(path.read_bytes(), before)


class InventoryTests(unittest.TestCase):
    def test_exactly_five_mcp_tools(self):
        tree = ast.parse((ROOT / 'mcp/server.py').read_text())
        tools = [n.name for n in tree.body if isinstance(n, ast.FunctionDef)
                 and any(isinstance(d, ast.Call) and ast.unparse(d.func) == 'mcp.tool' for d in n.decorator_list)]
        self.assertEqual(set(tools), {'omicstat_list_modules', 'omicstat_describe', 'omicstat_run',
                                     'omicstat_read', 'omicstat_validate_publication'})
        self.assertEqual(len(tools), 5)

    def test_router_only_lists_real_entries(self):
        text = (ROOT / 'skills/omicstat/SKILL.md').read_text()
        rows = re.findall(r'\|\s*`([a-z0-9-]+)`\s*\|\s*`(scripts/run_[a-z0-9_]+\.(?:R|py))`\s*\|', text)
        self.assertEqual(len(rows), 43)  # 38 analysis engines, three display/annotation modules and two utilities.
        self.assertEqual(len({m for m, _ in rows}), len(rows))
        for module, script in rows:
            self.assertTrue((ROOT / 'skills' / module / script).is_file(), module)

    def test_method_map_and_source_status_cover_all_41(self):
        methods = json.loads((ROOT / 'reference_service/app/method_map.json').read_text())
        status = json.loads((ROOT / 'docs/build/BUILD_STATUS.json').read_text())
        self.assertEqual(len([m['module'] for m in methods['modules']]), 41)
        self.assertEqual(set([m['module'] for m in methods['modules']]), {m['module'] for m in status['modules']})
        self.assertEqual(len(status['implemented_new']), 27)
        self.assertEqual(len(status['unimplemented_new']), 0)
        self.assertFalse(status['complete_request'])  # independent S3 remains pending
        by_name = {m['module']: m for m in methods['modules']}
        source_status = {m['module']: m for m in status['modules']}
        for name in status['unimplemented_new']:
            self.assertFalse((ROOT / 'skills' / name).exists(), 'Do not ship a pretend engine: ' + name)
        for name in status['implemented_new']:
            module = ROOT / 'skills' / name
            entry = by_name[name]
            self.assertEqual(entry['entry_status'], 'implemented_routed', name)
            self.assertTrue(source_status[name]['source_available'], name)
            self.assertIn(source_status[name]['locked_acceptance'],
                          {'pending_this_build', 'pending_independent_s3'}, name)
            self.assertTrue((module / entry['entry_script']).is_file(), name)
            suffix = Path(entry['entry_script']).suffix
            self.assertTrue((module / ('tests/run_smoke_test' + suffix)).is_file(), name)
            registry = json.loads((module / 'scripts/calls_registry.json').read_text())
            self.assertTrue(registry.get('calls'), 'No native workflow registered: ' + name)
            self.assertTrue((module / 'module_lock.json').is_file(), name)
            if suffix == '.R':
                self.assertTrue(list((module / 'scripts').glob('*_core.R')), name)

    def test_routing_dataset_structure_not_accuracy(self):
        records = [json.loads(line) for line in (ROOT / 'skills/omicstat/tests/routing_eval.jsonl').read_text(encoding='utf-8').splitlines()]
        known = {m['module'] for m in json.loads((ROOT / 'reference_service/app/method_map.json').read_text())['modules']}
        self.assertEqual(len(records), 146)
        self.assertEqual(len({r['id'] for r in records}), 146)
        counts = collections.Counter()
        def modules(answer):
            if isinstance(answer, str):
                return [answer]
            if 'pipeline' in answer:
                return answer['pipeline']
            self.assertIn('out_of_scope', answer)
            return []
        for record in records:
            self.assertTrue({'id', 'question', 'language', 'expected', 'acceptable', 'family', 'tests', 'note'} <= record.keys())
            for answer in [record['expected']] + record['acceptable']:
                for name in modules(answer):
                    self.assertIn(name, known)
                    counts[name] += 1
        self.assertTrue(all(counts[m] >= 2 for m in known))


class InvocationTests(unittest.TestCase):
    def test_entry_extension_dispatch(self):
        ns = server_functions('_is_python_entry', '_tool_for')
        self.assertEqual(ns['_tool_for']('run_scanpy_qc.py'), 'python')
        self.assertEqual(ns['_tool_for']('run_limma_camera.R'), 'Rscript')

    def test_exec_passes_run_id_and_closes_protocol_stdin(self):
        ns = server_functions('_engine_env', '_kill_tree', '_exec')
        with tempfile.TemporaryDirectory() as folder:
            command = [sys.executable, '-c', 'import os,sys,json;print(json.dumps([os.getenv("OMICSTAT_RUN_ID"),sys.stdin.read()]))']
            code, out, err, duration, timed_out = ns['_exec'](command, folder, 15, 'container',
                                                            {'OMICSTAT_RUN_ID': 'unit-run-42'})
        self.assertEqual(code, 0, err)
        self.assertEqual(json.loads(out), ['unit-run-42', ''])
        self.assertFalse(timed_out)
        self.assertGreaterEqual(duration, 0)

    @unittest.skipIf(os.name == 'nt', 'POSIX launcher')
    def test_native_launcher_preserves_run_id_and_spaces(self):
        with tempfile.TemporaryDirectory(prefix='omicstat native ') as folder:
            cfg = Path(folder) / 'native-env.json'
            cfg.write_text(json.dumps({'python': sys.executable}))
            env = dict(os.environ, OMICSTAT_R_NATIVE='1', OMICSTAT_NATIVE_ENV=str(cfg), OMICSTAT_RUN_ID='native-42')
            result = subprocess.run(['bash', str(ROOT / 'bin/omicstat-r-route.sh'), 'python', '-c',
                                     'import os,sys,json;print(json.dumps([os.getenv("OMICSTAT_RUN_ID"),sys.argv[1]]))', 'a b'],
                                    env=env, cwd=folder, capture_output=True, text=True, timeout=15)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(result.stdout), ['native-42', 'a b'])

    @unittest.skipIf(os.name == 'nt', 'POSIX launcher')
    def test_container_launcher_forwards_run_id_argument(self):
        with tempfile.TemporaryDirectory() as folder:
            docker = Path(folder) / 'docker'
            docker.write_text('#!' + sys.executable + '\nimport json,os,sys\nprint(json.dumps({"args":sys.argv[1:],"run_id":os.getenv("OMICSTAT_RUN_ID")}))\n')
            docker.chmod(0o755)
            env = dict(os.environ, PATH=folder + os.pathsep + os.environ['PATH'], OMICSTAT_RUN_ID='docker-42')
            env.pop('OMICSTAT_R_NATIVE', None)
            result = subprocess.run(['bash', str(ROOT / 'bin/omicstat-r-route.sh'), 'Rscript',
                                     str(ROOT / 'skills/limma-camera/scripts/run_limma_camera.R'), '--outdir', folder],
                                    env=env, cwd=folder, capture_output=True, text=True, timeout=15)
        self.assertEqual(result.returncode, 0, result.stderr)
        recorded = json.loads(result.stdout)
        self.assertEqual(recorded['run_id'], 'docker-42')
        args = recorded['args']
        self.assertTrue(any(args[i:i+2] == ['-e', 'OMICSTAT_RUN_ID'] for i in range(len(args)-1)))
        cfg = json.loads((ROOT / 'env/omicstat-env.json').read_text())
        self.assertIn(cfg['image'] + ':' + cfg['image_tag'], args)
        self.assertIn('/omicstat/skills/limma-camera/scripts/run_limma_camera.R', args)


class SealTests(unittest.TestCase):
    def fixture(self, root):
        folder = root / 'skills/x-test'
        files = {'skills/x-test/scripts/run_x_test.py': '# fixture, not a scientific engine\n',
                 'skills/x-test/scripts/calls_registry.json': '{}\n',
                 'skills/x-test/tests/golden_manifest.csv': '# synthetic test fixture only\n'}
        for relative, text in files.items():
            path = root / relative
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(text)
        lock = {'schema': 'omicstat.module_lock.v1', 'module': 'x-test',
                'files': {name: hashlib.sha256((root/name).read_bytes()).hexdigest() for name in files}}
        (folder/'module_lock.json').write_text(json.dumps(lock))
        return folder, lock

    def test_unsealed_real_python_modules_are_blocked(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            for module in json.loads((ROOT/'docs/build/BUILD_STATUS.json').read_text())['implemented_new']:
                (root / 'skills' / module).mkdir(parents=True)
                self.assertFalse(verify_module_seal(root, module)['ok'])

    def test_bound_files_tamper_and_missing(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp); folder, lock = self.fixture(root)
            self.assertTrue(verify_module_seal(root, 'x-test')['ok'])
            (folder/'scripts/run_x_test.py').write_text('changed\n')
            self.assertFalse(verify_module_seal(root, 'x-test')['ok'])
            (folder/'scripts/run_x_test.py').unlink()
            self.assertFalse(verify_module_seal(root, 'x-test')['ok'])

    def test_traversal_and_unbound_golden_are_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp); folder, lock = self.fixture(root)
            lock['files'] = {'../outside': '0'*64}
            (folder/'module_lock.json').write_text(json.dumps(lock))
            self.assertFalse(verify_module_seal(root, 'x-test')['ok'])
        self.assertFalse(verify_module_seal(ROOT, '../scanpy-qc')['ok'])

    def test_module_identity_is_checked(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp); folder, lock = self.fixture(root)
            lock['module'] = 'other'
            (folder/'module_lock.json').write_text(json.dumps(lock))
            self.assertFalse(verify_module_seal(root, 'x-test')['ok'])


if __name__ == '__main__':
    unittest.main(verbosity=2)
