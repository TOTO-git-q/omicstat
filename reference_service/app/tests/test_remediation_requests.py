"""(omicstat fork: omics request fixtures.) Audit remediation for literature requests: R2 states/resubmission (F-02), caps (F-07), wording (F-09),
keyword folding (F-11) and MRN refusal (F-12)."""
import datetime as dt
import threading
import unittest
from pathlib import Path

import literature_requests as lr
from harvest import REQUEST_PHASE_MAX_REQUESTS, HarvestStore, harvest_daily
from scratch import scratch_directory
from v2fixtures import TODAY, Fetcher, UniqueStream, result


def req(module="deseq2-wald", requester="analysis agent", conditions=("apeglm shrinkage",), **extra):
    base = {"module": module, "question": "Which LFC shrinkage estimators are used with DESeq2 Wald tests?",
            "study_context": {"design": "two_group", "data_structure": "bulk_counts", "outcome_type": "gene_level_differential_expression"},
            "required_conditions": list(conditions), "parameters_of_interest": ["shrinkage estimator"], "requester": requester}
    base.update(extra)
    return base


class RequestRemediationTests(unittest.TestCase):
    def setUp(self):
        self.scratch = scratch_directory()
        self.dir = Path(self.scratch.__enter__())
        self.store = HarvestStore(self.dir / "harvest.sqlite")

    def tearDown(self):
        self.scratch.__exit__(None, None, None)

    def active_rows(self):
        con = self.store._connection()
        try:
            return con.execute("SELECT count(*) FROM literature_requests WHERE status IN ('queued','searching')").fetchone()[0]
        finally:
            con.close()

    # ---- R2 resubmission -------------------------------------------------
    def test_resubmission_after_cancel_expire_and_unavailable_creates_new_request(self):
        first = lr.submit(self.store, req(), now=TODAY)
        dup = lr.submit(self.store, req(question="other wording"), now=TODAY)
        self.assertEqual((dup["request_id"], dup["merged"]), (first["request_id"], True))
        lr.cancel(self.store, first["request_id"], now=TODAY)
        again = lr.submit(self.store, req(), now=TODAY)
        self.assertNotEqual(again["request_id"], first["request_id"])
        self.assertEqual((again["merged"], again["status"]), (False, "queued"))
        self.assertEqual(again["history"][0]["resubmission_of"], first["request_id"])
        # expired
        short = lr.submit(self.store, req(module="seurat-qc", expires_days=1), now=TODAY)
        later = TODAY + dt.timedelta(days=2)
        self.assertEqual(lr.get_status(self.store, short["request_id"], now=later)["status"], "expired")
        renewed = lr.submit(self.store, req(module="seurat-qc", expires_days=1), now=later)
        self.assertEqual((renewed["merged"], renewed["status"]), (False, "queued"))
        self.assertNotEqual(renewed["request_id"], short["request_id"])
        # unavailable (3 empty attempts)
        empty = lr.submit(self.store, req(module="deseq2-qc", expires_days=14), now=TODAY)
        fetcher = Fetcher(pages=lambda q, n: [])
        for offset in range(3):
            harvest_daily(self.store, target=10, transport="direct", fetcher=fetcher, now=TODAY + dt.timedelta(days=offset), max_requests=5)
        self.assertEqual(lr.get_status(self.store, empty["request_id"], now=TODAY + dt.timedelta(days=3))["status"], "unavailable")
        back = lr.submit(self.store, req(module="deseq2-qc", expires_days=14), now=TODAY + dt.timedelta(days=3))
        self.assertEqual((back["merged"], back["status"]), (False, "queued"))
        self.assertNotEqual(back["request_id"], empty["request_id"])

    def test_partially_fulfilled_is_terminal_after_exhausted_attempts(self):
        request = lr.submit(self.store, req(max_papers=3, expires_days=14), now=TODAY)
        calls = {"n": 0}
        def pages(query, n):
            if '"apeglm"' in query:
                calls["n"] += 1
                return [result(701)] if calls["n"] == 1 else []
            return []
        fetcher = Fetcher(pages=pages)
        for offset in range(3):
            harvest_daily(self.store, target=10, transport="direct", fetcher=fetcher, now=TODAY + dt.timedelta(days=offset), max_requests=6)
        day4 = TODAY + dt.timedelta(days=3)
        status = lr.get_status(self.store, request["request_id"], now=day4)
        self.assertEqual(status["status"], "partially_fulfilled")
        self.assertEqual(len(status["linked_candidates"]), 1)
        self.assertEqual(status["gap_report"]["reason"], "attempts_exhausted_partial")
        self.assertEqual(status["progress"], {"linked": 1, "max_papers": 3})
        self.assertEqual(lr.due_requests(self.store, "2026-09-23", now=day4), [])
        self.assertFalse(lr.cancel(self.store, request["request_id"], now=day4)["cancelled"])

    def test_concurrent_identical_submissions_leave_one_active_row(self):
        ids, errors = [], []
        def worker():
            try:
                ids.append(lr.submit(HarvestStore(self.dir / "harvest.sqlite"), req(), now=TODAY)["request_id"])
            except Exception as exc:  # surfaced below
                errors.append(exc)
        threads = [threading.Thread(target=worker) for _ in range(8)]
        for t in threads:
            t.start()
        for t in threads:
            t.join()
        self.assertEqual(errors, [])
        self.assertEqual(len(set(ids)), 1)
        self.assertEqual(self.active_rows(), 1)

    # ---- F-07 caps -------------------------------------------------------
    def test_request_phase_is_capped_and_unstarted_requests_keep_attempts(self):
        ids = [lr.submit(self.store, req(requester=f"agent-{i // 5}", conditions=(f"condition{i} marker",)), now=TODAY)["request_id"]
               for i in range(10)]
        stream = UniqueStream(size=2)
        fetcher = Fetcher(pages=lambda q, n: [] if "marker" in q else stream(q, n))
        answer = harvest_daily(self.store, target=10, transport="direct", fetcher=fetcher, now=TODAY)
        request_searches = [q for q in fetcher.search_queries if "marker" in q]
        self.assertLessEqual(len(request_searches), REQUEST_PHASE_MAX_REQUESTS)
        self.assertEqual(len(request_searches), 6)
        self.assertEqual(answer["daily_total"], 10)
        attempts = [lr.get_status(self.store, rid, now=TODAY)["attempts_used"] for rid in ids]
        self.assertEqual(attempts[:6], [1] * 6)
        self.assertEqual(attempts[6:], [0] * 4)

    def test_queue_caps(self):
        for i in range(5):
            lr.submit(self.store, req(requester="same", conditions=(f"cond{i} alpha",)), now=TODAY)
        with self.assertRaises(lr.RequestError) as mine:
            lr.submit(self.store, req(requester="same", conditions=("cond5 alpha",)), now=TODAY)
        self.assertEqual(mine.exception.code, "request_queue_full")
        for i in range(25):
            lr.submit(self.store, req(requester=f"r{i}", conditions=(f"other{i} beta",)), now=TODAY)
        self.assertEqual(self.active_rows(), 30)
        import service
        from unittest.mock import patch
        with patch.object(service, "harvest_store", return_value=self.store):
            answer = service.invoke(service.request_literature, req(requester="newcomer", conditions=("thirty one",)))
        self.assertEqual((answer["status"], answer["error"]["code"]), ("needs_input", "request_queue_full"))
        self.assertEqual(self.active_rows(), 30)

    # ---- F-09, F-11, F-12 ------------------------------------------------
    def test_next_action_wording(self):
        answer = lr.submit(self.store, req(), now=TODAY)
        self.assertIn("Asia/Shanghai", answer["next_action"])
        self.assertIn("Do not wait", answer["next_action"])

    def test_accent_folding_and_non_latin_tokens(self):
        self.assertEqual(lr._clean_words("résumé naïve café"), ["resume", "naive", "cafe"])
        self.assertEqual(lr._clean_words("中文 pseudobulk"), ["pseudobulk"])
        kw = lr.extract_keywords(lr.validate_request(req(conditions=('METHODS:"x") OR (TITLE:y',))))
        self.assertEqual(kw["required"], ["methods", "title"])

    def test_mrn_followed_by_digits_is_refused(self):
        for text in ("MRN12345 in the sample sheet", "MRN:12 was linked"):
            with self.assertRaises(lr.RequestError, msg=text) as ctx:
                lr.validate_request(req(question=text))
            self.assertEqual(ctx.exception.code, "sensitive_content_refused")
        lr.validate_request(req(question="MRNA vaccine single-cell cohorts"))


if __name__ == "__main__":
    unittest.main()
