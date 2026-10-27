"""Actual help subprocesses: failed or empty help must never become 0/0 PASS."""
import pathlib, subprocess, sys, tempfile, unittest
ROOT = pathlib.Path(__file__).resolve().parents[1]
class FlagDocsTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = pathlib.Path(self.tmp.name)
        self.mod = self.root / "skills/test-module"
        (self.mod / "scripts").mkdir(parents=True)
        (self.mod / "references").mkdir()
        (self.mod / "SKILL.md").write_text("# Test fixture\n--outdir\n")
        self.entry = self.mod / "scripts/run_test.py"
    def tearDown(self):
        self.tmp.cleanup()
    def run_help(self, source, common=""):
        self.entry.write_text(source)
        p = self.root / "skills/_shared/docs/STUDY_CONTRACT.md"
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text(common)
        return subprocess.run([sys.executable, str(ROOT / "tools/check_flag_docs.py"), str(self.mod)], capture_output=True, text=True)
    def test_documented_help_passes(self):
        p = self.run_help('print("--outdir --help")')
        self.assertEqual(p.returncode, 0, p.stdout + p.stderr)
        self.assertIn("1/1", p.stdout)
    def test_failed_help_with_or_without_flags_refuses(self):
        for text in ("", "--outdir"):
            p = self.run_help('import sys; print(' + repr(text) + '); sys.exit(3)')
            self.assertNotEqual(p.returncode, 0)
            self.assertIn("not assessed", p.stdout)
    def test_empty_help_refuses(self):
        for text in ("", "--help", "plain message"):
            p = self.run_help('print(' + repr(text) + ')')
            self.assertNotEqual(p.returncode, 0)
            self.assertIn("no flags discovered", p.stdout)
    def test_common_flags_need_actual_shared_documentation(self):
        source = 'print("--outdir --study-contract --study-contract-sha256")'
        self.assertNotEqual(self.run_help(source).returncode, 0)
        self.assertEqual(self.run_help(source, "--study-contract --study-contract-sha256").returncode, 0)
    def test_shared_document_cannot_excuse_other_flags(self):
        p = self.run_help('print("--outdir --new-parameter")', "--new-parameter")
        self.assertNotEqual(p.returncode, 0)
        self.assertIn("UNDOCUMENTED --new-parameter", p.stdout)
    def test_multiple_entries_refuse(self):
        (self.mod / "scripts/run_second.py").write_text('print("--outdir")')
        self.assertNotEqual(self.run_help('print("--outdir")').returncode, 0)
if __name__ == "__main__":
    unittest.main(verbosity=2)
