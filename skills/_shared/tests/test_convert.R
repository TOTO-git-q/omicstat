# test_convert.R -- tests for convert.R (Seurat <-> SingleCellExperiment <->
# AnnData) and the single-cell ecosystem additions of handoff.R.
# ASCII only. Run with: Rscript test_convert.R (any working directory).
# Same PASS/FAIL protocol as the other _shared tests.
# requires: SeuratObject Seurat SingleCellExperiment zellkonverter basilisk rhdf5 digest jsonlite
#
# Fixture: SeuratObject::pbmc_small (80 cells x 230 genes, a subsample of the
# real 10x pbmc3k data shipped in the locked package: integer counts,
# LogNormalize data, clusters RNA_snn_res.0.8 / RNA_snn_res.1, pca, tsne) plus a
# UMAP computed here and metadata columns that stress the carrying rules
# (non-alphabetical level order, an unused level, an ordered factor, logical,
# character).
# The AnnData lane needs the prebuilt anndata environment of the image. Where
# it is not reachable (the image builds it under /root; the router runs the
# container as the calling user) the AnnData round trips print SKIP and the
# typed refusal OS_ENV_MISSING is asserted instead. The 2026.10.1 fixed-path
# environment must exercise all lanes as a non-root user with zero skips.

here <- tryCatch({
  a <- commandArgs(trailingOnly = FALSE)
  f <- sub("^--file=", "", a[grep("^--file=", a)])
  if (length(f)) dirname(normalizePath(f)) else getwd()
}, error = function(e) getwd())
S <- file.path(here, "..", "scripts")
source(file.path(S, "handoff.R")); source(file.path(S, "convert.R"))

failures <- character(0); skips <- character(0)
check <- function(cond, msg) {
  if (isTRUE(cond)) cat(sprintf("PASS: %s\n", msg))
  else { cat(sprintf("FAIL: %s\n", msg)); failures <<- c(failures, msg) }
}
skip <- function(msg) { cat(sprintf("SKIP: %s\n", msg)); skips <<- c(skips, msg) }
err_code <- function(expr) tryCatch({ force(expr); "" }, error = function(e) sub(":.*$", "", conditionMessage(e)))
err_msg <- function(expr) tryCatch({ force(expr); "" }, error = function(e) conditionMessage(e))
options(warn = 1)
tmp <- file.path(tempdir(), "omicstat_convert_test"); unlink(tmp, recursive = TRUE); dir.create(tmp)

# ------------------------------------------------------------------ fixture
e <- new.env()
utils::data("pbmc_small", package = "SeuratObject", envir = e)
so <- suppressMessages(suppressWarnings(SeuratObject::UpdateSeuratObject(e$pbmc_small)))
so[["RNA"]] <- methods::as(so[["RNA"]], "Assay5")
so <- suppressMessages(suppressWarnings(Seurat::RunUMAP(so, dims = 1:10, n.neighbors = 30L, seed.use = 42L, umap.method = "uwot",
                                                         reduction = "pca", reduction.name = "umap", verbose = FALSE)))
md <- so[[]]
md$groups <- factor(md$groups, levels = c("g2", "g1"))
md$letter.idents <- factor(as.character(md$letter.idents), levels = c("B", "A", "Z"))
md$stage <- factor(ifelse(md$nCount_RNA > 150, "late", "early"), levels = c("late", "early"), ordered = TRUE)
md$flag <- md$nFeature_RNA > 50
md$sample <- paste0("s", rep(1:4, length.out = nrow(md)))
methods::slot(so, "meta.data") <- md
so <- SeuratObject::SetIdent(so, value = "RNA_snn_res.1")
CL <- "RNA_snn_res.1"
LAY_SO <- c(counts = "counts", logcounts = "data")
cat(sprintf("fixture: %d cells x %d genes; reductions %s; feature metadata columns %s\n", ncol(so), nrow(so),
            paste(SeuratObject::Reductions(so), collapse = ","), paste(names(so[["RNA"]][[]]), collapse = ",")))

emb_equal <- function(sce, so_obj) all(vapply(SeuratObject::Reductions(so_obj), function(r)
  identical(SingleCellExperiment::reducedDim(sce, r), SeuratObject::Embeddings(so_obj[[r]])), logical(1)))
# embeddings / SCE compared without non-dimension attributes of the embedding
# matrices (uwot's "scaled:center"): AnnData obsm holds coordinates only.
strip_emb <- function(x) { for (r in SingleCellExperiment::reducedDimNames(x)) { e <- SingleCellExperiment::reducedDim(x, r)
  attributes(e) <- attributes(e)[c("dim", "dimnames")]; SingleCellExperiment::reducedDim(x, r) <- e }; x }
emb_so <- function(o, r) { e <- SeuratObject::Embeddings(o[[r]]); attributes(e) <- attributes(e)[c("dim", "dimnames")]; e }
lay <- function(o, l) SeuratObject::LayerData(o, assay = "RNA", layer = l)

