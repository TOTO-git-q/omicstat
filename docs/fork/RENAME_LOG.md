# M0 rename log (medstat-55692f7 -> omicstat)

Scope: the files owned by the M0 infrastructure fork (`mcp/**`, `skills/_shared/schemas/**`,
`skills/_shared/publication/**`, the nine forked `skills/_shared/scripts/*.R`, the forked
`skills/_shared/tests/*.R`, `bin/**`, `docker/**`, `skills/omicstat/SKILL.md`).
Source of truth for "before": `reference/medstat-55692f7` (and `reference/medstat-docker`).
The rename was done per category with explicit patterns, then every remaining `medstat` /
`MS_` / `MEDSTAT` hit was reviewed by hand (last section).

## 1. Replacement categories

| # | Category | Pattern (before -> after) | Where |
|---|---|---|---|
| C1 | MCP tool names | `medstat_{list_modules,describe,run,read,validate_publication}` -> `omicstat_*` | `mcp/server.py`, `mcp/test_publication.py`, `mcp/test_client.py`, `mcp/README.md` |
| C2 | Environment variables | `MEDSTAT_` -> `OMICSTAT_` (`*_SUITE_ROOT`, `*_WORKSPACE`, `*_RUNS_ROOT`, `*_TEST_TMP`, `*_MCP_SCRATCH`, `*_R_NATIVE`, `*_NATIVE_R_ROOT`, `*_CONTAINER`) and the R-probe stdout markers `__MEDSTAT_R_VERSION__` / `__MEDSTAT_SESSION_BEGIN__` / `__MEDSTAT_SESSION_END__` / `__MEDSTAT_PACKAGE__` -> `__OMICSTAT_*__` | `mcp/server.py`, `mcp/test_client.py`, `mcp/test_package_identity.py`, `mcp/README.md`, `bin/omicstat-r-route.ps1`, `docker/Dockerfile` |
| C3 | Error-code / console-code prefix | uppercase `MS_` at a word boundary -> `OS_` (all `MS_*` error codes, the `MS_NOTE:` console prefix, the `MS_FOREST_PALETTE` / `MS_FOREST_PCH` constants, the Python `OS_[A-Z]...` warning-scrape regexes and the `OS_ENGINE_WARNING` / `OS_CONTRACT_INVALID` / `OS_SCHEMA_VALIDATION_FAILED` / `OS_JSON_*` / `OS_VALUE_NONFINITE` codes); variable `_MS_CODE` -> `_OS_CODE` | 9 shared R scripts, 8 shared R tests, `mcp/server.py`, `mcp/publication.py`, `mcp/test_publication.py`, `mcp/test_client.py` |
| C4 | Versioned schema discriminators | `medstat.<name>.v1` -> `omicstat.<name>.v1` for `study-contract`, `publication-review`, `publication-manifest`, `artifact-index`, `effect-table-validation`, `semantic-value-map`, `run-registry`, `publication-commit`, `publication-commit-failure`, `package-identity`, `literature-evidence`; rule catalogs `medstat.publication_rules` / `medstat.module_publication_rules` -> `omicstat.*` | `mcp/publication.py`, `mcp/package_identity.py`, `mcp/server.py`, 4 schemas, `validate_effect_table_cli.R`, both rule catalogs, `test_publication_rules.py` |
| C5 | Schema `$id` host | `https://medstat.local/` -> `https://omicstat.local/` | 4 schemas |
| C6 | Container image | `medstat-r:latest` -> `omicstat-r:latest` | `mcp/server.py`, `bin/omicstat-r-route.ps1`, `mcp/README.md` |
| C7 | Router / paths / names | `skills/medstat/SKILL.md` -> `skills/omicstat/SKILL.md`; `bin/medstat-r-route.ps1` -> `bin/omicstat-r-route.ps1`; `medstat-runs` -> `omicstat-runs`; logger `medstat-mcp` -> `omicstat-mcp`; `FastMCP("medstat")` -> `FastMCP("omicstat")`; resources `medstat://router|skill|help` -> `omicstat://...` (names/descriptions likewise); uuid5 seed `"medstat:"` -> `"omicstat:"`; ps1 in-container suite mount `/medstat` -> `/omicstat`, temp-script prefix `medstat-r-` -> `omicstat-r-` | `mcp/server.py`, `bin/omicstat-r-route.ps1`, tests, README |
| C8 | R S3 class / temp-dir names | `"medstat_spec"` -> `"omicstat_spec"`; `tempdir()/medstat_{integration_test,render_test,spec_tests}` -> `omicstat_*` | `spec.R`, `test_spec.R`, `test_integration.R`, `test_render.R` |
| C9 | Prose "medstat" meaning "this suite" | -> "omicstat" (file headers of `forest.R`, `report_engine.R`, `survey_design.R`, `var_typing.R`, `publication.py`, `test_publication.py`, `test_client.py`, `server.py` docstrings/tool docstrings) | as listed |
| C10 | Wording that was factually medstat-specific | "27 R engines/modules" -> the router-table count (0 at M0); "which kind of statistics question" -> "which kind of bioinformatics analysis question" (router resource description); "List every medstat statistics module" -> "List every omicstat analysis module" | `mcp/server.py`, `mcp/README.md` |

