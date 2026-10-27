#!/usr/bin/env python3
"""Exercise the actual shell run functions without running scientific engines."""
from pathlib import Path
import os
import re
import subprocess
import tempfile
import unittest
ROOT=Path(__file__).resolve().parents[1]

class RunnerStatusTests(unittest.TestCase):
    def check_runner(self, name):
        source=(ROOT/'tools'/name).read_text()
        function=re.search(r'^run\(\) \{.*?^\}',source,re.M|re.S).group(0)
        with tempfile.TemporaryDirectory()as temporary:
            directory=Path(temporary)
            env=dict(os.environ,OMICSTAT_TEST_LOG_DIR=str(directory/'logs'),TEST_DIRECTORY=str(directory))
            shell='set -u\nfail=0; test_index=0; log="$TEST_DIRECTORY/one.log"\n'+function+'\nrun bash -c "exit 0"\nrun bash -c "exit 7"\nprintf "FINAL %s %s\\n" "$fail" "$test_index"\n'
            result=subprocess.run(['bash','-c',shell],env=env,capture_output=True,text=True,check=True)
            self.assertIn('FINAL 1 2',result.stdout)
            statuses=[row.split('\t',2)for row in(directory/'logs/status.tsv').read_text().splitlines()]
            self.assertEqual([(r[0],r[1])for r in statuses],[('001','0'),('002','7')])
            self.assertEqual(len((directory/'logs/index.tsv').read_text().splitlines()),2)
            self.assertTrue((directory/'logs/001.log').exists());self.assertTrue((directory/'logs/002.log').exists())
    def test_r_lane(self):self.check_runner('run_tests.sh')
    def test_python_lane(self):self.check_runner('run_tests_py.sh')

if __name__=='__main__':unittest.main()
