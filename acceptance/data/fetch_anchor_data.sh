#!/usr/bin/env bash
# fetch_anchor_data.sh -- download the public anchor datasets used by module
# smoke tests (PACK section C) that are NOT shipped inside an R package, and
# verify each file's sha256. The files are git-ignored; tests SKIP (never
# FAIL) when a file is absent. Which module uses which file, and every
# package-embedded / on-demand dataset: ANCHOR_REGISTRY.md (same directory).
#   bash acceptance/data/fetch_anchor_data.sh            # everything (~282 MB)
#   bash acceptance/data/fetch_anchor_data.sh sc bulk    # only these groups
# Groups: 10x bulk sc hub. Every sha256 below was computed from a real
# download on 2026-09-27; a mismatch stops the script (set -e).
set -euo pipefail
cd "$(dirname "$0")"
GROUPS_WANTED="${*:-}"
fetch() {  # <group> <file> <url> <sha256>
  [[ -z "$GROUPS_WANTED" || " $GROUPS_WANTED " == *" $1 "* ]] || return 0
  if [[ ! -f "$2" ]]; then
    curl -fsSL --retry 3 "$3" -o "$2.part"
    mv -f "$2.part" "$2"
  fi
  echo "$4  $2" | sha256sum -c -
}

## --- 10x: Seurat / OSCA tutorial PBMCs (10x Genomics public datasets on AWS S3,
##     the host that cf.10xgenomics.com redirects to) --------------------------
# pbmc3k: seurat-qc / seurat-cluster / seurat-markers / seurat-modulescore
fetch 10x pbmc3k_filtered_gene_bc_matrices.tar.gz \
  https://s3-us-west-2.amazonaws.com/10x.files/samples/cell/pbmc3k/pbmc3k_filtered_gene_bc_matrices.tar.gz \
  847d6ebd9a1ec9a768f2be7e40ca42cbfe75ebeb6d76a4c24167041699dc28b5
# pbmc4k: OSCA clustering / marker chapters (same data as TENxPBMCData "pbmc4k", EH1611)
fetch 10x pbmc4k_filtered_gene_bc_matrices.tar.gz \
  https://s3-us-west-2.amazonaws.com/10x.files/samples/cell/pbmc4k/pbmc4k_filtered_gene_bc_matrices.tar.gz \
  87fe6bed5cd3a764a2e01a3fda30bb04dccb138b694c0c255645a0170123ee42

## --- bulk: edgeR / limma user guides and workflows ---------------------------
# GEO GSE60450 (Mus musculus, 12 samples): edgeR User's Guide case study 4.4 and the
# edgeR QL workflow (Chen, Lun, Smyth 2016)                           -> edger-qlf
fetch bulk GSE60450_Lactation-GenewiseCounts.txt.gz \
  https://ftp.ncbi.nlm.nih.gov/geo/series/GSE60nnn/GSE60450/suppl/GSE60450_Lactation-GenewiseCounts.txt.gz \
  906b6ec4c33e95ca0ba454a3e0d07ad74e9cb7528ee38b89a9b122f5674a5f0d
# GEO GSE63310 (Mus musculus, 11 samples): RNAseq123 workflow -> limma-voom, limma-camera
fetch bulk GSE63310_RAW.tar \
  https://ftp.ncbi.nlm.nih.gov/geo/series/GSE63nnn/GSE63310/suppl/GSE63310_RAW.tar \
  d2567b6753711e86820acbed4a4786ea1c57c59212503a8622b56982bcd53e44
# GEO GSE33005 = ArrayExpress E-GEOD-33005 (Rattus norvegicus, Agilent 8x60K, 19 arrays):
# limma User's Guide case study 17.4 (the guide downloads the same raw files
# from ArrayExpress; the SDRF is its targets file)                     -> limma-array
fetch bulk GSE33005_RAW.tar \
  https://ftp.ncbi.nlm.nih.gov/geo/series/GSE33nnn/GSE33005/suppl/GSE33005_RAW.tar \
  3d094f4dc7a771d54d9efff7c67c12dcbdf06e036220132719515ab246e70d92
