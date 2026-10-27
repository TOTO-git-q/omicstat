# scvi-integrate verify_gptpro worklog
Worktree: /home/<user>/omic-v-gptpro; branch verify/gptpro; scratch /home/<user>/omic-sol61/verify_gptpro.

- [x] locked default capture and L1/policy comparison
- [x] numerical replay, flag effectiveness, refusal paths and --spec determinism
- [x] generate_golden.sh twice; golden PASS and module lock OK
- [x] R rendering / PNG visual review (details in lane report)
- [x] S3_REQUEST prepared
- [ ] independent S3 (outside this lane)

Verified output: `/home/<user>/omic-sol61/verify_gptpro/python-smoke/scvi-integrate_h4kvdsxl/anchor`. Observed: 96 cells, 160 genes.
Logs: `scvi-integrate-pass1.log`, `scvi-integrate-pass2.log` under lane scratch.
NEXT: independent S3. No tolerance or assertion loosened.

## 待裁决 (S2)
Full tutorial-scale biological validation, scientific thresholds/dimensions/epochs, backend ecosystem labelling and cross-platform equivalence remain owner/independent-review items.

## Defaults adjudication 2026-10-11 (lock 7 record, module 1.1.0 -> 1.2.0)
- `--n-latent`: default 10 removed. It is required whenever the model is trained (typed OS_MISSING_PARAMETER) and not needed with `--latent-from-run`. Evidence: reviewed literature 30 (6 papers), 10 (2), 64 (2), 50, 52, 6, so no majority; the module text already said the analysis dimension is chosen by the user. The shared anchor helper already passes `--n-latent 5`, so the goldens are byte-identical and no shared file changed.
- `--n-layers`: stays 1 (locked scvi-tools 1.5.1 default). The harmonization tutorial configuration `n_layers=2, n_latent=30, gene_likelihood="nb"` (the tutorial calls it non-default and says it generally works well for integration) is documented as a named optional configuration; the S4 replay `tutorial_structure` already runs it.
- Module smoke gains two checks (no assertion changed): latent reuse without `--n-latent` still works, and training without `--n-latent` is refused.
