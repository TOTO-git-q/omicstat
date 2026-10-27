# scanpy-markers verify_gptpro worklog
Worktree: /home/<user>/omic-v-gptpro; branch verify/gptpro; scratch /home/<user>/omic-sol61/verify_gptpro.

- [x] locked default capture and L1/policy comparison
- [x] numerical replay, flag effectiveness, refusal paths and --spec determinism
- [x] generate_golden.sh twice; golden PASS and module lock OK
- [x] R rendering / PNG visual review (details in lane report)
- [x] S3_REQUEST prepared
- [ ] independent S3 (outside this lane)

Verified output: `/home/<user>/omic-sol61/verify_gptpro/python-smoke/scanpy-markers_8wphrym0/anchor`. Observed: 600 cells, 13769 genes.
Logs: `scanpy-markers-pass1.log`, `scanpy-markers-pass2.log` under lane scratch.
NEXT: independent S3. No tolerance or assertion loosened.

## 待裁决 (S2)
Full tutorial-scale biological validation, scientific thresholds/dimensions/epochs, backend ecosystem labelling and cross-platform equivalence remain owner/independent-review items.

## Defaults adjudication 2026-10-11 (lock 7 record, module 1.0.0 -> 1.0.1, documentation only)
- `--test` keeps the scanpy 1.12.4 documented default t-test. Evidence: 21 reviewed papers report a test, 16 Wilcoxon (scverse-only 13 of 16, mixed 3) and 5 t-test; the official clustering tutorial uses wilcoxon; Pullin and McCarthy 2024 (PMID 38409056) find Wilcoxon, t-test and logistic regression all effective. The module output is descriptive_cluster_markers, so there is no reproducible statistical error. Options/SKILL/method-basis now state the tutorial value and the difference from seurat-markers (wilcox). No script behaviour, shared file or golden changed.