fetch bulk E-GEOD-33005.sdrf.txt \
  https://www.ebi.ac.uk/biostudies/files/E-GEOD-33005/E-GEOD-33005.sdrf.txt \
  a2e13071c73023ed6b4762d003f2748df97016c184235d22c7b2316838e1fb25
# limma User's Guide case study 17.3 (Illumina BeadChips; GEO GSE16997), files as
# served by WEHI (the file names contain spaces upstream)              -> limma-dupcor
fetch bulk limma_IlluminaCaseStudy_probe_profile.txt.gz \
  "https://bioinf.wehi.edu.au/marray/IlluminaCaseStudy/probe%20profile.txt.gz" \
  6493d66dabb22fbd11023c5f412482edd972ad222fea3865d530335905cda0ed
fetch bulk limma_IlluminaCaseStudy_control_probe_profile.txt.gz \
  "https://bioinf.wehi.edu.au/marray/IlluminaCaseStudy/control%20probe%20profile.txt.gz" \
  1ce713157988d8bfb195c93b08c079aa63daf25ae95e817d2bff797e24423ba9
fetch bulk limma_IlluminaCaseStudy_Targets.txt \
  https://bioinf.wehi.edu.au/marray/IlluminaCaseStudy/Targets.txt \
  8a52b386e482ba0f686e0b4c57c2fd593621dbfeae9b72f64dc512b26f337ddb
# limma User's Guide case study 18.1 (Yoruba HapMap RNA-seq, DGEList y) + gene sets
# (msYgenes, XiEgenes)                                   -> limma-camera (+ limma-dupcor, voom block)
fetch bulk limma_Yoruba.RData \
  https://bioinf.wehi.edu.au/limma/data/Yoruba.RData \
  62abb9669bf545e70bfa4abf3a8e99a86d49f35b8bd0ef7801deb8db0486a01b
fetch bulk limma_GenderGenes.RData \
  https://bioinf.wehi.edu.au/software/GenderGenes/GenderGenes.RData \
  ad2e78f108281864be9a9fdc2b686068f24b785158bc8782ac03d510938ea493

## --- sc: single-cell files not in any Bioconductor package ------------------
# GEO GSE60361 (Zeisel 2015, Mus musculus, 3005 cells): AUCell vignette  -> aucell-score
fetch sc GSE60361_C1-3005-Expression.txt.gz \
  https://ftp.ncbi.nlm.nih.gov/geo/series/GSE60nnn/GSE60361/suppl/GSE60361_C1-3005-Expression.txt.gz \
  dd09532c73822b632b1914356bfca8e186aff2300b30299e066a6105205e5c4c
# CellBench single_cell_data.RData (3 cell-line mixtures: 10x/CEL-seq2/Drop-seq), the file
# CellBench::load_sc_data() downloads; pinned to commit e548bbb of Shians/scBenchData
#                                                                       -> speckle-propeller
fetch sc CellBench_single_cell_data.RData \
  https://raw.githubusercontent.com/Shians/scBenchData/e548bbb5497b8bdedf641b33dfbfb81d260d6cf3/single_cell_data.RData \
  60a335a36be2b4e5de61b1bf6ff6c1fd542347f9337551a2a01b01d96505812b
# figshare 10.6084/m9.figshare.24470719.v1 (CC BY 4.0), human skin atopic dermatitis;
# CellChat tutorial "CellChat-vignette" input (md5 9d31f4c8... as listed by figshare)
#                                                                       -> cellchat-communication
fetch sc CellChat_data_humanSkin_CellChat.rda \
  https://ndownloader.figshare.com/files/42997198 \
  c062532981d49145dbdbbec01e352ac291b483bd5ad203c9109ceadc892e0d9b
# monocle3 "Constructing single-cell trajectories" tutorial: Packer et al. 2019 C. elegans
# embryo, as served by the Trapnell lab                                 -> monocle3-trajectory
fetch sc monocle3_packer_embryo_expression.rds \
  https://depts.washington.edu/trapnell-lab/software/monocle3/celegans/data/packer_embryo_expression.rds \
  1d0460a8dba5967972791ad47b4ae93b8ff25b78f6ab3f1ea08a451f0ebbbbc1
