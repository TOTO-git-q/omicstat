"""Real MCP stdio smoke of the omicstat_reference server (the fork in app/).

Offline (default): stages the fork (app/) into a temp dir, starts `python server.py`
with a scratch data directory, and exercises all ten tools (including the request -> merge -> cancel
-> resubmit flow). No network: requests are only queued.

Remote (--remote): runs the same READ-ONLY checks against the deployed container through the
registered command, e.g.
  python tests/smoke_reference_stdio.py --remote ssh -T -o BatchMode=yes <user>@<analysis-host> \
      docker exec -i omicstat-reference python /app/server.py
Nothing is written to the live store in remote mode.
"""
from __future__ import annotations

import asyncio
import json
import os
import shutil
import sys
import tempfile
from pathlib import Path

from mcp import ClientSession, StdioServerParameters
from mcp.client.stdio import stdio_client

HERE = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(HERE))
import stage_build  # noqa: E402

EXPECTED = {"reference_status", "reference_search", "reference_get_record", "reference_advise",
            "reference_list_candidates", "reference_submit_review", "reference_request_literature",
            "reference_request_status", "reference_cancel_request", "reference_propose_domain"}
REQUEST = {"module": "deseq2-wald", "question": "Which adjusted P cutoff and LFC shrinkage estimator are reported for two-group bulk RNA-seq DESeq2 Wald tests",
           "study_context": {"design": "two_group", "data_structure": "bulk_counts", "outcome_type": "gene_level_differential_expression"},
           "required_conditions": ["bulk RNA-seq counts"], "parameters_of_interest": ["lfcShrink estimator"],
           "requester": "omicstat reference smoke"}


CONTRACT = {"study_design": "two-group, 3 vs 3 biological replicates", "analysis_population": "samples.csv; 6 samples",
            "estimand": "treated vs control; shrunken log2 fold change", "exposure_or_intervention": "condition = treated",
            "comparator": "control", "outcomes": ["Homo sapiens genes, GENCODE v44"], "covariates": ["batch"],
            "missing_data": "genes with >= 10 counts in >= 3 samples kept", "multiplicity": "Benjamini-Hochberg, padj < 0.05"}


async def call(session, name, arguments):
    result = await session.call_tool(name, arguments)
    assert not result.isError, (name, result)
    structured = result.structuredContent
    assert isinstance(structured, dict), (name, result)
    json.dumps(structured, allow_nan=False)
    return structured


