# seurat-qc S2
Worktree /home/<user>/omic-b-seurat; branch build/m3a-seurat; run build_m3a_seurat.
- [x] scaffold and read PACK
- [x] engine / registry
- [x] QC / five references / reporting / SKILL
- [x] anchor / smoke / goldens / lock
- [x] inspect all figures / S3 request / commit
VERIFIED: scaffold created; source anchor copied, not re-downloaded.
NEXT STEP: locked container formals probe and engine.
## 待裁决 (S2)
QC thresholds and mitochondrial pattern must be supplied explicitly; no universal thresholds chosen.
VERIFIED: slim build retained working wrapper and existing checks; required/judgement options now direct caller to reference service; advanced creation controls exposed as JSON CLI values. Container qc_slim.log: 19 checks PASS, locked PBMC printed values and replay, goldens regenerated. NEXT STEP: lock check and finish visual review.
VERIFIED: module_lock seurat-qc 1.0.0 OK (15 files); all nine anchor/replay/alternate PNGs opened, readable and unclipped; captions include n and thresholds. S3_REQUEST written.
NEXT STEP: independent S3; S2 complete.
Integration-anchor compatibility: packaged harmony pbmc_stim is a preselected matrix with no MT- genes. Added explicit --missing-mito error|zero (default error preserved); zero delegates to native PercentageFeatureSet and reports matched-gene count, not a claim of measured mitochondrial burden. Integration chain smoke will verify this opt-in path; lock refresh required.

FINAL VERIFIED: final_audit.log calls/default drift/golden PASS; final_locks.log module_lock --check OK; CLI flag docs/default consistency/lint PASS. Methods names core functions and actual options. S3_REQUEST present. NEXT STEP: independent S3; all authorized S2 lane steps complete; commit record is the lane worklog under the external helper policy.
2026-10-01 env_rebuild: baseline new-image smoke PASS; existing golden retained; lock refreshed/check; addon-specific checks pending
seurat-qc: final 2026.10.1 smoke PASS (non-root/offline; golden unchanged; lock checked; awaiting independent S3); next remaining full R suite
