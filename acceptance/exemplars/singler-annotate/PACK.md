# PACK — singler-annotate

S0 evidence pack; S1 choices below are drafts. This version is the redo after the independent verification of 2026-09-29 (`docs/build/S0_REDO_lane_b.md`); `verification.json` is written by the verifier, not this lane.

| Layer | Evidence |
|---|---|
| L1 | SingleR **2.14.2** and celldex **1.22.0**, Bioconductor `RELEASE_3_23`: Rd, function defaults, rendered vignettes, source vignettes, NEWS where supplied, CITATION, sha256 manifest in `L1_bioc3.23/`. Source git commits are recorded in the manifest. celldex supplies no NEWS file on that branch. |
| L2 | Three official SingleRBook 3.23 chapters, URL and page sha256 pinned in `L2/manifest.tsv` (single-cell references, annotation diagnostics, advanced options). |
| L3 | 10 tier-A close readings, of which 9 use the pinned R-package analysis part (`literature/l3_notes.md`). |
| L4 | 30 licensed, full-text, whitelisted, PubMed-echoed articles; 29 applicable (`literature/corpus.jsonl`, `extraction.jsonl`, `efetch/`). The excluded article specifies a Python SingleR implementation. |

## T — table skeleton

Draft annotation table: cell identifier, input cluster, assigned label, pruned label (NA when uncertain), best and runner-up scores, delta, reference identity/version, and source assay/layer. Keep the full per-label score matrix as a companion artifact. The L3 Methods do not establish a shared published table column order or Top-N truncation convention; these columns follow the locked SingleR result and its vignette rather than an invented journal consensus.

## F — figure grammar

`plotScoreHeatmap` in the locked vignette puts reference labels on rows and cells on columns; score colour shows relative assignment confidence. Pair it with a cluster-by-label contingency heatmap and a UMAP coloured by pruned label, with unassigned cells visibly separate. The vignette also uses the delta distribution to diagnose ambiguous labels. These are draft engine graphics from L1; the 10 L3 Methods excerpts do not establish one common plot palette or cutoff line.

## W — wording

Methods template: “Cells were annotated with SingleR (v2.14.2) against <named reference and version>, using <test assay/layer> and <cell/cluster unit>; `de.method`, fine tuning, and pruning settings were <explicit values>. Ambiguous assignments were reported as unassigned.” Results template: “Of <N> input cells, <N> retained a pruned label; the cross-tabulation against source clusters and score diagnostics are shown.” The placeholders must be filled from the run, never from an exemplar's unreported settings. L3 papers commonly name SingleR and a reference but omit tuning arguments; see `l3_notes.md`.

## V — variant frequencies

Redo after independent verification (2026-09-29): the whole corpus was re-read and references, marker settings, versions and labels re-extracted; counts below are recomputed from `extraction.jsonl` per ecosystem.

Denominator: **29 applicable / 30 corpus**. Each article has one front-end ecosystem in `extraction.jsonl`: Seurat **21/29**, Bioconductor **4/29**, mixed **4/29**, scverse **0/29**. The one scverse-labelled paper (PMC13581597) uses a Python SingleR implementation and is excluded from the 29. PMC12700527 (41384492) was relabelled mixed (Scanpy front end, SingleR in R). "Not reported" means absent from the accessible Methods, not a default value.

| Parameter | Seurat (n=21) | Bioconductor (n=4) | Mixed (n=4) | scverse (n=0) |
|---|---|---|---|---|
| Reference stated | 14/21; ImmGen family 6 (incl. one Blueprint/ENCODE + ImmGen paper); HPCA/ENCODE 2; other 6 (Muto kidney data, tumour-infiltrating immune atlas, mouse references + ZilionisLungData, HCA data set, in-house + Blueprint/ENCODE, `celldex` only) | 4/4; MouseRNAseqData, Monaco, HPCA, human embryoid body data | 4/4; Monaco + others, HPCA + ENCODE, MouseRNAseqData + Tabula Muris intestine, "sorted immune subsets" | - |
| Annotation unit | cluster 5, per cell 2, per-cell labels with a cluster rule 1, not reported 13 | not reported 4/4 | per cell 1, not reported 3 | - |
| Test assay | raw counts 1/21 | 0/4 | 0/4 | - |
| Reference assay | log-scale normalised counts 1/21 | 0/4 | 0/4 | - |
| Reference label column | `main.label` 1/21 | 0/4 | 0/4 | - |
| Marker detection (`de.method` and `de.n`) | Wilcoxon markers, 50 genes, 1/21 (one study) | 0/4 | 0/4 | - |
| Pruned scores mentioned | 1/21 | 0/4 | 1/4 | - |
| Version reported | 8/21 (1.0.6 x3, 1.4.1, 1.6.1, 1.8.1, 1.14.1, 3.11) | 2/4 (1.4.1, 1.8.1) | 2/4 (1.2.4 x2) | - |
| celldex package version | 0/21 | 1/4 (v1.2.0) | 0/4 | - |
| Fine-tuning, prune MAD threshold and all other profiled options | not reported 21/21 | not reported 4/4 | not reported 4/4 | - |

