"""Literature requests: schema, PII refusal, keyword sanitation, dedupe/concurrency, budget, state machine."""
import datetime as dt
import json
import threading
import unittest
from pathlib import Path

import discovery
import literature_requests as lr
from harvest import HarvestStore, harvest_daily
from scratch import scratch_directory
from v2fixtures import TODAY, Fetcher, UniqueStream, result

ROOT = Path(__file__).resolve().parents[1]


def valid(**extra):
    base = {"module": "deseq2-wald", "question": "Which LFC shrinkage estimators are used with DESeq2 Wald tests in two-group bulk RNA-seq?",
            "study_context": {"design": "two_group", "data_structure": "bulk_counts", "outcome_type": "gene_level_differential_expression",
                              "estimand": "log2 fold change treated vs control"},
            "required_conditions": ["apeglm shrinkage"], "parameters_of_interest": ["shrinkage estimator"],
            "requester": "analysis agent"}
    base.update(extra)
    return base


class ValidationTests(unittest.TestCase):
    def test_defaults_and_schema_enums_match_method_map(self):
        normalized = lr.validate_request(valid())
        self.assertEqual((normalized["max_papers"], normalized["expires_days"]), (3, 7))
        self.assertEqual(normalized["exclusions"], [])
        schema = lr.load_schema()
        order = [m["module"] for m in json.loads((ROOT / "method_map.json").read_text(encoding="utf-8"))["modules"]]
        self.assertEqual(schema["properties"]["module"]["enum"], order + ["unmapped"])
        self.assertFalse(schema["additionalProperties"])

    def test_schema_rejections(self):
        cases = [
            {k: v for k, v in valid().items() if k != "module"},
            valid(extra_field=1),
            valid(module="made-up"),
            valid(question="x" * 501),
            valid(study_context={"design": "alien", "data_structure": "bulk_counts", "outcome_type": "gene_level_differential_expression"}),
            valid(study_context={"design": "two_group", "data_structure": "bulk_counts", "outcome_type": "gene_level_differential_expression", "estimand": "e" * 201}),
            valid(required_conditions=["c"] * 9),
            valid(parameters_of_interest=["p" * 121]),
            valid(max_papers=6), valid(max_papers=0), valid(max_papers=True), valid(expires_days=15),
            valid(requester="r" * 81),
        ]
        for case in cases:
            with self.assertRaises(lr.RequestError, msg=str(case)[:120]):
                lr.validate_request(case)
        with self.assertRaises(lr.RequestError) as big:
            lr.validate_request(valid(question="问" * 500, exclusions=["e" * 119] * 8, required_conditions=["c" * 119] * 8,
                                      parameters_of_interest=["p" * 119] * 8))
        self.assertEqual(big.exception.code, "request_too_large")

    def test_sensitive_content_is_refused(self):
        bad = ["contact me at someone@example.org", "call +86 138 0013 8000", "phone 555-123-4567",
               "patient 1234567 had", "MRN 12AB", "住院号 A12", "病案号 B7", "use the patient id column"]
        for text in bad:
            with self.assertRaises(lr.RequestError, msg=text) as ctx:
                lr.validate_request(valid(question=text))
            self.assertEqual(ctx.exception.code, "sensitive_content_refused")
        for ok in ["samples from 2018-2020 with n=250,000 cells", "log2FC 1.25 (padj 0.01) in 5 samples"]:
            lr.validate_request(valid(question=ok))

    def test_keywords_are_sanitized_and_bounded(self):
        hostile = valid(required_conditions=['METHODS:"x") OR (TITLE:y', "binary OUTCOME; DROP TABLE"],
                        parameters_of_interest=["shrinkage estimator choice", "padj threshold"],
                        exclusions=["Animal study!"])
        kw = lr.extract_keywords(lr.validate_request(hostile))
        words = kw["required"] + kw["any_of"]
        self.assertLessEqual(len(words), 6)
        for word in words:
            self.assertRegex(word, r"^[a-z0-9\-]+$")
        self.assertIn("methods", kw["required"])
        self.assertNotIn("or", words)
        self.assertEqual(kw["exclusions"], ["animal study"])
        config, journals = discovery.load_profiles(), discovery.load_journals()
        query = discovery.build_query(config["profiles"]["deseq2-wald"], config, journals, today=dt.date(2026, 9, 20),
                                      keyword_mode=(kw["required"], kw["any_of"]))
        head = query.split(" AND HAS_FT:Y")[0]
        self.assertNotIn("TITLE:", head)
        self.assertEqual(head.count("("), head.count(")"))
        self.assertIn('"methods"', head)

    def test_fingerprint_normalizes_order_and_case(self):
        a = lr.fingerprint(lr.validate_request(valid(required_conditions=["A  b", "c"], parameters_of_interest=["X"])))
        b = lr.fingerprint(lr.validate_request(valid(required_conditions=["c", "a b"], parameters_of_interest=["x"], question="other wording")))
        c = lr.fingerprint(lr.validate_request(valid(module="seurat-qc", required_conditions=["c", "a b"], parameters_of_interest=["x"])))
        self.assertEqual(a, b)
        self.assertNotEqual(a, c)