# ------------------------------------------------------- Seurat -> SCE
r1 <- os_sc_convert(so, to = "SingleCellExperiment", consumer = "back_end", layers = LAY_SO, cluster_col = CL, source_assay = "RNA")
sce <- r1$object
check(methods::is(sce, "SingleCellExperiment"), "S2B returns a SingleCellExperiment")
check(identical(as.integer(dim(sce)), as.integer(dim(so))), "S2B cell and gene counts unchanged")
check(identical(SummarizedExperiment::assayNames(sce), c("counts", "logcounts")), "S2B assays named by role (counts, logcounts)")
check(identical(SummarizedExperiment::assay(sce, "counts"), lay(so, "counts")), "S2B counts byte-identical (identical dgCMatrix)")
check(identical(SummarizedExperiment::assay(sce, "logcounts"), lay(so, "data")), "S2B logcounts identical to the Seurat data layer")
check(identical(as.data.frame(SummarizedExperiment::colData(sce), optional = TRUE), so[[]]), "S2B cell metadata identical (values, types, column order)")
check(identical(levels(sce$groups), c("g2", "g1")) && identical(levels(sce$letter.idents), c("B", "A", "Z")) && is.ordered(sce$stage),
      "S2B level order, unused level and ordered flag carried")
check(identical(sce[[CL]], so[[]][[CL]]), "S2B cluster labels identical")
check(identical(SingleCellExperiment::reducedDimNames(sce), c("pca", "tsne", "umap")), "S2B reduction names carried as they are")
check(emb_equal(sce, so), "S2B embeddings identical incl. column names")
check(identical(as.data.frame(SummarizedExperiment::rowData(sce), optional = TRUE), so[["RNA"]][[]]), "S2B feature metadata identical")
st <- r1$step
check(identical(st$content_sha256_before, st$content_sha256_after) && nchar(st$content_sha256_before) == 64, "S2B provenance: content hash before == after")
check(identical(st$from, "Seurat") && identical(st$to, "SingleCellExperiment") && identical(st$source$assay, "RNA") &&
        identical(unlist(st$source$layers), LAY_SO) && identical(st$function_name, "os_sc_convert") && length(st$implementation) >= 1,
      "S2B provenance: function, source assay and layers recorded")
check(nchar(st$source$sha256) == 64 && nchar(st$target$sha256) == 64, "S2B provenance: source and target object hashes recorded")
check(any(grepl("scale.data", st$not_carried)) && any(grepl("graph RNA_snn", st$not_carried)), "S2B provenance: not-carried parts listed (scale.data, graph)")
js <- jsonlite::toJSON(st, auto_unbox = TRUE, null = "null", na = "null", digits = I(10))
check(jsonlite::validate(js), "S2B provenance step serialises to JSON")

# ------------------------------------------------------- SCE -> Seurat
r2 <- os_sc_convert(sce, to = "Seurat", consumer = "back_end", layers = c(counts = "counts", logcounts = "logcounts"),
                    cluster_col = CL, target_assay = "RNA")
so2 <- r2$object
check(methods::is(so2, "Seurat") && identical(dim(so2), dim(so)), "B2S returns a Seurat object with the same dimensions")
check(identical(SeuratObject::Layers(so2[["RNA"]]), c("counts", "data")), "B2S layers counts and data")
check(identical(lay(so2, "counts"), lay(so, "counts")) && identical(lay(so2, "data"), lay(so, "data")), "B2S round trip: counts and data byte-identical")
check(identical(so2[[]], so[[]]), "B2S round trip: cell metadata identical (incl. level order)")
check(identical(so2[["RNA"]][[]], so[["RNA"]][[]]), "B2S round trip: feature metadata identical")
check(all(vapply(SeuratObject::Reductions(so), function(r) identical(SeuratObject::Embeddings(so2[[r]]), SeuratObject::Embeddings(so[[r]])) &&
                   identical(SeuratObject::Key(so2[[r]]), SeuratObject::Key(so[[r]])), logical(1))) &&
        identical(SeuratObject::Reductions(so2), SeuratObject::Reductions(so)), "B2S round trip: reductions, keys and embeddings identical")
check(identical(as.character(SeuratObject::Idents(so2)), as.character(so[[]][[CL]])) && identical(levels(SeuratObject::Idents(so2)), levels(so[[]][[CL]])),
      "B2S identities set from cluster_col")
r3 <- os_sc_convert(so2, to = "SingleCellExperiment", consumer = "back_end", layers = LAY_SO, cluster_col = CL, source_assay = "RNA")
check(identical(r3$object, sce), "S2B2S2B: second SCE identical() to the first")

# non-Seurat-style embedding column names survive SCE -> Seurat -> SCE
sce_b <- sce
um <- SingleCellExperiment::reducedDim(sce_b, "umap"); colnames(um) <- c("UMAP1", "UMAP2")
SingleCellExperiment::reducedDim(sce_b, "UMAP_custom") <- um
SingleCellExperiment::reducedDim(sce_b, "noname") <- unname(um)
rb <- os_sc_convert(os_sc_convert(sce_b, to = "Seurat", consumer = "back_end", layers = c(counts = "counts", logcounts = "logcounts"),
                                  cluster_col = CL, target_assay = "RNA")$object,
                    to = "SingleCellExperiment", consumer = "back_end", layers = LAY_SO, cluster_col = CL, source_assay = "RNA")
