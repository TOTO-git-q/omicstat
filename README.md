# omicstat

**Locked, evidence-anchored omics analysis modules behind one MCP server.**

omicstat wraps the official workflow of one R or Python package *analysis part* per module — DESeq2 Wald, limma-voom, clusterProfiler ORA, Seurat clustering, muscat pseudobulk, CellChat, WGCNA, … 38 analysis modules plus 3 display modules — and freezes each one so that the same input and the same choices give the same numbers on any machine, and any drift is caught mechanically. An LLM (or a person) calls the modules through five generic MCP tools; the modules return tables, figures in one journal style, QC findings, a filled Methods/Results draft, and a provenance record that lets every reported number be traced to its source.

omicstat does **not** invent statistics. It runs the package the way its authors' vignette runs it, exposes every result-affecting argument as an explicit option, and refuses to decide scientific judgements on the caller's behalf.

---

## What a module guarantees

| Lock | What it means |
|---|---|
| Locked environment | R modules run in `omicstat-r:2026.10.1` (R 4.6.1, Bioconductor 3.23, CRAN snapshot 2026-09-15, 544 packages, `env/pkg_lock.csv`); Python modules in `omicstat-py:2026.09.1` (scanpy 1.12.4, anndata 0.13.3, scvi-tools 1.5.1, torch 2.14 CPU). Image digests go into every run's provenance. Single-threaded BLAS. |
| One entry-script skeleton | Flag whitelist, typed `OS_*` errors, input validation, `--spec` replay of a finished run. |
| Calls registry | `scripts/calls_registry.json` lists every package function the module calls and every result-affecting argument with its source (locked default, vignette value, or user-required). A static check refuses undeclared calls. |
| Seeds | Every stochastic step has an explicit, recorded seed. |
| Golden baseline | The anchor dataset run with fixed parameters; sha256 of every artefact in `tests/golden_manifest.csv`. The smoke test fails on any byte change. |
| Module lock | `module_lock.json` binds the engine, the shared files it uses, the environment id and the golden; the publication gate refuses an unsealed or changed module. |
| Anchors | Printed values from the package's own vignette or workflow are asserted on the vignette's own code path (e.g. DESeq2 pasilla, limma RNAseq123, muscat Kang18, WGCNA FemaleLiver, TCGA-LAML for maftools). Known failures are kept visible, never loosened. |

Every module ships: `SKILL.md` (what it does, every option, when to choose which, what it refuses), `scripts/` (entry, core, report, QC, `calls_registry.json`), `references/` (Methods template, option-to-evidence map), `tests/` (smoke test on the anchor, golden), and `module_lock.json`.

## Modules

| Group | Modules |
|---|---|
| Bulk differential expression (8) | `deseq2-qc` `deseq2-wald` `deseq2-lrt` `edger-qlf` `limma-voom` `limma-array` `limma-dupcor` `sva-batch` |
| Enrichment and scoring (6) | `clusterprofiler-ora` `clusterprofiler-gsea` `clusterprofiler-compare` `fgsea-prerank` `gsva-score` `limma-camera` |
| Single cell, Seurat lane (5) | `seurat-qc` `seurat-cluster` `seurat-integrate` `seurat-markers` `seurat-modulescore` |
| Single cell, Bioconductor lane (5) | `scater-qc` `scran-cluster` `batchelor-integrate` `scran-markers` `aucell-score` |
| Single cell, scverse lane (5, Python) | `scanpy-qc` `scanpy-cluster` `scanpy-markers` `scvi-integrate` `scanvi-annotate` |
| Single-cell back ends, ecosystem-neutral (6) | `singler-annotate` `muscat-pseudobulk` `speckle-propeller` `monocle3-trajectory` `slingshot-trajectory` `cellchat-communication` |
| Network, mutation, infiltration (3) | `wgcna-network` `maftools-landscape` `immunedeconv-infiltration` |
| Single-cell display, scverse (3, Python) | `scanpy-annotate` (describe clusters with a marker panel and a user label map) `scanpy-purity` (neighbour-purity and island diagnostics for display clean-up) `scanpy-ingest` (project a query onto a fixed reference UMAP) — outputs carry a `display_only` mark that the inference modules refuse |
| Utilities | `omicstat` (the router: a map, no engine) · `omicstat-selftest` · `omicstat-selftest-py` |