`bin/omicstat-r-route.ps1` was verified to differ from `medstat-r-route.ps1` ONLY by C2/C6/C7
(`sed 's/omicstat/medstat/g; s/OMICSTAT/MEDSTAT/g'` reproduces the original byte-for-byte).

## 2. Per-file record

| File | Categories | Notes |
|---|---|---|
| `mcp/server.py` | C1 C2 C3 C4 C6 C7 C9 C10 | plus the M0 functional changes listed in section 4 |
| `mcp/publication.py` | C3 C4 C9 | no functional change |
| `mcp/package_identity.py` | C4 | no functional change |
| `mcp/test_package_identity.py` | C2 | no logic change |
| `mcp/test_publication.py` | C1 C3 C4 C9 | 6 module-dependent tests skipped (section 5); new `OmicstatForkAdditionsTests` class |
| `mcp/test_client.py` | C1 C2 C3 C7 C9 | restructured into module-independent checks + a gated `module_checks()` (section 5) |
| `mcp/README.md` | C1 C2 C3 C6 C7 C10 | adjusted for the empty registry, feature table, `upstream_runs`, `.sh` router |
| `mcp/requirements.txt` | none | unchanged |
| `mcp/testdata/make_cohort800.R` | none | **medstat-era fixture** (simulated clinical cohort for the medstat `rcs-analysis` / `sample-size` acceptance runs); kept verbatim, only used by the skipped module-dependent block of `test_client.py` |
| `skills/_shared/schemas/*.json` (4) | C4 C5 | `study_contract`: descriptions added (section 4); `publication_manifest`: `upstream_runs` property added |
| `skills/_shared/publication/universal_rules_v1.json` | C4 | PUB-U-001 / PUB-U-002 text reworded for omics denominators; IDs, categories, severities unchanged |
| `skills/_shared/publication/module_rules_v1.json` | C4 | replaced by an empty `modules` list + `note` (same top-level structure) |
| `skills/_shared/publication/test_publication_rules.py` | C4 | `EXPECTED_MODULES` = empty set; the medstat-only `rcs-analysis` assertion removed |
| `skills/_shared/publication/README.md` | C7 C9 | module-count sentence and run path adjusted |
| `skills/_shared/scripts/effect_table.R` | C3 | |
| `skills/_shared/scripts/forest.R` | C3 C9 | `MS_FOREST_PALETTE`/`MS_FOREST_PCH` -> `OS_FOREST_*` (exported constants: any new caller must use the `OS_` names) |
| `skills/_shared/scripts/render_docx.R`, `render_md.R` | C3 | |
| `skills/_shared/scripts/report_engine.R` | C3 C9 | |
| `skills/_shared/scripts/spec.R` | C3 C8 | |
| `skills/_shared/scripts/survey_design.R` | C3 C9 | |
| `skills/_shared/scripts/validate_effect_table_cli.R` | C3 C4 | |
| `skills/_shared/scripts/var_typing.R` | C3 C9 | |
| `skills/_shared/tests/test_{effect_table,forest,integration,primitives,render,spec,survey_design,var_typing}.R` | C3 C8 | no logic change |
| `bin/omicstat-r-route.ps1` | C2 C6 C7 | line-by-line copy |
| `bin/omicstat-r-route.sh` | new | POSIX counterpart (pending decision D5) |
| `docker/*` | rewritten | omics package layers (not a rename); see final report |
| `skills/omicstat/SKILL.md` | new | router skeleton, empty section-1 table |

## 3. Occurrences deliberately NOT renamed

