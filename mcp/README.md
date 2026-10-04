# omicstat MCP thin shell

A FastMCP stdio server that exposes the omicstat R engines (the modules listed
in the router `skills/omicstat/SKILL.md` section 1 -- currently the environment
self-test `omicstat-selftest`) as **five generic tools plus three document
resources**. Statistical estimators and routing stay in the module SKILL.md/R
files. The shell also finalizes versioned publication contracts, provenance and
rule-based review without re-estimating results.

It runs only on omicstat's own R environment (`env/omicstat-env.json`): the
pinned `omicstat-r` container image, or the isolated native library built by
`env/native/setup_native.R`. Architecture derived from medstat's MCP shell
(medstat-55692f7 `mcp/`); there is no runtime dependency on medstat.

## Tools

| Tool | Input | Output |
|---|---|---|
| `omicstat_list_modules` | -- | JSON: one row per router-table module of `{module, summary, entry}` |
| `omicstat_describe` | `module` | SKILL.md (capped at 20k chars) + the module's full `--help` + its `references/` file list |
| `omicstat_run` | `module`, `args{}`, `engine`, optional `study_contract` | JSON manifest (capped at 8k chars) |
| `omicstat_validate_publication` | exactly one of `run_id`, `outdir` | Re-run publication validation and return the compact JSON manifest |
| `omicstat_read` | `path` | verbatim text for `.md .csv .txt .json .yml .yaml .tsv` (capped at 60k chars; oversized JSON becomes a valid shape summary); path + size only for figures and other binaries |

Resources: `omicstat://router` (the routing map), `omicstat://skill/{module}`,
`omicstat://help/{module}`.

There is deliberately **no** background/job mode. Everything runs synchronously
and is hard-killed at 25 minutes (the stdio idle timeout is 30 minutes).

## Environment variables

| Variable | Default | Meaning |
|---|---|---|
| `OMICSTAT_SUITE_ROOT` | the directory above `mcp/` | the installed suite (skills, bin, env) the server executes |
| `OMICSTAT_WORKSPACE` | `OMICSTAT_SUITE_ROOT` | an extra allowed root for input/output paths |
| `OMICSTAT_RUNS_ROOT` | `<system temp>/omicstat-runs` | parent of the UUID run directories and of the run registry (`_registry/`) |
| `OMICSTAT_IMAGE` | `image:image_tag` from `env/omicstat-env.json` | container image override (testing only; never a floating tag in production) |
| `OMICSTAT_NATIVE_ENV` | `<suite>/.omicstat-r/native-env.json` | the native-environment description (`rscript`, `library`, `rprofile`); the server and both routers read the same variable |

## `args` convention

`args` is a free dictionary whose keys are flag names **without** the leading
dashes. No flag list is duplicated anywhere in this shell.

| Value | Becomes |
|---|---|
| `true` | a bare flag (`--strict`) |
| `false` / `null` | omitted entirely |
| list `["a","b"]` | `--flag a,b` |
| number / string | `--seed 7` |

`outdir` is accepted inside `args` but always means a **parent directory**.
Every execution receives an exclusive UUID v4 leaf beneath that parent. When
omitted, the parent is `<OMICSTAT_RUNS_ROOT>/<module>/`. The response returns
both the actual leaf in `outdir` and the caller's parent in
`requested_outdir`, preventing stale artifacts from entering a new run.

`study_contract` is optional, so calls without it remain valid. When supplied it
is validated as StudyContract v1 before R starts. Omitting it yields
`needs_input`, because design-dependent publication checks cannot be completed.
Each `outcomes` entry is an object with an outcome `name` (or `definition`) and
either a `timepoint` or `time_horizon`. Required declarations are recursively
meaningful: surrounding whitespace is normalized, while whitespace-only
strings, booleans, and empty objects/arrays are rejected.

**Validation is the module's own `--help`, parsed once and cached.** A flag
that does not appear there is refused with the three closest known flags: one
contract, zero drift, nothing to update when an engine gains a flag.

Path-looking values (absolute paths, or relative paths carrying a file
extension) must resolve under the suite, the workspace, the runs root, or the
system temporary directory, whichever flag carries them. Everything else is
refused before the engine starts. Symlinks/junctions on the path are refused.