Modules chain with `--from-run <previous run directory>`: the hand-off verifies every file hash, the object type, the StudyContract, the front-end ecosystem (a chain never silently switches between Seurat, Bioconductor and scverse) and the batch-correction lineage (a batch-corrected matrix is for display and scoring only and never enters a differential test).

## Before you start: build one runtime

omicstat does not run against whatever R or Python is installed on your machine. Every module runs inside a locked runtime, and nothing works until one exists. A fresh clone that has neither Docker nor a native library will fail with `OS_ENV_MISSING` (`.omicstat-r/native-env.json` not found); that is expected, and adding a file will not fix it.

Pick one runtime:

| Runtime | What you need | Build once | Notes |
|---|---|---|---|
| **Container (recommended)** | Docker (Linux, macOS, or Windows with WSL2), about 20 GB of disk, internet for the build | `bash env/build.sh` (R image `omicstat-r:2026.10.1`, about 1 hour) and `bash env/py/build.sh` (Python image `omicstat-py:2026.09.1`, only for the five scverse modules) | Golden baselines are defined on these images, so the byte-level checks run. |
| **Native isolated library** | R 4.6.x on the host, internet for the install | `Rscript env/native/setup_native.R` (installs the same package versions into `.omicstat-r/library` and writes `.omicstat-r/native-env.json`; then set `OMICSTAT_ENGINE=native`); `bash env/py/setup_native.sh` for the Python lane | Results match the container's versions, but the byte-level golden checks report SKIP because the environment signature differs. |

Then check the runtime:

```bash
bash env/test.sh                                            # full R suite in the container
bin/omicstat-r-route.sh Rscript skills/omicstat-selftest/scripts/run_omicstat_selftest.R --outdir /tmp/selftest --strict
```

The anchor datasets used by the smoke tests are fetched separately with `bash acceptance/data/fetch_anchor_data.sh` (public sources, sha256-checked). The MCP server needs a Python with `mcp/requirements.txt` installed; see `mcp/README.md` for the registration snippet and the `OMICSTAT_SUITE_ROOT` / `OMICSTAT_RUNS_ROOT` variables.

`mcp/package_identity.py` looks for a release identity file (`research/remediation/package_identity.json`) that only a packaged release carries. In a source checkout it is absent; runs still work and their provenance records "source checkout, not bound to a release".

## How it is used

**Through MCP** (the intended way). `mcp/server.py` is a stdio FastMCP server with exactly five tools:

| Tool | Purpose |
|---|---|
| `omicstat_list_modules` | the router table: module, one-line summary, entry script |
| `omicstat_describe` | a module's SKILL.md, its full `--help` and reference files |
| `omicstat_run` | run one module in the locked container; returns a compact manifest: exit code, triggered QC rules (blocking first), engine warnings, the primary result rows, degenerate-estimate flags, upstream run chain, artefact listing |
| `omicstat_read` | read any text artefact of a run |
| `omicstat_validate_publication` | re-run the publication gates on a finished run |

Register it with a Python that has `mcp/requirements.txt` installed, pointing `OMICSTAT_SUITE_ROOT` at this directory and `OMICSTAT_RUNS_ROOT` at a writable run root (see `mcp/README.md`). The calling LLM reads `skills/omicstat/SKILL.md` to decide which module answers a question; each module's SKILL.md tells it which options are scientific judgements that must come from the user, and to consult the reference companion (below) before choosing.

**From the command line.** Every module is also a plain script, run through the router that selects the locked container (or an isolated native library):