class StoreTests(unittest.TestCase):
    def setUp(self):
        self.scratch = scratch_directory()
        self.dir = Path(self.scratch.__enter__())
        self.store = HarvestStore(self.dir / "harvest.sqlite")

    def tearDown(self):
        self.scratch.__exit__(None, None, None)

    def count(self, table="literature_requests"):
        con = self.store._connection()
        try:
            return con.execute(f"SELECT count(*) FROM {table}").fetchone()[0]
        finally:
            con.close()

    def test_submit_is_immediate_and_refusal_stores_nothing(self):
        answer = lr.submit(self.store, valid(), now=TODAY)
        self.assertEqual(answer["status"], "queued")
        self.assertFalse(answer["merged"])
        self.assertFalse(answer["blocking"])
        self.assertRegex(answer["request_id"], r"^LR-[0-9a-f]{16}$")
        with self.assertRaises(lr.RequestError):
            lr.submit(self.store, valid(question="email a@b.co"), now=TODAY)
        self.assertEqual(self.count(), 1)

    def test_duplicate_merges_and_concurrent_submissions_create_one_row(self):
        first = lr.submit(self.store, valid(), now=TODAY)
        again = lr.submit(self.store, valid(question="Same conditions, different wording"), now=TODAY)
        self.assertEqual((again["request_id"], again["merged"]), (first["request_id"], True))
        ids, errors = [], []
        def worker():
            try:
                ids.append(lr.submit(HarvestStore(self.dir / "harvest.sqlite"), valid(module="seurat-qc"), now=TODAY)["request_id"])
            except Exception as exc:  # pragma: no cover - surfaced below
                errors.append(exc)
        threads = [threading.Thread(target=worker) for _ in range(8)]
        for t in threads: t.start()
        for t in threads: t.join()
        self.assertEqual(errors, [])
        self.assertEqual(len(set(ids)), 1)
        self.assertEqual(self.count(), 2)

    def test_unmapped_is_unavailable_without_search(self):
        answer = lr.submit(self.store, valid(module="unmapped"), now=TODAY)
        self.assertEqual(answer["status"], "unavailable")
        self.assertEqual(answer["gap_report"]["reason"], "no_method_gate_for_unmapped_module")
        self.assertEqual(lr.due_requests(self.store, "2026-09-20", now=TODAY), [])

    def test_cancel_expire_and_terminal(self):
        a = lr.submit(self.store, valid(), now=TODAY)
        cancelled = lr.cancel(self.store, a["request_id"], now=TODAY)
        self.assertTrue(cancelled["cancelled"])
        self.assertEqual(cancelled["status"], "cancelled")
        again = lr.cancel(self.store, a["request_id"], now=TODAY)
        self.assertFalse(again["cancelled"])
        b = lr.submit(self.store, valid(module="seurat-qc", expires_days=1), now=TODAY)
        self.assertEqual(lr.get_status(self.store, b["request_id"], now=TODAY + dt.timedelta(days=2))["status"], "expired")
        with self.assertRaises(lr.RequestError):
            lr.get_status(self.store, "LR-" + "0" * 16, now=TODAY)
        with self.assertRaises(lr.RequestError):
            lr.get_status(self.store, "../etc", now=TODAY)

    def test_attempt_reservation_is_once_per_day(self):
        a = lr.submit(self.store, valid(), now=TODAY)
        self.assertTrue(lr.start_attempt(self.store, a["request_id"], "2026-09-20"))
        self.assertFalse(lr.start_attempt(self.store, a["request_id"], "2026-09-20"))
        self.assertEqual(lr.get_status(self.store, a["request_id"], now=TODAY)["status"], "searching")


