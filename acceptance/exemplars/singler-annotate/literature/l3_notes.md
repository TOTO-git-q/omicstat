# SingleR annotation: L3 close-reading notes

These notes concern the ten tier-A articles marked `L3+L4` in `corpus.jsonl`. They were revised in the redo of 2026-09-29 (the verifier listed missing references, a missing marker-detection setting, one non-verbatim snippet and one wrong ecosystem label; the whole corpus was re-read). They summarize the accessible Methods regions retrieved with `collect.py methods`; exact, short evidence fragments and section paths are in `extraction.jsonl`. A method absent from those regions is recorded as not reported, even if it might appear in supplementary files. The counts in PACK V use only the applicable articles.

## PMC10735226 — glioblastoma regional immune cells

The Methods describe SingleR as a Bioconductor annotation tool and compare more than one immune reference, including Monaco data through celldex. The author uses pruned assignments as a quality filter alongside manual marker checks. SingleR's marker detection settings and numeric pruning threshold are not given. The front end includes Seurat and Bioconductor functions, so the ecosystem is mixed.

## PMC8672480 — splatPop simulation

The reference-data section says SingleR v1.4.1 annotated mouse cells against MouseRNAseqData from celldex v1.2.0 (a package version, not a reference release date). This is a supporting annotation step for a simulation study, not evidence that its later Wilcoxon differential expression test was a SingleR setting. The front end uses scater; the SingleR invocation does not state an assay selector or pruning rule.

## PMC13495209 — cross-platform deconvolution benchmark

The authors label simulated single-cell source data with SingleR using MonacoImmuneDataset from celldex as reference. The Methods also mention scran. Raw-count aggregation in the pseudo-bulk construction is a separate step and does not determine `assay.type.test` for SingleR. No fine-tuning or pruning parameter is specified.

## PMC13581597 — patient-derived cancer model compendium

The paper explicitly says it used a Python implementation of SingleR with Blueprint-ENCODE. This is useful context for cross-ecosystem adoption, but it does not run the pinned R package; `_applies = no`, and it is excluded from the parameter denominator. The surrounding single-cell work is scverse.

## PMC7426428 — abdominal adhesion fibrosis

The Methods report SingleR annotation against human Blueprint/ENCODE and mouse references. Seurat is used earlier for data preparation. A `3.11` version string is printed near SingleR in the Methods; it is preserved as reported, without assuming that it matches the R package's release numbering. The annotation call's marker and pruning settings are not reported.

## PMC8630108 — refractory myeloma

Seurat is used for clustering and integration, and SingleR corroborates manual cell labels using the Human Cell Atlas (HCA) data set and its cell type labels as reference, after downsampling to at most 1000 cells per cell type. The paper treats the automated labels as support for interpretation rather than a substitute for marker review. It gives no explicit SingleR scoring, fine-tuning, or pruning arguments.

## PMC7439502 — idiopathic pulmonary fibrosis

The Methods compare manual labels with SingleR classifications using both the Human Primary Cell Atlas (HPCA) and ENCODE human reference sets. Seurat 2.3.1 does the Louvain clustering while Scanpy 1.3.7 is used for UMAP, cell-network analysis and regressing out cell-cycle terms, so the ecosystem stays mixed (a borderline case: Scanpy could be read as downstream only). The Methods do not tie the reported Wilcoxon tests or any numerical threshold to SingleR's own arguments.

## PMC10593820 — checkpoint inhibitor colitis

The authors describe cluster-level SingleR annotation against ImmGen after a Seurat integration workflow. That explicit unit matters because treating every cell independently would be a different setting. The Methods do not specify the marker test, fine-tuning cutoff, or pruning threshold.

## PMC8566524 — longitudinal myeloma mouse model

SingleR v1.0.6 is run with ref=immgen while Seurat is the front end; labels come from the `main.label` category of the reference, and clusters are called B_PC lineage when more than 50% of their cells carry a B or pro-B label, so the unit is per-cell labels aggregated by a cluster rule. The Methods give no direct evidence for the test assay selector. Nearby raw-count and log-normalization descriptions belong to upstream processing and are not assigned to `assay.type.test`.

## PMC11535242 — mucosal innate lymphoid cells

The authors report cluster-level SingleR (v1.0.6) annotation with ImmGen after Seurat processing, using default parameter settings. The separate statement about pruned labels lacks an explicit `pruneScores` call or numeric threshold; the extraction records the observed pruning mention only. As in the other cluster-level paper, the labeling unit is explicit but most SingleR tuning arguments are not.

## Outside L3

The rest of the corpus was re-read in the same redo. The only paper that states a marker-detection setting is PMC10680277 (38008725): labels are predicted per cell against the single-cell tumour-infiltrating immune cell atlas (log-normalised reference counts, raw test counts) with the Spearman correlation over 50 marker genes per reference identified by the Wilcoxon rank sum test, SingleR 1.14.1; this is one study's choice and not a package default. Versions missed earlier were 1.6.1 (PMC10848745), 1.8.1 (PMC10577904) and 1.2.4 (PMC9433106). PMC12700527 (41384492) runs Scanpy for QC, normalisation and Leiden clustering and SingleR (R) for provisional annotation (first cell-wise, later per compartment with cluster information), so its ecosystem is mixed and no applicable article has a scverse front end.
