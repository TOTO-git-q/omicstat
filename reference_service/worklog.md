# M7 omicstat_reference — worklog

Branch `infra/omicstat-reference` (worktree `E:\claude workspace\skills-dev\omic-infra-reference`,
based on `origin/build/m1m2` @ 2ddf174). GT103 work only under `~/omic-infra-reference` and
`~/omic-build-logs/infra-reference/`. Never touch medstat-reference (container, image, data).

## Steps

| # | Step | State |
|---|---|---|
| 1 | Vendor medstat-reference@07fdebd (v2, deployed) + manifest + VENDOR.md | DONE |
| 2 | `build_config.py` -> `config/` (journals, profiles, method_map, decision_rules, seed, request schema) | DONE |
| 3 | `omicstat_entry.py` + `REFERENCE_WORKFLOW.md` | DONE |
| 4 | `stage_build.py`, compose, `deploy_gt103.sh`; tests (config, vendor pin, offline reference stdio, entry stdio) | DONE |
| 5 | `DEPLOYMENT.md`; push | DONE |
| 6 | GT103 build + run + verify; `DEPLOYMENT_LOG.md`; push | DONE |

## Verified state

- Step 1 (2026-09-29): `pin_vendor.py --commit 07fdebd` -> 61 files, 0 mismatches; c1f39aa refused.
  GT103 deployed medstat-reference program files (host dir and inside container) hash-equal to the pin.

- Step 2 (2026-09-29): `build_config.py` (inputs pinned in `config_sources.json`) -> 6 files in `config/`;
  `--check` byte-identical. 38 journals (A 23 / B 15), 38 profiles all `ok` from S0 search logs (screened
  21-30 each), no drift of the 14 M1/M2 profiles across the three S0 branches, method map 38 modules
  (deseq2-wald first = router section 1; utility omicstat-selftest excluded). Seed = scaffold (0 papers,
  0 usages, 38 no-evidence decisions) - see pending decision D1.

- Step 3 (2026-09-29): `omicstat_entry.py` generated from vendored medstat_entry.py (same structure; names,
  default path = ../mcp/server.py with env OMICSTAT_ORIGINAL_SERVER, guidance text). Resource
  `omicstat://reference-workflow` = `REFERENCE_WORKFLOW.md`. `tests/smoke_omicstat_entry.py` PASSED
  locally: 5 tools, input/output schemas + annotations byte-identical, suffix only on list/describe/run.

- Step 4 (2026-09-29): local results: `python -m unittest discover -s tests` 10/10 OK; upstream 120 tests
  OK on a temp copy of the vendored tree; `tests/smoke_reference_stdio.py` (offline) PASSED: 10 tools,
  curated 0/0/38, module search returns the scaffold + three columns, advise needs_input, request
  queued -> merged -> cancelled, medstat module and PII refused, domain proposal registered.
- Step 5 (2026-09-29): `DEPLOYMENT.md` written; branch pushed.

- Step 6 (2026-09-29): shipped d5a76cc to GT103 `~/omic-infra-reference/release`; `deploy_gt103.sh`
  (detached) built `omicstat-reference:20260929-m7` and started container `omicstat-reference` with
  `~/omic-infra-reference/runtime/{data,logs}`; health OK; first cycle 10 screened / 28 requests / 150 s;
  remote MCP smoke (read-only) and wrapper smoke PASSED; medstat-reference untouched and healthy.
  Details and registration snippets in `DEPLOYMENT_LOG.md`.

## Phase 2 - omic-only fork (owner decision 2026-09-29; resolves D1, D2)

| # | Step | State |
|---|---|---|
| F1 | vendor/ -> app/ fork; FORK.md + FORK_BASE.json (07fdebd hashes) + FORK_CHANGES.json; medstat-only files removed | DONE |
| F2 | code: rename (server name, OMICSTAT_REFERENCE_* env, texts, schema tags); module registry from method map; empty seed answers "no curated evidence yet"; omics request enums / advise common fields / covariate goals / aliases | DONE |
| F3 | build_config.py writes into app/ (empty seed); port upstream tests to omics fixtures; fork provenance test | DONE |
| F4 | wrapper + router section 7 text check; DEPLOYMENT.md | DONE |
| F5 | GT103: backup runtime/, fresh sqlite, new tag, recreate container, verify | DONE |
| F6 | DEPLOYMENT_LOG, snippets, worklog; push | DONE |

- F1-F4 (2026-09-29): vendor/ -> app/ fork (git mv); FORK.md + FORK_BASE.json (61 base hashes) +
  FORK_CHANGES.json (28 modified / 25 removed / 2 added, all declared; `fork_status.py --verify-base`
  against the medstat-reference git base: no problems). Code: server `omicstat_reference`,
  OMICSTAT_REFERENCE_* env, omicstat schema tags, registry.py (method map = registry), empty seed ->
  `curated_evidence.status = no_curated_evidence_yet`, omics aliases / StudyContract checklist /
  covariate prompts / request enums, rcs rule removed. Tests: app suite ported, 119 OK; outer 12 OK;
  offline MCP smoke PASSED (server name omicstat_reference, 4 modules search+advise = no_curated_evidence_yet);
  wrapper smoke PASSED; build_config --check OK. Router SKILL.md section 7 updated (text only; section 1 untouched).

- F5 (2026-09-29 18:20Z): shipped 7d73145; reset_runtime (backup runtime-backups/runtime-20260928T182031Z-pre-fork1.tar
  sha256 OK, old data -> runtime/data.pre-fork1-20260928T182031Z); deploy: host tests 12 OK, image
  `omicstat-reference:20260929-fork1` (84780d57a57f), in-image suite 119 OK, container recreated, healthy,
  status 0/0/0 + 38 registered; remote MCP smoke PASSED (server omicstat_reference; 4 modules
  no_curated_evidence_yet); wrapper smoke PASSED; first cycle 10 screened / 27 requests; three columns
  verified on edger-qlf. medstat-reference untouched, healthy.
- F6: DEPLOYMENT_LOG fork1 section + snippets; pushed.

## Next step

Nothing open in this task. Owner/main session: register `omicstat` + `omicstat_reference` (snippets in
DEPLOYMENT_LOG.md); curate seed evidence later (needs a fresh reference.sqlite, see DEPLOYMENT.md).

## Pending decisions (待裁决)

(D1 and D2 below were resolved by the owner on 2026-09-29: omic-only fork, registry from method map, empty seed.)

- D1 Seed. The vendored ReferenceStore derives its known modules from seed usages/decisions, so a truly
  empty seed makes `reference_search(module=...)` and `reference_advise` fail with `unknown_module` for
  every omics module. Chosen (config only, no code change): a scaffold seed with one explicitly labelled
  no-evidence decision per module. Alternative: empty seed and accept the module filter failing.
- D2 Cosmetic texts in vendored code say "Medstat" / "27 modules" (server name `medstat_reference`,
  instructions, some next_action strings, env var names MEDSTAT_REFERENCE_*). Left unchanged (code
  byte-identical); the Claude/Codex registration key `omicstat_reference` names the tools, and the
  omicstat entry guidance says which modules apply. Fixing it needs an upstream parameterisation.