class BudgetAndStateTests(unittest.TestCase):
    def setUp(self):
        self.scratch = scratch_directory()
        self.dir = Path(self.scratch.__enter__())
        self.store = HarvestStore(self.dir / "harvest.sqlite")

    def tearDown(self):
        self.scratch.__exit__(None, None, None)

    def links(self, request_id):
        con = self.store._connection()
        try:
            return con.execute("SELECT counted FROM request_links WHERE request_id=?", (request_id,)).fetchall()
        finally:
            con.close()

    def test_empty_queue_gives_rotation_all_ten(self):
        answer = harvest_daily(self.store, target=10, transport="direct", fetcher=Fetcher(pages=UniqueStream(size=2)), now=TODAY)
        self.assertEqual(answer["daily_total"], 10)
        self.assertEqual(answer["literature_requests_served"], [])
        self.assertEqual(self.store.request_slots_used("2026-09-20"), 0)

    def test_nonempty_queue_takes_at_most_four(self):
        req = lr.submit(self.store, valid(max_papers=5), now=TODAY)
        fetcher = Fetcher(pages=UniqueStream(size=6))
        answer = harvest_daily(self.store, target=10, transport="direct", fetcher=fetcher, now=TODAY)
        self.assertEqual(answer["daily_total"], 10)
        self.assertEqual(self.store.request_slots_used("2026-09-20"), 4)
        status = lr.get_status(self.store, req["request_id"], now=TODAY)
        self.assertEqual(status["status"], "searching")  # R2: attempts remain, so still active
        self.assertEqual(status["progress"], {"linked": 4, "max_papers": 5})
        self.assertEqual(len(status["linked_candidates"]), 4)
        self.assertTrue(all(c["review_state"] == "unreviewed_machine_screened" for c in status["linked_candidates"]))
        self.assertIn('"apeglm"', fetcher.search_queries[0])  # requests are served first in the cycle

    def test_unused_request_slots_return_to_rotation(self):
        req = lr.submit(self.store, valid(max_papers=3), now=TODAY)
        stream = UniqueStream(size=4)
        def pages(query, n):
            if '"apeglm"' in query:
                return [result(1)]  # the request finds only one paper
            return stream(query, n)
        answer = harvest_daily(self.store, target=10, transport="direct", fetcher=Fetcher(pages=pages), now=TODAY)
        self.assertEqual(answer["daily_total"], 10)
        self.assertEqual(self.store.request_slots_used("2026-09-20"), 1)
        status = lr.get_status(self.store, req["request_id"], now=TODAY)
        self.assertEqual((status["status"], status["progress"]["linked"]), ("searching", 1))

    def test_fulfilled_is_not_endorsement(self):
        req = lr.submit(self.store, valid(max_papers=2), now=TODAY)
        harvest_daily(self.store, target=10, transport="direct", fetcher=Fetcher(pages=UniqueStream(size=3)), now=TODAY)
        status = lr.get_status(self.store, req["request_id"], now=TODAY)
        self.assertEqual(status["status"], "fulfilled")
        self.assertIn("not scientific endorsement", status["scientific_status"])
        self.assertFalse(status["execution_authorized"])

    def test_existing_screened_candidate_is_linked_without_quota(self):
        self.store.add_candidate({"title": "Known", "module": "deseq2-wald", "status": "screened", "pmid": "4242",
                                  "flags": [], "provenance": {}}, day="2026-09-19", quota=10)
        req = lr.submit(self.store, valid(max_papers=1), now=TODAY)
        pages = lambda q, n: [result(4242)] if '"apeglm"' in q else []
        harvest_daily(self.store, target=10, transport="direct", fetcher=Fetcher(pages=pages), now=TODAY, max_requests=30)
        self.assertEqual([r[0] for r in self.links(req["request_id"])], [0])
        self.assertEqual(lr.get_status(self.store, req["request_id"], now=TODAY)["status"], "fulfilled")
        self.assertEqual(self.store.day_count("2026-09-20"), 0)

    def test_three_attempts_on_three_days_then_unavailable_with_gap_report(self):
        req = lr.submit(self.store, valid(expires_days=14), now=TODAY)
        fetcher = Fetcher(pages=lambda q, n: [])
        states = []
        for offset in range(4):
            now = TODAY + dt.timedelta(days=offset)
            harvest_daily(self.store, target=10, transport="direct", fetcher=fetcher, now=now, max_requests=5)
            harvest_daily(self.store, target=10, transport="direct", fetcher=fetcher, now=now + dt.timedelta(hours=3), max_requests=5)
            states.append(lr.get_status(self.store, req["request_id"], now=now)["status"])
        self.assertEqual(states, ["searching", "searching", "unavailable", "unavailable"])
        status = lr.get_status(self.store, req["request_id"], now=TODAY + dt.timedelta(days=4))
        self.assertEqual(status["attempts_used"], 3)
        self.assertEqual(len(status["attempts"]), 3)
        gap = status["gap_report"]
        self.assertEqual(gap["reason"], "attempts_exhausted")
        self.assertEqual(len(gap["searched"]), 3)
        self.assertEqual(gap["blocked_at"], "no_search_hits")
        request_queries = [q for q in fetcher.search_queries if '"apeglm"' in q]
        self.assertEqual(len(request_queries), 3)


if __name__ == "__main__":
    unittest.main()