async def run(params: StdioServerParameters, remote: bool) -> dict:
    report: dict = {"mode": "remote" if remote else "offline"}
    async with stdio_client(params) as (read, write):
        async with ClientSession(read, write) as session:
            init = await session.initialize()
            assert init.serverInfo.name == "omicstat_reference", init.serverInfo
            report["server_name"] = init.serverInfo.name
            names = {t.name for t in (await session.list_tools()).tools}
            assert names == EXPECTED, names
            report["tools"] = sorted(names)

            status = await call(session, "reference_status", {})
            assert status["curated"]["counts"] == {"papers": 0, "usages": 0, "decisions": 0}, status["curated"]
            assert status["curated"]["registered_modules"] == 41, status["curated"]
            assert status["interface"]["server"] == "omicstat_reference", status["interface"]
            assert status["discovery"]["quota_basis"] == "screened_only", status["discovery"]
            assert status["interface"]["search_columns"] == ["curated", "reviewed_supplement", "discovery"]
            report["status"] = {"curated_counts": status["curated"]["counts"], "deployment": status["deployment"],
                                "discovery_keys": sorted(status["discovery"])[:40]}

            search = await call(session, "reference_search", {"module": "deseq2-wald", "limit": 5})
            assert search["columns_order"] == ["curated", "reviewed_supplement", "discovery"], search
            assert search["results"] == [] and search["curated_evidence"]["status"] == "no_curated_evidence_yet", search
            assert search["discovery"]["label"] == "unreviewed_machine_screened", search["discovery"]
            assert "reviewed_supplement" in search
            report["search_deseq2_wald"] = {"curated_total": search["total"], "curated_evidence": search["curated_evidence"]["status"],
                                            "reviewed_supplement_total": search["reviewed_supplement"].get("total"),
                                            "discovery_total": search["discovery"].get("total")}
            free = await call(session, "reference_search", {"query": "DESeq2", "limit": 3})
            report["search_query_DESeq2"] = {"curated_total": free["total"], "discovery_total": free["discovery"].get("total")}
            medstat = await call(session, "reference_search", {"module": "rcs-analysis"})
            assert medstat["status"] == "needs_input" and medstat["error"]["code"] == "unknown_module", medstat

            advise = await call(session, "reference_advise", {"module": "scran-cluster", "study_contract": {}})
            assert advise["status"] == "needs_input" and advise["automatic_parameter_application"] is False, advise
            report["advise"] = {}
            for module in ("deseq2-wald", "scran-cluster", "wgcna-network", "scanvi-annotate"):
                found = await call(session, "reference_search", {"module": module, "limit": 2})
                assert found["curated_evidence"]["status"] == "no_curated_evidence_yet", (module, found)
                got = await call(session, "reference_advise", {"module": module, "study_contract": CONTRACT})
                assert got["status"] == "review_required", (module, got)
                assert got["curated_evidence"]["status"] == "no_curated_evidence_yet", (module, got)
                assert got["execution_authorized"] is False and got["automatic_parameter_application"] is False
                report["advise"][module] = {"search": found["curated_evidence"]["status"], "discovery_total": found["discovery"].get("total"),
                                            "advise": got["status"], "curated_evidence": got["curated_evidence"]["status"]}
            listing = await call(session, "reference_list_candidates", {"limit": 3})
            report["candidates_total"] = listing.get("total")
            missing = await call(session, "reference_get_record", {"record_type": "paper", "record_id": "missing"})
            assert missing["status"] == "needs_input", missing

            if not remote:
                first = await call(session, "reference_request_literature", {"request": REQUEST})
                assert first["status"] == "queued" and first["merged"] is False and first["blocking"] is False, first
                again = await call(session, "reference_request_literature", {"request": REQUEST})
                assert again["request_id"] == first["request_id"] and again["merged"] is True, again
                follow = await call(session, "reference_request_status", {"request_id": first["request_id"]})
                assert follow["status"] == "queued" and follow["attempts_allowed"] == 3, follow
                cancelled = await call(session, "reference_cancel_request", {"request_id": first["request_id"]})
                assert cancelled["status"] == "cancelled", cancelled
                wrong = await call(session, "reference_request_literature", {"request": {**REQUEST, "module": "rcs-analysis"}})
                assert wrong["status"] == "needs_input", wrong
                pii = await call(session, "reference_request_literature", {"request": {**REQUEST, "question": "mail a@b.org"}})
                assert pii["error"]["code"] == "sensitive_content_refused", pii
                proposal = await call(session, "reference_propose_domain", {"proposal": {
                    "kind": "analysis_module_request", "name": "Spatial transcriptomics domains",
                    "rationale": "Spatially resolved clustering is not covered",
                    "modules_checked": [{"module": "seurat-cluster", "reason_not_applicable": "no spatial neighbourhood model"}],
                    "evidence_locators": [], "proposer": "omicstat reference smoke"}})
                assert proposal["status"] == "proposed", proposal
                report["request_flow"] = "queued -> merged -> cancelled; medstat module and PII refused; domain proposal registered"
    report["status_result"] = "passed"
    return report


def main() -> int:
    argv = sys.argv[1:]
    if argv and argv[0] == "--remote":
        command = argv[1:]
        params = StdioServerParameters(command=command[0], args=command[1:], env=dict(os.environ))
        print(json.dumps(asyncio.run(run(params, remote=True)), indent=2))
        return 0
    tmp = Path(tempfile.mkdtemp(prefix="omicref-smoke-"))
    try:
        stage_build.stage(tmp / "context")
        params = StdioServerParameters(command=sys.executable, args=[str(tmp / "context" / "server.py")],
                                       env={**os.environ, "OMICSTAT_REFERENCE_DATA": str(tmp / "data"),
                                            "OMICSTAT_REFERENCE_LOGS": str(tmp / "logs"), "PYTHONDONTWRITEBYTECODE": "1"})
        print(json.dumps(asyncio.run(run(params, remote=False)), indent=2))
    finally:
        shutil.rmtree(tmp, ignore_errors=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
