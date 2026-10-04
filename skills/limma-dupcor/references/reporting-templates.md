# limma-dupcor report templates

Every slot is filled from the actual run (S4, S3 F2): versions, input preparation (RNA:
the filterByExpr thresholds actually used and the TMM factors; arrays: the user-supplied
normalised matrix), both voom -> duplicateCorrelation rounds with their spans and consensus
correlations (RNA), the block definition with unit counts and sizes, trim, and the eBayes
or treat settings with their source and the estimated prior.

```template methods
Differential expression was assessed with limma (v{package_version}){edger_sentence} on {n_samples} {data_kind} samples, testing {n_tested} of {n_input} features. {input_sentence} The design was {design}; {target} (n = {n_target}) was compared with {reference} (n = {n_reference}). {block_sentence} {chain_sentence} {moderation_sentence} P values were adjusted with the Benjamini-Hochberg method and the reporting cutoff was an adjusted P value below {alpha}. {display}
```

```template results
Of {n_tested} features tested, {n_sig} had adjusted P < {alpha}; {n_up} were higher and {n_down} lower in {target}. The consensus intra-unit correlation was {consensus_value} across {n_blocks} units.
```