| Occurrence | Where | Reason |
|---|---|---|
| lowercase internal identifiers `ms_*` / `.ms_*` (e.g. `ms_forest` class, `ms_provenance` attribute, `ms_mi_combine`, `ms_svy_*`, `.ms_template_registry`, `.ms_spec_to_args_assoc`) | shared R scripts and tests | Not in the rename list (only `MS_` error codes were); they are internal API and persisted attribute/class names, renaming them is an API change, not a rename. Pending decision D8. |
| "medstat-55692f7", "forked from medstat" | server.py docstring, README, schemas, publication README, rule catalog note, Dockerfile, layer_lib.R, .sh header | provenance citations of the fork source |
| `research/audit-0902/...`, "Measured on 2026-09-02", MCP-DESIGN section refs | `mcp/server.py`, `mcp/README.md` | design provenance inside the medstat tree; kept verbatim and labelled as medstat provenance |
| medstat module names in comments (`rcs-analysis`, `cpm-pipeline --boot-B`, `its-analysis --boot-R`, `target-trial`, `run_recur.R`, joint-frailty examples) | `mcp/server.py`, `mcp/README.md`, `mcp/test_client.py` | they document why a behaviour exists (evidence), not the omicstat module set |
| medstat module references in logic: `spec.R` `spec_to_args()` targets `rcs` / `assoc` (medstat `run_rcs.R` / `run_assoc.R`); `test_spec.R` / `test_primitives.R` cross-check `../../rcs-analysis/scripts/*` | shared R | rename-only fork; these are medstat-domain helpers (pending decision D6) |
| survey-design / NHANES content of `survey_design.R`, `var_typing.R` clinical test-selection table | shared R | copied "as is" per IMPLEMENTATION_SPEC section 0 row `_shared/scripts` |
| test fixture module names `sample-size`, `rcs-analysis`, `recurrent-events` | `mcp/test_publication.py`, `mcp/test_client.py` | medstat-era fixtures; the tests needing them are skipped at M0 and re-pointed at the first S5 module |
| every `medstat` mention in `skills/omicstat/SKILL.md` section 4 and description | router | medstat is the hand-off TARGET for survival / prediction / clinical association analyses |
| `C:\Program Files\R\R-4.6.0\bin\Rscript.exe`, `taskkill`, PowerShell route | `mcp/server.py`, tests | Windows-only execution design copied unchanged (pending decision D4) |
| `E:\claude workspace\...` paths in docstrings | `mcp/server.py` docstring, `skills/_shared/publication/README.md` | only the `medstat` path segment was renamed |

Line endings: the medstat sources are CRLF (some with a few stray LF lines). Every forked text
file keeps CRLF; files rewritten during the fork were re-saved as whole-file CRLF, so the only
whitespace delta vs medstat is those few formerly-LF lines (`mcp/server.py` 20 lines,
`mcp/test_publication.py` 64 lines). New files are LF except `skills/omicstat/SKILL.md` (CRLF,
like the medstat router); `docker/*` and `bin/*.sh` are LF, as in medstat-docker.

## 4. Non-rename changes (the only functional deltas)

1. `mcp/server.py` `_modules()`: a router whose section-1 table has the header row and zero data
   rows is a valid EMPTY registry (medstat raised "could not parse the module table"); a router
   without the header row still raises. Unknown-module message prints `(none installed)` instead
   of an empty closest-match list.
2. `mcp/server.py` feature-table tier (IMPLEMENTATION_SPEC section 3 step 7 (1)): by column header,
   core subset `feature_id, log2fc, pvalue, padj`; ranks after the shared effect table and before
   the module-local fallback; `effect_table_schema = "feature-table"`.
3. `mcp/server.py` `_degenerate_features()` (step 7 (2)): full-table re-read, per (file, contrast):
   padj all NA; all non-NA padj < 0.05; non-finite log2fc (Inf/-Inf/NaN; `NA` is missing, not
   flagged). `_short_num()` guards non-finite values (medstat would raise OverflowError on `Inf`).
4. `mcp/server.py` `upstream_runs` manifest field from `objects/handoff.json` key `upstream_runs`
   (strings or `{run_id}` objects); schema property added (optional, not in `required`).
5. `study_contract.v1.schema.json`: `description` keywords with the omics meaning
   (IMPLEMENTATION_SPEC section 4); field names and validation unchanged.
