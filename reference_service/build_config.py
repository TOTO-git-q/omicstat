#!/usr/bin/env python3
"""Build the configuration files of the omicstat_reference fork (app/) from pinned repository inputs.

The fork (app/, based on medstat-reference v2 07fdebd, see FORK.md) reads its configuration from its
own directory. This script writes those files from the omicstat S0 literature-layer inputs:

  app/journals.json                       <- tools/lit/journals.json (38 journals, ISSN-verified)
  app/discovery_profiles.json             <- tools/lit/discovery_profiles.json of four branches
  app/method_map.json                     <- skills/omicstat/SKILL.md section 1 + ENGINEERING_PLAN 1.2 / 10.2 (THE module registry)
  app/decision_rules.json                 <- omics common study-context fields (StudyContract omics mapping) + covariate-purpose prompts
  app/seed/catalog.json                   <- empty seed: zero papers, usages and decisions
  app/schemas/literature_request.v1.json  <- request schema with omics study_context enums (module enum = registry)

All inputs are read from FIXED commits (config_sources.json) with `git show`, as UTF-8 bytes, so the output
is reproducible. Output is deterministic (LF, trailing newline).

  python build_config.py            # write app/ configuration files
  python build_config.py --check    # rebuild in memory and compare with app/ byte for byte

WARNING: the deployed harvest database binds the method-map hash and the reference database binds
the seed SHA-256. Changing method_map.json or seed/catalog.json after deployment blocks harvesting
(`method_map_changed`) or opening the reference store (`seed_mismatch`). See DEPLOYMENT.md.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parent
CONFIG = HERE / "app"

# Fixed input commits (resolved 2026-09-29 from the branch heads named in the M7 task).
SOURCES_FILE = HERE / "config_sources.json"

M1M2 = ["deseq2-qc", "deseq2-wald", "deseq2-lrt", "edger-qlf", "limma-voom", "limma-array", "limma-dupcor",
        "sva-batch", "clusterprofiler-ora", "clusterprofiler-gsea", "clusterprofiler-compare", "fgsea-prerank",
        "gsva-score", "limma-camera"]
BRANCH_MODULES = {
    "s0/m3-frontends": ["seurat-qc", "seurat-cluster", "seurat-integrate", "seurat-markers", "seurat-modulescore",
                        "scater-qc", "scran-cluster", "batchelor-integrate", "scran-markers", "aucell-score"],
    "s0/m3b-m4": ["singler-annotate", "muscat-pseudobulk", "speckle-propeller", "cellchat-communication",
                  "monocle3-trajectory", "slingshot-trajectory", "wgcna-network", "maftools-landscape",
                  "immunedeconv-infiltration"],
    "s0/m3c-scverse": ["scanpy-qc", "scanpy-cluster", "scanpy-markers", "scvi-integrate", "scanvi-annotate"],
}
PYTHON_LANE = {"scanpy-qc", "scanpy-cluster", "scanpy-markers", "scvi-integrate", "scanvi-annotate"}
UTILITY_MODULES = {"omicstat-selftest"}  # router rows that are not analysis modules


def git_show(commit: str, path: str) -> bytes:
    return subprocess.run(["git", "-C", str(REPO), "show", f"{commit}:{path}"], check=True,
                          capture_output=True).stdout


def git_ls(commit: str) -> list[str]:
    out = subprocess.run(["git", "-C", str(REPO), "ls-tree", "-r", "--name-only", commit], check=True,
                         capture_output=True).stdout.decode("utf-8")
    return out.splitlines()


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def dump(obj) -> bytes:
    return (json.dumps(obj, ensure_ascii=False, indent=1) + "\n").encode("utf-8")


def load_sources() -> dict[str, str]:
    pinned = json.loads(SOURCES_FILE.read_text(encoding="utf-8"))["commits"]
    if set(pinned) != {"build/m1m2", *BRANCH_MODULES}:
        raise SystemExit("config_sources.json must pin build/m1m2 and the three S0 branches")
    ok = subprocess.run(["git", "-C", str(REPO), "merge-base", "--is-ancestor", pinned["build/m1m2"], "HEAD"])
    if ok.returncode != 0:
        raise SystemExit("config_sources.json build/m1m2 commit is not an ancestor of HEAD")
    return pinned


# --------------------------------------------------------------------------- method map

def module_order(base: str) -> tuple[list[dict], bytes, bytes]:
    router = git_show(base, "skills/omicstat/SKILL.md")
    plan = git_show(base, "docs/handoff/ENGINEERING_PLAN.md")
    text = router.decode("utf-8")
    sec1 = text.split("## 1. Routing table", 1)[1].split("\n## 2.", 1)[0]
    routed = re.findall(r"^\|[^|\n]*\|\s*`([a-z0-9-]+)`\s*\|\s*`(scripts/[^`]+)`\s*\|\s*$", sec1, re.M)
    ptext = plan.decode("utf-8")
    catalogue = ptext.split("### 1.2", 1)[1].split("### 1.3", 1)[0]
    # module tables only: first cell is `module`, second cell is a package (not a Seurat/Bioc pair table)
    planned = [m for m in re.findall(r"^\|\s*`([a-z0-9-]+)`\s*\|\s*[^`|][^|]*\|", catalogue, re.M)]
    scverse = ptext.split("### 10.2", 1)[1].split("### 10.3", 1)[0]
    planned += re.findall(r"^\|\s*`([a-z0-9-]+)`\s*\|\s*[^`|][^|]*\|", scverse, re.M)
    base_files = set(git_ls(base))
    entries: list[dict] = []
    seen: set[str] = set()
    for module, script in routed:
        if module in UTILITY_MODULES:
            continue
        entries.append({"module": module, "entry_script": script, "entry_status": "installed_router_section_1"})
        seen.add(module)
    for module in planned:
        if module in seen:
            continue
        seen.add(module)
        built = sorted(p for p in base_files if re.fullmatch(rf"skills/{re.escape(module)}/scripts/run_[^/]+\.(R|py)", p))
        if built:
            entries.append({"module": module, "entry_script": built[0].split(f"skills/{module}/", 1)[1],
                            "entry_status": "built_not_yet_routed"})
        else:
            ext = "py" if module in PYTHON_LANE else "R"
            entries.append({"module": module, "entry_script": "scripts/run_%s.%s" % (module.replace("-", "_"), ext),
                            "entry_status": "planned_name_by_convention"})
    return entries, router, plan


# --------------------------------------------------------------------------- builders

def build(sources: dict[str, str]) -> dict[str, bytes]:
    base = sources["build/m1m2"]
    out: dict[str, bytes] = {}

    # journals ------------------------------------------------------------
    jraw = git_show(base, "tools/lit/journals.json")
    jsrc = json.loads(jraw.decode("utf-8"))
    for ref in BRANCH_MODULES:
        other = git_show(sources[ref], "tools/lit/journals.json")
        if sha(other) != sha(jraw):
            raise SystemExit(f"journals.json differs on {ref}; resolve before building")
    keep = ("name", "nlm_abbreviation", "issn", "tier", "nlm_id", "verified_on", "verified_via")
    journals = {
        "schema": "omicstat.reference.journals.v1",
        "note": ("omicstat_reference whitelist gate. Converted verbatim from "
                 "omic-MCP tools/lit/journals.json; every ISSN was echoed by a live Europe PMC query on verified_on. "
                 "A journal outside this list is never stored and never counts toward the daily quota. "
                 "Tier M (statistics/methodology) is unused for omics."),
        "source": {"path": "tools/lit/journals.json", "commit": base, "sha256": sha(jraw),
                   "source_schema": jsrc.get("schema")},
        "tiers": {"A": jsrc["tiers"]["A"], "B": jsrc["tiers"]["B"]},
        "journals": [{k: j[k] for k in keep if k in j} for j in jsrc["journals"]],
    }
    out["journals.json"] = dump(journals)

    # discovery profiles --------------------------------------------------
    by_ref: dict[str, dict] = {}
    for ref, commit in sources.items():
        data = json.loads(git_show(commit, "tools/lit/discovery_profiles.json").decode("utf-8"))
        by_ref[ref] = {"doc": data, "profiles": {p["module"]: p for p in data["profiles"]},
                       "sha256": sha(git_show(commit, "tools/lit/discovery_profiles.json"))}
    base_doc = by_ref["build/m1m2"]["doc"]
    min_year = int(base_doc["min_year"])
    common = base_doc["common_filter"].replace("{min_year}", str(min_year))
    shared_drift = {}
    for ref in BRANCH_MODULES:
        for m in M1M2:
            if json.dumps(by_ref[ref]["profiles"].get(m), sort_keys=True) != json.dumps(by_ref["build/m1m2"]["profiles"][m], sort_keys=True):
                shared_drift.setdefault(ref, []).append(m)
        if by_ref[ref]["doc"]["common_filter"] != base_doc["common_filter"] or by_ref[ref]["doc"].get("min_year") != base_doc.get("min_year"):
            raise SystemExit(f"common_filter/min_year differs on {ref}")
    origin = {m: "build/m1m2" for m in M1M2}
    for ref, mods in BRANCH_MODULES.items():
        for m in mods:
            origin[m] = ref
    entries, router_raw, plan_raw = module_order(base)
    order = [e["module"] for e in entries]
    if sorted(order) != sorted(origin):
        raise SystemExit("router/plan module list and profile module list differ: %s" % sorted(set(order) ^ set(origin)))
    profiles = []
    for m in order:
        ref = origin[m]
        p = by_ref[ref]["profiles"][m]
        s0 = json.loads(git_show(sources[ref], f"acceptance/exemplars/{m}/literature/search_log.json").decode("utf-8"))
        exclude = p.get("exclude_regex")
        # omlit compiles exclude_regex case-sensitively; the vendored loader compiles it with re.I.
        # Keep the S0 meaning: patterns without an inline (?i) are wrapped in a scoped (?-i:...).
        if exclude and not exclude.startswith("(?i)"):
            exclude = "(?-i:" + exclude + ")"
        gates = s0.get("gates", {})
        prof = {"module": m, "epmc_query": p["epmc_query"], "meta": False, "signal_regex": p["signal_regex"]}
        if p.get("require_regex"):
            prof["signal_require_regex"] = p["require_regex"]
        if exclude:
            prof["exclude_regex"] = exclude
        prof["profile_status"] = "ok" if int(gates.get("screened", 0)) > 0 else "weak"
        prof["validation_rounds"] = 1
        prof["s0_validation"] = {"source_ref": ref, "source_commit": sources[ref], "date": s0.get("date"),
                                 "hit_count": s0.get("hit_count"), "screened": gates.get("screened"),
                                 "corpus": s0.get("corpus"), "target": s0.get("target"),
                                 "search_log": f"acceptance/exemplars/{m}/literature/search_log.json"}
        profiles.append(prof)
    discovery = {
        "schema": "omicstat.reference.discovery-profiles.v1",
        "note": ("omicstat_reference discovery profiles. Converted from the omicstat S0 "
                 "profiles (tools/lit/discovery_profiles.json): epmc_query, signal_regex, require_regex -> signal_require_regex "
                 "and exclude_regex are copied verbatim (exclude patterns without an inline (?i) are wrapped in (?-i:...) to keep "
                 "their S0 case-sensitive meaning under the re.I compile of discovery.py); the PACK parameter regexes are dropped (the "
                 "reference service does not extract parameters). profile_status comes from the S0 live search logs "
                 "(ok = at least one screened article). The journal whitelist is the gate; the query only ranks within it."),
        "common_filter": common,
        "meta_filter": common,
        "sources": {ref: {"commit": sources[ref], "path": "tools/lit/discovery_profiles.json",
                          "sha256": by_ref[ref]["sha256"]} for ref in sources},
        "shared_m1m2_profile_drift": shared_drift,
        "profiles": profiles,
    }
    out["discovery_profiles.json"] = dump(discovery)

    # method map ----------------------------------------------------------
    method_map = {
        "schema": "omicstat.method-map.v1",
        "source_path": "omic-MCP@%s:skills/omicstat/SKILL.md (section 1) + docs/handoff/ENGINEERING_PLAN.md (1.2, 10.2)" % base[:7],
        "source_sha256": sha(router_raw),
        "plan_sha256": sha(plan_raw),
        "order_rule": ("Router section 1 rows first (utility omicstat-selftest excluded), then the remaining modules in "
                       "ENGINEERING_PLAN 1.2 table order (A bulk DE, B enrichment, C1 Seurat, C2 Bioconductor, C3 back end, "
                       "D network/mutation/infiltration), then 10.2 (scverse). This file is the module registry of omicstat_reference. "
                       "Frozen at deployment: the harvest store binds this file's hash."),
        "modules": entries,
    }
    out["method_map.json"] = dump(method_map)

    # decision rules ------------------------------------------------------
    rules = {
        "schema": "omicstat.reference.decision-rules.v1",
        "note": ("omicstat_reference advise checklist. common_required = the omicstat StudyContract v1 fields "
                 "(skills/_shared/schemas/study_contract.v1.schema.json required list, without schema_version and "
                 "analysis_sets) with the omics meanings of IMPLEMENTATION_SPEC section 4. Module-specific rules are "
                 "empty until PACK-derived omics rules are written."),
        "common_required": {
            "study_design": "nonempty_string",
            "analysis_population": "nonempty_description",
            "estimand": "nonempty_description",
            "exposure_or_intervention": "nonempty_description",
            "comparator": "nonempty_description",
            "outcomes": "list_or_not_applicable",
            "covariates": "list_or_not_applicable",
            "missing_data": "nonempty_description",
            "multiplicity": "nonempty_description",
        },
        "reusable_covariate_goals": [
            {"goal": "design_adjustment",
             "prompt": "Covariates in the design formula (batch, pairing/donor, sex) are declared from the experimental design; do not select them by testing their association with expression."},
            {"goal": "batch_correction_for_display_only",
             "prompt": "A batch-corrected matrix is for visualisation or downstream scoring only; differential analysis models the batch in the design instead (ENGINEERING_PLAN sva-batch rule)."},
            {"goal": "surrogate_variables",
             "prompt": "Surrogate variables added to a design must be reported with their number and the estimation method."},
            {"goal": "biological_replicate_unit",
             "prompt": "Condition comparisons in single-cell data are made at the biological-sample level (pseudobulk or proportion models); cells are not independent replicates."},
        ],
        "modules": {},
    }
    out["decision_rules.json"] = dump(rules)

    # empty seed ----------------------------------------------------------
    seed = {
        "schema": "omicstat.method-applicability.catalog.v1",
        "status": "empty_no_curated_evidence",
        "inputs": [],
        "papers": [], "usages": [], "decisions": [],
        "limitations": [
            "Empty seed: no curated omics evidence yet. Every omicstat module of the method map is still accepted "
            "by search and advise, which report no_curated_evidence_yet.",
            "Replacing this seed later requires a new reference.sqlite (the store refuses a changed seed: seed_mismatch).",
        ],
    }
    out["seed/catalog.json"] = dump(seed)

    # literature request schema ------------------------------------------
    schema = {
        "$schema": "https://json-schema.org/draft/2020-12/schema",
        "$id": "omicstat.reference.literature-request.v1",
        "title": "omicstat reference literature request v1",
        "description": ("Structured on-demand literature request. Free text is data, never an instruction: only sanitized "
                        "keywords (ASCII letters, digits, spaces, hyphens; at most 6) reach a search, combined with the "
                        "module's Methods-section gate, the uniform filters, the journal whitelist and the Methods-signal "
                        "screen. The whole request must serialize to at most 4096 bytes and must not contain e-mail "
                        "addresses, phone numbers, 6+ digit numeric identifiers or record-identifier keywords. The module "
                        "enum is filled at load time from method_map.json (the list below is the build-time copy). States: "
                        "active queued, searching; terminal fulfilled, partially_fulfilled, unavailable, cancelled, expired. "
                        "Only active requests are deduplicated (same module + normalized required_conditions + "
                        "parameters_of_interest); resubmitting a terminal request creates a new request. Queue caps: 30 "
                        "active requests, 5 per requester."),
        "type": "object", "additionalProperties": False,
        "required": ["module", "question", "study_context", "requester"],
        "properties": {
            "module": {"type": "string", "enum": order + ["unmapped"]},
            "question": {"type": "string", "minLength": 1, "maxLength": 500},
            "study_context": {
                "type": "object", "additionalProperties": False,
                "required": ["design", "data_structure", "outcome_type"],
                "properties": {
                    "design": {"type": "string", "enum": [
                        "two_group", "multi_group", "paired_or_blocked", "time_course", "factorial_or_interaction",
                        "multi_sample_single_cell", "reference_mapping", "other", "unknown"]},
                    "data_structure": {"type": "string", "enum": [
                        "bulk_counts", "normalized_expression_matrix", "microarray_intensities", "single_cell_counts",
                        "single_cell_object", "ranked_gene_list", "gene_list", "mutation_maf", "other", "unknown"]},
                    "outcome_type": {"type": "string", "enum": [
                        "gene_level_differential_expression", "gene_set_or_pathway", "cell_clusters_or_types",
                        "cell_type_proportions", "trajectory_or_pseudotime", "cell_communication",
                        "coexpression_modules", "mutation_landscape", "immune_infiltration", "other", "unknown"]},
                    "estimand": {"type": "string", "maxLength": 200},
                },
            },
        },
    }
    # unchanged from the medstat-reference v2 schema:
    schema["properties"].update({
        "required_conditions": {"type": "array", "maxItems": 8, "items": {"type": "string", "minLength": 1, "maxLength": 120}, "default": []},
        "parameters_of_interest": {"type": "array", "maxItems": 8, "items": {"type": "string", "minLength": 1, "maxLength": 120}, "default": []},
        "exclusions": {"type": "array", "maxItems": 8, "items": {"type": "string", "minLength": 1, "maxLength": 120}, "default": []},
        "max_papers": {"type": "integer", "minimum": 1, "maximum": 5, "default": 3},
        "expires_days": {"type": "integer", "minimum": 1, "maximum": 14, "default": 7},
        "requester": {"type": "string", "minLength": 1, "maxLength": 80},
    })
    out["schemas/literature_request.v1.json"] = dump(schema)
    return out


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true")
    args = ap.parse_args()
    built = build(load_sources())
    if args.check:
        bad = [k for k, v in built.items() if not (CONFIG / k).is_file() or (CONFIG / k).read_bytes() != v]
        print(json.dumps({"status": "ok" if not bad else "stale", "differs": bad}))
        return 1 if bad else 0
    for name, data in built.items():
        path = CONFIG / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)
    print(json.dumps({"status": "written", "files": {k: sha(v) for k, v in sorted(built.items())}}, indent=1))
    return 0


if __name__ == "__main__":
    sys.exit(main())
