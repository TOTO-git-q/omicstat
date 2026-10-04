# limma-voom report templates

Every slot is filled from the actual run (S4, S3 F2): versions, the filterByExpr thresholds
the call used, the TMM factors, the interface and its voom span, the sample-weight setting
and estimates, and the eBayes or treat settings with the estimated prior.

```template methods
Differential expression was assessed with limma (v{package_version}) and edgeR (v{edger_version}) on {n_samples} RNA-seq samples using the {interface_label}. {filter_sentence} {norm_sentence} The design was {design}; {target} (n = {n_target}) was compared with {reference} (n = {n_reference}). {voom_sentence} {weights_sentence} {moderation_sentence} P values were adjusted with the Benjamini-Hochberg method and the reporting cutoff was an adjusted P value below {alpha}. {display}
```

```template results
Of {n_tested} genes tested, {n_sig} had adjusted P < {alpha}; {n_up} were higher and {n_down} lower in {target}.
```