```bash
# bulk: two-group DESeq2 Wald test, then fgsea on its ranked list
bin/omicstat-r-route.sh Rscript skills/deseq2-wald/scripts/run_deseq2_wald.R \
    --counts counts.tsv --samples samples.csv --condition-col condition \
    --target treated --reference control --outdir runs/wald
bin/omicstat-r-route.sh Rscript skills/fgsea-prerank/scripts/run_fgsea_prerank.R \
    --from-run runs/wald --collection <registered offline collection> --outdir runs/fgsea

# single cell, scverse lane
bin/omicstat-r-route.sh python skills/scanpy-qc/scripts/run_scanpy_qc.py \
    --input pbmc.h5ad --sample-col sample --counts-layer X --mito-prefix MT- \
    --min-genes 200 --max-genes 2500 --min-counts 1 --max-counts 100000 \
    --max-mito-percent 5 --min-cells 3 --doublet-mode skip \
    --species human --annotation declared_release --outdir runs/qc
```

`--help` of each entry script lists every option with its locked default; QC thresholds, clustering resolution, numbers of PCs/HVGs/neighbours, reference sets and similar judgements are required, not defaulted.

**Outputs of a run** (`<outdir>/`): `tables/` (native result tables as CSV plus the shared feature table), `figures/` (PDF + PNG + `figure_spec.json` with data, caption, thresholds and n), `draft/` (Methods and Results text filled from the actual calls and values), `qc/` (rule table and per-stage engine warnings), `objects/` (native objects and `handoff.json`), `provenance/` (inputs, image id, package versions, seed, `resolved_spec.json` for replay), `publication/` (gate results, value map).

## Figures

All figures go through one layer (`skills/_shared/scripts/fig_*.R`, rules in `skills/_shared/docs/FIGURE_STYLE.md`): print-size presets for Nature / Cell / Science / generic, fixed fonts and point sizes, a fixed palette (up `#B2182B`, down `#2166AC`, non-significant grey, Okabe–Ito for conditions, viridis for continuous values), colour registries that travel along a chain so the same cell type keeps its colour from UMAP to proportion bar to heatmap, automatic captions from the plotted data, byte-identical re-renders, and a lint that refuses a figure with clipped or sub-5-pt text. Python modules emit figure requests that the same R layer renders. Single-cell embeddings can label each group on its largest island, take a fixed colour registry, cap points per group for display only, and draw labels with a white halo and collision avoidance (`--label-style halo`; the default output is unchanged). Examples: `docs/figure-gallery/`.

## Parameter policy and the reference companion

The default of an option is the locked function default, or the value the package's official vignette recommends (cited). Literature frequencies are never turned into defaults. Where the documentation does not settle a scientific choice, the option is required.

To help choose, `reference_service/` is a separate MCP companion (`reference_search`, `reference_advise`, `reference_request_literature`) holding what published studies reported for each module's options: 753 open-access papers, 958 module-level usage records (every module now has reviewed evidence), each with a verbatim Methods snippet, the PubMed id and the extraction provenance. Evidence is kept in three separate columns — curated, reviewed supplement, unreviewed discovery — and only reviewed records can appear in advice. Advice is context, never an executable parameter. A snapshot of the deployed service's databases is in `reference_service/data/` (see `SNAPSHOT.md`); the same evidence is also shipped as a loadable bundle, `reference_service/app/s0_evidence/catalog.json`.

## Publication gates

`omicstat_validate_publication` and the on-disk `publication/` record apply universal rules (module sealed, run exited cleanly, artefacts present, canonical tables validate against the shared schema, no cross-table value conflicts) and two traceability checks ported from medstat: every number in the drafts and captions must be traceable to a table, result scalar or QC evidence; reported denominators must agree with the inclusion/exclusion ledger (features filtered, cells retained, samples per group). A run is `ready_for_manuscript_integration` only when nothing remains for human review.

## Status (2026-10-09)

| Check | Result |
|---|---|
| Modules installed | 38 analysis modules + 3 display modules + 2 self-tests; 42/42 module locks verified |
| R suite (`env/test.sh`, locked container) | ALL PASSED, 198 commands, 0 skipped for missing packages; the only failing assertions are the two documented sva-batch A6a anchors (a vignette-printed `num.sv` that differs by numerical noise; kept visible on purpose) |
| Python suite | 44 commands ALL PASSED |
| MCP end to end (host stdio, both containers) | 99/99 assertions (3 native-engine checks skipped on a container-only host) |
| Router blind reading (139 scored questions; 146 in the set, 7 new items structure-checked only) | 92.8 % first choice (gate 90 %), 100 % within acceptable (gate 98 %) — `docs/build/ROUTING_BLIND_EVAL.md`, `docs/build/UMAP_DISPLAY_REPORT.md` |
| Independent review | every analysis module passed an independent S3 review on the locked image after its build; repair lists and verdicts are under `acceptance/exemplars/<module>/`. The three display modules (2026-10-08) are sealed and tested but still await their independent review |

