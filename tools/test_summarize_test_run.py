import importlib.util
from pathlib import Path
import tempfile
import unittest

spec = importlib.util.spec_from_file_location("summarize_test_run", Path(__file__).with_name("summarize_test_run.py"))
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class SummaryTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        (self.root / "logs").mkdir()
        (self.root / "logs/status.tsv").write_text("001\t0\tpython first.py\n002\t1\tpython second.py\n")
        (self.root / "logs/index.tsv").write_text("001\tpython first.py\n002\tpython second.py\n")
        (self.root / "logs/001.log").write_text("SKIP: explicit internal subcheck\nOK\n")
        (self.root / "logs/002.log").write_text("FAIL: project-generated fixture assertion\n")
        (self.root / "output.log").write_text("SKIP: missing package\nSKIP: delegated subcheck\n== done: FAILURES (1 skipped for missing packages)\n")

    def test_runner_skips_are_not_all_skip_lines(self):
        result = module.summarize(self.root)
        self.assertEqual(result["runner_missing_package_skips"], 1)
        self.assertEqual(result["output_skip_messages"], 2)
        self.assertEqual(result["internal_command_skip_messages"], 1)
        self.assertEqual(result["commands_exit_zero"], 1)
        self.assertEqual(result["commands_nonzero"], 1)
        self.assertFalse(result["counts_are_scientific_assertions"])
        self.assertFalse(result["log_contents_included"])
        self.assertNotIn("project-generated fixture assertion", str(result))

    def test_python_terminal_count(self):
        (self.root / "output.log").write_text("== done: FAILURES (2 commands)\n")
        self.assertEqual(module.summarize(self.root)["runner_missing_package_skips"], 0)
        (self.root / "output.log").write_text("== done: FAILURES (3 commands)\n")
        with self.assertRaisesRegex(ValueError, "count disagrees"):
            module.summarize(self.root)

    def test_incomplete_output_fails(self):
        (self.root / "output.log").write_text("still running\n")
        with self.assertRaisesRegex(ValueError, "terminal"):
            module.summarize(self.root)

    def test_missing_log_fails(self):
        (self.root / "logs/002.log").unlink()
        with self.assertRaises(FileNotFoundError):
            module.summarize(self.root)

    def test_duplicate_index_fails(self):
        with (self.root / "logs/status.tsv").open("a") as stream:
            stream.write("001\t0\tpython duplicate.py\n")
        with self.assertRaisesRegex(ValueError, "duplicate"):
            module.summarize(self.root)

    def test_false_all_passed_fails(self):
        (self.root / "output.log").write_text("== done: ALL PASSED (0 skipped for missing packages)\n")
        with self.assertRaisesRegex(ValueError, "verdict disagrees"):
            module.summarize(self.root)

    def test_wrong_command_index_fails(self):
        (self.root / "logs/index.tsv").write_text("001\tpython other.py\n")
        with self.assertRaisesRegex(ValueError, "index differs"):
            module.summarize(self.root)


if __name__ == "__main__":
    unittest.main()
