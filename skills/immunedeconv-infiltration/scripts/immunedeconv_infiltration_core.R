# Official locked immunedeconv workflows; native tables and scales retained.
ID_MODULE_VERSION <- "1.1.0"
id_method_unit <- function(method) switch(method,
 quantiseq = "cell_fraction", epic = "cell_fraction", cibersort = "relative_fraction",
 abis = "estimated_percent", estimate = "scores_and_tumor_purity",
 "native_score")
immunedeconv_infiltration_compute <- function(a, mat) {
 methods <- c("quantiseq", "mcp_counter", "epic", "xcell", "timer", "abis", "consensus_tme", "estimate", "cibersort", "cibersort_abs")
 if (!a$method %in% methods) stop("OS_METHOD_UNAVAILABLE: unsupported locked human immunedeconv method.", call. = FALSE)
 if (a$method == "epic" && !identical(a[["accept-licence"]], "epic")) stop("OS_LICENCE_REQUIRED: --accept-licence epic acknowledges academic non-commercial use, no redistribution and agreed-user access only (EPIC LICENSE).", call. = FALSE)
 if (a$method %in% c("cibersort", "cibersort_abs")) {
  if (!identical(a[["accept-licence"]], "cibersort")) stop("OS_LICENCE_REQUIRED: --accept-licence cibersort is required for both CIBERSORT routes.", call. = FALSE)
  if (is.null(a[["cibersort-source"]]) || is.null(a[["cibersort-matrix"]])) stop("OS_REFDATA_MISSING: user-supplied --cibersort-source and --cibersort-matrix are required; never bundled.", call. = FALSE)
  immunedeconv::set_cibersort_binary(path=a[["cibersort-source"]])
  immunedeconv::set_cibersort_mat(path=a[["cibersort-matrix"]])
 }
 allowed <- if (a$method == "mcp_counter") c("TPM", "log2TPM") else "TPM"
 if (!a[["input-scale"]] %in% allowed || a$arrays != "false") stop("OS_INPUT_SCALE: declare non-log TPM, arrays=false; MCP-counter also accepts log2(TPM+1), declared log2TPM.", call. = FALSE)
 if (any(!is.finite(mat)) || any(mat < 0) || any(colSums(mat) <= 0)) stop("OS_INPUT_SCALE: finite nonnegative expression with positive sample totals required.", call. = FALSE)
 if (a[["input-scale"]] == "TPM" && any(colSums(mat) > 1010000)) stop("OS_INPUT_SCALE: TPM sample totals exceed 1e6; verify scale and identifiers.", call. = FALSE)
 if (any(grepl("^ENSG[0-9]", rownames(mat)))) stop("OS_GENE_IDENTIFIER: human HGNC symbols required; map Ensembl IDs upstream.", call. = FALSE)
 indications <- if (is.null(a$indications)) NULL else strsplit(a$indications, ",", fixed = TRUE)[[1]]
 if (a$method %in% c("timer", "consensus_tme") && (is.null(indications) || length(indications) != ncol(mat))) stop("OS_MISSING_PARAMETER: --indications requires one documented cancer type per sample, in input column order.", call. = FALSE)
 extra <- list()
 if (a$method == "quantiseq") extra$signature_matrix <- "TIL10"
 if (a$method == "epic") suppressPackageStartupMessages(library("EPIC", character.only = TRUE))
 if (a$method == "xcell") {
  suppressPackageStartupMessages(library("xCell", character.only = TRUE))
  extra$parallel.sz <- a[["xcell-threads"]]
  extra$alpha <- a[["xcell-alpha"]]
  extra$scale <- a[["xcell-scale"]] == "true"
 }
 if (a$method == "mcp_counter") {
  registry <- jsonlite::fromJSON("/opt/omicstat/env/refdata_registry.json", simplifyVector = FALSE)
  for (name in c("genes", "probesets")) {
   e <- Filter(function(x) identical(x$id, paste0("mcp_counter_",name)), registry$entries)[[1]]
   if (!file.exists(e$cache)) stop("OS_REFDATA_MISSING: MCP-counter build-time signature missing.", call. = FALSE)
   if (!identical(digest::digest(file=e$cache,algo="sha256"),e$sha256)) stop("OS_REFDATA_MISMATCH: MCP-counter signature hash differs.", call. = FALSE)
   extra[[name]] <- utils::read.table(e$cache, sep="\t", header=name=="genes", colClasses="character", stringsAsFactors=FALSE, check.names=FALSE)
  }
  extra$feature_types <- "HUGO_symbols"
  extra$log_transform <- a[["input-scale"]] == "TPM"
 }
 if (a$method == "consensus_tme") extra$method <- a[["consensus-stat-method"]]
 # deconvolute's 'method' selects the backend, so ConsensusTME's argument of
 # the same name cannot pass through it. Call its public official wrapper.
 if (a$method == "consensus_tme" && a[["consensus-stat-method"]] != "ssgsea") {
  stop("OS_METHOD_UNAVAILABLE: locked top-level wrapper fixes ConsensusTME ssgsea; other frameworks need the custom wrapper.", call. = FALSE)
 }
 extra$method <- NULL
 supplied <- if(is.null(a[["method-args"]])) list() else jsonlite::fromJSON(a[["method-args"]],simplifyVector=TRUE)
 if(!is.list(supplied) || (length(supplied) && (is.null(names(supplied)) || any(!nzchar(names(supplied)))))) stop("OS_INVALID_PARAMETER: method-args must be a named JSON object.",call.=FALSE)
 reserved <- c("gene_expression","gene_expression_matrix","method","indications","tumor","arrays","column","rmgenes","scale_mrna","expected_cell_types","absolute")
 if(a$method == "mcp_counter") reserved <- c(reserved,"log_transform","feature_types","featuresType","genes","probesets")
 if(any(names(supplied)%in%reserved)) stop("OS_CONFLICTING_PARAMETERS: use the dedicated CLI flags for top-level method controls.",call.=FALSE)
 if(length(supplied) && a$method %in% c("abis","estimate")) stop("OS_METHOD_UNAVAILABLE: locked top-level method has no supplementary argument forwarding.",call.=FALSE)
 if(a$method %in% c("cibersort","cibersort_abs")) extra$abs_method <- a[["cibersort-abs-method"]] %||% "sig.score"
 extra <- utils::modifyList(extra,supplied,keep.null=TRUE)
 run_native <- function(...) immunedeconv::deconvolute(gene_expression=mat, method=a$method,
  indications=indications, tumor=a$tumor=="true", arrays=FALSE, column="gene_symbol",
  rmgenes=if(is.null(a$rmgenes)) NULL else strsplit(a$rmgenes,",",fixed=TRUE)[[1]],
  scale_mrna=a[["scale-mrna"]]=="true", expected_cell_types=if(is.null(a[["expected-cell-types"]])) NULL else strsplit(a[["expected-cell-types"]],",",fixed=TRUE)[[1]], ...)
 result <- do.call(run_native,extra)
 attr(result,"omicstat_native_args") <- list(method=a$method,arguments=extra[setdiff(names(extra),c("genes","probesets"))])
 result
}