## `engine`

| `engine` | How | When |
|---|---|---|
| `container` (default) | `bin/omicstat-r-route.sh` (Linux/macOS) or `bin/omicstat-r-route.ps1` (Windows -> WSL) -> `docker run <image pinned in env/omicstat-env.json>` | The reference environment; golden baselines are defined on it. Use it for anything that will be reported. |
| `native` | the same routers with `OMICSTAT_R_NATIVE=1`: the `rscript` named in `OMICSTAT_NATIVE_ENV` (default `.omicstat-r/native-env.json`), with `OMICSTAT_R_LIBS=<library>` and `R_PROFILE_USER=env/native/Rprofile.omicstat` so that only the omicstat library plus R's base library is on the search path | Faster startup; same pins, "visual equivalence" tier (byte-level golden checks skip). |

Both engines go through the routers, so path translation and environment
selection live in one place. The native environment is created with
`Rscript env/native/setup_native.R` (R of the pinned major.minor, network
access); a missing native environment is refused before any run directory is
allocated. `--help` is cached once per module, acquired natively when the
native environment exists and from the container otherwise.

To check an installation, run the self-test module:
`omicstat_run(module="omicstat-selftest", args={}, engine="native")` (or
`"container"`), then read `environment_report.md` from the returned `outdir`.

## Manifest

```
schema_version, run_id, status, module, engine, exit_code, duration_s,
outdir, requested_outdir, command, artifact_count, total_artifact_count
artifacts            grouped as tables/figures/draft/qc/provenance/
                     publication/machine/other,
                     each {name, bytes}
qc_triggered         [{id, severity, message}] -- rows where triggered==TRUE
engine_warnings      OS_* codes and convergence/NaN/singularity lines scraped
                     out of stderr+stdout
structured_warnings  `{code, message}` companion records for engine_warnings
effect_table         up to 20 estimate rows (or feature-table rows)
effect_table_sources / effect_table_schema
                     (shared-schema | feature-table | module-local | none)
degenerate_estimates [{row, issue}]
upstream_runs        upstream run_id chain from objects/handoff.json ([] if none)
results_summary      top-level scalars of the module's results JSON (optional)
stderr_tail (40 lines) / stdout_tail (20 lines) / notes
```

For compatibility, `artifact_count` and `artifacts` describe only engine
outputs. `all_artifact_count` and `all_artifacts` describe the complete on-disk
inventory except `provenance/publication_manifest.json`: a manifest cannot
accurately self-report its own bytes because it is written after the
inventory. `total_artifact_count` uses that same explicit exclusion.

The five publication artifacts written by every finalized run are:

```
provenance/publication_manifest.json
publication/review.json
publication/artifact_index.json
publication/results_outline.md
publication/value_map.json
```

The status vocabulary is `blocked`, `needs_input`, `review_required`, and
`ready_for_manuscript_integration`. `review.json` separates checks the
finalizer actually performed (`automated_checks`) from work it did not claim
to automate (`human_review_pending`): artifact presence using module
aliases/expectations (`skills/_shared/publication/module_rules_v1.json`, one
record per registered module), real canonical effect-table schema validation,
caption-sidecar evidence, PNG pixel dimensions, QC dialects, and hashes.
Canonical effect tables and other mappable CSV/JSON estimate rows are compared
through `value_map.json`, which records included, skipped and unmappable
sources. One-sided missing/NA fields are recorded as coverage gaps, while
contradictory finite values and non-finite values remain blocking conflicts.
Markdown, DOCX, caption semantics and visual font/cropping/colour review remain
explicitly pending.

