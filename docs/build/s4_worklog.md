# S4 concentrated fix — worklog (integrate/m1m2)

Protocol: verified state + exact next step, updated as work proceeds. A resumed
session reads this file first and continues from "Next step".

## Environment
- Local worktree: `E:/claude workspace/skills-dev/omic-integrate` (branch `integrate/m1m2`).
- GT103 runtime mirror: `~/omic-integrate` (detached worktree of `~/omic-MCP`); acceptance
  layer = hard-link copy (`cp -al`) of `~/omic-build/.omicstat-acceptance` (a symlink does not
  resolve inside the container mount); untracked anchor files copied from
  `~/omic-build/acceptance/data/`. Logs: `~/omic-build-logs/s4/`.
- Coordinator dev runs: `~/omic-build-logs/s4/coord/` via `docs/build/agent_briefs/s4_sync.sh`
  (never sync while a run in that dir is active).
- Helpers: local worktrees `skills-dev/omic-s4-<name>` on local branches `s4/<name>`
  (never pushed); GT103 dirs `~/omic-build-logs/s4/<module>/`. Brief:
  `docs/build/agent_briefs/S4_HELPER_BRIEF.md`.

## Verified state
- [x] Step 1 merges: build/m1-limma, build/m2, build/m2-rank, s3/review merged (base
  build/m1m2@2ddf174). Conflicts only in `_shared/docs/FIGURE_STYLE.md` (all lanes' §19.x kept,
  renumbered 19.2–19.9) and `_shared/scripts/fig_all.R` (both new builder files loaded).
- [x] Baseline @b9a26b9 in container: `env/test.sh` ALL PASSED, but 3 SKIPs = the three
  clusterProfiler smoke tests (`# requires:` header with commas; run_tests.sh fixed in ab73aae).
  Log `~/omic-build-logs/s4/baseline-b9a26b9.log`; cp smokes run directly:
  `~/omic-build-logs/s4/baseline-cp.log`.
- [x] Shared contracts committed ab73aae/fb63e52: ranked_list.R (contract a), limma_io.R
  hand-off objects + consumer reader (contract b producer side), handoff.R corrected lineage
  (contract c), fig_mod_bulk.R builders os_sample_mds / os_ql_dispersion / os_voom_trend /
  os_prior_density (looked at: fine).
- [x] Wave-1 helpers launched from fb63e52: s4/deseq2-qc-lrt, s4/sva-batch, s4/edger-qlf,
  s4/cp-ora-compare (contract d inside).
- [x] deseq2-wald 1.2.0 done (df21432): S4_FIXES.md written; smoke PASS incl. golden, lock OK.
- [x] Shared figure additions (df21432, 8faae95): os_barcode, os_md_set_highlight,
  os_score_by_group, os_nes_bar direction wording, set-bar legend; FIGURE_STYLE 19.10.
- [x] Yoruba/camera printed-value root cause (479c255, docs/build/S4_ANCHOR_TRACE.md): voom
  adaptive.span default changed in limma 3.66.0; with adaptive.span = FALSE every printed value
  of User's Guide 18.1.9/18.1.10 reproduces.

- [x] Merged helper branches: s4/edger-qlf (02a0251), s4/deseq2-qc-lrt (53006d8), s4/sva-batch
  (a79e19e), s4/limma-array (d1f21bb). Each touched only its own module/exemplar dirs.
- [x] fgsea-prerank 1.1.0 by coordinator (f27e815).
- [x] Acceptance layer: RnAgilentDesign028282.db 3.2.3 + org.Rn.eg.db 3.23.0 added to the lock and
  installer (4c17146); installed in GT103 `~/omic-integrate/.omicstat-acceptance` (now a real copy,
  no hard links to ~/omic-build). limma-array smoke in the mirror PASSES.
- [~] clusterprofiler-gsea 1.1.0 by coordinator: smoke PASS; goldens/lock run `coord-cpg2.log`.
- Rate-limit cut-off ~04:30; resumed. cp-gsea WIP committed (a9dce92). s4/cp-ora-compare finished
  and merged (bfd9cfe). s4/limma-voom-dupcor and s4/gsva-camera: unverified work saved as WIP commits
  (c34d593, 644c72e), integrate merged in, fresh opus helpers relaunched on the same branches.
- Shared fix fa9227c: limma_io `res[["expr"]]` (partial matching of res$expr_scale).

- [x] cp-gsea 1.1.0 committed (b308d59). s4/limma-voom-dupcor merged (4c45a40), s4/gsva-camera merged
  (f35de0f). All 14 modules repaired. Shared follow-ups: 1c61a9c (direction summary lfc),
  shared figure fixes for gsva/camera (colours, caption, MD palette, plural).
- Pre-merge full test (`~/omic-build-logs/s4/pretest.log`, tree b308d59) was still running at merge time.

- [x] gsva-score + limma-camera goldens/locks regenerated after shared figure fixes (e0a2865, pushed).
- [~] Final run started on GT103 at e0a2865: `~/omic-build-logs/s4/final.log`, `final-test.log`,
  `final-lockcheck.log` (mirror reset to origin/integrate/m1m2; acceptance layer kept).

- [x] Final run @e0a2865 (report commits after it change docs only): env/test.sh ALL PASSED 0 SKIP;
  lock --check OK x14. Logs `~/omic-build-logs/s4/final-test.log`, `final-lockcheck.log`.
- [x] docs/build/S4_REPORT.md complete.

## Next step
- None: S4 done. Hand over to the final verifier.
