"""Timeout defaults/bounds and nonblocking MCP progress, without changing modules."""
import asyncio
import os
import subprocess
import sys
import time
import tempfile
import json
from pathlib import Path
import unittest
from unittest import mock
import server


class TimeoutTests(unittest.TestCase):
    def test_default_and_override(self):
        with mock.patch.dict(os.environ, {}, clear=True):
            self.assertEqual(server.run_timeout_s(), 1500)
        with mock.patch.dict(os.environ, {'OMICSTAT_RUN_TIMEOUT_S': '21600'}):
            self.assertEqual(server.run_timeout_s(), 21600)
        self.assertEqual(server.run_timeout_s('1'), 1)

    def test_bounds(self):
        for value in ('0', '-1', '21601', 'nan', '1.5', ''):
            with self.subTest(value=value), self.assertRaises(ValueError):
                server.run_timeout_s(value)

    def test_process_override(self):
        env = dict(os.environ, OMICSTAT_RUN_TIMEOUT_S='17')
        p = subprocess.run([sys.executable, '-c', 'import server; print(server.RUN_TIMEOUT_S)'],
                           cwd=os.path.dirname(__file__), env=env, capture_output=True, text=True)
        self.assertEqual(p.returncode, 0, p.stderr)
        self.assertEqual(p.stdout.strip(), '17')

    def test_exec_honours_bound(self):
        rc, out, err, duration, timed_out = server._exec(
            [sys.executable, '-c', 'import time; time.sleep(10)'], cwd=os.path.dirname(__file__), timeout=1)
        self.assertTrue(timed_out)
        self.assertNotEqual(rc, 0)
        self.assertLess(duration, 5)

    def test_host_allocation_receipt_before_engine_starts(self):
        with tempfile.TemporaryDirectory() as root:
            receipt = Path(root) / 'receipt.json'
            with mock.patch.dict(os.environ, {'OMICSTAT_RUN_STATE_PATH': str(receipt)}), \
                 mock.patch.object(server, '_entry_path', return_value='entry'), \
                 mock.patch.object(server, '_to_argv', return_value=[]), \
                 mock.patch.object(server, '_build_cmd', return_value=['engine']), \
                 mock.patch.object(server, '_allocate_run_directory', return_value=('uuid', root, root)), \
                 mock.patch.object(server, '_exec', side_effect=RuntimeError('engine starts')) as execute:
                with self.assertRaisesRegex(RuntimeError, 'engine starts'):
                    server.omicstat_run('x', {})
                self.assertEqual(json.loads(receipt.read_text()), {'run_id': 'uuid', 'outdir': root})
                self.assertEqual(execute.call_args.kwargs['extra_env'], {'OMICSTAT_RUN_ID': 'uuid'})

    def test_protocol_stays_responsive_and_reports_progress(self):
        async def check():
            ctx = mock.AsyncMock()
            with mock.patch.object(server, 'PROGRESS_INTERVAL_S', .01), mock.patch.object(
                server, 'omicstat_run', side_effect=lambda *a: (time.sleep(.06), 'result')[1]):
                task = asyncio.create_task(server._run_with_progress('x', {}, ctx))
                await asyncio.sleep(.02)
                self.assertFalse(task.done())
                self.assertEqual(await task, 'result')
                self.assertGreater(ctx.report_progress.await_count, 0)
        asyncio.run(check())


if __name__ == '__main__':
    unittest.main()