check(identical(SingleCellExperiment::reducedDims(rb$object), SingleCellExperiment::reducedDims(sce_b)),
      "B2S2B: embeddings with free-form / missing column names come back unchanged")

# identity canonicalisation: extra assays dropped and listed
sce_x <- sce; SummarizedExperiment::assay(sce_x, "scaled") <- SummarizedExperiment::assay(sce, "logcounts") * 2
S4Vectors::metadata(sce_x)$note <- "x"
ri <- os_sc_convert(sce_x, to = "SingleCellExperiment", consumer = "front_end", layers = c(counts = "counts", logcounts = "logcounts"), cluster_col = CL)
check(identical(ri$object, sce), "B2B identity: canonical SCE (extra assay dropped) equals the converted one; allowed for front ends")
check(all(c("assay scaled", "metadata note") %in% ri$step$not_carried), "B2B identity: dropped assay and metadata listed as not carried")

# counts only / logcounts only
rc <- os_sc_convert(so, to = "SingleCellExperiment", consumer = "back_end", layers = c(counts = "counts"), cluster_col = CL, source_assay = "RNA")
check(identical(SummarizedExperiment::assayNames(rc$object), "counts"), "S2B with the counts role only")
rl <- os_sc_convert(sce, to = "Seurat", consumer = "back_end", layers = c(logcounts = "logcounts"), cluster_col = CL, target_assay = "RNA")
check(identical(SeuratObject::Layers(rl$object[["RNA"]]), "data") && identical(lay(rl$object, "data"), lay(so, "data")), "B2S with the logcounts role only")

# determinism
r1b <- os_sc_convert(so, to = "SingleCellExperiment", consumer = "back_end", layers = LAY_SO, cluster_col = CL, source_assay = "RNA")
check(identical(r1b$object, r1$object) && identical(jsonlite::toJSON(r1b$step, auto_unbox = TRUE, digits = I(10)), jsonlite::toJSON(r1$step, auto_unbox = TRUE, digits = I(10))),
      "determinism: repeated conversion gives identical object and provenance step")

# ------------------------------------------------ handoff entries and files
up <- file.path(tmp, "run_sc"); dir.create(file.path(up, "objects"), recursive = TRUE)
saveRDS(so, file.path(up, "objects", "seurat.rds"))
write_handoff(up, "run-0100", "seurat-cluster", "1.0.0", list(obj = list(path = file.path(up, "objects", "seurat.rds"), type = "Seurat")),
              ecosystem = "seurat")
h <- read_handoff(up, expect = list(obj = "Seurat"))
rh <- os_sc_convert(h$objects$obj, to = "SingleCellExperiment", consumer = "back_end", layers = LAY_SO, cluster_col = CL, source_assay = "RNA")
check(identical(rh$object, sce) && identical(rh$step$source$sha256, h$objects$obj$sha256) && identical(rh$step$source$file, "seurat.rds"),
      "handoff entry: converted from the rds, source sha256 = handoff sha256")
bad_entry <- h$objects$obj; bad_entry$type <- "SingleCellExperiment"
check(identical(err_code(os_sc_convert(bad_entry, to = "Seurat", consumer = "back_end", layers = LAY_SO, cluster_col = CL, target_assay = "RNA")), "OS_HANDOFF_MISMATCH"),
      "handoff entry with the wrong type -> OS_HANDOFF_MISMATCH")
bad_entry <- h$objects$obj; bad_entry$sha256 <- strrep("0", 64)
check(identical(err_code(os_sc_convert(bad_entry, to = "SingleCellExperiment", consumer = "back_end", layers = LAY_SO, cluster_col = CL, source_assay = "RNA")), "OS_HANDOFF_MISMATCH"),
      "handoff entry with a stale sha256 -> OS_HANDOFF_MISMATCH")
saveRDS(sce, file.path(tmp, "sce.rds"))
rp <- os_sc_convert(file.path(tmp, "sce.rds"), to = "Seurat", consumer = "back_end", layers = c(counts = "counts", logcounts = "logcounts"), cluster_col = CL, target_assay = "RNA")
check(identical(lay(rp$object, "counts"), lay(so, "counts")) && identical(rp$step$source$sha256, digest::digest(file = file.path(tmp, "sce.rds"), algo = "sha256")),
      ".rds path source: converted, file sha256 recorded")