Not yet done: an end-to-end run on a real study from raw data to a complete manuscript draft (planned); a few owner-level scientific choices remain open and are listed in `SUITE.md` (they are handled safely in code — refused or required — never decided silently).

## Evidence and build records

Each module's `acceptance/exemplars/<module>/` holds the evidence pack used to build it: `PACK.md` (the package's locked documentation, the anchor dataset, extracted parameter usage from open-access literature, the decision appendix), `literature/` (corpus, verbatim extraction, PubMed records), `L1_*/` (the locked version's help pages, vignettes with printed output, NEWS), and the review files. The build itself was run as one build → one independent audit → one concentrated fix → one final verification per module; the reports are in `docs/build/` (`S3_*`, `S4_REPORT.md`, `S5_REPORT_m3m4.md`, `FABLE_CHECKUP_REPORT.md`, …) and the authoritative design is `docs/handoff/ENGINEERING_PLAN.md`.

## Repository layout

```
skills/<module>/        38 analysis + 3 display modules, the router (skills/omicstat) and two self-tests
skills/_shared/         figure layer, feature/effect tables, hand-off contract, engine-warning capture,
                        report rendering, conversion between Seurat / SCE / AnnData, Python counterpart (py/ospy),
                        schemas, publication rule catalogues, docs (FIGURE_STYLE, CONVENTIONS)
mcp/                    the MCP shell: server, publication gates, module seal, tests
env/                    the locked environments: omicstat-env.json (single pin source), layered package lists,
                        Dockerfile, build/test scripts, pkg_lock.csv, native isolated-library setup, Python lane
bin/                    omicstat-r-route.sh / .ps1: route a tool call into the locked container or native library
reference_service/      the omic-only reference companion (separate container; offline tests)
acceptance/             evidence packs and reviews per module; anchor data registry and fetch script
docs/                   design (handoff/), build and review reports (build/), figure gallery
tools/                  scaffolding, static checks (calls, defaults, flag docs, front matter), lock tools, test runners
templates/              new-module templates
```

## Running the tests

After building a runtime (see *Before you start*):

```bash
bash env/test.sh           # full R suite inside the locked container
bash env/py/test.sh        # full Python suite
bash env/py/test_e2e.sh    # real MCP stdio across both containers
```

Anchor datasets are public and fetched by `acceptance/data/fetch_anchor_data.sh` (sha256-registered in `ANCHOR_REGISTRY.md`). Nothing from KEGG, CADD, PanglaoDB or DepMap is included or downloaded by omicstat; enrichment and scoring modules accept a user-supplied local gene-set file (e.g. KEGG pathways the user retrieved under academic terms) through `--database custom` / `--collection user` with recorded provenance, and the user is responsible for those terms; CIBERSORT runs only from user-supplied licensed files; EPIC requires an explicit academic-licence acknowledgement flag.

## Release note

This repository is a clean export of the private development repository at `integrate/final`. The vendored literature-retrieval clients (`vendor/`, used only by `tools/lit` during evidence collection) and the medstat reference snapshots (`reference/`) are not included; nothing at run time depends on them. Host names, user names and session identifiers of the development machines were replaced by placeholders. The reference companion's deployment scripts are included with the same placeholders. The architecture of the MCP shell, the publication contracts and the StudyContract follows the author's medstat suite for clinical statistics; omicstat runs independently of it.

## Licence

MIT (see `LICENSE`). The wrapped packages keep their own licences (Bioconductor and CRAN packages, scverse packages, CellChat, monocle3, immunedeconv and their signature data); see each module's `references/options.md` for the licence of any bundled reference data.
