# Module build brief

Written in the cloud session of 2026-09-27 for the module build, which was then moved to the
owner's own machine (see `docs/build/CLOUD_BLOCKERS_2026-09-27.md`). On a machine with full
internet: build the locked container first (`bash env/gt103.sh`) and use it instead of the dev tier;
do the L3/L4 literature step of S0 (ENGINEERING_PLAN 2.2) before S1 -- the "not collectable here"
notes below apply only to the cloud session.

Instructions every module builder follows. The authoritative design is
`docs/handoff/ENGINEERING_PLAN.md` (read parts 1-4 and 7 before starting); the
conventions are `skills/_shared/docs/CONVENTIONS.md`; the figure style is
`skills/_shared/docs/FIGURE_STYLE.md`. **The reference implementation is
`skills/deseq2-wald/` plus `acceptance/exemplars/deseq2-wald/PACK.md`: copy its
structure, level of detail and test style.**

## 1. Environment

- R: `export PATH=/opt/mm/env/omicstat-dev/bin:$PATH` (R 4.5.3, Bioconductor 3.22,
  every package of the suite incl. Seurat 5.5, CellChat, monocle3, immunedeconv).
  `Rscript env/conda/check_dev.R` lists versions. The environment is shared by
  several builders: do not upgrade or remove packages. If a package is truly
  missing, install it with
  `MAMBA_ROOT_PREFIX=/opt/mm/root /opt/mm/bin/micromamba install -y -p /opt/mm/env/omicstat-dev -c conda-forge -c bioconda <pkg>`
  and list it in your final report.
- Network: GitHub (git clone, raw.githubusercontent.com), conda.anaconda.org,
  PyPI and the 10x Genomics S3 bucket work. CRAN, Bioconductor, ExperimentHub,
  AnnotationHub, zenodo, Europe PMC, PubMed, NCBI, Ensembl, KEGG, MSigDB are
  **blocked**. Consequences:
  - (updated 2026-09-27, network opened) the dev tier now has the official
    Bioconductor 3.22 GO.db, org.Hs.eg.db, org.Mm.eg.db and celldex; the 2016
    GO.db stand-in is retired. msigdbr data (MSigDB 2026.1) and the five celldex
    references are cached per user (see `env/conda/README.md`,
    `env/refdata_registry.json` entries with `tier = dev`). scRNAseq /
    muscData / TENxPBMCData are still not installed.
  - Tests that need those resources are **container-only**: they print
    `SKIP: <reason>` and never FAIL in this tier.
- Anchor data: package-embedded datasets (airway, pasilla, parathyroidSE,
  fgsea examplePathways/exampleRanks, DOSE geneList, maftools extdata, ...),
  and `bash acceptance/data/fetch_anchor_data.sh` (10x pbmc3k and pbmc4k from
  S3, sha256-checked; git-ignored -- run it inside your worktree). More 10x
  public datasets exist under `https://s3-us-west-2.amazonaws.com/10x.files/samples/cell/<name>/`;
  add any you use to the fetch script with its sha256. Multi-sample /
  multi-condition single-cell anchors may be simulated with the package's own
  simulator (e.g. `muscat::prepSim` + `simData`) from real data, as its vignette does.
- Reference source code (clone locally with `git clone --depth 1 https://github.com/<owner>/<repo>`):
  (nf-core modules / differentialabundance, rnaseqGene, RNAseq123, OSCA books,
  Seurat + seurat-wrappers, clusterProfiler + its book, fgsea, GSVA, CellChat,
  monocle3, slingshot, tradeSeq, muscat, speckle, maftools, immunedeconv,
  harmony, scuttle, scran, batchelor, AUCell, SingleR, WGCNA, sva) -- repos used in the
  cloud session: nf-core/modules, nf-core/differentialabundance, mikelove/rnaseqGene,
  Shians/RNAseq123, OSCA-source/OSCA.basic|advanced|workflows|multisample,
  satijalab/seurat, satijalab/seurat-wrappers, YuLab-SMU/clusterProfiler,
  YuLab-SMU/biomedical-knowledge-mining-book, ctlab/fgsea, rcastelo/GSVA, jinworks/CellChat,
  cole-trapnell-lab/monocle3, kstreet13/slingshot, statOmics/tradeSeq, HelenaLC/muscat,
  phipsonlab/speckle, PoisonAlien/maftools, omnideconv/immunedeconv, immunogenomics/harmony,
  LTLA/scuttle, MarioniLab/scran, LTLA/batchelor, aertslab/AUCell, LTLA/SingleR, cran/WGCNA,
  jtleek/sva-devel (Bioconductor package mirrors: `github.com/bioc/<Package>`).

