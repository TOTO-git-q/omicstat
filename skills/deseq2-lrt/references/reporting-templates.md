# deseq2-lrt reporting templates

The entry script fills these fenced templates into `draft/methods_results.md`. The wording follows PACK W and S1 P-1/P-3.

```template methods
DESeq2 (v{deseq2_version}) in R (v{r_version}) fitted a negative-binomial likelihood ratio test. Of {n_input} count features, {n_tested} with counts >= {min_count} in at least {min_samples} samples were retained. The full model was `{full}` and the nested reduced model was `{reduced}`; removed terms were {terms} (degrees of freedom {df}). DESeq used test = "LRT", fitType = "{fit_type}", sfType = "{sf_type}" and betaPrior = FALSE. Results used independent filtering, BH correction, alpha = {alpha}, and lfcThreshold = 0. The displayed log2 fold change is the single coefficient `{coef}`; it is not the effect size of the joint test.

Figures are displays and are separate from the inferential test. They show features with BH-adjusted LRT P < {alpha} across the {n_samples} samples, ranked by adjusted P: up to {top_n} in the heatmap, as row z-scores of expression transformed with {display_transform} after the fit, and up to {n_traj} in the trajectory figure (when a time column is given), as DESeq2 normalized counts. The transformation is used only for display and does not enter the likelihood ratio test.
```

```template results
At BH adjusted P < {alpha}, {n_sig} of {n_tested} tested features were significant in the joint test; {n_padj_na} adjusted P values were missing. The complete result table is retained. The LRT statistic is a nonnegative deviance difference; a separate, prespecified Wald contrast is needed to interpret a particular effect size.
```

Slots `{deseq2_version}`, `{r_version}`, `{n_input}`, `{n_tested}`, `{min_count}`, `{min_samples}`, `{full}`, `{reduced}`, `{terms}`, `{df}`, `{fit_type}`, `{sf_type}`, `{alpha}`, `{coef}`, `{n_sig}`, `{n_padj_na}`, `{n_samples}`, `{display_transform}` (the transformation call that actually ran: `vst(blind = FALSE, nsub = 1000, fitType)` or, below 1,000 features with mean normalized count > 5, the direct `varianceStabilizingTransformation(blind = FALSE, fitType)`), `{top_n}` and `{n_traj}` are supplied by `deseq2_lrt_draft()` from resolved arguments and fitted results.
