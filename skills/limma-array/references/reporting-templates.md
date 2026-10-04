# limma-array report templates

Every sentence slot is filled from the actual run (S3 F2): control removal
(file or declaration), the above-background rule with its k and pass count,
technical-ID averaging with probe and feature counts, the design levels,
trend/robust and where they came from, the probe annotation, and the input
preprocessing exactly as declared with `--preprocessing` ("not stated"
otherwise; the module never infers it).

```template methods
Differential expression was assessed with limma (v{package_version}) on {n_samples} normalized log2 microarrays ({platform_label}). {preprocessing_sentence} {control_sentence} {background_sentence} {retained_sentence} {averaging_sentence} {design_sentence} {target} (n = {n_target}) was compared with {reference} (n = {n_reference}). The test was {test}; {moderation_sentence} P values were adjusted with Benjamini-Hochberg and the reporting cutoff was {alpha}. {annotation_sentence} {display}
```

```template results
Of {n_tested} features tested, {n_sig} had adjusted P < {alpha}: {n_up} were higher and {n_down} lower in {target}, and {n_notsig} were not significant (Down / NotSig / Up in tables/direction_summary.csv).
```
