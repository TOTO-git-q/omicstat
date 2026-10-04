# Anchor dataset registry (PACK section C)

Brief: `docs/build/VENDOR_INTEGRATION_BRIEF.md` §4. One anchor per planned module
(ENGINEERING_PLAN §1.2, 33 modules), chosen in this order: data shipped with the
package's own vignette / user's guide -> data of the official workflow or book
(rnaseqGene, RNAseq123, OSCA, Seurat tutorials, clusterProfiler book, ...) -> other
public data. Compiled 2026-09-27 from the vignettes installed in
`/opt/mm/env/omicstat-dev` (R 4.5.3, Bioconductor 3.22), the package sources, and the
edgeR / limma user's guides (PDF in `doc/`). Resume notes: `worklog-anchors.md`.

- Files marked `F<n>` are downloaded and sha256-checked by `fetch_anchor_data.sh`
  (git-ignored; every hash computed from a real download on 2026-09-27; total ~282 MB).
- GEO / ArrayExpress metadata were looked up with the vendored clients
  (`geo_meta.fetch_series`, `arrayexpress_experiments.fetch_experiment` /
  `get_experiment_files`, no contact e-mail sent). ExperimentHub ids and paths come from
  `experimenthub.sqlite3` (downloaded 2026-09-27, sha256 `6b9f7759...ac0c`); files are
  fetched straight from `https://mghp.osn.xsede.org/bir190004-bucket01/ExperimentHub/<rdatapath>`
  so the smoke tests stay offline (no hub cache needed).
- "Printed" = the value is printed in the package's document (first-choice anchor);
  "replay" = the document's own code, run in the test session, must equal the engine
  (MODULE_BUILD_BRIEF §2.4). Only the printed values quoted here were read in this
  session; all others are for the module builder to read at S0.
- Licence column: what the source states. "not stated" = no licence found in the
  record; package licences are from the package DESCRIPTION / Bioconductor PACKAGES and
  cover the package, not necessarily the underlying data.

## 1. Per-module anchors

