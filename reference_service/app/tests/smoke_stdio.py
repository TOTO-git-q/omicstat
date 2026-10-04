"""Run real MCP stdio initialization/tool calls in an isolated local data directory (omicstat fork)."""
import asyncio
import json
import os
from pathlib import Path
import sys
from contextlib import nullcontext
from scratch import scratch_directory

from mcp import ClientSession, StdioServerParameters
from mcp.client.stdio import stdio_client


async def main():
    project = Path(__file__).resolve().parents[1]
    live = "--live" in sys.argv
    with (nullcontext(str(project / "data")) if live else scratch_directory()) as scratch:
        params = StdioServerParameters(command=sys.executable, args=[str(project / "server.py")],
                                      env={**os.environ, "OMICSTAT_REFERENCE_DATA": scratch})
        async with stdio_client(params) as (read, write):
            async with ClientSession(read, write) as session:
                await session.initialize()
                discovered = await session.list_tools()
                names = {tool.name for tool in discovered.tools}
                expected = {"reference_status", "reference_search", "reference_get_record",
                            "reference_advise", "reference_list_candidates", "reference_submit_review",
                            "reference_request_literature", "reference_request_status",
                            "reference_cancel_request", "reference_propose_domain"}
                assert names == expected, names
                checks = []
                for name, arguments in [
                    ("reference_status", {}),
                    ("reference_search", {"query": "差异表达", "module": "deseq2-wald", "limit": 3}),
                    ("reference_advise", {"module": "deseq2-wald", "study_contract": {}}),
                                        ("reference_get_record", {"record_type": "paper", "record_id": "missing"}),
                    ("reference_list_candidates", {}),
                    ("reference_list_candidates", {"include_legacy": True, "limit": 2}),
                    ("reference_search", {"query": "DESeq2", "module": "deseq2-wald", "limit": 2, "include_discovery": True}),
                    ("reference_request_literature", {"request": {"module": "deseq2-wald", "question": "Shrinkage estimator for two-group DESeq2 Wald tests",
                        "study_context": {"design": "two_group", "data_structure": "bulk_counts", "outcome_type": "gene_level_differential_expression"},
                        "required_conditions": ["bulk RNA-seq"], "parameters_of_interest": ["shrinkage estimator"], "requester": "smoke test"}}),
                    ("reference_request_literature", {"request": {"module": "deseq2-wald", "question": "contact a@b.org",
                        "study_context": {"design": "two_group", "data_structure": "bulk_counts", "outcome_type": "gene_level_differential_expression"},
                        "requester": "smoke test"}}),
                    ("reference_request_status", {"request_id": "LR-0000000000000000"}),
                    ("reference_cancel_request", {"request_id": "not-an-id"}),
                    ("reference_propose_domain", {"proposal": {"kind": "analysis_module_request", "name": "Spatial domain detection",
                        "rationale": "Spatially resolved clustering is not covered", "modules_checked": [{"module": "seurat-integrate",
                        "reason_not_applicable": "no spatial neighbourhood model"}], "evidence_locators": [], "proposer": "smoke test"}}),
                ]:
                    result = await session.call_tool(name, arguments)
                    assert not result.isError, (name, result)
                    structured = result.structuredContent
                    assert isinstance(structured, dict), (name, result)
                    json.dumps(structured, allow_nan=False)
                    if name == "reference_advise":
                        assert structured["status"] == "needs_input", structured
                        assert structured["automatic_parameter_application"] is False
                    if name == "reference_status":
                        assert structured["curated"]["counts"] == {"papers": 0, "usages": 0, "decisions": 0}, structured
                        assert structured["discovery"]["quota_basis"] == "screened_only", structured
                    if name == "reference_search":
                        for key in ("results", "reviewed_supplement", "discovery", "columns_order"):
                            assert key in structured, (key, structured)
                        assert structured["columns_order"] == ["curated", "reviewed_supplement", "discovery"], structured
                        assert structured["discovery"]["label"] == "unreviewed_machine_screened", structured
                    if name == "reference_request_literature":
                        if "a@b.org" in json.dumps(arguments):
                            assert structured["status"] == "needs_input", structured
                            assert structured["error"]["code"] == "sensitive_content_refused", structured
                        else:
                            assert structured["status"] == "queued" and structured["merged"] is False, structured
                            assert structured["blocking"] is False, structured
                            first_id = structured["request_id"]
                            again = (await session.call_tool(name, arguments)).structuredContent
                            assert again["request_id"] == first_id and again["merged"] is True, again
                            followup = (await session.call_tool("reference_request_status", {"request_id": first_id})).structuredContent
                            assert followup["status"] == "queued" and followup["attempts_allowed"] == 3, followup
                            cancelled = (await session.call_tool("reference_cancel_request", {"request_id": first_id})).structuredContent
                            assert cancelled["status"] == "cancelled" and cancelled["cancelled"] is True, cancelled
                            resubmitted = (await session.call_tool(name, arguments)).structuredContent  # R2
                            assert resubmitted["request_id"] != first_id and resubmitted["merged"] is False, resubmitted
                            assert resubmitted["status"] == "queued", resubmitted
                    if name in {"reference_request_status", "reference_cancel_request"}:
                        assert structured["status"] == "needs_input", structured
                    if name == "reference_propose_domain":
                        assert structured["status"] == "proposed", structured
                        assert structured["effects"] == {"rotation_changed": False, "code_installed": False, "analysis_supported": False}, structured
                    if name == "reference_list_candidates" and live:
                        assert structured["total"] >= 1, structured
                        candidate_id = structured["items"][0]["candidate_id"]
                        fetched = await session.call_tool("reference_get_record", {"record_type": "candidate", "record_id": candidate_id})
                        assert fetched.structuredContent["candidate_id"] == candidate_id, fetched
                    checks.append({"tool": name, "json_valid": True})
        print(json.dumps({"status": "passed", "live_data": live, "tools": sorted(names), "checks": checks}, indent=2))


if __name__ == "__main__":
    asyncio.run(main())
