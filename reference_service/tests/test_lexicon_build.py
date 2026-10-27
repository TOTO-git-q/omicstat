"""The committed method lexicon is exactly what build_lexicon.py produces from the curated table and the env locks."""
import json
import sys
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parents[1]
sys.dont_write_bytecode = True
sys.path.insert(0, str(HERE))
import build_lexicon  # noqa: E402


class LexiconBuildTests(unittest.TestCase):
    def test_committed_lexicon_is_current(self):
        committed = (HERE / "app" / "method_lexicon.json").read_text(encoding="utf-8")
        self.assertEqual(committed, build_lexicon.encoded(build_lexicon.build()), "run: python build_lexicon.py")

    def test_every_rank_eligible_entry_has_a_valid_section_query(self):
        doc = json.loads((HERE / "app" / "method_lexicon.json").read_text(encoding="utf-8"))
        for entry in doc["entries"]:
            if entry["rank_eligible"]:
                self.assertTrue(entry["epmc_query"].startswith("("), entry["token"])
                self.assertEqual(entry["epmc_query"].count("("), entry["epmc_query"].count(")"), entry["token"])
                self.assertEqual(entry["epmc_query"].count('"') % 2, 0, entry["token"])
                self.assertIn("METHODS:", entry["epmc_query"])
            else:
                self.assertIsNone(entry["epmc_query"])
        self.assertTrue(any(e["licence_note"] for e in doc["entries"] if e["token"] in ("kegg", "depmap", "cadd", "panglaodb")))
        self.assertEqual({e["token"] for e in doc["entries"] if e["licence_note"]}, {"kegg", "depmap", "cadd", "panglaodb"})


if __name__ == "__main__":
    unittest.main()