Across all 29, 12 name a SingleR version in the Methods; 17 do not. The `3.11` version string in one paper is kept exactly as reported, although it is inconsistent with the R package's release series and must not be used as a pin. Among the eight Seurat-front-end papers that state the unit, cluster-level is the most common (5 vs 2 per cell vs 1 hybrid), but 13 of 21 omit it. The ImmGen family is the most common reference (6/29 overall) but is not a majority. Wilcoxon marker detection with 50 genes per comparison is one paper's setting (1/29). No value has an overall majority (> half of 29), so literature alone defines no default for these arguments.

## C — replay and printed anchors

`acceptance/data/ANCHOR_REGISTRY.md` #25: Muraro pancreas reference (EH2692–2693; F23–F24) against Grun pancreas test counts (EH2687; F22). All three files were downloaded and passed the sha256 checks in `fetch_anchor_data.sh` (`hub` group). The SingleR 2.14.2 rendered vignette uses `scrapper::normalizeRnaCounts.se`, excludes unlabelled reference libraries and zero-count test libraries, then calls `SingleR(test=sceG, ref=sceM, labels=sceM$label, de.method="wilcox")`. It prints 1,718 labels: acinar 723, alpha 228, beta 232, delta 65, duct 344, endothelial 15, epsilon 2, mesenchymal 69, pp 36, unclear 4; `summary(is.na(pred.grun$pruned.labels))` prints FALSE 1659 and TRUE 59. These are the hard assertions for the exact vignette recipe, not tolerances. The celldex built-in reference is a separately pinned reference-data input, not this anchor.

## D — function default / official guidance / exemplar evidence

Defaults are read from `L1_bioc3.23/SingleR/defaults.tsv` and `L1_bioc3.23/celldex/defaults.tsv`. “No recommendation” means the locked vignette/guide does not prescribe a general value; an example is identified explicitly. Exemplar counts refer to applicable articles only, with ecosystem split in V.

