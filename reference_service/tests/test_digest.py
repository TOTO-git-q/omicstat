"""Monthly digest (host-side tool): rendering with zero unmet needs, ranking, alerts, old-schema stores."""
import datetime as dt
import json
import sqlite3
import sys
import tempfile
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parents[1]
sys.dont_write_bytecode = True
sys.path.insert(0, str(HERE))
sys.path.insert(0, str(HERE / "app"))

import reference_digest as digest  # noqa: E402
from harvest import HarvestStore  # noqa: E402

NOW = dt.datetime(2026, 10, 10, 6, tzinfo=dt.timezone.utc)
YEAR_ENDS = {y: f"{y}-12-31" for y in range(2020, 2026)} | {2026: "2026-09-30"}


class DigestTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.dir = Path(self.tmp.name)
        self.store = HarvestStore(self.dir / "harvest.sqlite")
        for year, end in YEAR_ENDS.items():
            self.store.add_probe_row("2026-10", "__whitelist_total__", "total", year, end, 10000, "t")

    def tearDown(self):
        self.tmp.cleanup()

    def series(self, token, kind, hits_by_year):
        for year, hits in hits_by_year.items():
            self.store.add_probe_row("2026-10", token, kind, year, YEAR_ENDS[year], hits, "q" + token)

    def build(self, unmet=None):
        return digest.build(self.dir, month="2026-10", now=NOW, unmet_path=unmet, env_json=None, repo=None)

    def test_zero_unmet_needs_and_empty_ranking_render(self):
        doc = self.build(unmet=self.dir / "does_not_exist.jsonl")
        text = digest.render(doc)
        self.assertEqual(doc["E_demand"]["unmet_needs"], 0)
        self.assertFalse(doc["E_demand"]["unmet_needs_file_present"])
        self.assertIn("No unmet-need records this month (zero demand-side evidence).", text)
        self.assertIn("not present yet", text)
        for heading in ("## A. Coverage ranking", "## B. Family trends", "## C. Locked defaults versus literature", "## D. Collection health",
                        "## E. Unmet needs, proposals, unavailable requests", "## F. Upgrade window", "## Limits"):
            self.assertIn(heading, text)
        self.assertEqual(doc["headline"]["top3"], [])
        self.assertIn("Partial ranking", text)                       # nothing is probed yet: say so
        self.assertNotIn("PaperFlow", text)                          # the recurring template has no lab-reading section
        self.assertNotIn("实验室阅读", text)

    def test_defaults_section_shows_owner_verdict_and_unparsed(self):
        doc = self.build(unmet=self.dir / "does_not_exist.jsonl")
        verdict = {"verdict": "keep_documented", "note": "n", "decided": "2026-10-11"}

        def row(module, option, owner_verdict):
            return {"module": module, "option": option, "locked_default": "x", "n_parsed": 9, "n_unparsed": 2, "n_excluded_cross_ecosystem": 5,
                    "default_share": 0.1, "flags": ["default_minority"], "owner_verdict": owner_verdict, "top_values": [{"value": "y", "n": 8}]}
        doc["C_defaults"].update(flagged=[row("a", "--open", None), row("b", "--done", verdict)], open_flags=1, adjudicated_flags=1)
        text = digest.render(doc)
        self.assertIn("of which open: 1, already decided by the owner: 1", text)
        self.assertIn("| owner verdict |", text)
        self.assertIn("9 / 2 (+5 other-ecosystem values excluded)", text)
        self.assertIn("| open |", text)
        self.assertIn("keep_documented (2026-10-11)", text)
        self.assertIn("still open: 0 (already decided by the owner: 0)", text)                  # the headline comes from the built document

    def test_ranking_orders_by_hits_and_keeps_demand_separate(self):
        self.series("cellrank", "candidate", {2025: 500, 2026: 480})
        self.series("scanorama", "candidate", {2025: 120, 2026: 40})
        self.series("scvelo", "candidate", {2025: 900, 2026: 700})
        self.series("harmony", "family_member", {2025: 9999})     # has an omicstat module (seurat-integrate): never a candidate
        unmet = self.dir / "unmet_needs.jsonl"
        unmet.write_text(json.dumps({"kind": "report", "id": "n1", "time": "2026-10-02T00:00:00", "requested_analysis": "trajectory fate mapping with CellRank"}) + "\n" +
                         json.dumps({"kind": "update", "id": "n1", "time": "2026-10-02T01:00:00", "method": "CellRank", "packages": ["cellrank 2.0"]}) + "\n", encoding="utf-8")
        doc = self.build(unmet=unmet)
        top = doc["A_coverage"]["top"]
        self.assertEqual([r["token"] for r in top], ["scvelo", "cellrank", "scanorama"])
        self.assertEqual(top[0]["per_1000_last_year"], 90.0)
        self.assertEqual(top[2]["ytd_vs_last_year_pct"], -67)
        by_token = {r["token"]: r for r in top}
        self.assertEqual(by_token["cellrank"]["demand"]["unmet_needs"], 1)
        self.assertEqual(by_token["scvelo"]["demand"]["unmet_needs"], 0)
        self.assertNotIn("score", json.dumps(top[0]).replace("per_1000", ""))                  # no combined score field
        self.assertEqual(doc["headline"]["top3"], ["scvelo", "cellrank", "scanorama"])
        self.assertIn("1 / 0 / 0", digest.render(doc))

    def test_own_watch_proposals_are_not_demand(self):
        self.series("cellrank", "candidate", {2025: 500, 2026: 480})
        con = digest.sqlite3.connect(self.dir / "reference.sqlite")
        con.executescript("CREATE TABLE domain_proposals(name TEXT, kind TEXT, status TEXT, payload_json TEXT);")
        con.execute("INSERT INTO domain_proposals VALUES('CellRank watch','method_family','accepted',?)", (json.dumps({"rationale": "x", "proposer": "coverage-upgrade"}),))
        con.execute("INSERT INTO domain_proposals VALUES('CellRank fate mapping','analysis_module_request','proposed',?)", (json.dumps({"rationale": "x", "proposer": "agent"}),))
        con.commit(); con.close()
        doc = self.build()
        self.assertEqual(doc["A_coverage"]["top"][0]["demand"]["domain_proposals"], 1)

    def test_decline_and_emerging_alerts(self):
        self.series("scanorama", "candidate", {2023: 200, 2024: 150, 2025: 100})
        self.series("cellrank", "candidate", {2023: 600, 2024: 600, 2025: 600})
        self.series("bbknn", "candidate", {2023: 10, 2024: 150, 2025: 400})
        fam = digest.section_b(digest.lexicon.default_lexicon(), *digest.load_series(digest.ro(self.dir / "harvest.sqlite")), 2026)
        integration = fam["families"]["sc-integration"]
        self.assertEqual([d["member"] for d in integration["decliners"]], ["scanorama"])
        self.assertEqual([r["member"] for r in integration["risers"]], ["bbknn"])
        self.assertEqual(fam["alerts"], 2)
        self.assertEqual(fam["families"]["bulk-de"]["decliners"], [])

    def test_two_points_are_not_a_trend(self):
        self.series("scanorama", "candidate", {2025: 200, 2026: 10})
        fam = digest.section_b(digest.lexicon.default_lexicon(), *digest.load_series(digest.ro(self.dir / "harvest.sqlite")), 2026)
        self.assertEqual(fam["alerts"], 0)

    def test_store_without_v3_tables_still_renders(self):
        legacy = self.dir / "legacy"
        legacy.mkdir()
        con = sqlite3.connect(legacy / "harvest.sqlite")
        con.executescript("""CREATE TABLE candidates(candidate_id TEXT, status TEXT, legacy_flag TEXT, module TEXT);
            CREATE TABLE daily_runs(day TEXT, state TEXT, detail_json TEXT, updated_at TEXT);
            CREATE TABLE daily_gate_counts(day TEXT, gate TEXT, n INTEGER);
            CREATE TABLE method_map_state(map_hash TEXT, order_json TEXT, next_module TEXT, state TEXT, updated_at TEXT);
            CREATE TABLE literature_requests(payload_json TEXT, keywords_json TEXT, module TEXT, status TEXT);""")
        con.commit()
        con.close()
        doc = digest.build(legacy, month="2026-10", now=NOW, unmet_path=None, env_json=None, repo=None)
        self.assertEqual(doc["A_coverage"]["candidates_probed"], 0)
        self.assertIn("## A. Coverage ranking", digest.render(doc))

    def test_main_writes_markdown_and_json_next_to_each_other(self):
        out = self.dir / "reports"
        sys.argv = ["reference_digest.py", "--data-dir", str(self.dir), "--out-dir", str(out), "--month", "2026-10",
                    "--unmet-needs", str(self.dir / "none.jsonl"), "--env-json", str(self.dir / "none.json"), "--repo", str(self.dir)]
        self.assertEqual(digest.main(), 0)
        md, js = out / "digest-2026-10.md", out / "digest-2026-10.json"
        self.assertTrue(md.is_file() and js.is_file())
        self.assertEqual(json.loads(js.read_text(encoding="utf-8"))["month"], "2026-10")


if __name__ == "__main__":
    unittest.main()