# ------------------------------------------------------------- AnnData lane
ad_ready <- identical(err_code(.os_sc_require_anndata_env()), "")
if (!ad_ready) {
  skip(sprintf("AnnData round trips: %s", err_msg(.os_sc_require_anndata_env())))
  check(identical(err_code(os_sc_convert(so, to = "AnnData", consumer = "back_end", layers = LAY_SO, cluster_col = CL, source_assay = "RNA",
                                         x_role = "logcounts", file = file.path(tmp, "a.h5ad"))), "OS_ENV_MISSING"),
        "AnnData without the prebuilt environment -> OS_ENV_MISSING (never a download)")
} else {
  tagged <- so
  tagged@misc$omicstat_state <- list(front_end_ecosystem="seurat",batch_corrected_lineage=TRUE)
  state_file <- file.path(tmp,"lineage.h5ad")
  os_sc_convert(tagged,to="AnnData",consumer="back_end",layers=LAY_SO,cluster_col=CL,source_assay="RNA",x_role="logcounts",file=state_file)
  state_back <- os_sc_convert(state_file,to="SingleCellExperiment",consumer="back_end",layers=c(counts="counts",logcounts="X"),cluster_col=CL)$object
  check(identical(S4Vectors::metadata(state_back)$omicstat,tagged@misc$omicstat_state),"Seurat -> AnnData -> SCE preserves ecosystem and corrected lineage")
  state_seurat <- os_sc_convert(state_back,to="Seurat",consumer="back_end",layers=c(counts="counts",logcounts="logcounts"),cluster_col=CL,target_assay="RNA")$object
  check(identical(state_seurat@misc$omicstat_state,tagged@misc$omicstat_state),"SCE -> Seurat preserves embedded scientific state")
  f1 <- file.path(tmp, "from_seurat.h5ad")
  ra <- os_sc_convert(so, to = "AnnData", consumer = "back_end", layers = LAY_SO, cluster_col = CL, source_assay = "RNA", x_role = "logcounts", file = f1)
  check(file.exists(f1) && identical(ra$object, normalizePath(f1, winslash = "/")), "S2A writes the .h5ad and returns its path")
  check(identical(ra$step$target$sha256, digest::digest(file = f1, algo = "sha256")) && identical(unlist(ra$step$target$layers), c(counts = "counts", logcounts = "X")) &&
          identical(ra$step$content_sha256_before, ra$step$content_sha256_after) && identical(ra$step$anndata, OS_SC_ANNDATA_VERSION),
        "S2A provenance: file sha256, X/layer mapping, content hash before == after, anndata version")
  rab <- os_sc_convert(f1, to = "SingleCellExperiment", consumer = "back_end", layers = c(counts = "counts", logcounts = "X"), cluster_col = CL)
  check(identical(rab$object, strip_emb(sce)), "S2A2B: SCE read back from the h5ad identical() to the direct Seurat -> SCE conversion (embedding attributes aside)")
  check(is.character(rab$object$sample) && is.character(SummarizedExperiment::rowData(rab$object)$var.features), "S2A2B: character columns come back as character")
  check(identical(levels(rab$object$groups), c("g2", "g1")) && identical(levels(rab$object$letter.idents), c("B", "A", "Z")) && is.ordered(rab$object$stage),
        "S2A2B: level order, unused level and ordered flag survive the h5ad")
  ras <- os_sc_convert(f1, to = "Seurat", consumer = "back_end", layers = c(counts = "counts", logcounts = "X"), cluster_col = CL, target_assay = "RNA")
  check(identical(lay(ras$object, "counts"), lay(so, "counts")) && identical(lay(ras$object, "data"), lay(so, "data")) && identical(ras$object[[]], so[[]]) &&
          all(vapply(SeuratObject::Reductions(so), function(r) identical(emb_so(ras$object, r), emb_so(so, r)), logical(1))),
        "S2A2S: counts, data, metadata and embeddings identical after Seurat -> AnnData -> Seurat")
  f2 <- file.path(tmp, "from_sce.h5ad")
  rb2 <- os_sc_convert(sce, to = "AnnData", consumer = "back_end", layers = c(counts = "counts", logcounts = "logcounts"), cluster_col = CL, x_role = "counts", file = f2)
  rbb <- os_sc_convert(f2, to = "SingleCellExperiment", consumer = "back_end", layers = c(counts = "X", logcounts = "logcounts"), cluster_col = CL)
  check(identical(rbb$object, strip_emb(sce)), "B2A2B with counts in X: SCE identical() after the round trip (embedding attributes aside)")
  check(identical(SingleCellExperiment::reducedDimNames(rbb$object), c("pca", "tsne", "umap")), "B2A2B: obsm names carried as they are")
  edge <- sce
  edge$one_level <- factor(rep(NA_character_, ncol(edge)), levels = "unused", ordered = TRUE)
  SummarizedExperiment::rowData(edge)$one_level <- factor(rep("one", nrow(edge)), levels = "one")
  SingleCellExperiment::reducedDims(edge) <- SingleCellExperiment::reducedDims(edge)[c("umap", "pca", "tsne")]
  ef <- file.path(tmp, "embedding_order_single_factor.h5ad")
  os_sc_convert(edge, to = "AnnData", consumer = "back_end", layers = c(counts = "counts", logcounts = "logcounts"), cluster_col = CL, x_role = "counts", file = ef)
  er <- os_sc_convert(ef, to = "SingleCellExperiment", consumer = "back_end", layers = c(counts = "X", logcounts = "logcounts"), cluster_col = CL)
  check(identical(er$object, strip_emb(edge)), "B2A2B preserves non-alphabetical embedding order and singleton/unused factor levels")
  check(identical(as.character(rhdf5::h5read(ef, "obs/one_level/categories")), "unused") &&
          identical(as.character(rhdf5::h5read(ef, "var/one_level/categories")), "one"),
        "H5AD native categorical datasets retain exactly the original singleton levels")
  for (axis in c("feature", "cell")) {
    tiny <- if (axis == "feature") edge[1L, ] else edge[, 1L]
    SummarizedExperiment::assays(tiny) <- SummarizedExperiment::assays(tiny)["counts"]
    tf <- file.path(tmp, paste0("singleton_", axis, ".h5ad"))
    os_sc_convert(tiny, to = "AnnData", consumer = "back_end", layers = c(counts = "counts"), cluster_col = CL, x_role = "counts", file = tf)
    tr <- os_sc_convert(tf, to = "SingleCellExperiment", consumer = "back_end", layers = c(counts = "X"), cluster_col = CL)
    check(identical(tr$object, strip_emb(tiny)), paste("B2A2B singleton", axis, "axis preserves IDs, values, metadata and embeddings"))
  }
  # an h5ad written elsewhere (no omicstat marker in uns): string columns are
  # anndata categoricals and arrive as factors, as they are in the file
  f3 <- file.path(tmp, "foreign.h5ad"); invisible(file.copy(f1, f3))
  rhdf5::h5delete(f3, paste0("uns/", OS_SC_UNS_KEY))
  rf <- os_sc_convert(f3, to = "SingleCellExperiment", consumer = "back_end", layers = c(counts = "counts", logcounts = "X"), cluster_col = CL)
  check(is.factor(rf$object$sample) && identical(levels(rf$object$sample), sort(unique(md$sample))) && identical(as.character(rf$object$sample), md$sample) &&
          identical(SummarizedExperiment::assay(rf$object, "counts"), lay(so, "counts")),
        "foreign h5ad: categoricals arrive as factors, counts identical")
  # handoff entry of type AnnData
  ua <- file.path(tmp, "run_ad"); dir.create(file.path(ua, "objects"), recursive = TRUE)
  invisible(file.copy(f1, file.path(ua, "objects", "adata.h5ad")))
  write_handoff(ua, "run-0300", "scanpy-cluster", "1.0.0", list(adata = list(path = file.path(ua, "objects", "adata.h5ad"), type = "AnnData")), ecosystem = "scverse")
  ha <- read_handoff(ua, expect = list(adata = "AnnData"))
  rha <- os_sc_convert(ha$objects$adata, to = "SingleCellExperiment", consumer = "back_end", layers = c(counts = "counts", logcounts = "X"), cluster_col = CL)
  check(identical(rha$object, strip_emb(sce)) && identical(rha$step$from_ecosystem, "scverse"), "AnnData handoff entry (ecosystem scverse) -> SCE for a back-end module")
  check(identical(err_code(os_sc_convert(ha$objects$adata, to = "SingleCellExperiment", consumer = "front_end", layers = c(counts = "counts", logcounts = "X"), cluster_col = CL)), "OS_ECOSYSTEM_MIXED"),
        "AnnData -> SCE for a Bioconductor front-end module -> OS_ECOSYSTEM_MIXED")
  check(identical(err_code(os_sc_convert(f1, to = "SingleCellExperiment", consumer = "back_end", layers = c(counts = "raw_counts", logcounts = "X"), cluster_col = CL)), "OS_CONVERT_LAYER_MISSING"),
        "AnnData layer that does not exist -> OS_CONVERT_LAYER_MISSING")
  check(identical(err_code(os_sc_convert(f1, to = "AnnData", consumer = "back_end", layers = c(logcounts = "X"), cluster_col = CL, x_role = "logcounts", file = file.path(tmp, "b.h5ad"))), "OS_CONVERT_UNSUPPORTED"),
        "AnnData -> AnnData -> OS_CONVERT_UNSUPPORTED")
  old <- Sys.getenv("BASILISK_EXTERNAL_DIR", NA)
  Sys.setenv(BASILISK_EXTERNAL_DIR = file.path(tmp, "no_basilisk"))
  check(identical(err_code(os_sc_convert(so, to = "AnnData", consumer = "back_end", layers = LAY_SO, cluster_col = CL, source_assay = "RNA", x_role = "logcounts", file = file.path(tmp, "c.h5ad"))), "OS_ENV_MISSING") &&
          !dir.exists(file.path(tmp, "no_basilisk")), "AnnData without the prebuilt environment -> OS_ENV_MISSING before basilisk touches anything")
  if (is.na(old)) Sys.unsetenv("BASILISK_EXTERNAL_DIR") else Sys.setenv(BASILISK_EXTERNAL_DIR = old)
}

