#!/usr/bin/env python3
"""Build app/method_lexicon.json: the omics method / package lexicon used for co-occurrence counting.

Scope (owner decision 2026-10-10): omics packages (Bioconductor / CRAN / PyPI / GitHub) and omics method names
(spatial-domain methods, proteomics differential abundance, RNA velocity, ATAC, doublet detection, integration, ...).
Clinical statistics (Cox, mixed models, survival, meta-analysis, ...) are OUT.

The curated table below is the single source; `in_pkg_lock` is derived from env/pkg_lock.csv and env/py/py_installed.csv,
`our_module` is checked against app/method_map.json.  The output is deterministic.

    python build_lexicon.py            # write app/method_lexicon.json
    python build_lexicon.py --check    # exit 1 if the committed file is stale

Fields of an entry
    token        stable lower-case id (what is stored in method_mentions / methods_used)
    name         display name
    regex        pattern searched in Methods text (flags: "i" case-insensitive, "" case-sensitive)
    family       trend family (family-share alerts compare members of one family)
    kind         package | method
    ecosystem    bioc | cran | pypi | github | software | method
    in_pkg_lock  the package is in the locked omicstat environment (R or Python lane)
    our_module   omicstat modules this token is the engine/front end of ([] = not covered)
    rank_eligible  may appear in the coverage ranking (False for upstream tools, databases, utilities)
    exclusion    why not rank_eligible
    licence_note reference-data licence gate (KEGG / CADD / PanglaoDB / DepMap are never bundled or auto-downloaded)
"""
from __future__ import annotations

import argparse
import csv
import hashlib
import json
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parent
OUT = HERE / "app" / "method_lexicon.json"
SCHEMA = "omicstat.reference.method-lexicon.v1"
VERSION = "lexicon-v1"

UP = "upstream processing (alignment / quantification / QC), not an analysis-module candidate"
DB = "reference database, not a method"
UTIL = "visualisation / utility, not an analysis method"
KEGG_NOTE = "KEGG: licence-restricted data; never bundled or auto-downloaded"

# (token, name, family, kind, ecosystem, lock package, modules, regex, case-insensitive, rank flag/exclusion, licence note)
_ROWS: list[tuple] = []


def E(token, name, family, kind, eco, pkg=None, modules=(), regex=None, ci=True, exclusion=None, note=None):
    _ROWS.append((token, name, family, kind, eco, pkg, tuple(modules), regex, ci, exclusion, note))


