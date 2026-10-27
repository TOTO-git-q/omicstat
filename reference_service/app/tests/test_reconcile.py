"""Method-map reconciliation (omicstat fork coverage upgrade): order-preserving extension reconciles
automatically and keeps the harvest cursor; every other change stays blocked until `cli.py map-reconcile`."""
import json
import os
import subprocess
import sys
import unittest
from pathlib import Path

from harvest import HarvestError, HarvestStore, _load_method_map, harvest_daily
from scratch import scratch_directory
from v2fixtures import TODAY, Fetcher, UniqueStream

APP = Path(__file__).resolve().parents[1]


def sub_map(method_map, keep):
    order = [m for m in method_map["order"] if m in keep]
    return {**method_map, "hash": "h-" + "-".join(order)[:40] + str(len(order)), "order": order}


class ReconcileTests(unittest.TestCase):
    def setUp(self):
        self.scratch = scratch_directory()
        self.dir = Path(self.scratch.__enter__())
        self.store = HarvestStore(self.dir / "harvest.sqlite")
        self.full = _load_method_map()
        self.old = {**self.full, "hash": "old-38", "order": self.full["order"][:38]}

    def tearDown(self):
        self.scratch.__exit__(None, None, None)

    def test_map_has_the_three_display_modules_appended(self):
        self.assertEqual(len(self.full["order"]), 41)
        self.assertEqual(self.full["order"][38:], ["scanpy-annotate", "scanpy-purity", "scanpy-ingest"])

    def test_extension_reconciles_and_keeps_cursor(self):
        self.store.configure_method_map(self.old)
        self.store.add_candidate({"title": "x", "module": "deseq2-wald", "status": "screened", "pmid": "1", "flags": [], "provenance": {}},
                                 day="2026-09-20", quota=10, map_hash="old-38", next_module="seurat-markers")
        self.store.set_cursor("v2:seurat-markers", "AoEcursor123")
        result = self.store.configure_method_map(self.full)
        self.assertEqual(result["state"], "reconciled")
        self.assertEqual(result["next_module"], "seurat-markers")
        self.assertEqual(result["added"], ["scanpy-annotate", "scanpy-purity", "scanpy-ingest"])
        state = self.store.status()["method_map"]
        self.assertEqual((state["state"], state["hash"], state["next_module"], len(state["order"])), ("active", self.full["hash"], "seurat-markers", 41))
        self.assertIn("auto", state["last_reconcile"]["detail"])
        self.assertEqual(self.store.cursor("v2:seurat-markers"), "AoEcursor123")
        # idempotent: the second call is a plain active pass with the same cursor
        again = self.store.configure_method_map(self.full)
        self.assertEqual((again["state"], again["next_module"]), ("active", "seurat-markers"))

    def test_insertion_in_the_middle_still_reconciles(self):
        self.store.configure_method_map(self.old)
        order = list(self.old["order"])
        order.insert(5, "a-new-module")
        changed = {**self.old, "hash": "mid", "order": order}
        self.assertEqual(self.store.configure_method_map(changed)["state"], "reconciled")

    def test_blocked_when_not_a_subsequence(self):
        self.store.configure_method_map(self.old)
        for name, order in (("removed", self.old["order"][:-1] + ["z-extra"][:0]),
                            ("reordered", list(reversed(self.old["order"]))),
                            ("swapped", [self.old["order"][1], self.old["order"][0]] + self.old["order"][2:])):
            with self.subTest(name):
                store = HarvestStore(self.dir / f"{name}.sqlite")
                store.configure_method_map(self.old)
                with self.assertRaises(HarvestError) as failure:
                    store.configure_method_map({**self.old, "hash": "x-" + name, "order": order})
                self.assertEqual(failure.exception.code, "method_map_changed")
                self.assertEqual(store.status()["method_map"]["state"], "map_change_blocked")

    def test_blocked_when_next_module_disappears(self):
        self.store.configure_method_map(self.old)
        self.store.add_candidate({"title": "x", "module": "deseq2-wald", "status": "screened", "pmid": "1", "flags": [], "provenance": {}},
                                 day="2026-09-20", quota=10, map_hash="old-38", next_module="limma-voom")
        order = [m for m in self.full["order"] if m != "limma-voom"]
        with self.assertRaises(HarvestError):
            self.store.configure_method_map({**self.full, "hash": "no-next", "order": order})
        self.assertEqual(self.store.status()["method_map"]["next_module"], "limma-voom")

    def test_manual_reconcile_dry_run_then_confirm(self):
        self.store.configure_method_map(self.old)
        self.store.set_cursor("v2:limma-voom", "keep-me")
        reordered = {**self.full, "hash": "reordered", "order": list(reversed(self.full["order"]))}
        with self.assertRaises(HarvestError):
            self.store.configure_method_map(reordered)
        dry = self.store.reconcile_method_map(reordered, "deseq2-qc")
        self.assertEqual(dry["state"], "dry_run")
        self.assertEqual(self.store.status()["method_map"]["state"], "map_change_blocked")
        with self.assertRaises(HarvestError) as bad:
            self.store.reconcile_method_map(reordered, "not-a-module", confirm=True)
        self.assertEqual(bad.exception.code, "unknown_module")
        done = self.store.reconcile_method_map(reordered, "deseq2-qc", confirm=True)
        self.assertEqual(done["state"], "reconciled")
        state = self.store.status()["method_map"]
        self.assertEqual((state["state"], state["next_module"], state["hash"]), ("active", "deseq2-qc", "reordered"))
        self.assertIn("manual", state["last_reconcile"]["detail"])
        self.assertEqual(self.store.cursor("v2:limma-voom"), "keep-me")
        self.assertEqual(self.store.configure_method_map(reordered)["state"], "active")

    def test_harvest_cycle_after_extension_has_no_method_map_changed(self):
        """Full cycle: 38-module profiles/map first, then the 41-module files; cursor continues."""
        profiles = json.loads((APP / "discovery_profiles.json").read_text(encoding="utf-8"))
        full_map = json.loads((APP / "method_map.json").read_text(encoding="utf-8"))
        keep = {m["module"] for m in full_map["modules"][:38]}
        small_profiles = {**profiles, "profiles": [p for p in profiles["profiles"] if p["module"] in keep]}
        small_map = {**full_map, "modules": full_map["modules"][:38]}
        (self.dir / "p38.json").write_text(json.dumps(small_profiles), encoding="utf-8")
        (self.dir / "m38.json").write_text(json.dumps(small_map), encoding="utf-8")
        first = harvest_daily(self.store, target=2, transport="direct", fetcher=Fetcher(pages=UniqueStream(size=3)), now=TODAY,
                              method_map_path=self.dir / "m38.json", profiles_path=self.dir / "p38.json")
        self.assertEqual(first["method_map"]["state"], "active")
        cursor_module = first["method_map"]["next_module"]
        self.assertNotEqual(cursor_module, "deseq2-wald")
        later = TODAY.replace(day=21)
        second = harvest_daily(self.store, target=1, transport="direct", fetcher=Fetcher(pages=UniqueStream(size=3, start=500000)), now=later)
        self.assertNotIn("method_map_changed", json.dumps(second))
        self.assertEqual(second["method_map"]["state"], "active")
        self.assertEqual(len(second["method_map"]["order"]), 41)
        self.assertEqual(second["method_map"]["last_reconcile"]["next_module"], cursor_module)
        self.assertGreaterEqual(second["collected"], 1)

    def test_cli_map_reconcile(self):
        reordered = {**self.full, "hash": "reordered", "order": list(reversed(self.full["order"]))}
        self.store.configure_method_map(reordered)  # a stored state that the shipped map cannot extend
        with self.assertRaises(HarvestError):
            self.store.configure_method_map(self.full)
        env = {**os.environ, "OMICSTAT_REFERENCE_DATA": str(self.dir), "PYTHONUTF8": "1"}

        def cli(*args):
            done = subprocess.run([sys.executable, str(APP / "cli.py"), *args], cwd=APP, env=env, capture_output=True, text=True, timeout=60)
            return done.returncode, json.loads(done.stdout)
        code, dry = cli("map-reconcile", "--to-module", "deseq2-lrt")
        self.assertEqual((code, dry["state"]), (0, "dry_run"))
        code, bad = cli("map-reconcile", "--to-module", "nope", "--confirm")
        self.assertEqual(code, 1)
        self.assertEqual(bad["error"]["code"], "unknown_module")
        code, done = cli("map-reconcile", "--to-module", "deseq2-lrt", "--confirm")
        self.assertEqual((code, done["state"]), (0, "reconciled"))
        code, status = cli("status")
        self.assertEqual(status["discovery"]["method_map"]["state"], "active")
        self.assertEqual(status["discovery"]["method_map"]["next_module"], "deseq2-lrt")


if __name__ == "__main__":
    unittest.main()