# ------------------------------------------------------------ typed errors
conv <- function(...) err_code(os_sc_convert(...))
check(identical(conv(so, to = "SingleCellExperiment", consumer = "back_end", cluster_col = CL, source_assay = "RNA"), "OS_MISSING_PARAMETER"), "no layers named -> OS_MISSING_PARAMETER")
check(identical(conv(so, to = "SingleCellExperiment", consumer = "back_end", layers = c(raw = "counts"), cluster_col = CL, source_assay = "RNA"), "OS_INVALID_PARAMETER"), "unknown role -> OS_INVALID_PARAMETER")
check(identical(conv(so, to = "SingleCellExperiment", consumer = "back_end", layers = "counts", cluster_col = CL, source_assay = "RNA"), "OS_INVALID_PARAMETER"), "unnamed layers -> OS_INVALID_PARAMETER")
check(identical(conv(so, to = "loom", consumer = "back_end", layers = LAY_SO, cluster_col = CL, source_assay = "RNA"), "OS_INVALID_PARAMETER"), "unknown target type -> OS_INVALID_PARAMETER")
check(identical(conv(so, to = "SingleCellExperiment", layers = LAY_SO, cluster_col = CL, source_assay = "RNA"), "OS_MISSING_PARAMETER"), "no consumer -> OS_MISSING_PARAMETER")
check(identical(conv(so, to = "SingleCellExperiment", consumer = "back_end", layers = LAY_SO, cluster_col = CL), "OS_MISSING_PARAMETER"), "Seurat source without source_assay -> OS_MISSING_PARAMETER")
check(identical(conv(sce, to = "Seurat", consumer = "back_end", layers = c(counts = "counts"), cluster_col = CL), "OS_MISSING_PARAMETER"), "Seurat target without target_assay -> OS_MISSING_PARAMETER")
check(identical(conv(sce, to = "AnnData", consumer = "back_end", layers = c(counts = "counts"), cluster_col = CL, x_role = "counts"), "OS_MISSING_PARAMETER"), "AnnData target without file -> OS_MISSING_PARAMETER")
check(identical(conv(sce, to = "AnnData", consumer = "back_end", layers = c(counts = "counts"), cluster_col = CL, file = file.path(tmp, "d.h5ad")), "OS_MISSING_PARAMETER"), "AnnData target without x_role -> OS_MISSING_PARAMETER")
check(identical(conv(sce, to = "AnnData", consumer = "back_end", layers = c(counts = "counts"), cluster_col = CL, x_role = "logcounts", file = file.path(tmp, "d.h5ad")), "OS_INVALID_PARAMETER"), "x_role not among the roles -> OS_INVALID_PARAMETER")
check(identical(conv(list(a = 1), to = "Seurat", consumer = "back_end", layers = LAY_SO, cluster_col = CL, target_assay = "RNA"), "OS_INVALID_INPUT"), "not a single-cell object -> OS_INVALID_INPUT")
saveRDS(data.frame(a = 1), file.path(tmp, "df.rds"))
check(identical(conv(file.path(tmp, "df.rds"), to = "Seurat", consumer = "back_end", layers = LAY_SO, cluster_col = CL, target_assay = "RNA"), "OS_INVALID_INPUT"), ".rds without a single-cell object -> OS_INVALID_INPUT")
check(identical(conv(so, to = "SingleCellExperiment", consumer = "back_end", layers = LAY_SO, cluster_col = CL, source_assay = "SCT"), "OS_CONVERT_LAYER_MISSING"), "Seurat assay that does not exist -> OS_CONVERT_LAYER_MISSING")
check(identical(conv(so, to = "SingleCellExperiment", consumer = "back_end", layers = c(counts = "counts", logcounts = "lognorm"), cluster_col = CL, source_assay = "RNA"), "OS_CONVERT_LAYER_MISSING"), "Seurat layer that does not exist -> OS_CONVERT_LAYER_MISSING")
so_split <- so; so_split[["RNA"]] <- split(so_split[["RNA"]], f = so_split$sample)
m_split <- err_msg(os_sc_convert(so_split, to = "SingleCellExperiment", consumer = "back_end", layers = LAY_SO, cluster_col = CL, source_assay = "RNA"))
check(startsWith(m_split, "OS_CONVERT_LAYER_MISSING") && grepl("JoinLayers", m_split), "split Seurat layers -> OS_CONVERT_LAYER_MISSING naming JoinLayers")
check(identical(conv(sce, to = "Seurat", consumer = "back_end", layers = c(counts = "raw"), cluster_col = CL, target_assay = "RNA"), "OS_CONVERT_LAYER_MISSING"), "SCE assay that does not exist -> OS_CONVERT_LAYER_MISSING")
check(identical(conv(so, to = "SingleCellExperiment", consumer = "back_end", layers = c(counts = "data"), cluster_col = CL, source_assay = "RNA"), "OS_CONVERT_LAYER_ROLE"), "normalised layer named as counts -> OS_CONVERT_LAYER_ROLE")
check(identical(conv(so, to = "SingleCellExperiment", consumer = "back_end", layers = c(counts = "counts", logcounts = "counts"), cluster_col = CL, source_assay = "RNA"), "OS_CONVERT_LAYER_ROLE"), "logcounts equal to counts -> OS_CONVERT_LAYER_ROLE")
check(identical(conv(so, to = "SingleCellExperiment", consumer = "back_end", layers = c(logcounts = "counts"), cluster_col = CL, source_assay = "RNA"), "OS_CONVERT_LAYER_ROLE"), "raw counts named as logcounts -> OS_CONVERT_LAYER_ROLE")
check(identical(conv(so, to = "SingleCellExperiment", consumer = "back_end", layers = LAY_SO, source_assay = "RNA"), "OS_MISSING_PARAMETER"), "no cluster_col -> OS_MISSING_PARAMETER")
check(identical(conv(so, to = "SingleCellExperiment", consumer = "back_end", layers = LAY_SO, cluster_col = "seurat_clusters", source_assay = "RNA"), "OS_MISSING_COLUMN"), "cluster_col not in metadata -> OS_MISSING_COLUMN")
sce_na <- sce; sce_na[[CL]][3] <- NA
check(identical(conv(sce_na, to = "Seurat", consumer = "back_end", layers = c(counts = "counts"), cluster_col = CL, target_assay = "RNA"), "OS_INVALID_INPUT"), "NA cluster labels -> OS_INVALID_INPUT")
check(identical(conv(sce, to = "Seurat", consumer = "back_end", layers = c(counts = "counts"), cluster_col = "nCount_RNA", target_assay = "RNA"), "OS_INVALID_INPUT"), "numeric cluster_col -> OS_INVALID_INPUT")
sce_us <- sce; rownames(sce_us)[1:2] <- c("GENE_A", "GENE_B")
check(identical(conv(sce_us, to = "Seurat", consumer = "back_end", layers = c(counts = "counts"), cluster_col = CL, target_assay = "RNA"), "OS_CONVERT_UNSUPPORTED"), "feature names with '_' into Seurat -> OS_CONVERT_UNSUPPORTED")
sce_dup <- sce; rownames(sce_dup)[2] <- rownames(sce_dup)[1]
check(identical(conv(sce_dup, to = "Seurat", consumer = "back_end", layers = c(counts = "counts"), cluster_col = CL, target_assay = "RNA"), "OS_INVALID_INPUT"), "duplicated feature ids -> OS_INVALID_INPUT")
sce_nest <- sce; SummarizedExperiment::colData(sce_nest)$nested <- S4Vectors::DataFrame(a = seq_len(ncol(sce)), b = seq_len(ncol(sce)))
check(identical(conv(sce_nest, to = "Seurat", consumer = "back_end", layers = c(counts = "counts"), cluster_col = CL, target_assay = "RNA"), "OS_CONVERT_UNSUPPORTED"), "nested colData column -> OS_CONVERT_UNSUPPORTED")
check(identical(conv(sce, to = "Seurat", consumer = "front_end", layers = c(counts = "counts"), cluster_col = CL, target_assay = "RNA"), "OS_ECOSYSTEM_MIXED"), "SCE -> Seurat for a Seurat front-end module -> OS_ECOSYSTEM_MIXED")
check(identical(conv(so, to = "SingleCellExperiment", consumer = "front_end", layers = LAY_SO, cluster_col = CL, source_assay = "RNA"), "OS_ECOSYSTEM_MIXED"), "Seurat -> SCE for a Bioconductor front-end module -> OS_ECOSYSTEM_MIXED")
check(identical(conv(so, to = "SingleCellExperiment", consumer = "sideways", layers = LAY_SO, cluster_col = CL, source_assay = "RNA"), "OS_INVALID_PARAMETER"), "unknown consumer -> OS_INVALID_PARAMETER")