| Parameter (profile id) | Function default, locked version | Vignette / guide recommendation | Exemplar evidence | S1 draft |
|---|---|---|---|---|
| Reference (D-SR1) | `ref` required | Choose a relevant labelled reference; celldex guide lists dated releases | 22/29 state a reference; ImmGen family 6/29 (Seurat 6), HPCA 4/29 (Seurat 2, Bioconductor 1, mixed 1; two pair it with ENCODE), others one each | Require identity, version and species; no universal atlas preset |
| Label vector (D-SR2) | `labels` required | Use reference labels; Muraro example uses `sceM$label` | 1/29 names the `main.label` column (Seurat) | Explicit reference label column |
| Unit (D-SR3) | `clusters=NULL` means per cell | Muraro example is per cell; cluster mode is documented | cluster 5/29 (Seurat); per cell 3/29 (Seurat 2, mixed 1); per-cell labels with a cluster rule 1/29; 20 not reported | Expose per-cell and per-cluster explicitly; decide S1 default |
| Test assay (D-SR4) | `assay.type.test="logcounts"` | Vignette says test need not be log transformed for ranking; normalizes for heatmap | raw counts 1/29 (Seurat); 28 not reported | Explicit input layer, validate ranks and heatmap requirements |
| Marker method (D-SR5) | `de.method="classic"` | `"wilcox"` advised in the single-cell Muraro example | 1/29 (Seurat; Wilcoxon markers, `de.n` 50 = 50 genes per comparison); 28 not reported | S1 decide `"wilcox"` for single-cell reference |
| Fine tuning (D-SR6) | `fine.tune=TRUE` | No general override | 0/29 | Keep explicit TRUE provisionally |
| Pruning (D-SR7, D-SR17) | `prune=TRUE` | Inspect `pruned.labels`; unassigned entries are NA | pruned scores mentioned 2/29; numeric options absent | Explicit TRUE, retain raw and pruned labels |
| Prune MADs (D-SR8) | `pruneScores(nmads=3)` | Outlier-based delta threshold; no fixed score cutoff | 0/29 | Explicit 3, subject to S1 |
| `method` (D-SR9) | NULL | No recommendation | 0/29 | Explicit locked default if used |
| `genes` (D-SR10) | `"de"` | Marker selection is important for the reference | 0/29 | Explicit `"de"` |
| `sd.thresh` (D-SR11) | 1 | No recommendation | 0/29 | Explicit 1 when classic markers used |
| `de.n` (D-SR12) | NULL | No recommendation | 1/29 (50; same Seurat study as `de.method`) | Explicit NULL |
| `aggr.ref` (D-SR13) | FALSE | NEWS 2.14.0 suggests TRUE for large single-cell references | 0/29 | S1 decide size-dependent option |
| `restrict` (D-SR14) | NULL | No recommendation | 0/29 | Explicit NULL |
| `quantile` (D-SR15) | 0.8 | No recommendation | 0/29 | Explicit 0.8 |
| `tune.thresh` (D-SR16) | 0.05 | No recommendation | 0/29 | Explicit 0.05 |
| Reference assay (D-SR18) | `assay.type.ref="logcounts"` | Reference should be normalized and log transformed | 1/29 (log-scale normalised reference counts; Seurat) | Explicit logcounts; confirm assay exists |
| Missing test check (D-SR19) | FALSE | NEWS says default avoids unnecessary check | 0/29 | Explicit FALSE |
| Missing reference check (D-SR20) | `check.missing` (=TRUE) | No override | 0/29 | Explicit TRUE |
| `min.diff.med` (D-SR21) | `-Inf` | No recommendation | 0/29 | Explicit `-Inf`; this is a pruning bound, not a numerical tolerance |
| `min.diff.next` (D-SR22) | 0 | No recommendation | 0/29 | Explicit 0 |
| Score heatmap normalization (D-SR23) | TRUE | Vignette calls `plotScoreHeatmap` for diagnostics | 0/29 | Explicit TRUE |
| Show pruned label on heatmap (D-SR24) | FALSE | Vignette plots scores and separately reports pruning | 0/29 | Expose option, retain raw score view |
| celldex reference version (D-SR25) | `fetchReference(version)` required | Guide examples use dated `2024-02-26` releases | 0/29 gives a `fetchReference` version; 1/29 gives the celldex package version (v1.2.0) only | Pin chosen reference data by name, date and sha256 |

The profile's X row is package version reporting, not a function argument. Figure-only arguments not selected above remain an S1 display-spec decision and must be explicit in the engine call registry if they affect the rendered figure.

## X — version-sensitive items

- SingleR 2.14.2 fixes `SingleR()` ignoring a non-default `assay.type.ref`; older runs may have used another reference assay despite their call.
- SingleR 2.14.0 adds `hint.sce` and recommends considering `de.method` and aggregation for single-cell references. It also adopts sparse matrix support from singlepp and soft-deprecates `BNPARAM`.
- SingleR 2.10.0 changes Wilcoxon/t-test marker implementation to scrapper; SingleR 2.8.0 changes marker tie handling, which can change classification at tied cutoffs. These items come from the locked NEWS and warrant container-level goldens.
- celldex 1.22.0 has a rendered guide and CITATION but no NEWS file in its locked source branch. A named reference's data release must be pinned separately from the package version.

## S1 drafts and pending decisions

1. Choose the default labeling unit. The reported Seurat cases more often use clusters (5/8 reporting, with 2 per cell and 1 hybrid), while the official Muraro example uses per-cell assignment. Preserve both modes and record the choice; neither 5/21 nor 3/29 is an overall majority.
2. Decide whether the single-cell-reference preset should use `de.method="wilcox"` (vignette recommendation) instead of the function's `"classic"`; do not infer this setting from papers' separate Wilcoxon DE tests.
3. Decide reference selection and whether large single-cell references set `aggr.ref=TRUE`. Require reference name/version/species and a pinned file hash.
4. Review per-cell confidence display and pruning: retain both raw and pruned labels and show the number unassigned. Do not treat `nmads` or `min.diff.*` as numeric tolerances.