QC CSV files under `qc/` are read by column name: an id column (`id`, `code`,
`qc_id` or `rule_id`), `message`, and either `triggered` or `status`, with
optional `severity`, `blocking`, `action`, `evidence`. Severity `blocker`
(omicstat's vocabulary) is normalized to `critical`; a triggered row with
`blocking = TRUE` makes the run `blocked` for publication.

Accepted or rejected reviewer decisions are revalidated inside the publication
core whether they arrived through the MCP call or were already present in an
imported manifest. Every such decision must reference fixed local engine
evidence, provide exact SHA-256 coverage for every evidence path, and match the
current bytes. Dynamic publication artifacts and unverifiable URLs cannot be
used as decision evidence.

Three fields make the envelope more than a file tree:

- **`engine_warnings`** -- non-convergence and similar problems can exist only
  as a console line that no QC rule and no file records. The shell scrapes
  those lines (including the bodies under a bare `Warning message:` header) and
  puts them next to the QC block. **Read this field before quoting any number.**
- **`effect_table`** -- the primary machine payload, detected by **column
  header**, not filename. `effect_table_schema` says `shared-schema` only when
  all 20 canonical effect-table columns are present, and the persisted CSV is
  then passed through the shared R `validate_effect_table()`. It says
  `feature-table` when no shared effect table is present but a CSV carries the
  feature-table core columns `feature_id`, `log2fc`, `pvalue`, `padj` (full
  schema: `_shared/scripts/feature_table.R`); rows are carried in the engine's
  own file order. It says `module-local` when the shell fell back to a small
  estimate+CI+P table.
- **`degenerate_estimates`** -- a mechanical scan of those same rows for a
  zero-width confidence interval or a point estimate outside its own interval.
  For a feature table the shell additionally re-reads the FULL table(s) and
  flags, per contrast: padj NA for every feature, every non-NA padj < 0.05, or
  a non-finite (Inf/-Inf/NaN) `log2fc`.
- **`upstream_runs`** -- the `--from-run` chain: the upstream run_ids found
  under `upstream_runs` in `objects/handoff.json` of the run directory; an
  empty list otherwise.

The response manifest is held under 8,000 characters by shrinking in a fixed
order (stderr tail, stdout tail, `results_summary`, QC rows, artifact listing,
and only last the effect table and engine warnings), recording what it dropped
in `notes`. It is never truncated as raw text, so it remains valid strict JSON.
Non-finite values become `null` and are recorded as structured serialization
warnings. The full manifest is `provenance/publication_manifest.json`.

The manifest also records the Git commit and dirty state (with a replayable
worktree identity when dirty), the module entry-script hash, structured Python
and R package inventories of the engine that ran, R session information, and an
immutable container image ID when the container engine is used. Missing
required provenance is a blocking finding. A validator with no canonical
candidates is labeled `not_applicable`, not `executed`.

The schemas live in `skills/_shared/schemas/`: StudyContract v1,
LiteratureEvidence v1, PublicationReview v1 and PublicationManifest v1. The
publication rule catalogs are versioned separately under
`skills/_shared/publication/`.

## One pitfall worth remembering

Engine subprocesses are spawned with `stdin=subprocess.DEVNULL`, and that is
load-bearing. In a **stdio** MCP server the process's own stdin is the protocol
channel from the client: a child R process that inherits it blocks as soon as R
touches stdin, and could eat protocol bytes. Anything added here that shells
out must keep that keyword.

Module output layouts and QC CSV column sets vary, so artifacts are classified
by subdirectory first and filename second, and QC files are read by column name
with missing columns tolerated.

## Known limits

- **Timeout kill is best-effort for the container.** The process tree is killed
  by PID (POSIX process group / `taskkill /T`); a `docker run` already started
  may survive and need `docker ps` / `docker stop`.
- **The flag whitelist is permissive by construction.** The regex
  (`--[A-Za-z0-9][A-Za-z0-9-]*`) harvests every `--flag` token in the help
  text, so a flag named only in prose is accepted. It rejects typos and
  hallucinated flags; it is not an argument type-checker. The engine's own
  `parse_args` remains the authority on values.
- **The `--help` cache is per process.** Restart the server after editing an
  engine's argument parser.
- **Entry scripts come from the router SKILL.md section 1 table.** Adding a
  module means adding its row there (S5 install step) and its record in
  `module_rules_v1.json`. A table with its header row and zero data rows is a
  valid, empty registry; a router file without the table is refused.
- **No composite pipeline tools.** Multi-module `--from-run` recipes stay in the
  router; the shell runs one module per call.

## Enabling it in Claude Code

Point the stdio registration at this suite's `mcp/server.py` (or set
`OMICSTAT_SUITE_ROOT` to the installed suite root) with a Python that has
`mcp/requirements.txt` installed. The server resolves its own package-local
routers; it never falls back to another checkout. Verify with your MCP client --
exactly five tools should be listed -- then run `omicstat-selftest`.