# post-conversion verification: every component is checked
P <- os_sc_parts(sce, "SingleCellExperiment", c(counts = "counts", logcounts = "logcounts"))
fp <- os_sc_fingerprint(P, CL)
mism <- function(mut) { Q <- P; Q <- mut(Q); err_msg(os_sc_verify(fp, os_sc_fingerprint(Q, CL))) }
check(identical(err_code(os_sc_verify(fp, fp)), ""), "verify: identical fingerprints pass")
m <- mism(function(Q) { k <- -1L; Q$cells <- Q$cells[k]; Q$mats <- lapply(Q$mats, function(x) x[, k]); Q$coldata <- Q$coldata[k, , drop = FALSE]
  Q$reductions <- lapply(Q$reductions, function(r) { r$emb <- r$emb[k, , drop = FALSE]; r }); Q })
check(startsWith(m, "OS_CONVERT_MISMATCH") && grepl("cell count 80 -> 79", m), "verify: dropped cell -> OS_CONVERT_MISMATCH (cell count)")
m <- mism(function(Q) { Q$features <- Q$features[-1]; Q$mats <- lapply(Q$mats, function(x) x[-1, ]); Q$rowdata <- Q$rowdata[-1, , drop = FALSE]; Q })
check(startsWith(m, "OS_CONVERT_MISMATCH") && grepl("gene count 230 -> 229", m), "verify: dropped gene -> OS_CONVERT_MISMATCH (gene count)")
m <- mism(function(Q) { v <- Q$coldata[[CL]]; v[1] <- levels(v)[2]; Q$coldata[[CL]] <- v; Q })
check(startsWith(m, "OS_CONVERT_MISMATCH") && grepl("cluster labels", m), "verify: changed cluster label -> OS_CONVERT_MISMATCH (cluster labels)")
m <- mism(function(Q) { Q$coldata$groups <- factor(as.character(Q$coldata$groups), levels = c("g1", "g2")); Q })
check(startsWith(m, "OS_CONVERT_MISMATCH") && grepl("cell metadata column 'groups'", m), "verify: level order changed -> OS_CONVERT_MISMATCH (metadata column)")
m <- mism(function(Q) { Q$coldata$letter.idents <- droplevels(Q$coldata$letter.idents); Q })
check(startsWith(m, "OS_CONVERT_MISMATCH") && grepl("letter.idents", m), "verify: unused level dropped -> OS_CONVERT_MISMATCH")
m <- mism(function(Q) { x <- Q$mats$counts; x[1, 1] <- x[1, 1] + 1; Q$mats$counts <- x; Q })
check(startsWith(m, "OS_CONVERT_MISMATCH") && grepl("matrix 'counts'", m), "verify: one count changed -> OS_CONVERT_MISMATCH (matrix)")
m <- mism(function(Q) { Q$mats <- stats::setNames(Q$mats, c("counts", "data")); Q })
check(startsWith(m, "OS_CONVERT_MISMATCH") && grepl("matrix names", m), "verify: renamed layer -> OS_CONVERT_MISMATCH")
m <- mism(function(Q) { Q$reductions$umap$emb[1, 1] <- Q$reductions$umap$emb[1, 1] + 1e-12; Q })
check(startsWith(m, "OS_CONVERT_MISMATCH") && grepl("embedding 'umap'", m), "verify: embedding moved by 1e-12 -> OS_CONVERT_MISMATCH")
m <- mism(function(Q) { Q$reductions$pca$colnames <- paste0("x", Q$reductions$pca$colnames); Q })
check(startsWith(m, "OS_CONVERT_MISMATCH") && grepl("embedding 'pca'", m), "verify: embedding column names changed -> OS_CONVERT_MISMATCH")
m <- mism(function(Q) { Q$reductions$umap <- NULL; Q })
check(startsWith(m, "OS_CONVERT_MISMATCH") && grepl("embedding names", m), "verify: embedding lost -> OS_CONVERT_MISMATCH")
m <- mism(function(Q) { Q$cells <- rev(Q$cells); Q })
check(startsWith(m, "OS_CONVERT_MISMATCH") && grepl("cell ids", m), "verify: cell order changed -> OS_CONVERT_MISMATCH")
m <- mism(function(Q) { Q$coldata$nFeature_RNA <- as.double(Q$coldata$nFeature_RNA); Q })
check(startsWith(m, "OS_CONVERT_MISMATCH") && grepl("nFeature_RNA", m), "verify: integer column turned double -> OS_CONVERT_MISMATCH")

