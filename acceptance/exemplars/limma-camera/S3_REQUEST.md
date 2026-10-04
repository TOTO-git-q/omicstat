# limma-camera — independent S3 request

## Review scope

Run `skills/limma-camera/tests/run_smoke_test.R` and `tools/make_module_lock.R limma-camera --check` in `omicstat-r:2026.09.1`. Check the question-first single-method route, exact ranked-list type, expression/weight/sample alignment, explicit limma arguments and locked defaults, 0.01 camera correlation as a preset, roast/mroast 9999 publication rotations and seed/RNG/midp recording, offline collection hash, method-specific raw table, typed errors, handoff, golden, QC and figure. S3 review must be independent; S2 does not accept itself.

## Anchors and outputs

- Source: locked limma 3.68.5 User's Guide §18.1.10 and PACK C; F10 `limma_Yoruba.RData` SHA-256 `62abb9669bf545e70bfa4abf3a8e99a86d49f35b8bd0ef7801deb8db0486a01b`; F11 `limma_GenderGenes.RData` SHA-256 `ad2e78f108281864be9a9fdc2b686068f24b785158bc8782ac03d510938ea493`; registered canonical set hash `3e712f5538b2b79b9d950f38ea9e397802f587747f83ff2f9340aaaf7af59cdd`. The fixture rebuilds guide preprocessing from 86 printed Targets rows, retaining 16,918 genes, and applies voom weights and a gender plus concentration design.
- **Guide printed camera anchor differs from direct locked-container replay.** Guide: Y 13 Up, P=2.40e-262, FDR=4.80e-262; X 54 Down, P=5.58e-26. Locked-container direct and engine replay: Y 13 Up, P=1.79122449658387e-262, FDR=3.58244899316775e-262; X 54 Down, P=6.02018304198957e-26. The printed-value camera anchor is **not passed**. Please determine whether preprocessing, printed-guide provenance, or locked release behaviour accounts for the difference before S3 acceptance. No estimator was changed to force agreement.
- Guide mroast 9999 anchor **passes**: Y 13 Up and X 54 Down, both P=1e-04 with seed 20260925. fry, roast and cameraPR are smoke-tested as separate prespecified routes; those route values are replay checks, not printed guide anchors.
- Final S2 smoke: `/home/<user>/omic-build-logs/build_m2b/limma_final_smoke.log` (26 PASS, 0 FAIL, SMOKE PASSED); output `/home/<user>/omic-build-logs/build_m2b/limma-camera-smoke/a1/`; golden checks full primary/raw tables, result JSON, PNG and figure spec bytewise in the same container signature. The PNG was visually reviewed for clipping and overlap; figure lint has only informational FIG-03 grayscale proximity.

## Owner items and limitations

- Resolve the camera printed-anchor discrepancy above. Until resolved, treat numerical interpretation against the guide as provisional.
- The default `msigdb_collections` Hallmark asset has no locked offline hash and raises `OS_REFDATA_MISSING`; the Yoruba GenderGenes collection is an acceptance fixture, not the intended Hallmark publication collection.
- The parent `deseq2-wald` on this branch does not write the frozen `ranked_list` handoff. Coordinator must integrate a conforming producer before the cross-module route is available.
- Self-contained fry/roast/mroast requires a method named before analysis. A within-block correlation must be supplied along with the block column; this module does not silently estimate it. `nrot=1999` is a flagged development-only signature.
- Add separate router evaluation controls: a context-verified “camera” microscopy sentence and a “FRY” gene-symbol sentence as two negative cases; add a limma cameraPR sentence as a positive case. Keep these controls separate from the 29/30 applicable literature frequency corpus (PACK S1 P-3).

## Proposed router row

| competitive gene-set test, limma camera, cameraPR ranked statistic, self-contained fry roast mroast, 竞争性基因集检验 | `limma-camera` | `scripts/run_limma_camera.R` |

## Proposed module_rules_v1.json record

```json
{
  "module": "limma-camera",
  "rule_id": "PUB-M-CAMERA-001",
  "category": "design_conditional",
  "severity": "hard_error",
  "reporting_guidelines": ["Name the prespecified competitive or self-contained question, one limma method, version, input object, design/contrast or ranked-statistic direction, collection species/version/hash, retained set sizes, BH threshold, and camera correlation preset or roast rotation seed/RNG/nrot/midp."],
  "effect_table_policy": {"primary_metrics": ["pvalue", "padj", "direction", "n_genes"], "allow_no_effect_table": true, "requirements": ["Report the unfiltered gene-set table and preserve the raw method columns; these are set-test values, not gene-level effects."]},
  "artifact_aliases": {"tables/gene_set_table.csv": "primary_table", "tables/method_raw.csv": "method_raw", "results/*.json": "machine"},
  "artifact_expectations": ["gene-set table", "raw method table", "adjusted-P set figure", "QC", "provenance", "methods draft"],
  "required_diagnostics": ["LC-01..LC-05", "set ID overlap and retained/excluded counts", "camera preset correlation or rotation settings"],
  "narrative_points": ["camera/cameraPR test a competitive null; fry/roast/mroast test a self-contained null.", "The camera inter-gene correlation 0.01 is prespecified, not estimated.", "1999 rotations is development-only; mroast BH uses mid-p."],
  "causal_language": {"forbidden": ["The tested set causes the phenotype based only on a gene-set P value"], "restricted_to": ["enrichment or gene-set association in the declared contrast"]}
}
```