fetch sc monocle3_packer_embryo_colData.rds \
  https://depts.washington.edu/trapnell-lab/software/monocle3/celegans/data/packer_embryo_colData.rds \
  6b8a25a5d74eddf84f32503d81f40162b05ef565af037e8eb79b9f36bd9b75a4
fetch sc monocle3_packer_embryo_rowData.rds \
  https://depts.washington.edu/trapnell-lab/software/monocle3/celegans/data/packer_embryo_rowData.rds \
  beffa9762e912161bf8416e5a8e4afd9f368e04847355dcd11e4038bf869d111

## --- hub: ExperimentHub resources, fetched directly from the hub bucket so the
##     tests run offline (ids/paths from experimenthub.sqlite3, 2026-09-27) --------
EH=https://mghp.osn.xsede.org/bir190004-bucket01/ExperimentHub
# scRNAseq::ZeiselBrainData() (EH2580-2582): scater/scuttle vignettes  -> scater-qc, batchelor-integrate
fetch hub EH2580_zeisel-brain_counts.rds  "$EH/scRNAseq/zeisel-brain/2.0.0/counts.rds" \
  4357e6850705c096c8c1276f32b415628dcc16c51ba2c61a36598948ca12a215
fetch hub EH2581_zeisel-brain_rowdata.rds "$EH/scRNAseq/zeisel-brain/2.0.0/rowdata.rds" \
  39ab99d7e8d1387103214b0be92a2e4acd83d46715f5b876dbc5d014c678fb12
fetch hub EH2582_zeisel-brain_coldata.rds "$EH/scRNAseq/zeisel-brain/2.0.0/coldata.rds" \
  652d0476cf3274d8d7804f5096b55580c6b298a2f4fa288f1d8934afad70405f
# scRNAseq::TasicBrainData() (EH2578-2579): batchelor vignette          -> batchelor-integrate
fetch hub EH2578_tasic-brain_counts.rds   "$EH/scRNAseq/tasic-brain/2.0.0/counts.rds" \
  cfb44779bc27f0de3eee8086f510afd2d31a8cf2e354c80c457a10b1c72c156c
fetch hub EH2579_tasic-brain_coldata.rds  "$EH/scRNAseq/tasic-brain/2.0.0/coldata.rds" \
  3c667abcb2b6af1371e43799d050a705a2a243050e21a743c84941c01791efb6
# scRNAseq::GrunPancreasData() (EH2687; colData is rebuilt from the column names by the
# package): scran + bluster vignettes, SingleR test set  -> scran-cluster, scran-markers, singler-annotate
fetch hub EH2687_grun-pancreas_counts.rds "$EH/scRNAseq/grun-pancreas/2.0.0/counts.rds" \
  237f99410659bb6614f2cbc2cd1fcb2a5d242230c97490c87f324a59bbac246d
# scRNAseq::MuraroPancreasData() (EH2692-2693): SingleR vignette reference -> singler-annotate
fetch hub EH2692_muraro-pancreas_counts.rds  "$EH/scRNAseq/muraro-pancreas/2.0.0/counts.rds" \
  c78a0281d1c48021c37925d8aad052a2a9baf28ead94531c52d94b61cd034f60
fetch hub EH2693_muraro-pancreas_coldata.rds "$EH/scRNAseq/muraro-pancreas/2.0.0/coldata.rds" \
  813dd8b393a5090d68c5aa650438faffc2d5041073bffe065c9db1e3c94719d1
# muscData Kang18_8vs8 (EH2259; GEO GSE96583): muscat vignette           -> muscat-pseudobulk
fetch hub EH2259_muscData_Kang18_8vs8.Rda "$EH/muscData/Kang18_8vs8.Rda" \
  b631d72139ad157cfc7530800268a4a9d1194f81dce0d2b387ca3d600acce485

## On demand only (not fetched here; see ANCHOR_REGISTRY.md "On demand"): WGCNA
## FemaleLiver-Data.zip (source host TLS certificate expired on 2026-09-27).

for d in pbmc3k pbmc4k; do
  [[ -f "${d}_filtered_gene_bc_matrices.tar.gz" ]] || continue
  [[ -d "$d" ]] || { mkdir -p "$d"; tar -xzf "${d}_filtered_gene_bc_matrices.tar.gz" -C "$d"; }
done
echo "anchor data OK"