# ---- bulk expression: differential testing
E("deseq2", "DESeq2", "bulk-de", "package", "bioc", "R:DESeq2", ["deseq2-wald", "deseq2-qc", "deseq2-lrt"])
E("edger", "edgeR", "bulk-de", "package", "bioc", "R:edgeR", ["edger-qlf"])
E("limma", "limma", "bulk-de", "package", "bioc", "R:limma", ["limma-voom", "limma-array", "limma-dupcor", "limma-camera"])
E("voom", "voom", "bulk-de", "method", "bioc", "R:limma", ["limma-voom"], r"\bvoom(?:WithQualityWeights)?\b")
E("dream", "dream / variancePartition", "bulk-de", "package", "bioc", "R:variancePartition", [], r"\bdream\b[^.]{0,60}\b(?:variancePartition|mixed|differential expression)|\bvariancePartition\b", True)
E("sleuth", "sleuth", "bulk-de", "package", "github", None, [], r"\bsleuth\b[^.]{0,60}\b(?:kallisto|differential|transcript)|\b(?:kallisto|differential)[^.]{0,60}\bsleuth\b")
E("ebseq", "EBSeq", "bulk-de", "package", "bioc", None, [], r"\bEBSeq\b")
E("dexseq", "DEXSeq", "bulk-de", "package", "bioc", None, [], r"\bDEXSeq\b")
E("cuffdiff", "Cuffdiff", "bulk-de", "package", "software", None, [], r"\bCuffdiff\b|\bCufflinks\b")
# ---- batch / unwanted variation
E("sva", "sva (surrogate variable analysis)", "batch-correction", "package", "bioc", "R:sva", ["sva-batch"], r"\bsva(?:seq)?\b|\bsurrogate variable analysis\b")
E("combat", "ComBat", "batch-correction", "method", "bioc", "R:sva", ["sva-batch"], r"\bComBat\b(?![-_]seq)", False)
E("combat-seq", "ComBat-seq", "batch-correction", "method", "bioc", "R:sva", ["sva-batch"], r"\bComBat[-_]seq\b", False)
E("ruvseq", "RUVSeq", "batch-correction", "package", "bioc", None, [], r"\bRUVSeq\b|\bRUV[gsr]\b", False)
E("removebatcheffect", "removeBatchEffect", "batch-correction", "method", "bioc", "R:limma", [], r"\bremoveBatchEffect\b")
# ---- enrichment / gene-set analysis
E("clusterprofiler", "clusterProfiler", "enrichment", "package", "bioc", "R:clusterProfiler", ["clusterprofiler-ora", "clusterprofiler-gsea", "clusterprofiler-compare"])
E("fgsea", "fgsea", "enrichment", "package", "bioc", "R:fgsea", ["fgsea-prerank"])
E("gsea", "GSEA (gene set enrichment analysis)", "enrichment", "method", "software", "R:fgsea", ["clusterprofiler-gsea", "fgsea-prerank"], r"\bGSEA\b|\bgene set enrichment analysis\b")
E("gsva", "GSVA", "enrichment", "package", "bioc", "R:GSVA", ["gsva-score"], r"\bGSVA\b|\bgene set variation analysis\b")
E("ssgsea", "ssGSEA", "enrichment", "method", "bioc", "R:GSVA", ["gsva-score"], r"\bssGSEA\b|\bsingle[- ]sample GSEA\b")
E("singscore", "singscore", "enrichment", "package", "bioc", "R:singscore", [], r"\bsingscore\b")
E("gseapy", "GSEApy", "enrichment", "package", "pypi", None, [], r"\bGSEApy\b")
E("topgo", "topGO", "enrichment", "package", "bioc", None, [], r"\btopGO\b")
E("goseq", "goseq", "enrichment", "package", "bioc", None, [], r"\bgoseq\b")
E("gprofiler", "g:Profiler", "enrichment", "package", "software", None, [], r"\bg:Profiler\b|\bgProfileR\b|\bgprofiler2?\b")
E("enrichr", "Enrichr", "enrichment", "software", "software", None, [], r"\bEnrichr\b")
E("metascape", "Metascape", "enrichment", "software", "software", None, [], r"\bMetascape\b")
E("camera", "limma camera", "enrichment", "method", "bioc", "R:limma", ["limma-camera"], r"\bcamera\b[^.]{0,60}\b(?:gene set|limma|competitive)|\b(?:limma|competitive)[^.]{0,60}\bcamera\b")
E("roast", "ROAST / fry", "enrichment", "method", "bioc", "R:limma", [], r"\b(?:ROAST|mroast|fry)\b[^.]{0,60}\b(?:gene set|limma|rotation)|\b(?:limma|rotation)[^.]{0,60}\b(?:ROAST|mroast)\b", False)
E("reactomepa", "ReactomePA", "enrichment", "package", "bioc", "R:ReactomePA", ["clusterprofiler-ora"], r"\bReactomePA\b")
E("msigdb", "MSigDB", "enrichment", "method", "software", "R:msigdbr", [], r"\bMSigDB\b|\bmsigdbr\b", exclusion=DB)
E("kegg", "KEGG pathways", "enrichment", "method", "software", "R:KEGGREST", [], r"\bKEGG\b", False, exclusion=DB, note=KEGG_NOTE)
# ---- activity / regulon inference
E("progeny", "PROGENy", "regulon-tf", "package", "bioc", None, [], r"\bPROGENy\b", False)
E("decoupler", "decoupleR", "regulon-tf", "package", "bioc", None, [], r"\bdecoupleR\b|\bdecoupler\b", False)
E("viper", "VIPER", "regulon-tf", "package", "bioc", None, [], r"\bVIPER\b[^.]{0,60}\b(?:regulon|activity|protein)|\bregulon\b[^.]{0,60}\bVIPER\b", False)
E("dorothea", "DoRothEA", "regulon-tf", "package", "bioc", None, [], r"\bDoRothEA\b", False)
E("scenic", "SCENIC / pySCENIC", "regulon-tf", "package", "pypi", None, [], r"\bp?y?SCENIC\b", False)
E("genie3", "GENIE3", "regulon-tf", "package", "bioc", None, [], r"\bGENIE3\b|\bGRNBoost2?\b")
E("aucell", "AUCell", "regulon-tf", "package", "bioc", "R:AUCell", ["aucell-score"], r"\bAUCell\b", False)
# ---- coexpression networks
E("wgcna", "WGCNA", "coexpression", "package", "cran", "R:WGCNA", ["wgcna-network"], r"\bWGCNA\b|\bweighted gene co-?expression network\b")
E("hdwgcna", "hdWGCNA", "coexpression", "package", "github", None, [], r"\bhdWGCNA\b", False)
# ---- single-cell frameworks
E("seurat", "Seurat", "sc-framework", "package", "cran", "R:Seurat", ["seurat-qc", "seurat-cluster", "seurat-integrate", "seurat-markers", "seurat-modulescore"])
E("scanpy", "Scanpy", "sc-framework", "package", "pypi", "PY:scanpy", ["scanpy-qc", "scanpy-cluster", "scanpy-markers", "scanpy-annotate", "scanpy-purity", "scanpy-ingest"])
E("sce", "SingleCellExperiment", "sc-framework", "package", "bioc", "R:SingleCellExperiment", [], r"\bSingleCellExperiment\b", exclusion=UTIL)
E("scater", "scater", "sc-framework", "package", "bioc", "R:scater", ["scater-qc"])
E("scran", "scran", "sc-framework", "package", "bioc", "R:scran", ["scran-cluster", "scran-markers"])
E("anndata", "AnnData", "sc-framework", "package", "pypi", "PY:anndata", [], r"\bAnnData\b", exclusion=UTIL)
E("sctransform", "SCTransform", "sc-framework", "method", "cran", "R:sctransform", [], r"\bSCTransform\b|\bsctransform\b")
E("cellranger", "Cell Ranger", "upstream", "software", "software", None, [], r"\bCell ?Ranger\b", exclusion=UP)
# ---- single-cell QC: doublets, ambient RNA
E("doubletfinder", "DoubletFinder", "doublet-detection", "package", "github", None, [], r"\bDoubletFinder\b", False)
E("scdblfinder", "scDblFinder", "doublet-detection", "package", "bioc", None, [], r"\bscDblFinder\b", False)
E("scrublet", "Scrublet", "doublet-detection", "package", "pypi", None, [], r"\bScrublet\b", False)
E("doubletdecon", "DoubletDecon", "doublet-detection", "package", "github", None, [], r"\bDoubletDecon\b", False)
E("scds", "scds", "doublet-detection", "package", "bioc", None, [], r"\bscds\b[^.]{0,40}\b(?:doublet|cxds|bcds|hybrid)", True)
E("soupx", "SoupX", "ambient-rna", "package", "cran", None, [], r"\bSoupX\b", False)
E("decontx", "DecontX", "ambient-rna", "package", "bioc", None, [], r"\bDecontX\b", False)
E("cellbender", "CellBender", "ambient-rna", "package", "pypi", None, [], r"\bCellBender\b", False)
E("dropletutils", "DropletUtils", "ambient-rna", "package", "bioc", "R:DropletUtils", [], r"\bDropletUtils\b|\bemptyDrops\b", False)
# ---- single-cell integration / batch correction
E("harmony", "Harmony", "sc-integration", "package", "cran", "R:harmony", ["seurat-integrate"], r"\bHarmony\b[^.]{0,80}\b(?:integrat|batch|PCA|correct|cluster|RunHarmony)|\b(?:integrat|batch|correct)\w*[^.]{0,80}\bHarmony\b|\bRunHarmony\b|\bharmonypy\b", False)
E("scvi", "scVI", "sc-integration", "package", "pypi", "PY:scvi-tools", ["scvi-integrate", "scanvi-annotate"], r"\bscVI\b|\bscvi-tools\b|\bSCVI\b", False)
E("totalvi", "totalVI", "sc-integration", "package", "pypi", "PY:scvi-tools", [], r"\btotalVI\b", False)
E("multivi", "MultiVI", "sc-integration", "package", "pypi", "PY:scvi-tools", [], r"\bMultiVI\b", False)
E("scanvi", "scANVI", "sc-annotation", "package", "pypi", "PY:scvi-tools", ["scanvi-annotate"], r"\bscANVI\b", False)
E("fastmnn", "fastMNN / batchelor", "sc-integration", "package", "bioc", "R:batchelor", ["batchelor-integrate"], r"\bfastMNN\b|\bbatchelor\b|\bmnnCorrect\b")
E("bbknn", "BBKNN", "sc-integration", "package", "pypi", None, [], r"\bBBKNN\b", False)
E("scanorama", "Scanorama", "sc-integration", "package", "pypi", None, [], r"\bScanorama\b")
E("liger", "LIGER", "sc-integration", "package", "cran", None, [], r"\bLIGER\b|\brliger\b", False)
E("seurat-cca", "Seurat CCA / RPCA anchors", "sc-integration", "method", "cran", "R:Seurat", ["seurat-integrate"], r"\bIntegrateData\b|\bFindIntegrationAnchors\b|\bRPCA\b|\banchor-based integration\b", False)
E("seurat-wnn", "Seurat WNN", "multi-omics", "method", "cran", "R:Seurat", [], r"\bweighted nearest neighbou?r\b|\bFindMultiModalNeighbors\b", False)
# ---- annotation / reference mapping
E("singler", "SingleR", "sc-annotation", "package", "bioc", "R:SingleR", ["singler-annotate"], r"\bSingleR\b", False)
E("celltypist", "CellTypist", "sc-annotation", "package", "pypi", None, [], r"\bCellTypist\b")
E("azimuth", "Azimuth", "sc-annotation", "package", "github", None, [], r"\bAzimuth\b[^.]{0,60}\b(?:reference|annotation|map|cell)|\b(?:reference|annotation|mapp\w+)[^.]{0,60}\bAzimuth\b", False)
E("sctype", "scType", "sc-annotation", "package", "github", None, [], r"\bscType\b", False)
E("scanpy-ingest-method", "Scanpy ingest (label transfer)", "sc-annotation", "method", "pypi", "PY:scanpy", ["scanpy-ingest"], r"\bsc\.tl\.ingest\b|\bscanpy[^.]{0,60}\bingest\b", False)
E("celldex", "celldex references", "sc-annotation", "package", "bioc", "R:celldex", ["singler-annotate"], r"\bcelldex\b", False)
E("panglaodb", "PanglaoDB markers", "sc-annotation", "method", "software", None, [], r"\bPanglaoDB\b", False, exclusion=DB, note="PanglaoDB: licence-restricted data; never bundled or auto-downloaded")
# ---- trajectory and RNA velocity
E("monocle3", "Monocle 3", "sc-trajectory", "package", "github", "R:monocle3", ["monocle3-trajectory"], r"\bMonocle ?3\b|\bmonocle3\b", False)
E("monocle2", "Monocle 2", "sc-trajectory", "package", "bioc", None, [], r"\bMonocle ?2\b|\bmonocle2\b|\bDDRTree\b", False)
E("slingshot", "Slingshot", "sc-trajectory", "package", "bioc", "R:slingshot", ["slingshot-trajectory"])
E("tradeseq", "tradeSeq", "sc-trajectory", "package", "bioc", "R:tradeSeq", [], r"\btradeSeq\b", False)
E("paga", "PAGA", "sc-trajectory", "method", "pypi", "PY:scanpy", [], r"\bPAGA\b|\bpartition-based graph abstraction\b")
E("dpt", "diffusion pseudotime (DPT)", "sc-trajectory", "method", "pypi", "PY:scanpy", [], r"\bdiffusion pseudotime\b|\bDPT\b[^.]{0,40}\bpseudotime")
E("palantir", "Palantir", "sc-trajectory", "package", "pypi", None, [], r"\bPalantir\b[^.]{0,60}\b(?:pseudotime|trajectory|cell|fate)", False)
E("cytotrace", "CytoTRACE", "sc-trajectory", "package", "cran", None, [], r"\bCytoTRACE\b", False)
E("scvelo", "scVelo", "rna-velocity", "package", "pypi", None, [], r"\bscVelo\b", False)
E("velocyto", "velocyto", "rna-velocity", "package", "pypi", None, [], r"\bvelocyto\b")
E("dynamo", "dynamo (RNA velocity)", "rna-velocity", "package", "pypi", None, [], r"\bdynamo\b[^.]{0,60}\b(?:velocity|vector field|metabolic labeling)", True)
E("cellrank", "CellRank", "rna-velocity", "package", "pypi", None, [], r"\bCellRank\b", False)
# ---- cell-cell communication
E("cellchat", "CellChat", "cell-communication", "package", "github", "R:CellChat", ["cellchat-communication"], r"\bCellChat\b", False)
E("liana", "LIANA", "cell-communication", "package", "bioc", None, [], r"\bLIANA\+?\b", False)
E("nichenet", "NicheNet", "cell-communication", "package", "github", None, [], r"\bNicheNet\b|\bnichenetr\b", False)
E("cellphonedb", "CellPhoneDB", "cell-communication", "package", "pypi", None, [], r"\bCellPhoneDB\b")
E("commot", "COMMOT", "cell-communication", "package", "pypi", None, [], r"\bCOMMOT\b", False)
E("cell2cell", "Cell2Cell / Tensor-cell2cell", "cell-communication", "package", "pypi", None, [], r"\b(?:Tensor-)?cell2cell\b")
# ---- composition / pseudobulk / multi-sample
E("muscat", "muscat", "sc-multisample", "package", "bioc", "R:muscat", ["muscat-pseudobulk"], r"\bmuscat\b")
E("propeller", "speckle / propeller", "sc-multisample", "package", "bioc", "R:speckle", ["speckle-propeller"], r"\bpropeller\b|\bspeckle\b[^.]{0,60}\b(?:propor|composition|propeller)")
E("milo", "miloR / Milo", "sc-multisample", "package", "bioc", None, [], r"\bmiloR\b|\bMilo\b[^.]{0,60}\b(?:neighbou?rhood|differential abundance)", False)
E("sccoda", "scCODA", "sc-multisample", "package", "pypi", None, [], r"\bscCODA\b", False)
E("mast", "MAST", "sc-multisample", "package", "bioc", None, [], r"\bMAST\b[^.]{0,60}\b(?:hurdle|differential|single|expression|test)|\b(?:hurdle|differential)[^.]{0,60}\bMAST\b", False)
E("presto", "presto", "sc-multisample", "package", "github", "R:presto", ["seurat-markers"], r"\bpresto\b[^.]{0,60}\b(?:Wilcoxon|marker|auc|differential)", True)
# ---- copy number / tumour genomics
E("infercnv", "inferCNV", "cnv", "package", "bioc", None, [], r"\binferCNV\b", False)
E("copykat", "CopyKAT", "cnv", "package", "github", None, [], r"\bCopyKAT\b", False)
E("numbat", "Numbat", "cnv", "package", "github", None, [], r"\bNumbat\b", False)
E("gistic", "GISTIC2", "cancer-genomics", "package", "software", None, [], r"\bGISTIC\s?2?(?:\.0)?\b", False)
E("maftools", "maftools", "cancer-genomics", "package", "bioc", "R:maftools", ["maftools-landscape"])
E("mutsigcv", "MutSigCV", "cancer-genomics", "package", "software", None, [], r"\bMutSig(?:CV|2CV)\b", False)
E("dndscv", "dNdScv", "cancer-genomics", "package", "github", None, [], r"\bdNdScv\b", False)
E("sigprofiler", "SigProfiler", "cancer-genomics", "package", "pypi", None, [], r"\bSigProfiler\w*\b", False)
E("deconstructsigs", "deconstructSigs", "cancer-genomics", "package", "cran", None, [], r"\bdeconstructSigs\b", False)
E("mutationalpatterns", "MutationalPatterns", "cancer-genomics", "package", "bioc", None, [], r"\bMutationalPatterns\b", False)
E("dnacopy", "DNAcopy / CBS", "cancer-genomics", "package", "bioc", "R:DNAcopy", [], r"\bDNAcopy\b|\bcircular binary segmentation\b")
E("consensusclusterplus", "ConsensusClusterPlus", "cancer-genomics", "package", "bioc", "R:ConsensusClusterPlus", [], r"\bConsensusClusterPlus\b")
E("nmf", "NMF (non-negative matrix factorisation)", "cancer-genomics", "method", "cran", "R:NMF", [], r"\bnon-?negative matrix factori[sz]ation\b|\bNMF\b[^.]{0,40}\b(?:cluster|signature|factor|subtype)")
# ---- immune deconvolution
E("immunedeconv", "immunedeconv", "immune-deconvolution", "package", "github", "R:immunedeconv", ["immunedeconv-infiltration"], r"\bimmunedeconv\b", False)
E("cibersort", "CIBERSORT / CIBERSORTx", "immune-deconvolution", "package", "software", None, ["immunedeconv-infiltration"], r"\bCIBERSORTx?\b", False)
E("xcell", "xCell", "immune-deconvolution", "package", "github", "R:xCell", ["immunedeconv-infiltration"], r"\bxCell\b", False)
E("mcpcounter", "MCP-counter", "immune-deconvolution", "package", "github", "R:MCPcounter", ["immunedeconv-infiltration"], r"\bMCP-?counter\b", False)
E("epic-deconv", "EPIC (immune deconvolution)", "immune-deconvolution", "package", "github", "R:EPIC", ["immunedeconv-infiltration"], r"\bEPIC\b(?=[^.]{0,80}(?:deconvol|immune|infiltrat|cell fraction|cell proportion))", False)
E("timer", "TIMER", "immune-deconvolution", "package", "software", None, ["immunedeconv-infiltration"], r"\bTIMER2?(?:\.0)?\b[^.]{0,60}\b(?:immune|infiltrat|deconvol)", False)
E("quantiseq", "quanTIseq", "immune-deconvolution", "package", "github", "R:quantiseqr", ["immunedeconv-infiltration"], r"\bquanTIseq\b|\bquantiseqr\b", True)
E("estimate-score", "ESTIMATE (stromal / immune score)", "immune-deconvolution", "package", "r-forge", None, ["immunedeconv-infiltration"], r"\bESTIMATE\b[^.]{0,60}\b(?:stromal|immune score|tumou?r purity|algorithm)", False)
E("bisque", "BisqueRNA", "immune-deconvolution", "package", "cran", None, [], r"\bBisque(?:RNA)?\b[^.]{0,60}\b(?:deconvol|bulk|reference|proportion)", False)
E("bayesprism", "BayesPrism", "immune-deconvolution", "package", "github", None, [], r"\bBayesPrism\b|\bTED\b[^.]{0,40}\bBayesPrism", False)
E("consensustme", "ConsensusTME", "immune-deconvolution", "package", "github", "R:ConsensusTME", [], r"\bConsensusTME\b", False)
# ---- spatial transcriptomics
E("spatial-seurat", "Seurat spatial", "spatial-other", "method", "cran", "R:Seurat", [], r"\bSpatialFeaturePlot\b|\bSeurat\b[^.]{0,60}\b(?:Visium|spatial transcriptom)", False)
E("squidpy", "Squidpy", "spatial-other", "package", "pypi", None, [], r"\bSquidpy\b", False)
E("spatialexperiment", "SpatialExperiment", "spatial-other", "package", "bioc", "R:SpatialExperiment", [], r"\bSpatialExperiment\b", exclusion=UTIL)
E("giotto", "Giotto", "spatial-other", "package", "github", None, [], r"\bGiotto\b", False)
E("spatialde", "SpatialDE", "spatial-svg", "package", "pypi", None, [], r"\bSpatialDE\b", False)
E("spark", "SPARK / SPARK-X", "spatial-svg", "package", "cran", None, [], r"\bSPARK(?:-X)?\b[^.]{0,60}\b(?:spatial|variable|expression)", False)
E("nnsvg", "nnSVG", "spatial-svg", "package", "bioc", None, [], r"\bnnSVG\b", False)
E("moransi", "Moran's I (spatially variable genes)", "spatial-svg", "method", "method", None, [], r"\bMoran'?s I\b", False)
E("meringue", "MERINGUE", "spatial-svg", "package", "github", None, [], r"\bMERINGUE\b", False)
E("bayesspace", "BayesSpace", "spatial-domain", "package", "bioc", None, [], r"\bBayesSpace\b", False)
E("spagcn", "SpaGCN", "spatial-domain", "package", "pypi", None, [], r"\bSpaGCN\b", False)
E("stagate", "STAGATE", "spatial-domain", "package", "pypi", None, [], r"\bSTAGATE\b", False)
E("stlearn", "stLearn", "spatial-domain", "package", "pypi", None, [], r"\bstLearn\b", False)
E("banksy", "BANKSY", "spatial-domain", "package", "bioc", None, [], r"\bBANKSY\b", False)
E("graphst", "GraphST", "spatial-domain", "package", "pypi", None, [], r"\bGraphST\b", False)
E("deepst", "DeepST", "spatial-domain", "package", "pypi", None, [], r"\bDeepST\b", False)
E("spatialpca", "SpatialPCA", "spatial-domain", "package", "cran", None, [], r"\bSpatialPCA\b", False)
E("cell2location", "cell2location", "spatial-deconvolution", "package", "pypi", None, [], r"\bcell2location\b")
E("rctd", "RCTD / spacexr", "spatial-deconvolution", "package", "github", None, [], r"\bRCTD\b|\bspacexr\b", False)
E("stdeconvolve", "STdeconvolve", "spatial-deconvolution", "package", "bioc", None, [], r"\bSTdeconvolve\b", False)
E("spotlight", "SPOTlight", "spatial-deconvolution", "package", "bioc", None, [], r"\bSPOTlight\b", False)
E("tangram", "Tangram", "spatial-deconvolution", "package", "pypi", None, [], r"\bTangram\b[^.]{0,60}\b(?:spatial|map|single|deconvol)", False)
# ---- chromatin accessibility / epigenomics
E("archr", "ArchR", "atac-chromatin", "package", "github", None, [], r"\bArchR\b", False)
E("signac", "Signac", "atac-chromatin", "package", "cran", None, [], r"\bSignac\b", False)
E("snapatac2", "SnapATAC / SnapATAC2", "atac-chromatin", "package", "pypi", None, [], r"\bSnapATAC2?\b", False)
E("chromvar", "chromVAR", "atac-chromatin", "package", "bioc", None, [], r"\bchromVAR\b", False)
E("cicero", "Cicero", "atac-chromatin", "package", "bioc", None, [], r"\bCicero\b[^.]{0,60}\b(?:co-?accessib|ATAC|peak|chromatin)", False)
E("cistopic", "cisTopic", "atac-chromatin", "package", "github", None, [], r"\bcisTopic\b|\bpycisTopic\b", False)
E("macs", "MACS2 / MACS3", "atac-chromatin", "package", "pypi", None, [], r"\bMACS[23]?\b[^.]{0,40}\b(?:peak|call|ChIP|ATAC)|\b(?:peak|call)\w*[^.]{0,40}\bMACS[23]?\b", False)
E("diffbind", "DiffBind", "atac-chromatin", "package", "bioc", None, [], r"\bDiffBind\b", False)
E("csaw", "csaw", "atac-chromatin", "package", "bioc", None, [], r"\bcsaw\b", True)
E("homer", "HOMER", "atac-chromatin", "package", "software", None, [], r"\bHOMER\b[^.]{0,60}\b(?:motif|annotatePeaks|peak|ChIP|ATAC)", False)
E("meme-suite", "MEME suite", "atac-chromatin", "package", "software", None, [], r"\bMEME[- ]?(?:suite|ChIP)\b|\bFIMO\b|\bTOMTOM\b", False)
E("chipseeker", "ChIPseeker", "atac-chromatin", "package", "bioc", None, [], r"\bChIPseeker\b")
E("deeptools", "deepTools", "atac-chromatin", "package", "pypi", None, [], r"\bdeepTools\b", exclusion=UP)
E("scenicplus", "SCENIC+", "atac-chromatin", "package", "pypi", None, [], r"\bSCENIC\+", False)
E("minfi", "minfi", "methylation", "package", "bioc", None, [], r"\bminfi\b")
E("champ", "ChAMP", "methylation", "package", "bioc", None, [], r"\bChAMP\b", False)
E("methylkit", "methylKit", "methylation", "package", "bioc", None, [], r"\bmethylKit\b")
E("bsseq", "bsseq / DSS", "methylation", "package", "bioc", None, [], r"\bbsseq\b|\bDSS\b[^.]{0,60}\b(?:methylation|DMR|DML|dispersion)", False)
E("dmrcate", "DMRcate", "methylation", "package", "bioc", None, [], r"\bDMRcate\b")
E("bismark", "Bismark", "methylation", "package", "software", None, [], r"\bBismark\b", exclusion=UP)
E("rnbeads", "RnBeads", "methylation", "package", "bioc", None, [], r"\bRnBeads\b")
# ---- proteomics / metabolomics
E("msstats", "MSstats", "proteomics", "package", "bioc", None, [], r"\bMSstats(?:TMT)?\b", False)
E("dep", "DEP (differential enrichment of proteomics)", "proteomics", "package", "bioc", None, [], r"\bDEP\b[^.]{0,60}\b(?:package|proteom|enrichment|differential)", False)
E("proda", "proDA", "proteomics", "package", "bioc", None, [], r"\bproDA\b", False)
E("msqrob2", "msqrob2", "proteomics", "package", "bioc", None, [], r"\bmsqrob2?\b")
E("deqms", "DEqMS", "proteomics", "package", "bioc", None, [], r"\bDEqMS\b", False)
E("msnbase", "MSnbase", "proteomics", "package", "bioc", None, [], r"\bMSnbase\b", False)
E("perseus", "Perseus", "proteomics", "software", "software", None, [], r"\bPerseus\b[^.]{0,60}\b(?:proteom|software|imputation|t-test|MaxQuant)|\bMaxQuant\b[^.]{0,60}\bPerseus\b", False)
E("maxquant", "MaxQuant", "proteomics", "software", "software", None, [], r"\bMaxQuant\b", exclusion=UP)
E("diann", "DIA-NN", "proteomics", "software", "software", None, [], r"\bDIA-NN\b", exclusion=UP)
E("metaboanalyst", "MetaboAnalyst", "metabolomics", "software", "software", None, [], r"\bMetaboAnalyst(?:R)?\b", False)
# ---- multi-omics
E("mofa", "MOFA / MOFA+", "multi-omics", "package", "bioc", None, [], r"\bMOFA\+?2?\b", False)
E("mixomics", "mixOmics", "multi-omics", "package", "bioc", None, [], r"\bmixOmics\b|\bDIABLO\b|\bsPLS-?DA\b", False)
E("snf", "Similarity Network Fusion", "multi-omics", "method", "cran", None, [], r"\bSimilarity Network Fusion\b|\bSNFtool\b|\bSNF\b[^.]{0,40}\b(?:cluster|fusion|patient)", False)
E("iclusterplus", "iCluster / iClusterPlus", "multi-omics", "package", "bioc", None, [], r"\biCluster(?:Plus|Bayes)?\b", False)
# ---- microbiome
E("dada2", "DADA2", "microbiome", "package", "bioc", None, [], r"\bDADA2\b", False)
E("qiime2", "QIIME 2", "microbiome", "package", "software", None, [], r"\bQIIME ?2?\b", False)
E("phyloseq", "phyloseq", "microbiome", "package", "bioc", None, [], r"\bphyloseq\b")
E("metaphlan", "MetaPhlAn", "microbiome", "package", "software", None, [], r"\bMetaPhlAn\d?\b", False)
E("lefse", "LEfSe", "microbiome", "package", "software", None, [], r"\bLEfSe\b", False)
E("ancombc", "ANCOM / ANCOM-BC", "microbiome", "package", "bioc", None, [], r"\bANCOM(?:-BC)?\b", False)
E("maaslin2", "MaAsLin 2", "microbiome", "package", "bioc", None, [], r"\bMaAsLin ?2?\b", False)
E("vegan", "vegan (ordination / PERMANOVA)", "microbiome", "package", "cran", None, [], r"\bvegan\b[^.]{0,60}\b(?:package|PERMANOVA|adonis|ordination|diversity)|\badonis2?\b", False)
# ---- CRISPR screens
E("mageck", "MAGeCK", "crispr-screen", "package", "software", None, [], r"\bMAGeCK(?:-VISPR|Flute)?\b", False)
E("depmap", "DepMap", "crispr-screen", "method", "software", None, [], r"\bDepMap\b", False, exclusion=DB, note="DepMap: licence-restricted data; never bundled or auto-downloaded")
E("cadd", "CADD scores", "variant-annotation", "method", "software", None, [], r"\bCADD\b[^.]{0,40}\b(?:score|variant|PHRED|deleterious)", False, exclusion=DB, note="CADD: licence-restricted data; never bundled or auto-downloaded")
# ---- upstream processing (counted, never ranked)
E("star-aligner", "STAR", "upstream", "software", "software", None, [], r"\bSTAR\b[^.]{0,40}\b(?:align|v?\d\.\d)|\b(?:align\w*)[^.]{0,40}\bSTAR\b", False, exclusion=UP)
E("hisat2", "HISAT2", "upstream", "software", "software", None, [], r"\bHISAT2?\b", exclusion=UP)
E("salmon", "Salmon", "upstream", "software", "software", None, [], r"\bSalmon\b[^.]{0,60}\b(?:quantif|transcript|v?\d\.\d|selective alignment)", False, exclusion=UP)
E("kallisto", "kallisto", "upstream", "software", "software", None, [], r"\bkallisto\b", exclusion=UP)
E("featurecounts", "featureCounts", "upstream", "software", "software", None, [], r"\bfeatureCounts\b", False, exclusion=UP)
E("fastp", "fastp", "upstream", "software", "software", None, [], r"\bfastp\b", exclusion=UP)
E("fastqc", "FastQC / MultiQC", "upstream", "software", "software", None, [], r"\bFastQC\b|\bMultiQC\b", exclusion=UP)
# ---- visualisation / dimensionality (counted for context, never ranked)
E("complexheatmap", "ComplexHeatmap", "utility", "package", "bioc", "R:ComplexHeatmap", [], r"\bComplexHeatmap\b", exclusion=UTIL)
E("ggplot2", "ggplot2", "utility", "package", "cran", "R:ggplot2", [], r"\bggplot2\b", exclusion=UTIL)
E("pheatmap", "pheatmap", "utility", "package", "cran", "R:pheatmap", [], r"\bpheatmap\b", exclusion=UTIL)
E("enhancedvolcano", "EnhancedVolcano", "utility", "package", "bioc", None, [], r"\bEnhancedVolcano\b", exclusion=UTIL)
E("umap", "UMAP", "utility", "method", "method", "PY:umap-learn", [], r"\bUMAP\b|\bumap-learn\b", False, exclusion="visualisation method used in nearly every single-cell paper")
E("tsne", "t-SNE", "utility", "method", "method", "R:Rtsne", [], r"\bt-?SNE\b", False, exclusion="visualisation method used in nearly every single-cell paper")
E("leiden", "Leiden / Louvain clustering", "utility", "method", "method", "PY:leidenalg", [], r"\bLeiden\b|\bLouvain\b", False, exclusion="graph-clustering step inside the single-cell frameworks, not a standalone module candidate")