# --------------------------------------------- handoff: chain ecosystem rules
check("scverse" %in% OS_ECOSYSTEMS, "HO scverse is a handoff ecosystem")
nt <- file.path(tmp, "run_neutral"); dir.create(file.path(nt, "objects"), recursive = TRUE)
saveRDS(sce, file.path(nt, "objects", "sce.rds"))
write_handoff(nt, "run-0101", "singler-annotate", "1.0.0", list(obj = list(path = file.path(nt, "objects", "sce.rds"), type = "SingleCellExperiment")),
              ecosystem = "neutral", state = c(list(seed = 1L), os_sc_chain_state(h)), upstream_runs = h$upstream_runs)
check(identical(os_sc_chain_state(h), list(front_end_ecosystem = "seurat")), "HO os_sc_chain_state carries the upstream front-end ecosystem")
check(identical(err_code(read_handoff(nt, front_end_ecosystem = "bioconductor")), "OS_ECOSYSTEM_MIXED"), "HO seurat chain through a neutral module into a Bioconductor front end -> OS_ECOSYSTEM_MIXED")
check(identical(err_code(read_handoff(nt, front_end_ecosystem = "seurat")), ""), "HO seurat chain through a neutral module into a Seurat front end accepted")
check(identical(os_sc_chain_state(read_handoff(nt)), list(front_end_ecosystem = "seurat")), "HO chain ecosystem survives a second neutral hop")
sv <- file.path(tmp, "run_scverse"); dir.create(file.path(sv, "objects"), recursive = TRUE)
writeLines("x", file.path(sv, "objects", "adata.h5ad"))
write_handoff(sv, "run-0400", "scanpy-cluster", "1.0.0", list(adata = list(path = file.path(sv, "objects", "adata.h5ad"), type = "AnnData")), ecosystem = "scverse")
check(identical(err_code(read_handoff(sv, front_end_ecosystem = "seurat")), "OS_ECOSYSTEM_MIXED"), "HO scverse chain into a Seurat front end -> OS_ECOSYSTEM_MIXED")
check(identical(err_code(read_handoff(sv, expect = list(adata = "AnnData"))), ""), "HO scverse chain into a neutral back end accepted")
old_nt <- file.path(tmp, "run_neutral_plain"); dir.create(file.path(old_nt, "objects"), recursive = TRUE)
saveRDS(1, file.path(old_nt, "objects", "x.rds"))
write_handoff(old_nt, "run-0500", "speckle-propeller", "1.0.0", list(x = list(path = file.path(old_nt, "objects", "x.rds"), type = "feature_table")))
check(identical(err_code(read_handoff(old_nt, front_end_ecosystem = "bioconductor")), ""), "HO neutral handoff without a recorded chain ecosystem behaves as before")

if (identical(Sys.getenv("BASILISK_EXTERNAL_DIR"), "/opt/omicstat/basilisk")) check(length(skips) == 0L, "shared-image AnnData round trips cannot be skipped")
cat(sprintf("%d skip(s)\n", length(skips)))
if (length(failures)) {
  cat(sprintf("%d check(s) FAILED:\n", length(failures))); for (f in failures) cat("  - ", f, "\n", sep = ""); quit(status = 1)
} else { cat("ALL CONVERT CHECKS PASSED\n"); quit(status = 0) }
