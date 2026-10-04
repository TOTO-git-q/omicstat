# seurat-qc independent S3 request

Run in omicstat-r:2026.09.1 with suite at /omicstat and writable lane scratch at /scratch:
`Rscript skills/seurat-qc/tests/run_smoke_test.R`, then `Rscript tools/make_module_lock.R seurat-qc --check`.

Checked PBMC3k SHA256 847d6ebd9a1ec9a768f2be7e40ca42cbfe75ebeb6d76a4c24167041699dc28b5; official locked pbmc3k_tutorial: 2700 input cells, 13714 genes after CreateSeuratObject; first-cell 2419 UMI, 779 features, 3.0177759% mitochondrial. Strict tutorial QC retains 2638 cells; native-code replay, parameter effect, error cases and table/PNG determinism tested. Source: read-only S0 seurat-qc L1_cran2026-09-15/Seurat/vignettes and PACK C.

Outputs: /home/<user>/omic-sol61/build_m3a_seurat/qc_anchor (tables, native objects/seurat.rds, handoff, figures, draft, provenance); log qc_slim.log. All generated PNGs visually reviewed; finalizer figure lint passed. Warnings: underscore replacement is native Seurat; ggplot2 draw_quantiles deprecation is inherited suite violin code.

Limits / 待裁决: all QC thresholds, mitochondrial identifier pattern and organism are caller choices. No doublet inference. Consult reference service before choosing thresholds; PBMC values are examples.

Proposed router row: `| Seurat raw-count quality control / 单细胞质控 | seurat-qc | scripts/run_seurat_qc.R |`.
Proposed publication rule: `{ "module": "seurat-qc", "id": "SQ-QC", "category": "design_conditional", "rule": "Report explicit QC thresholds, retained cells, species and mitochondrial pattern; review QC warnings." }`.