# Europe PMC section-query phrases per token (only where the display name is not itself a plain phrase) and
# context terms for tokens that are ordinary words (the context is ANDed so that "Harmony" means the tool).
PHRASES = {
    "ancombc": ["ANCOM-BC", "ANCOM"], "bsseq": ["bsseq", "DSS"], "cell2cell": ["cell2cell"], "cibersort": ["CIBERSORT", "CIBERSORTx"],
    "dep": ["DEP package"], "dnacopy": ["DNAcopy"], "dpt": ["diffusion pseudotime"], "dream": ["variancePartition"],
    "dynamo": ["dynamo"], "epic-deconv": ["EPIC"], "estimate-score": ["ESTIMATE algorithm"], "fastmnn": ["fastMNN", "batchelor"],
    "gsea": ["GSEA", "gene set enrichment analysis"], "iclusterplus": ["iClusterPlus", "iClusterBayes"], "macs": ["MACS2", "MACS3"],
    "milo": ["miloR"], "mofa": ["MOFA", "MOFA+"], "moransi": ["Moran's I"], "nmf": ["non-negative matrix factorization", "NMF"],
    "propeller": ["propeller", "speckle"], "rctd": ["RCTD", "spacexr"], "roast": ["mroast", "ROAST"],
    "scanpy-ingest-method": ["scanpy ingest"], "scenic": ["pySCENIC", "SCENIC"], "seurat-cca": ["IntegrateData", "FindIntegrationAnchors"],
    "snapatac2": ["SnapATAC2", "SnapATAC"], "spark": ["SPARK-X", "SPARK"], "sva": ["surrogate variable analysis", "svaseq"],
    "vegan": ["PERMANOVA", "adonis2"], "removebatcheffect": ["removeBatchEffect"], "camera": ["camera"], "kegg": ["KEGG"],
    "umap": ["UMAP"], "tsne": ["t-SNE"], "leiden": ["Leiden"], "combat": ["ComBat"], "combat-seq": ["ComBat-seq"],
    "msigdb": ["MSigDB"], "timer": ["TIMER2.0", "TIMER"], "mcpcounter": ["MCP-counter"], "gprofiler": ["g:Profiler", "gprofiler2"],
}
SC_CONTEXT = ["single-cell", "scRNA-seq", "single cell"]
CONTEXT = {
    "harmony": SC_CONTEXT + ["batch effect"], "palantir": SC_CONTEXT, "azimuth": SC_CONTEXT, "cicero": ["scATAC-seq", "chromatin accessibility"],
    "giotto": ["spatial transcriptomics", "Visium"], "mast": SC_CONTEXT, "tangram": ["spatial transcriptomics", "Visium"],
    "milo": SC_CONTEXT, "numbat": SC_CONTEXT + ["copy number"], "dream": ["differential expression", "mixed model"],
    "camera": ["gene set", "limma"], "roast": ["gene set", "limma"], "viper": ["regulon", "master regulator"], "spark": ["spatial"],
    "dpt": ["pseudotime"], "nmf": ["clustering", "signature", "subtype"], "timer": ["immune infiltration", "immune cell"],
    "epic-deconv": ["immune", "deconvolution"], "vegan": ["microbiome", "16S", "diversity"], "dep": ["proteomics", "mass spectrometry"],
    "homer": ["motif", "ChIP-seq", "ATAC-seq"], "macs": ["ChIP-seq", "ATAC-seq", "peak calling"], "sleuth": ["kallisto", "RNA-seq"],
    "presto": SC_CONTEXT, "csaw": ["ChIP-seq", "ATAC-seq"], "leiden": SC_CONTEXT, "umap": SC_CONTEXT, "tsne": SC_CONTEXT,
    "scds": ["doublet"], "dynamo": ["velocity", "single-cell"], "scenic": ["regulon", "transcription factor"],
    "singscore": ["gene set", "signature"], "decoupler": ["activity", "transcription factor"], "progeny": ["pathway activity"],
    "moransi": ["spatially variable", "spatial transcriptomics"], "sce": SC_CONTEXT, "kegg": ["pathway", "enrichment"],
    "spatial-seurat": ["spatial"],
}


