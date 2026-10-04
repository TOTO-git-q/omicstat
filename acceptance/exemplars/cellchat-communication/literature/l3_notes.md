# CellChat communication: L3 close-reading notes

Nine tier-A papers run CellChat communication analysis and are applicable. The tenth tier-A article, PMC7889871, is the original CellChat method/development paper and is pinned as L2 instead of being counted as an independent application exemplar. Exact Methods fragments, each at most 25 words, are in `extraction.jsonl`. Revised in the redo of 2026-09-29 after the verifier found the version, minimum-cell rule and group definition of PMC11631771 and the database of PMC9729309 unextracted; the whole corpus was rescanned for version, database, estimator and trim statements.

## PMC12826670 — testicular interstitium

This Seurat-front-end study names CellChat 1.1.2 and analyzes interactions among mouse testis cell populations. It describes CellChat functions and visual signaling outputs, but does not give a `computeCommunProb(type=)` value or bootstrap count. Those settings remain not reported.

## PMC8660823 — GSDMD and virus packaging

The Seurat-front-end Methods report CellChat 1.1.0 and visualize aggregate communication networks by both interaction count and total strength. The circle plot is a display choice. No exact average-expression estimator or LR subset is stated.

## PMC13510688 — myocarditis immune niche

The Methods contain two related analyses. The spatial murine T-cell niche analysis explicitly gives `computeCommunProb(type="truncatedMean", trim=0.1, distance.use=TRUE, interaction.range=250, scale.distance=4.5, contact.dependent=TRUE, contact.range=15)` with distances stated in μm. The patient single-cell analysis names CellChat 2.1.2 and a truncated-mean method, but does not provide the same full spatial parameter set. The extraction notes this scope; the spatial values must not become defaults for dissociated single-cell data.

## PMC13042276 — neuroimmune corneal response

The Seurat-front-end study uses CellChat v2 communication probability analysis to study sensory neurons and immune cells. It does not provide a precise version beyond v2, estimator, seed, or permutation count. Generic significance thresholds elsewhere in Methods belong to other experiments.

## PMC8799469 — COVID-19 neutrophil states

The Seurat-front-end Methods name CellChat 1.0.0 alongside Connectome, and compute interaction count and strength with `compareInteractions`. The tools' results are not interchangeable; no CellChat inference parameters are stated.

## PMC10783873 — actinic keratosis progression

The Seurat-front-end study compares CellChat outgoing interaction strengths between stages and explicitly calls P < 0.1 significant for that comparison. This is one study's comparison criterion, not the locked `aggregateNet(thresh)` default.

## PMC11631771 — Alzheimer disease and trisomy 21

The workflow spans AnnData, Seurat and SingleCellExperiment, so its front end is mixed. CellChat v1.1.3 is run with the human CellChatDB on the normalized expression matrix and cell-type annotations combined with CellTrek-predicted spatial regions; cell groups with fewer than 30 cells were removed when the object was created, before the ordered overexpression/inference/filter/pathway/aggregation/centrality calls, which are listed without arguments; separate disease-status objects are merged. The 30-cell rule is therefore recorded as a pre-filter, not as an explicit `filterCommunication(min.cells=30)` call.

## PMC10709603 — acral melanoma

The Seurat-front-end study imports a normalized matrix, then names the CellChat preprocessing, probability, filtering, pathway and aggregation steps. It says default parameters without listing their historical values. The extraction records only the named calls and version 1.1.3.

## PMC9705540 — developing bone

The Seurat-front-end study passes the RNA assay's normalized `data` slot and cell-cluster identities to CellChat, uses CellChatDB.mouse, projects expression onto a PPI and performs inference, pathway aggregation and centrality. Its Bonferroni P < 0.05 in the overexpression-gene step is not the communication probability cutoff.

## Corpus caveats

PMC10688969 mentions the CellChat LR database without a CellChat software inference and is inapplicable. PMC8421219 (CellCall) runs CellChat as one of four comparator tools with their own default parameters on a human testicular scRNA-seq dataset, using the 1,141 L-R interactions embedded in CellCall for all comparators; it is applicable to the analysis part but gives no explicit locked-version settings and no upstream front end, so its ecosystem label is n/a. PMC8626557's JATS represents version 1.1.1 followed by superscript bibliography reference 40; flattened text reads 1.1.140. The extracted version is XML-corrected. No article's unqualified “default parameters” is expanded into parameter values.

Outside L3, the rescan found CellChat versions written only as "v2" in PMC13463609 and PMC13042276, a truncated mean of 10% with a normalized count matrix and cell annotation metadata in PMC9839452, the database sentence of PMC10783873, and a manually added HGF axis in the zebrafish analysis of PMC13574154; these are recorded or noted in `extraction.jsonl`.