The CLI path is untouched: every module still runs from `Rscript
<module>/scripts/run_*.R` exactly as its SKILL.md documents.

## Tests

```
python mcp/test_client.py
python mcp/test_publication.py
OMICSTAT_TEST_TMP=<writable dir> python mcp/test_package_identity.py
```

Engines in the tests: the native engine uses `OMICSTAT_NATIVE_ENV` if set, else
the real `.omicstat-r/native-env.json`, else a **temporary development
environment** the test writes itself (the `Rscript` on PATH, the R library that
holds ggplot2 -- override with `OMICSTAT_TEST_R_LIBRARY` -- and
`env/native/Rprofile.omicstat`), exported as `OMICSTAT_NATIVE_ENV` for the
server child and removed at exit. Container cases run only when
`docker image inspect <pinned image>` succeeds and are otherwise reported as
skipped with that reason. Windows-only cases (junctions) skip on POSIX.

`test_client.py` drives the server over real MCP stdio with the fixture module
`omicstat-selftest`: tool/resource surface, the router-table listing,
`describe`, the three refusal paths (unknown flag, out-of-root path value,
out-of-root `--outdir`), real runs (UUID leaf, publication artifacts,
provenance, dirty-worktree identity, feature-table payload detection, fixture
anchors, QC rule ids, no degenerate estimates), the contract-less
`needs_input` status, `--strict` as a bare switch, `omicstat_validate_publication`
by run_id, default outdir allocation, and `omicstat_read` on the draft and a
figure. It opens with offline checks that drive `engine_warnings` and both
degenerate detectors on planted input. `test_publication.py` covers schema
validation, strict JSON budgeting, UUID allocation/path guards, artifact
aliases, QC normalization (including `blocker`), hash tamper detection, the
five standard artifacts, release gating with the selftest's module rule,
persisted effect-table validation through the shared R implementation (native
engine), the router registry, the `OMICSTAT_NATIVE_ENV` override and the POSIX
router's library isolation, and the feature-table / `upstream_runs` additions.

Numeric publication gates (`universal_rules_v1.json` 1.1.0):
`publication/value_map.json` keys feature rows by `(contrast, feature_id)` and
summary rows by their available natural identifiers; effect-table keys are unchanged.
It discovers feature and native summary tables in `tables/` independently of the
R effect validator; summary keys include the source table to keep measurements distinct.
`text_coverage` scans `draft/*.md`, caption text sidecars and figure-spec JSON
captions. It compares integers exactly and decimals/scientific notation at printed
precision (percentages also match proportions) against canonical table values,
result JSON scalars and QC evidence columns. Package versions and years are omitted.
Optional `draft/number_sources.json` supplies a short justified allow-list, for example
`{"numbers": [{"value": 0.05, "source": "Methods threshold from the locked vignette"}]}`.
Invalid declarations are reported as coverage errors; they cannot silently waive review.
Uncovered numbers include their source and sentence. A numeric match establishes
traceability, not the correctness of a sentence or a statistical interpretation.

`case_flow` reads feature-table filtering reasons and group counts, Seurat/scater
cell-retention flows, Scanpy stage flows, cell audit flags and sample-count tables
(including pseudobulk/proportion outputs when present). It only reports `checked`
when a ledger has a matching result denominator or an independent cell audit;
otherwise it reports `not_present` and emits no automated denominator finding
(the existing universal human-review placeholder remains). Feature tables
contain fitted rows: independent adjusted-p filtering is not input prefiltering.
The reader does not infer biological replicates from cell counts, invent an absent
ledger, or equate upstream cells with a downstream analysis subset. `PUB-U-001`
and `PUB-U-003` gate findings use warning severity, pass/fail check status and human
review; they never block a run. Existing cross-table conflicts remain blocking.
DOCX text, caption semantics, unsupported ledger layouts, and absent evidence
still require human review.