## 2. Per-module steps (ENGINEERING_PLAN part 7, S0-S5, dev tier)

1. **S0 evidence.** `Rscript tools/collect_l1.R <module> <pkg,...> <fn,...>`
   exports the installed vignettes (Rmd, purled R, rendered text with printed
   values), Rd pages, NEWS, CITATION and deparsed formals to
   `acceptance/exemplars/<module>/L1/`. Read the vignette sections that define
   the analysis part, the Rd of every core function and recent NEWS. L2: the
   official workflow / book sources in the refs directory. **L3/L4 literature is
   not collectable here**: say so in the PACK (as the deseq2-wald PACK does) and
   leave the exemplar-majority column empty. **Never cite anything from
   memory**: literature references come only from the packages' own
   `CITATION.txt`; every vignette section title you cite must exist in the
   rendered text (grep it); every quoted console message must exist in the
   package source (grep it).
2. **PACK.md** (`acceptance/exemplars/<module>/PACK.md`): sections T, F, W, V,
   C, D, X and an "S1 decisions" appendix, same layout as deseq2-wald. You
   make the S1 decisions (the owner delegated them); prefer the vignette /
   official workflow recommendation, write the reason, flag every decision to
   revisit when L4 exists.
3. **S2 build.** `python tools/new_module.py <pkg> <part>` scaffolds
   `skills/<module>/`. Fill: entry script (one `os_arg_spec`, `os_spec_argv`
   for `--spec`, `os_engine_capture` around every stage, typed `OS_*` errors),
   core / report / qc scripts, `calls_registry.json` (every result-affecting
   argument written out at every call site, value + source + PACK id +
   `function_default` read from `formals()` of the installed version; pure
   accessors under `"accessors"`), `references/*.md` (parameters table with
   `Flag | Default` columns, method-basis, qc-rules, reporting-templates with
   ```` ```template <id> ```` blocks the engine fills through
   `os_read_templates` / `os_fill_template`, troubleshooting), SKILL.md
   (frontmatter description <= 1000 characters: verb + product first, triggers
   early incl. Chinese terms, NOT-for lines with the module to use instead;
   the eight body sections).
   Use `_shared/scripts/module_kit.R` (tables, QC rules, provenance, golden,
   templates), `design_check.R`, `feature_table.R` / `effect_table.R`,
   `handoff.R`, `engine_run.R`, `args.R`. Figures ONLY through
   `_shared/scripts/fig_*.R` + `os_finalize_figure`; no colour, size, shape or
   position literals in module code.
4. **Smoke test** `tests/run_smoke_test.R` with a `# requires: <R packages>`
   header line (tools/run_tests.sh SKIPs when one is missing): static checks
   (check_calls, check_default_drift, check_defaults.py, check_flag_docs.py,
   lint_r.py), anchors (PACK C: values printed in the rendered vignette are the
   first choice; otherwise a *replay anchor*: the vignette's own code, run in the
   same session, must give identical numbers to the engine -- say which kind
   each anchor is), flag effectiveness, typed errors and blockers, determinism
   (`--spec` replay byte-identical tables / specs / PNGs), `--from-run` chaining
   where the module has an upstream, `os_golden_check`, no `Rplots.pdf`. Keep
   the whole smoke test under ~5 minutes (subsample big data).
5. **Look at every figure** (open the PNGs). Labels must not overlap, nothing
   may be clipped, captions must state thresholds and n. Fix layout problems in
   the `_shared` builder (see section 4), not in the module.
6. **S5 (dev tier).** `OMICSTAT_WRITE_GOLDEN=1 Rscript skills/<m>/tests/run_smoke_test.R`
   then `Rscript tools/make_module_lock.R <m>`; commit. Goldens carry the dev
   signature and are regenerated in the container later.

Do **not** edit: `skills/omicstat/SKILL.md` (router), `skills/_shared/publication/*`,
`SUITE.md`, `tools/qc_prefixes.json`, `docs/LOCAL_BUILD_GUIDE.md`, other
builders' modules. Instead, put in your final report, per module: the router
§1 row (`| question sounds like ... | \`module\` | \`scripts/run_x_y.R\` |`),
a §2/§3 note if relevant, and a `module_rules_v1.json` record in the
deseq2-wald format (category one of universal_hard, design_conditional,
advisory, journal_specific). The coordinator installs them.

## 3. Chaining contract (objects in `objects/handoff.json`)

Use these type strings so chains fit together (add new ones only when none fits,
and name them in your report):

| type | file | written by (examples) |
|---|---|---|
| `count_matrix` | csv/tsv, first column feature_id, integer counts | deseq2-qc, deseq2-wald |
| `sample_table` | csv, one row per sample | deseq2-qc, deseq2-wald |
| `feature_table` | canonical feature table csv | every DE module, pseudobulk, markers |
| `expression_matrix` | csv, first column feature_id (log-scale values: vst, logCPM, voom E, GSVA scores) | deseq2-qc, limma-voom, gsva-score |
| `ranked_list` | csv `feature_id,symbol,score` sorted by score desc (score = Wald / moderated t statistic) | any DE module |
| `gene_sets` | GMT | enrichment modules (the set collection actually used) |
| `enrichment_table` | csv (clusterProfiler/fgsea columns + canonical `term_id, term_name, padj`) | enrichment modules |
| `DESeqDataSet`, `DGEList`, `EList`, `MArrayLM` | rds | the fitting module |
| `Seurat`, `SingleCellExperiment` | rds | single-cell front ends (`ecosystem` = seurat / bioconductor) |
| `AnnData` | h5ad | scverse front ends; explicit h5ad in/out through `skills/_shared/scripts/convert.R`, prebuilt non-root basilisk path `/opt/omicstat/basilisk` |
| `cell_metadata` | csv, one row per cell (cell, sample, cluster, celltype, ...) | single-cell modules |
| `colour_registry` | json | every module with categorical colours (read upstream first) |

Feature ids follow CONVENTIONS sec 8; single-cell modules pass colour registries
for clusters / cell types down the chain.

Accepted Methods layouts: M1/M2 retain `references/reporting-templates.md`
with fenced `template` blocks; slim back-end/M4 modules may use
`references/methods-template.md`. Do not rename either layout. `check_flag_docs.py`
reads SKILL.md and all references/*.md; `check_defaults.py` reads their Flag/Default
tables and inline default markers (it does not interpret template prose).

## 4. Shared-code ownership (avoid merge conflicts)

- `skills/_shared/scripts/module_kit.R`, `args.R`, `handoff.R`, `feature_table.R`,
  `fig_style.R`: do not change behaviour. If a bug blocks you, fix it minimally and
  describe the fix in your report.
- New shared figure builders go into ONE new file per builder group, loaded by
  adding its name at the end of the list in `fig_all.R`:
  bulk -> `fig_mod_bulk.R`, enrichment -> `fig_mod_enrich.R`, Seurat line ->
  `fig_mod_sc_seurat.R`, Bioconductor line -> `fig_mod_sc_bioc.R`, single-cell
  back end -> `fig_mod_sc_downstream.R`, network/mutation/infiltration ->
  `fig_mod_network.R`. Follow FIGURE_STYLE (tokens only, auto caption,
  figure_spec, lint-clean under nature and cell presets) and add a section to
  FIGURE_STYLE.md only in a new clearly headed block at the end (`## 19.x <group>`).
- Helpers shared by your modules: `_shared/scripts/<group>_io.R` (e.g. `bulk_io.R`).

## 5. Git

Work in your worktree branch; commit per module (message: what the module does,
anchors reproduced, anything deferred) with the trailer lines
`Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>` and
(session reference removed)
Do not push. Final report: per module status (S0..S5 done / deferred and why),
anchors (value, source, pass), container-only SKIPs, router rows, module_rules
records, shared-file changes, packages installed.
