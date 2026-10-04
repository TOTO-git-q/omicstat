# Native MAF object and package result tables.
MF_MODULE_VERSION <- "1.0.0"
os_mf_csv <- function(x) if (is.null(x)) NULL else strsplit(x, ",", fixed = TRUE)[[1]]
maftools_landscape_compute <- function(a, p) {
 if (endsWith(p, ".rds")) {
  maf <- readRDS(p)
  if (!methods::is(maf, "MAF")) stop("OS_INVALID_INPUT: expected MAF object.", call. = FALSE)
  if (any(c("clinical", "non-synonymous", "cn-table", "gistic-lesions", "gistic-amp", "gistic-del", "gistic-scores", "use-all", "is-tcga", "remove-duplicates", "rm-flags", "cn-level") %in% attr(a, "given"))) stop("OS_CONFLICTING_PARAMETERS: native MAF handoff already has read.maf policies; supply a raw MAF to change them.", call. = FALSE)
 } else maf <- maftools::read.maf(maf = p, clinicalData = a$clinical, rmFlags = a[["rm-flags"]] == "true", removeDuplicatedVariants = a[["remove-duplicates"]] == "true", useAll = a[["use-all"]] == "true", gisticAllLesionsFile = a[["gistic-lesions"]], gisticAmpGenesFile = a[["gistic-amp"]], gisticDelGenesFile = a[["gistic-del"]], gisticScoresFile = a[["gistic-scores"]], cnLevel = a[["cn-level"]], cnTable = a[["cn-table"]], isTCGA = a[["is-tcga"]] == "true", vc_nonSyn = os_mf_csv(a[["non-synonymous"]]), verbose = FALSE)
 # These functions plot as a side effect; only suite figures are deliverables.
 sink_plot <- tempfile(fileext = ".pdf"); grDevices::pdf(sink_plot); on.exit({grDevices::dev.off(); unlink(sink_plot)}, add = TRUE)
 tmb <- maftools::tmb(maf = maf, captureRegions = a[["capture-regions"]], captureSize = a[["capture-size"]] %||% 50, logScale = TRUE, ignoreCNV = a[["ignore-cnv"]] == "true", plotType = "classic", pointcol = "#2c3e50", verbose = FALSE)
 interactions <- maftools::somaticInteractions(maf = maf, top = a[["interaction-top"]], genes = os_mf_csv(a[["interaction-genes"]]), pvalue = c(0.05, 0.1), returnAll = TRUE)
 tables <- list(variants = as.data.frame(maf@data), silent_variants = as.data.frame(maf@maf.silent), sample_summary = as.data.frame(maftools::getSampleSummary(x = maf)), gene_summary = as.data.frame(maftools::getGeneSummary(x = maf)), clinical = as.data.frame(maftools::getClinicalData(x = maf)), tmb = as.data.frame(tmb), interactions = as.data.frame(interactions))
 if (nrow(tables$sample_summary) == 0) stop("OS_INVALID_INPUT: no samples in MAF.", call. = FALSE)
 if (!is.null(a$clinical)) {
  clin <- utils::read.delim(a$clinical, check.names = FALSE)
  if (!"Tumor_Sample_Barcode" %in% names(clin)) stop("OS_MISSING_COLUMN: clinical Tumor_Sample_Barcode required.", call. = FALSE)
  ids <- if (a[["is-tcga"]] == "true") substr(clin$Tumor_Sample_Barcode, 1, 12) else clin$Tumor_Sample_Barcode
  tables$clinical_join <- data.frame(Tumor_Sample_Barcode = clin$Tumor_Sample_Barcode, matched = ids %in% tables$sample_summary$Tumor_Sample_Barcode)
 }
 capture <- list(size_mb=a[["capture-size"]],regions=a[["capture-regions"]],source=a[["capture-regions-source"]])
 if(!is.null(capture$regions)) { regions <- data.table::fread(capture$regions);capture$size_mb <- sum(regions[[3]]-regions[[2]])/1e6;capture$sha256 <- digest::digest(file=capture$regions,algo="sha256") }
 list(maf = maf, tables = tables,capture=capture)
}
