#!/usr/bin/env python3
"""Offline tests of tools/lit/omlit.py (no network). Run: python3 tools/lit/test_omlit.py"""
import sys
import unittest
from pathlib import Path

sys.dont_write_bytecode = True
sys.path.insert(0, str(Path(__file__).resolve().parent))
try:
    import omlit
except ImportError as exc:  # lxml lives in the retrieval venv
    print(f"SKIP: {exc} (run with /opt/retrieval-venv/bin/python)")
    sys.exit(0)

JATS = b"""<article><front><article-meta><permissions><license xlink:href="https://creativecommons.org/licenses/by/4.0/" xmlns:xlink="http://www.w3.org/1999/xlink"><p>This article is distributed under CC BY 4.0.</p></license></permissions></article-meta></front>
<body><sec><title>Introduction</title><p>DESeq2 is popular but was not the method here.</p></sec>
<sec sec-type="methods"><title>Methods</title><sec><title>Differential expression</title>
<p>Differential expression was tested with DESeq2 (v1.40.2) using the Wald test; genes with adjusted P &lt; 0.05 and |log2 fold change| &gt; 1 were called significant. Shrinkage used apeglm.</p></sec></sec>
<sec><title>Results</title><p>DESeq2 found 500 genes with FDR &lt; 0.1.</p></sec></body></article>"""


class OmlitTests(unittest.TestCase):
    def setUp(self):
        self.prof = omlit.load_profiles()["by_module"]["deseq2-wald"]

    def test_licence(self):
        r = omlit.classify_rights("Creative Commons Attribution-NonCommercial-NoDerivatives 4.0", [])
        self.assertEqual(r["licence"], "cc-by-nc-nd")
        self.assertFalse(r["countable"])
        self.assertTrue(omlit.classify_rights("", ["https://creativecommons.org/licenses/by/4.0/"])["countable"])
        self.assertTrue(omlit.classify_rights("Text and data mining is not permitted. CC BY", [])["tdm_prohibited"])

    def test_methods_only(self):
        verdict, d = omlit.screen_fulltext(JATS, self.prof)
        self.assertEqual(verdict, "screened")
        self.assertIn("Methods", d["signal"]["section_path"])
        self.assertNotIn("500 genes", str(d))            # Results text is never read
        self.assertEqual([v["value"] for v in d["variants"]["padj_cutoff"]], ["0.05"])
        self.assertEqual(d["variants"]["lfc_filter"][0]["value"], "1")
        self.assertEqual(d["variants"]["shrinkage"][0]["value"], "apeglm")
        self.assertEqual(d["variants"]["deseq2_version"][0]["value"], "1.40.2")

    def test_snippet_length(self):
        _, d = omlit.screen_fulltext(JATS, self.prof)
        for vals in d["variants"].values():
            for v in vals:
                self.assertLessEqual(len(v["snippet"].split()), omlit.SNIPPET_MAX_WORDS)

    def test_negation(self):
        self.assertTrue(omlit._negated("shrinkage was not applied with apeglm", 34, 40))

    def test_title_norm(self):
        self.assertEqual(omlit._norm_title("implicate &lt;i&gt;CNN2&lt;/i&gt; in AMD."), omlit._norm_title("implicate CNN2 in AMD"))

    def test_journals_whitelist(self):
        j = omlit.load_journals()
        self.assertIn("2041-1723", j["by_issn"])
        self.assertTrue(all(x["verified_via"] for x in j["journals"]))


if __name__ == "__main__":
    unittest.main()
