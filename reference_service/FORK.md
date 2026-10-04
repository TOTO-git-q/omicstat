# omicstat_reference fork: provenance and changelog

Owner decision of 2026-09-29: the omicstat reference service is **omics-only** and is a **fork** of the
medstat-reference code base, not an unchanged vendored copy. It runs in its own container
`omicstat-reference` and shares nothing with the running medstat-reference.

## Base

| Item | Value |
|---|---|
| Upstream | `E:\claude workspace\skills-dev\medstat-reference` (local git repository, no remote) |
| Base commit | `07fdebd7bf37b8d58e3f0578574c5a4995ec33a8`: the v2 code deployed as medstat-reference on GT103 since 2026-09-25 (its program files were hash-checked against the running container on 2026-09-29) |
| Excluded | the v2.1 review-promotion commits `7f0a999` and `c1f39aa` (and audit `003f630`): an audit found a blocking bug there (a fabricated quote can pass verification) that is still unfixed. Nothing from them may be merged. |
| Fork directory | `app/` |
| Base file hashes | `FORK_BASE.json` (all 61 files of `git archive 07fdebd`, SHA-256, recorded at fork time) |
| Change list | `FORK_CHANGES.json` (every modified, removed and added file, with the reason) |
| Check | `python fork_status.py` (tree vs base vs declared changes; `--verify-base --repo <medstat-reference>` also re-derives the base hashes from git). Run by `tests/test_fork_provenance.py` and by `stage_build.py` before every build. |

History: M7 first deployed the base unchanged (vendored, config overlay only; deploy of 2026-09-29
17:45Z, image `omicstat-reference:20260929-m7`). The fork replaced that the same day.

## What the fork changes

**Identity (was D2).**
- The MCP server name is `omicstat_reference` (was `medstat_reference`).
- Environment variables are `OMICSTAT_REFERENCE_DATA`, `_LOGS`, `_DEPLOYMENT` and `_SCHEDULER`, and
  `OMICSTAT_REFERENCE_TEST_SCRATCH` for tests.
- Schema tags are `omicstat.*`: journals, discovery profiles, method map, worker status and literature
  request.
- The backup archive prefix is `omicstat-reference-data-`, and the HTTP User-Agent is
  `omicstat-reference-harvester`.
- The server instructions, the tool docstrings and the request `next_action` texts name omicstat. No
  "Medstat" or "27 modules" text reaches a client; `tests/test_interfaces.py` checks this.
- **Tool names and input schemas are unchanged.** No tool name contained "medstat", so the wrapper and
  the router need no tool-name changes.

**Module registry (was D1).**
- The new `registry.py` makes `method_map.json` (38 omicstat modules) the single registry. Search,
  advise, literature requests, review tags, domain proposals and the harvest rotation all use it.
- The base derived the reference store's modules from seed record tags, and the request schema
  hard-coded 27 modules. A seed record tagged with a module outside the registry is now rejected
  (`invalid_catalog`).
- The seed is **empty**: 0 papers, 0 usages, 0 decisions.
- `reference_search(module=...)` and `reference_advise` accept every registered module and return
  `curated_evidence: {status: "no_curated_evidence_yet", ...}` instead of `unknown_module`.
  `reference_status` reports `registered_modules` and `modules_without_curated_evidence`.

**Medstat-only rules removed.**
- The clinical query aliases are gone (restricted cubic spline, ICC, Bland-Altman, survey, MICE,
  meta, ...). A small set of omics aliases replaces them (差异表达, 富集, 单细胞, 批次, 轨迹,
  pseudobulk, ...).
- The rcs-analysis "events" rule is gone.
- The 27 medstat module rules in `decision_rules.json` are gone. The common advise checklist is now
  configuration: the omicstat StudyContract fields (`study_design`, `analysis_population`, `estimand`,
  `exposure_or_intervention`, `comparator`, `outcomes`, `covariates`, `missing_data`,
  `multiplicity`). A new value kind, `nonempty_description` (string or non-empty object), matches that
  schema.
- The covariate-purpose prompts are now omics prompts:
  - design adjustment;
  - a batch-corrected matrix is for display only;
  - surrogate variables must be reported with their number and method;
  - the biological-replicate unit.
- The literature-request `study_context` enums are omics values (design / data_structure /
  outcome_type). A clinical request (for example design `cohort`) is refused.

**Removed files.**
- The medstat wrapper, the v1 installer, the upgrade script, the release manifest and the medstat
  profile validation.
- The medstat docs, audit and worklogs (still available at the base commit and in
  `reference/medstat-reference/`).
- The medstat seed-hash test and the medstat production-snapshot migration test.

**Kept unchanged in behaviour.**
- The three-column search: curated / reviewed_supplement / discovery = `unreviewed_machine_screened`.
- The literature-request flow: queue, dedupe of active requests, caps, three attempts, R2 states,
  never blocking.
- The R1 licence gate and the PII / identifier refusals.
- Curator-only promotion through the CLI (no MCP promotion tool).
- The domain proposals.
- The worker caps: 10 screened per day, at most 4 per day for requests, 60 requests per cycle, 8
  attempts per day, every three hours.
- The Methods-section signal gate and the journal whitelist gate.
- The hardened read-only container.
- The additive legacy-v1 migration path in `harvest.py` stays. It is inert on a fresh database
  (`legacy_v1_unscreened` is always 0 here).

**Tests.**
- The base suite is ported to omics fixtures in `app/tests/`, 119 tests: a Genome Biology fixture
  journal, a Methods paragraph that matches all 38 profile signals, and a synthetic omics catalogue
  for the reference-store tests.
- Meta-analysis gate code is still exercised, through a synthetic fixture profile, because no
  omicstat module uses it.

## Rules

- The fork is ours to edit, but every change must be declared in `FORK_CHANGES.json` with its reason.
  Otherwise `fork_status.py` fails and `stage_build.py` refuses to build.
- The configuration files (journals, profiles, method map, decision rules, seed, request schema) are
  written by `build_config.py` from pinned inputs. Do not hand-edit them.
- Never port anything from medstat-reference v2.1 (7f0a999 / c1f39aa) until its audit finding is
  fixed and re-audited upstream.
