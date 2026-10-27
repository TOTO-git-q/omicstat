"""Offline tests of news_filter on a fixture NEWS tree (Rd, 'CHANGES IN VERSION' and Markdown formats)."""
import json
import sys
import tempfile
import unittest
from pathlib import Path

sys.dont_write_bytecode = True
sys.path.insert(0, str(Path(__file__).resolve().parent))
import news_filter as nf  # noqa: E402

RD = r"""\name{limmanews}
\title{limma News}

\section{version 3.68.0 (2026-04-28)}{\itemize{

  \item
  New arguments `offset` and `offset.prior` for voom(). voom() now
  supports offsets in DGEList objects.

  \item
  The function topTableF(), which has been deprecated for many years,
  is now formally removed.

  \item
  Fixed a bug in lmFit() with weights and missing values.

}}

\section{version 3.66.0 (2025-10-28)}{\itemize{

  \item
  In voom(), default for `span` is now chosen differently.

}}
"""

TEXT = """CHANGES IN VERSION 1.51.3
-------------------------

  o Numerous partial matching fixes from Hugo Gruson.

CHANGES	IN VERSION 1.50.0
-------------------------

  o The default of lfcShrink type is now apeglm.
    This changes results.
  o Fixes for useT in results().

CHANGES IN VERSION 1.48.0
-------------------------

  o Old entry about DESeq() that predates the window.
"""

MD = """# Version 2.1.2 (2024-2-6)
- Update `computeCommunProb` where the ECM-receptor signaling is now assumed diffusible.
- Typos in CellChatDB were fixed.

# Version 2.0.0 (2023-1-1)
- Old stuff about computeCommunProb.
"""


def make_repo(root: Path) -> None:
    reg = {"module": "mod-a", "package_versions": {"limma": "3.68.5", "DESeq2": "1.52.0", "CellChat": "2.2.0", "Seurat": "5.5.1"},
           "accessors": [], "calls": [
               {"fn": "limma::voom", "args": {"span": {}, "offset": {}}},
               {"fn": "limma::lmFit", "args": {}},
               {"fn": "DESeq2::DESeq", "args": {"useT": {"value": False}}},
               {"fn": "DESeq2::results", "args": {}},
               {"fn": "DESeq2::lfcShrink", "args": {"type": {}}},
               {"fn": "CellChat::computeCommunProb", "args": {}},
               {"fn": "Seurat::FindClusters", "args": {}}]}
    skill = root / "skills" / "mod-a" / "scripts"
    skill.mkdir(parents=True)
    (skill / "calls_registry.json").write_text(json.dumps(reg), encoding="utf-8")
    for rel, text in (("L1_bioc3.23/limma/NEWS.txt", RD), ("L1_bioc3.23/DESeq2/NEWS.txt", TEXT), ("L1_github/CellChat/NEWS.md", MD)):
        path = root / "acceptance" / "exemplars" / "mod-a" / rel
        path.parent.mkdir(parents=True)
        path.write_text(text, encoding="utf-8")


class NewsFilterTests(unittest.TestCase):
    def test_parsers_handle_three_formats(self):
        rd = nf.parse_news(RD)
        self.assertEqual([v for v, _ in rd], ["3.68.0", "3.66.0"])
        self.assertEqual(len(rd[0][1]), 3)
        text = nf.parse_news(TEXT)
        self.assertEqual([v for v, _ in text], ["1.51.3", "1.50.0", "1.48.0"])
        self.assertIn("The default of lfcShrink type is now apeglm. This changes results.", text[1][1])
        md = nf.parse_news(MD)
        self.assertEqual([v for v, _ in md], ["2.1.2", "2.0.0"])
        self.assertEqual(len(md[0][1]), 2)

    def test_classification(self):
        self.assertEqual(nf.classify("The function topTableF() is now formally removed."), "deprecation")
        self.assertEqual(nf.classify("The default of lfcShrink type is now apeglm."), "default_change")
        self.assertEqual(nf.classify("Fixed a bug in lmFit() with weights."), "bug_fix")
        self.assertEqual(nf.classify("results() now returns an extra column."), "behaviour_change")
        self.assertEqual(nf.classify("New function foo()."), "other")

    def test_bioc_window_is_previous_release_line(self):
        picked, rule = nf.window(nf.parse_news(RD), "3.68.5", True, None, 6)
        self.assertEqual([v for v, _ in picked], ["3.68.0"])          # 3.66.x belongs to the previous release line
        self.assertIn("Bioconductor previous release line", rule)
        picked, _ = nf.window(nf.parse_news(TEXT), "1.52.0", True, None, 6)
        self.assertEqual([v for v, _ in picked], ["1.51.3"])          # 1.50.x is the previous release; 1.48 older still
        picked, rule = nf.window(nf.parse_news(MD), "2.2.0", False, "2.0.0", 6)
        self.assertEqual([v for v, _ in picked], ["2.1.2"])
        picked, rule = nf.window(nf.parse_news(MD), "2.2.0", False, None, 1)
        self.assertEqual(len(picked), 1)

    def test_run_reports_only_entries_that_mention_registered_functions(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            make_repo(root)
            report = nf.run(root, {"CellChat": "2.0.0"}, 6)
            self.assertEqual(sorted(report["packages"]), ["CellChat", "DESeq2", "limma"])
            self.assertEqual([n["package"] for n in report["no_news"]], ["Seurat"])
            items = report["modules"]["mod-a"]
            texts = [(i["package"], i["class"]) for i in items]
            limma = [i for i in items if i["package"] == "limma"]
            self.assertTrue(any("voom" in i["matched"] for i in limma))
            self.assertTrue(any(i["class"] == "bug_fix" and "lmFit" in i["matched"] for i in limma))
            self.assertFalse(any("topTableF" in i["text"] for i in limma if "topTableF" in i["matched"]))
            self.assertTrue(all("DESeq2" != i["package"] or i["version"] != "1.48.0" for i in items))
            cellchat = [i for i in items if i["package"] == "CellChat"]
            self.assertEqual([i["version"] for i in cellchat], ["2.1.2"])
            out = root / "docs" / "affected.md"
            out.parent.mkdir()
            out.write_text(nf.render(report, "T"), encoding="utf-8")
            text = out.read_text(encoding="utf-8")
            self.assertIn("This is a filter, not a verdict", text)
            self.assertIn("### mod-a", text)
            self.assertIn("- Seurat 5.5.1", text)

    def test_cli_writes_report(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            make_repo(root)
            sys.argv = ["news_filter.py", "--repo", str(root), "--out", str(root / "o" / "a.md"), "--json", str(root / "o" / "a.json")]
            self.assertEqual(nf.main(), 0)
            self.assertTrue((root / "o" / "a.md").is_file())
            self.assertIn("mod-a", json.loads((root / "o" / "a.json").read_text(encoding="utf-8"))["modules"])


if __name__ == "__main__":
    unittest.main()
