# build_m3b lane worklog
Worktree: /home/<user>/omic-b-m3b; branch: build/m3b; scratch: /home/<user>/omic-sol61/build_m3b/
Modules in order: singler-annotate, muscat-pseudobulk, speckle-propeller, slingshot-trajectory, monocle3-trajectory, cellchat-communication.
2026-09-30 | setup verified: clean build/m3b, no prior lane log; locked Docker R 4.6.1 / SingleR 2.14.2 executed exit 0 | commit pending | next: SingleR scaffold
2026-10-01 | singler-annotate scaffold generated; S0 evidence copied read-only source to lane; anchor files copied, no downloads | commit FAILED: git index.lock read-only filesystem | next: engine and registry; commits still required
singler-annotate: S2 slim build and failure handover finished (classic smoke/static checks PASS; mandatory pancreas anchor blocked by locked-image missing scrapper; goldens/lock withheld; awaiting independent S3); next muscat-pseudobulk
muscat-pseudobulk: scaffold, wrapped engine/options/native tables and replica guard finished; next anchor smoke/golden/lock
muscat-pseudobulk: S2 build done (Kang18 counts 12/13/1362 and ISG15 5.47346/3.0e-21 PASS; direct/from-run identical; native tables, golden, lock --check OK; figures inspected; awaiting independent S3); next speckle-propeller
speckle-propeller: official wrapper/options/replicate guard scaffold finished; CellBench fixture input object-name mismatch under investigation; next anchor smoke
speckle-propeller: S2 build done (CellBench exact H1975 logit P/FDR .01841045/.05003357 and asin P .01578743 PASS; direct/from-run equality; native tables/golden/lock --check OK; figures inspected; awaiting independent S3); next slingshot-trajectory
slingshot-trajectory: pinned S4 options/official slingshot→fitGAM→associationTest wrappers finished; smoke in progress on bifurcating 140-cell fixture and seeded tradeSeq fixture
slingshot-trajectory: S2 build done (140-cell/two-lineage fixture and seeded tradeSeq 240 converged genes PASS; native tables/container goldens/lock --check OK; three PNGs inspected; awaiting independent S3); next monocle3-trajectory
monocle3-trajectory: official backend wrapper/options/root controls finished; full Packer 20222×6188 fixture preprocessing/alignment/UMAP in progress; next smoke/golden/lock
monocle3-trajectory: S2 build done (full Packer 20222×6188/four partitions PASS; root Y_134; 5576 finite/612 Inf retained; direct/from-run equality; 20-gene graph-test smoke; golden/lock --check OK; PNGs inspected; awaiting independent S3); next cellchat-communication
cellchat-communication: native official default anchor fails because locked image lacks presto; retrying documented explicit --genes-do-fast false (standard Wilcoxon); pinned optional projectData absent and recorded; no installs
cellchat-communication: S2 supported branch done (full human-skin LS 17328×5011/12 groups; explicit standard Wilcoxon do.fast=false; 365 LR rows/16 pathways; direct/from-run/native/golden PASS; locked default fast path FAIL missing presto, recorded); next final figures/locks/report
build_m3b: shared contract checks PASS (sample replicate refusal, lazy defaults/local RDS options, complete scverse chain state, OS_ECOSYSTEM_MIXED; four prior goldens match); non-root AnnData OS_ENV_MISSING confirmed existing image defect; next final seal/check/report
cellchat-communication: S2 supported-branch handover done (native default failure documented; all four figures inspected; final golden PASS and module_lock --check OK; awaiting independent S3)
build_m3b: final seal PASS (five container goldens and five locks OK; all six calls/default drift + R lint PASS; all PNGs opened); Chinese BUILD_REPORT_build_m3b.md complete; awaiting external helper report commit before DONE
