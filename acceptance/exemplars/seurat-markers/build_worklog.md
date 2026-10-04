# seurat-markers S2
Worktree /home/<user>/omic-b-seurat; branch build/m3a-seurat; run build_m3a_seurat.
VERIFIED: PACK read; native FindAllMarkers/FindMarkers tables retained; test and contrast options exposed.
NEXT STEP: marker figures and real PBMC QC-cluster-marker chain smoke.
## 待裁决 (S2)
Cluster test/contrast and display choices require caller review through reference service; condition inference routes to muscat-pseudobulk.
VERIFIED: full PBMC native replay found 11648 returned marker rows; 7023 with avg_log2FC>1 vs archived 7019, IL32 FC 1.324556 vs archived 1.3070772. Exact native replay agrees; no tolerance loosened. Dotplots/cluster-mean native scale.data heatmaps and six upstream PNGs opened (ten total), readable/no clipping. Locked Seurat object method derives norm.method internally; forwarded duplicate failed and was removed. Static call/default/CLI/lint checks PASS. NEXT STEP: parsed-up-front smoke completion, golden check and module lock, then independent S3.
VERIFIED: markers_final.log complete smoke exit 0 (10 checks PASS); native all/contrast replay, real chain, original golden PASS, registered calls/locked defaults/no device leak PASS. CLI docs/defaults/lint PASS; module_lock --check OK. S3_REQUEST lists printed discrepancies and route limits. NEXT STEP: independent S3; S2 complete.

FINAL VERIFIED: final_audit.log calls/default drift/golden PASS; final_locks.log module_lock --check OK; CLI flag docs/default consistency/lint PASS. Methods names core functions and actual options. S3_REQUEST present. NEXT STEP: independent S3; all authorized S2 lane steps complete; commit record is the lane worklog under the external helper policy.
2026-10-01 env_rebuild: native replay/2638 cells/9 clusters PASS; existing marker table golden mismatch on new image, preserved; investigate presto optional backend, do not regenerate golden.
2026-10-01 env_rebuild: seurat-markers: mismatch traced to native automatic presto Wilcoxon switch; old-image replay hash exactly equals existing golden, 11648 identical gene/cluster/order/log2FC/pct rows, only P serialization differs (raw max 1.8041124150158794e-16, adjusted max 2.398081733190338e-14); golden retained and strict failure reported, lock not refreshed; awaiting independent S3
2026-10-01 env_rebuild UPDATE: authorized native presto path; own smoke script regenerated golden and passed; 11648 rows/7023 log2FC>1/IL32 1.324556, historical 7019/1.3070772 still differ; P-value-only change explained; next final-image suite/lock; awaiting independent S3
seurat-markers: final 2026.10.1 smoke PASS (non-root/offline; golden authorized_presto_change; lock checked; awaiting independent S3); next remaining full R suite