def epmc_fragment(entry: dict) -> str:
    """The Europe PMC section-query fragment of a lexicon entry (phrases ORed, context terms ANDed)."""
    phrases = PHRASES.get(entry["token"]) or [entry["name"]]
    ok = re.compile(r"^[A-Za-z0-9 .+\-:']+$")
    for phrase in phrases:
        if not ok.match(phrase):
            raise SystemExit(f"{entry['token']}: EPMC phrase {phrase!r} needs an explicit PHRASES entry")
    fragment = " OR ".join('METHODS:"%s"' % p for p in phrases)
    if len(phrases) > 1:
        fragment = "(" + fragment + ")"
    context = CONTEXT.get(entry["token"], [])
    if context:
        fragment += " AND (" + " OR ".join('METHODS:"%s"' % c for c in context) + ")"
    return "(" + fragment + ")"


def _entries() -> list[dict]:
    seen: set[str] = set()
    out = []
    for token, name, family, kind, eco, pkg, modules, regex, ci, exclusion, note in _ROWS:
        if token in seen:
            raise SystemExit(f"duplicate token {token}")
        seen.add(token)
        if regex is None:
            regex = r"\b" + re.escape(name) + r"\b"
        re.compile(regex)
        kind = "method" if kind == "method" else "package"  # "software" and "package" are both tools
        out.append({"token": token, "name": name, "family": family, "kind": kind, "ecosystem": eco, "regex": regex,
                    "case_insensitive": bool(ci), "lock_package": pkg, "our_module": list(modules),
                    "rank_eligible": exclusion is None, "exclusion": exclusion, "licence_note": note})
    return out


