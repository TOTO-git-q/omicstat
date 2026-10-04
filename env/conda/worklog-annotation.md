# Worklog: annotation and reference data, dev tier (2026-09-27)

Task: VENDOR_INTEGRATION_BRIEF section 3. Scope (reduced by the owner): official
annotation packages in the dev tier, retire the GO.db stand-in, registry
entries in `env/refdata_registry.json`. mygene cross-check optional.

## Verified state (dev env /opt/mm/env/omicstat-dev)

1. GO.db stand-in (3.4.0, GO 2016-09-21) removed with `R CMD REMOVE`.
2. `micromamba install --force-reinstall` of the four bioconda data packages
   (exact builds from `omicstat-dev.explicit.txt`); each post-link download from
   bioconductor.org passed bioconda's md5 check and installed:
   GO.db 3.22.0, org.Hs.eg.db 3.22.0, org.Mm.eg.db 3.22.0, celldex 1.20.0.
3. Source dates read from the installed packages (`*_dbInfo()`):
   GO go-basic.obo 2025-07-22; NCBI Gene 2025-Sep24 (Hs and Mm);
   Ensembl 2025-Sep03 (Hs).
4. msigdbr 26.1.1 data: hard-coded zenodo record 18968178
   (`msigdb.2026.1.zip`, md5 in the package code); cached in
   `tools::R_user_dir("msigdbr", "cache")` = `/root/.cache/R/msigdbr`.
   db_version 2026.1.Hs / 2026.1.Mm.
5. celldex 1.20.0 defaults (`legacy = FALSE`) fetch from gypsum
   (https://gypsum.artifactdb.com), version `2024-02-26`, cached in
   `gypsum::cacheDirectory()` = `~/.cache/gypsum` (env `GYPSUM_CACHE_DIR`).
   hpca, blueprint_encode, monaco_immune, mouse_rnaseq, immgen downloaded;
   every file matches the md5 in its gypsum `..manifest`.
6. Offline check (proxy set to a dead port): celldex HPCA, msigdbr H,
   `bitr()` with org.Hs.eg.db and `enrichGO()` on DOSE::geneList all run.
7. sha256 of every downloaded file: see `env/refdata_registry.json`.

8. Repo edits: `env/conda/setup_dev.sh` (step 5 = official install with
   force-reinstall and sha256-checked source-tarball fallback; new step 6 =
   reference-data caches), `env/conda/check_dev.R` (OrgDb + celldex required,
   stand-in detection, source dates, cache status, accurate not-installed
   list), `env/conda/README.md`, `docs/build/MODULE_BUILD_BRIEF.md` (dev-tier
   bullet), `env/refdata_registry.json` (10 entries with `tier = dev`),
   `env/conda/omicstat-dev.explicit.txt` regenerated.
9. Explicit list diff: only r-ashr 2.2_63 and 4 dependencies (etrunct,
   invgamma, mixsqp, truncnorm; squarem reordered), installed into the shared
   env at 04:52 by another session, before this work. The four data-package
   builds are unchanged.
10. Step 5 tested in isolation: normal path (all present, no-op) and the
    fallback loop (downloads, sha256 OK for all four tarballs; install replaced
    by echo).
11. Tests (dev env): `Rscript env/conda/check_dev.R` -> DEV TIER OK;
    `python3 env/test_env_config.py` 72 PASS, exit 0; shared R tests
    (layer lib, figures, figures_ext, omics_shared, effect_table, render,
    engine_contract) all pass; `tools/test_tools.py` 21 OK; `lint_r.py` 0
    problems; deseq2-wald smoke PASSED. `bash tools/run_tests.sh` itself could
    not be launched from this agent (sandbox refused the wrapper), so its
    steps were run one by one. No existing test loads clusterProfiler/DOSE;
    `enrichGO` on DOSE::geneList was run by hand (offline, 156 terms).
12. mygene cross-check (optional, 100 protein-coding genes):
    `docs/build/ANNOTATION_CROSSCHECK_2026-09-27.md`.

## Where I stopped

Done with the reduced scope. Not done (out of scope or pending decision):
- scRNAseq / muscData / TENxPBMCData not installed (bioconda 3.22 builds exist).
- airway / pasilla / parathyroidSE / HDO.db still from GitHub (not the
  official 3.22 builds); switching pasilla may change the deseq2-wald dev golden (not tested).
- Container-side registry entries (`TO_FILL_AT_BUILD`) untouched: the locked
  image is Bioconductor 3.23; how the data enter it is a pending decision.