| # | Module | Anchor dataset | Kind | Accession | Source / object | Size | Used by | Licence / terms |
|---|---|---|---|---|---|---|---|---|
| 1 | deseq2-qc | pasilla (7 samples, `pasilla_gene_counts.tsv` + `pasilla_sample_annotation.csv`) | package-embedded | -- (not stated in the pasilla Rd) | `system.file("extdata", package="pasilla")`; `vst`, sample distances, `plotPCA` on the vignette's `dds` | small | DESeq2 vignette "Count matrix input", "Data transformations and visualization" (`vsd <- vst(dds, blind=FALSE)`, `plotPCA(vsd, intgroup=c("condition","type"))`) -- replay | pasilla: LGPL |
| 1b | deseq2-qc (alt.) | airway (8 samples, RangedSummarizedExperiment 63677 x 8) | package-embedded | GEO GSE52778 (16 samples, *Homo sapiens*) | `data(airway, package="airway")` | small | rnaseqGene workflow | airway: LGPL |
| 2 | deseq2-wald | pasilla | package-embedded | -- | as #1; `skills/deseq2-wald/tests/fixtures/make_pasilla.R` | small | DESeq2 vignette -- printed (PACK C, A1-A3) | LGPL |
| 3 | deseq2-lrt | fission (fission yeast time course) | package-embedded, **package not installed** (Bioc 3.22 data pkg `fission` 1.30.0) | -- | `fission` package data | -- | rnaseqGene workflow "Time course experiments". The DESeq2 vignette's LRT chunks are `eval=FALSE`; fallback = replay on pasilla (`~ type + condition` vs `reduced = ~ type`) | fission: LGPL |
| 4 | edger-qlf | Mouse mammary gland, 6 groups x 2 (GSE60450) | GEO | GSE60450 (*Mus musculus*, 12 samples, GPL13112, PMID 25730472) | **F3** `GSE60450_Lactation-GenewiseCounts.txt.gz` (27179 x 14 incl. EntrezGeneID, Length) | 0.5 MB | edgeR User's Guide case study 4.4 "RNA-Seq profiles of mouse mammary gland"; edgeR QL workflow | GEO: not stated |
| 5 | limma-voom | Mouse mammary stem / progenitor / mature populations (GSE63310) | GEO | GSE63310 (*Mus musculus*, 11 samples, GPL13112, PMID 25879659) | **F4** `GSE63310_RAW.tar` (11 `GSM15455xx_*.txt.gz` count files) | 2.0 MB | RNAseq123 workflow | GEO: not stated |
| 6 | limma-array | Corn-oil gavage, rat thymus, Agilent 8x60K one-colour (4 groups) | GEO + ArrayExpress | GSE33005 = E-GEOD-33005 (*Rattus norvegicus*, 19 arrays, GPL14746, PMID 22760963) | **F5** `GSE33005_RAW.tar` (19 raw Agilent files) + **F6** `E-GEOD-33005.sdrf.txt` (targets) | 42.8 MB | limma User's Guide case study 17.4 (read.maimages / normexp / normalizeBetweenArrays belong in the fixture script; the module receives the normalized matrix) | not stated |
| 7 | limma-dupcor | Mammary progenitor populations, Illumina BeadChip, 4 cell types x 3 donors | WEHI files (data in GEO GSE16997) | GSE16997 | **F7-F9** `limma_IlluminaCaseStudy_{probe_profile,control_probe_profile}.txt.gz`, `..._Targets.txt` | 9.6 MB | limma User's Guide 17.3 "Within-patient correlations": printed `dupcor$consensus.correlation` = 0.134 (`block = targets$Donor`) | not stated |
| 7b | limma-dupcor (RNA-seq, voom + block) | Yoruba HapMap LCLs, 86 libraries of 69 individuals (DGEList `y`, 25702 x 86) | WEHI file | -- | **F10** `limma_Yoruba.RData` | 3.4 MB | limma User's Guide 18.1: printed `cor$consensus` = 0.446 (`block = Targets$cellline`) | not stated |
| 8 | sva-batch | bladderbatch (`bladderEset`, bladder cancer arrays with batch) | package-embedded, **package not installed** (Bioc 3.22 `bladderbatch` 1.48.0) | -- | `data(bladderdata, package="bladderbatch")` -> `bladderEset` | -- | sva vignette (`ComBat`, `sva`); the vignette's `ComBat_seq` section uses a simulated count matrix (replay); `svaseq` section uses `zebrafishRNASeq::zfGenes` (also not installed) | bladderbatch: Artistic-2.0; zebrafishRNASeq: GPL |
| 9 | clusterprofiler-ora | DOSE `geneList` (12495 ranked Entrez ids; the ORA gene list is a cut of it) | package-embedded | -- | `data(geneList, package="DOSE")`; GO via `org.Hs.eg.db` 3.22.0 / `GO.db` 3.22.0 (refdata) | small | clusterProfiler book (the installed vignette points to it) | DOSE: Artistic-2.0 |
| 10 | clusterprofiler-gsea | DOSE `geneList` | package-embedded | -- | as #9 (`gseGO`) | small | clusterProfiler book | Artistic-2.0 |
| 11 | clusterprofiler-compare | clusterProfiler `gcSample` (8 gene clusters) | package-embedded | -- | `data(gcSample, package="clusterProfiler")` | small | clusterProfiler book (`compareCluster`) | Artistic-2.0 |
| 12 | fgsea-prerank | fgsea `examplePathways` (1457 pathways) + `exampleRanks` (12000 genes); file variant `naive.vs.th1.rnk` + `mouse.reactome.gmt` | package-embedded | -- | `data(examplePathways)`, `data(exampleRanks)`; `system.file("extdata", ..., package="fgsea")` | small | fgsea tutorial vignette | fgsea: MIT |
| 13 | gsva-score | GSVAdata (`c2BroadSets`, `commonPickrellHuang`, `genderGenesEntrez`, `gbm_VerhaakEtAl`, `brainTxDbSets`, `geneprotExpCostaEtAl2021`) | package-embedded, **package not installed** (Bioc 3.22 `GSVAdata` 1.46.0) | -- | `data(..., package="GSVAdata")`; GSVA ships only the cached result `extdata/cache4vignette_leukemia_es.RData` | -- | GSVA vignette. Installed alternative: `GSVA_scRNAseq` vignette runs on TENxPBMCData "pbmc4k" = **F2** (10x pbmc4k) | GSVAdata: Artistic-2.0 |
| 14 | limma-camera | Yoruba HapMap (`y`) + gender gene sets (`msYgenes` 34, `XiEgenes` 66) | WEHI files | -- | **F10** `limma_Yoruba.RData` + **F11** `limma_GenderGenes.RData` | 3.4 MB | limma User's Guide 18.1.10: printed `camera(v,index,design,2)`: Y 13 Up PValue 2.40e-262; X 54 Down 5.58e-26 | not stated |
| 14b | limma-camera (alt.) | GSE63310 + mouse MSigDB C2 | GEO | GSE63310 | **F4**; gene sets via `msigdbr` (refdata) | 2.0 MB | RNAseq123 workflow | GEO: not stated; MSigDB terms per refdata registry |
| 15 | seurat-qc | 10x PBMC 3k (2,700 cells) | 10x | 10x "pbmc3k" | **F1** `pbmc3k_filtered_gene_bc_matrices.tar.gz` | 7.6 MB | Seurat "Guided clustering tutorial" (`pbmc3k_tutorial.Rmd`; not installed with Seurat 5.5.1, read from the Seurat repository); fast unit fixture: `SeuratObject::pbmc_small` (230 x 80, embedded) | 10x terms: not stated in file |
| 16 | seurat-cluster | 10x PBMC 3k | 10x | pbmc3k | **F1** | 7.6 MB | Seurat guided clustering tutorial | as #15 |
| 17 | seurat-integrate | Kang et al. IFN-beta PBMC, ctrl + stim, 2 x 1000 cells (`pbmc.ctrl`, `pbmc.stim`, 9015 genes) | package-embedded | GEO GSE96583 (GSM2560248, GSM2560249) | `data("pbmc_stim", package="harmony")` | small | harmony `Seurat.Rmd` vignette. (Seurat's own `seurat5_integration.Rmd` uses SeuratData "pbmcsca" -- SeuratData is not installed and not in the container) | harmony: GPL-3 |
| 18 | seurat-markers | 10x PBMC 3k | 10x | pbmc3k | **F1** | 7.6 MB | Seurat guided clustering tutorial (`FindAllMarkers`) | as #15 |
| 19 | seurat-modulescore | 10x PBMC 3k + `cc.genes.updated.2019` (S / G2M gene lists) | 10x + package-embedded | pbmc3k | **F1**; `Seurat::cc.genes.updated.2019` | 7.6 MB | Seurat tutorials (the cell-cycle vignette's own data set is not registered) | as #15; Seurat: MIT |
| 20 | scater-qc | Zeisel brain (3005 cells x 21135 features; rowData marks the feature type) | ExperimentHub | EH2580-EH2582 (scRNAseq `ZeiselBrainData()`; GEO GSE60361) | **F17-F19** `EH258{0,1,2}_zeisel-brain_*.rds` | 19.4 MB | scuttle `qc.Rmd` / `norm.Rmd`, scater `overview.Rmd` | scRNAseq pkg: CC0 |
| 21 | scran-cluster | Grun pancreas (1728 cells, dgCMatrix 20148 x 1728) | ExperimentHub | EH2687 (scRNAseq `GrunPancreasData()`) | **F22** `EH2687_grun-pancreas_counts.rds` (colData is rebuilt from the column names by the package) | 9.2 MB | scran vignette, bluster `diagnostics.Rmd`. Candidate OSCA-book alternative: pbmc4k = **F2** (OSCA chapter data not verified in this session) | CC0 (package) |
| 22 | batchelor-integrate | Zeisel + Tasic brain (3005 + 1809 cells) | ExperimentHub | EH2580-2582 + EH2578-2579 (Zeisel = GEO GSE60361; Tasic accession not looked up) | **F17-F21** | 75 MB | batchelor `correction.Rmd`. Candidate OSCA-book alternative: pbmc3k + pbmc4k = **F1 + F2** (not verified in this session) | CC0 (package) |
| 23 | scran-markers | Grun pancreas | ExperimentHub | EH2687 | **F22** | 9.2 MB | scran vignette; candidate OSCA alternative pbmc4k = **F2** (not verified) | CC0 (package) |
| 24 | aucell-score | Zeisel cortex/hippocampus, 3005 cells (GEO matrix) + AUCell example gene sets | GEO + package-embedded | GSE60361 (*Mus musculus*, 3005 samples, PMID 25700174) | **F12** `GSE60361_C1-3005-Expression.txt.gz`; `system.file("examples", "geneSignatures.gmt", package="AUCell")`, `mouseBrain_cellLabels.tsv`, `cellsTsne.RData` | 11.2 MB | AUCell vignette (it downloads exactly this GEO file) | GEO: not stated; AUCell: GPL-3 |
| 25 | singler-annotate | Muraro pancreas (reference, 3072 cells, labelled) -> Grun pancreas (test, 1728 cells) | ExperimentHub | EH2692-2693 + EH2687 | **F23-F24** + **F22** | 38.7 MB | SingleR vignette "Using single-cell references". Built-in references (`celldex::fetchReference("hpca", "2024-02-26")` etc.) are reference data -> `env/refdata_registry.json`, not anchors | CC0 (package) |
| 26 | muscat-pseudobulk | Kang et al. 2018, 8 lupus patients ctrl vs IFN-beta, SCE 35635 x 29065 | ExperimentHub | EH2259 (muscData `Kang18_8vs8`; GEO GSE96583, 5 GSM, PMID 29227470) | **F25** `EH2259_muscData_Kang18_8vs8.Rda`; fast fixture `data(example_sce, package="muscat")` (1267 x 1556, subset of Kang) | 39.1 MB | muscat `analysis.Rmd` (`eh[["EH2259"]]`) | muscData: MIT; muscat: GPL-3 |
| 27 | speckle-propeller | CellBench 3 cell-line mixtures (sc_10x 902, sc_celseq 274, sc_dropseq 225 cells) + `pbmc_props` | file (GitHub) + package-embedded | -- | **F13** `CellBench_single_cell_data.RData` (the file `CellBench::load_sc_data()` downloads; pinned to Shians/scBenchData@e548bbb); `data("pbmc_props", package="speckle")` | 35.4 MB | speckle vignette | scBenchData: not stated; speckle: GPL-3 |
| 28 | cellchat-communication | Human skin, atopic dermatitis (`data_humanSkin`: normalized data + meta; tutorial subsets `condition == "LS"`) + `CellChatDB.human` | figshare + package-embedded | doi:10.6084/m9.figshare.24470719.v1 | **F14** `CellChat_data_humanSkin_CellChat.rda` (figshare md5 `9d31f4c8...6c2d` also matches) | 13.4 MB | CellChat tutorial `CellChat-vignette.Rmd` (pinned commit 75253cd) | **CC BY 4.0** (figshare) |
| 29 | monocle3-trajectory | Packer et al. C. elegans embryo (20222 genes x 6188 cells) | lab-hosted files | -- (not stated on the tutorial page) | **F15a-c** `monocle3_packer_embryo_{expression,colData,rowData}.rds` | 11.2 MB | monocle3 website tutorial "Constructing single-cell trajectories" | not stated |
| 30 | slingshot-trajectory | `slingshotExample` (simulated, 1 lineage) + tradeSeq `countMatrix` (240 x 2660), `crv`, `celltype` | package-embedded / simulated | -- | `data("slingshotExample", package="slingshot")`; `data(countMatrix / crv / celltype, package="tradeSeq")` | small | slingshot vignette, tradeSeq vignette (`fitGAM`, `associationTest`) | slingshot: Artistic-2.0; tradeSeq: MIT |
| 31 | wgcna-network | Female mouse liver (3600 genes, WGCNA tutorial I) | lab-hosted file -- **on demand, unresolved** | -- | `https://horvath.genetics.ucla.edu/html/CoexpressionNetwork/Rpackages/WGCNA/Tutorials/FemaleLiver-Data.zip` | -- | WGCNA tutorials (WGCNA 1.74 ships no vignette and no expression data) | not stated |
| 32 | maftools-landscape | TCGA LAML MAF (193 samples) + clinical annotation | package-embedded | TCGA-LAML | `system.file("extdata", "tcga_laml.maf.gz" / "tcga_laml_annot.tsv", package="maftools")` | small | maftools vignette, oncoplots vignette | maftools: MIT |
| 33 | immunedeconv-infiltration | `dataset_racle` (`expr_mat` + reference cell fractions) | package-embedded | -- | `immunedeconv::dataset_racle$expr_mat` | small | immunedeconv vignette (commit e625e6c: `deconvolute(immunedeconv::dataset_racle$expr_mat, "quantiseq")`) | immunedeconv: GPL-2 + file LICENSE; CIBERSORT stays user-supplied |

Primary-anchor kinds (33 modules): package-embedded 13 (#1, 2, 3, 8, 9, 10, 11, 12, 13, 17,
30, 32, 33; also part of #19, 24, 27, 28), 10x 4 (#15, 16, 18, 19), GEO 3 (#4, 5, 24),
GEO + ArrayExpress 1 (#6), ExperimentHub 5 (#20, 21, 22, 23, 25) + muscData hub 1 (#26),
other hosted files 5 (#7 WEHI, #14 WEHI, #27 GitHub, #28 figshare, #29 lab site),
simulated only as a section-level anchor (#8 `ComBat_seq`, #30 `slingshotExample`),
unresolved 1 (#31). Three primary anchors sit in packages that are not installed
(#3 fission, #8 bladderbatch, #13 GSVAdata) -- see section 4.

## 2. Downloaded files (fetch_anchor_data.sh)

| Id | File (local name) | Accession | URL | Bytes | sha256 |
|---|---|---|---|---|---|
| F1 | pbmc3k_filtered_gene_bc_matrices.tar.gz | 10x pbmc3k | https://s3-us-west-2.amazonaws.com/10x.files/samples/cell/pbmc3k/pbmc3k_filtered_gene_bc_matrices.tar.gz | 7621991 | 847d6ebd9a1ec9a768f2be7e40ca42cbfe75ebeb6d76a4c24167041699dc28b5 |
| F2 | pbmc4k_filtered_gene_bc_matrices.tar.gz | 10x pbmc4k (= EH1611-1613 content) | https://s3-us-west-2.amazonaws.com/10x.files/samples/cell/pbmc4k/pbmc4k_filtered_gene_bc_matrices.tar.gz | 18784558 | 87fe6bed5cd3a764a2e01a3fda30bb04dccb138b694c0c255645a0170123ee42 |
| F3 | GSE60450_Lactation-GenewiseCounts.txt.gz | GSE60450 | https://ftp.ncbi.nlm.nih.gov/geo/series/GSE60nnn/GSE60450/suppl/GSE60450_Lactation-GenewiseCounts.txt.gz | 513592 | 906b6ec4c33e95ca0ba454a3e0d07ad74e9cb7528ee38b89a9b122f5674a5f0d |
| F4 | GSE63310_RAW.tar | GSE63310 | https://ftp.ncbi.nlm.nih.gov/geo/series/GSE63nnn/GSE63310/suppl/GSE63310_RAW.tar | 1996800 | d2567b6753711e86820acbed4a4786ea1c57c59212503a8622b56982bcd53e44 |
| F5 | GSE33005_RAW.tar | GSE33005 / E-GEOD-33005 | https://ftp.ncbi.nlm.nih.gov/geo/series/GSE33nnn/GSE33005/suppl/GSE33005_RAW.tar | 42762240 | 3d094f4dc7a771d54d9efff7c67c12dcbdf06e036220132719515ab246e70d92 |
| F6 | E-GEOD-33005.sdrf.txt | E-GEOD-33005 | https://www.ebi.ac.uk/biostudies/files/E-GEOD-33005/E-GEOD-33005.sdrf.txt | 17572 | a2e13071c73023ed6b4762d003f2748df97016c184235d22c7b2316838e1fb25 |
| F7 | limma_IlluminaCaseStudy_probe_profile.txt.gz | GSE16997 | https://bioinf.wehi.edu.au/marray/IlluminaCaseStudy/probe%20profile.txt.gz | 9513689 | 6493d66dabb22fbd11023c5f412482edd972ad222fea3865d530335905cda0ed |
| F8 | limma_IlluminaCaseStudy_control_probe_profile.txt.gz | GSE16997 | https://bioinf.wehi.edu.au/marray/IlluminaCaseStudy/control%20probe%20profile.txt.gz | 135141 | 1ce713157988d8bfb195c93b08c079aa63daf25ae95e817d2bff797e24423ba9 |
| F9 | limma_IlluminaCaseStudy_Targets.txt | GSE16997 | https://bioinf.wehi.edu.au/marray/IlluminaCaseStudy/Targets.txt | 140 | 8a52b386e482ba0f686e0b4c57c2fd593621dbfeae9b72f64dc512b26f337ddb |
| F10 | limma_Yoruba.RData | -- | https://bioinf.wehi.edu.au/limma/data/Yoruba.RData | 3381149 | 62abb9669bf545e70bfa4abf3a8e99a86d49f35b8bd0ef7801deb8db0486a01b |
| F11 | limma_GenderGenes.RData | -- | https://bioinf.wehi.edu.au/software/GenderGenes/GenderGenes.RData | 420 | ad2e78f108281864be9a9fdc2b686068f24b785158bc8782ac03d510938ea493 |
| F12 | GSE60361_C1-3005-Expression.txt.gz | GSE60361 | https://ftp.ncbi.nlm.nih.gov/geo/series/GSE60nnn/GSE60361/suppl/GSE60361_C1-3005-Expression.txt.gz | 11239106 | dd09532c73822b632b1914356bfca8e186aff2300b30299e066a6105205e5c4c |
| F13 | CellBench_single_cell_data.RData | -- | https://raw.githubusercontent.com/Shians/scBenchData/e548bbb5497b8bdedf641b33dfbfb81d260d6cf3/single_cell_data.RData | 35423303 | 60a335a36be2b4e5de61b1bf6ff6c1fd542347f9337551a2a01b01d96505812b |
| F14 | CellChat_data_humanSkin_CellChat.rda | figshare 24470719 v1 | https://ndownloader.figshare.com/files/42997198 | 13426240 | c062532981d49145dbdbbec01e352ac291b483bd5ad203c9109ceadc892e0d9b |
| F15a | monocle3_packer_embryo_expression.rds | -- | https://depts.washington.edu/trapnell-lab/software/monocle3/celegans/data/packer_embryo_expression.rds | 10475830 | 1d0460a8dba5967972791ad47b4ae93b8ff25b78f6ab3f1ea08a451f0ebbbbc1 |
| F15b | monocle3_packer_embryo_colData.rds | -- | https://depts.washington.edu/trapnell-lab/software/monocle3/celegans/data/packer_embryo_colData.rds | 508659 | 6b8a25a5d74eddf84f32503d81f40162b05ef565af037e8eb79b9f36bd9b75a4 |
| F15c | monocle3_packer_embryo_rowData.rds | -- | https://depts.washington.edu/trapnell-lab/software/monocle3/celegans/data/packer_embryo_rowData.rds | 231763 | beffa9762e912161bf8416e5a8e4afd9f368e04847355dcd11e4038bf869d111 |
| F17 | EH2580_zeisel-brain_counts.rds | EH2580 | .../ExperimentHub/scRNAseq/zeisel-brain/2.0.0/counts.rds | 19213224 | 4357e6850705c096c8c1276f32b415628dcc16c51ba2c61a36598948ca12a215 |
| F18 | EH2581_zeisel-brain_rowdata.rds | EH2581 | .../ExperimentHub/scRNAseq/zeisel-brain/2.0.0/rowdata.rds | 103534 | 39ab99d7e8d1387103214b0be92a2e4acd83d46715f5b876dbc5d014c678fb12 |
| F19 | EH2582_zeisel-brain_coldata.rds | EH2582 | .../ExperimentHub/scRNAseq/zeisel-brain/2.0.0/coldata.rds | 47977 | 652d0476cf3274d8d7804f5096b55580c6b298a2f4fa288f1d8934afad70405f |
| F20 | EH2578_tasic-brain_counts.rds | EH2578 | .../ExperimentHub/scRNAseq/tasic-brain/2.0.0/counts.rds | 55571716 | cfb44779bc27f0de3eee8086f510afd2d31a8cf2e354c80c457a10b1c72c156c |
| F21 | EH2579_tasic-brain_coldata.rds | EH2579 | .../ExperimentHub/scRNAseq/tasic-brain/2.0.0/coldata.rds | 16629 | 3c667abcb2b6af1371e43799d050a705a2a243050e21a743c84941c01791efb6 |
| F22 | EH2687_grun-pancreas_counts.rds | EH2687 | .../ExperimentHub/scRNAseq/grun-pancreas/2.0.0/counts.rds | 9206365 | 237f99410659bb6614f2cbc2cd1fcb2a5d242230c97490c87f324a59bbac246d |
| F23 | EH2692_muraro-pancreas_counts.rds | EH2692 | .../ExperimentHub/scRNAseq/muraro-pancreas/2.0.0/counts.rds | 29480775 | c78a0281d1c48021c37925d8aad052a2a9baf28ead94531c52d94b61cd034f60 |
| F24 | EH2693_muraro-pancreas_coldata.rds | EH2693 | .../ExperimentHub/scRNAseq/muraro-pancreas/2.0.0/coldata.rds | 10830 | 813dd8b393a5090d68c5aa650438faffc2d5041073bffe065c9db1e3c94719d1 |
| F25 | EH2259_muscData_Kang18_8vs8.Rda | EH2259 | .../ExperimentHub/muscData/Kang18_8vs8.Rda | 39078983 | b631d72139ad157cfc7530800268a4a9d1194f81dce0d2b387ca3d600acce485 |

`...` = `https://mghp.osn.xsede.org/bir190004-bucket01`. Every file was loaded once in R
after download (dimensions quoted in section 1). Groups for partial runs: `10x` (F1-F2),
`bulk` (F3-F11), `sc` (F12-F15c), `hub` (F17-F25).

## 3. On demand / not downloaded

| Dataset | Why | Where |
|---|---|---|
| WGCNA FemaleLiver-Data.zip (#31) | the host's TLS certificate is reported expired (curl error 60, 2026-09-27); the Wayback copy (snapshot 20240728230333) could not be reached through the proxy; TLS verification is never disabled | URL in section 1; pin its sha256 from a host with working TLS, then add it to the `bulk` group |
| GSE96583_RAW.tar (full Kang data, 76 MB) | not needed: harmony `pbmc_stim` (#17) and muscData EH2259 (#26) already hold it | https://ftp.ncbi.nlm.nih.gov/geo/series/GSE96nnn/GSE96583/suppl/GSE96583_RAW.tar |
| La Manno human ES (EH2659-2660) | first SingleR example; needs a celldex reference (reference data), so the SC-reference example (#25) was chosen | ExperimentHub `scRNAseq/lamanno-brain/2.0.0/*-human-es.rds` |
| GSE60450_RAW.tar, GSE18508_RAW.tar, GSE19446 | raw per-sample files not used by the workflows (counts table / packages used instead) | GEO |
| No file above 500 MB was needed. | | |

## 4. Gaps for the owner (待裁决)

1. **Data packages are missing from the container layers.** `env/layers/*.txt` install none of
   `airway`, `pasilla`, `fission`, `bladderbatch`, `zebrafishRNASeq`, `GSVAdata`; the dev env has
   only airway 1.33.2, pasilla 1.41.0 (and parathyroidSE). In the omicstat-r image the
   deseq2-wald smoke test therefore SKIPs (`# requires: ... pasilla ...`) instead of checking
   its anchors; deseq2-lrt, sva-batch and gsva-score have no installed anchor anywhere.
   Options: a test-data layer (e.g. `L8_testdata`) or installing the Bioconductor source
   tarballs from `fetch_anchor_data.sh`. Not decided here.
2. Hub resources are fetched as files; a module fixture must rebuild the objects exactly as
   the scRNAseq / muscData accessor does (e.g. `GrunPancreasData()` derives colData from the
   column names; `ZeiselBrainData()` uses rowData to place non-gene features).
   Where a replay anchor needs the accessor itself, the test is container-only unless the
   accessor package is installed.
3. Versions: the dev env is Bioconductor 3.22, the container is 3.23 (`env/omicstat-env.json`);
   package-embedded data can change between them (e.g. pasilla 1.41.0 in dev vs 1.38.0 in the
   Bioc 3.22 repository). Anchors are regenerated in the container (brief §6).

## 5. Scverse source-build anchors (2026-09-30)

| ID | Modules | Accession / package source | Integrity | Role |
|---|---|---|---|---|
| F1-PY | scanpy-qc, scanpy-cluster, scanpy-markers | Existing F1 PBMC3k official tutorial input | Reuses F1 archive SHA256 above; first 600 cells in supplied order | Independent API replay, not invented printed values |
| PY-SIM-1 | scvi-integrate, scanvi-annotate | scvi-tools 1.5.1 `scvi.data.synthetic_iid`, seed 20260925 | Generated h5ad SHA256 pending execution; recorded by `sc_anchor.make_synthetic` | Package-owned IID simulator for workflow tests only |

The simulator has no accession or biological validation claim. Its exact arguments,
label holdout rule and generated dimensions are written by the fixture script.
No anchor was downloaded or numerically executed for this source-build record.