def _locks() -> tuple[set[str], set[str], str, str]:
    def read(path: Path) -> bytes:
        return path.read_bytes()
    r_path, p_path = REPO / "env" / "pkg_lock.csv", REPO / "env" / "py" / "py_installed.csv"
    r_names = {row["package"] for row in csv.DictReader(r_path.read_text(encoding="utf-8").splitlines())}
    p_names = {row["package"].lower() for row in csv.DictReader(p_path.read_text(encoding="utf-8").splitlines())}
    return r_names, p_names, hashlib.sha256(read(r_path)).hexdigest(), hashlib.sha256(read(p_path)).hexdigest()


def build() -> dict:
    r_names, p_names, r_sha, p_sha = _locks()
    method_map = json.loads((HERE / "app" / "method_map.json").read_text(encoding="utf-8"))
    modules = {m["module"] for m in method_map["modules"]}
    entries = _entries()
    for e in entries:
        bad = [m for m in e["our_module"] if m not in modules]
        if bad:
            raise SystemExit(f"{e['token']}: unknown module {bad}")
        pkg = e.pop("lock_package")
        if pkg is None:
            e["in_pkg_lock"] = False
        elif pkg.startswith("R:"):
            e["in_pkg_lock"] = pkg[2:] in r_names
        else:
            e["in_pkg_lock"] = pkg[3:].lower() in p_names
        e["lock_package"] = pkg
    for e in entries:
        e["epmc_query"] = epmc_fragment(e) if e["rank_eligible"] else None
    entries.sort(key=lambda e: e["token"])
    families = sorted({e["family"] for e in entries})
    return {"schema": SCHEMA, "version": VERSION,
            "note": "Omics packages and omics method names only (clinical statistics are out of scope). Used to count co-occurring methods in Methods text (token only, never a snippet) and to probe Europe PMC section-level hit counts. A token is a candidate for coverage ranking only when rank_eligible is true and our_module is empty.",
            "scope": "omics packages (Bioconductor/CRAN/PyPI/GitHub) and omics method names",
            "sources": {"env/pkg_lock.csv": r_sha, "env/py/py_installed.csv": p_sha, "method_map_modules": len(modules)},
            "families": families, "entries": entries}


def encoded(doc: dict) -> str:
    return json.dumps(doc, ensure_ascii=False, indent=1, sort_keys=True) + "\n"


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--check", action="store_true")
    args = ap.parse_args()
    text = encoded(build())
    if args.check:
        current = OUT.read_text(encoding="utf-8") if OUT.exists() else ""
        if current != text:
            print("method_lexicon.json is stale: run python build_lexicon.py", file=sys.stderr)
            return 1
        print("method_lexicon.json is current")
        return 0
    OUT.write_text(text, encoding="utf-8", newline="\n")
    doc = json.loads(text)
    print(f"{OUT.name}: {len(doc['entries'])} entries, {len(doc['families'])} families")
    return 0


if __name__ == "__main__":
    sys.exit(main())
