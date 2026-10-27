# Shared survival boundary: expression handoff mandatory, one biological subject per column.
os_survival_input <- function(a, allow_constant = FALSE) {
 up <- read_handoff(a[["from-run"]])
 if (isTRUE(up$state$candidate) || isTRUE(up$state$development_only))
  stop("OS_HANDOFF_MISMATCH: candidate upstream is not an accepted expression producer", call. = FALSE)
 hit <- names(Filter(function(x) identical(x$type, "expression_matrix"), up$objects))
 if (length(hit) != 1L) stop("OS_HANDOFF_MISMATCH: exactly one expression_matrix handoff is required", call. = FALSE)
 os_handoff_assert_uncorrected(up, hit)
 path <- up$objects[[hit]]$path
 if (grepl("\\.rds$", path, ignore.case = TRUE)) E <- readRDS(path) else {
  d <- utils::read.csv(path, check.names = FALSE, stringsAsFactors = FALSE, colClasses = "character")
  if (ncol(d) < 3 || anyNA(d[[1]]) || any(!nzchar(d[[1]])) || anyDuplicated(d[[1]])) stop("OS_INVALID_INPUT: unique feature IDs and at least two sample columns required", call. = FALSE)
  E <- as.matrix(d[-1]); rownames(E) <- d[[1]]; suppressWarnings(storage.mode(E) <- "double")
 }
 if (!is.matrix(E) || !is.numeric(E) || any(!is.finite(E)) || is.null(rownames(E)) || is.null(colnames(E)) ||
     anyNA(rownames(E)) || anyNA(colnames(E)) || anyDuplicated(rownames(E)) || anyDuplicated(colnames(E)) || any(!nzchar(rownames(E))) || any(!nzchar(colnames(E))))
  stop("OS_INVALID_INPUT: finite named numeric expression matrix required", call. = FALSE)
 d <- utils::read.csv(a$clinical, check.names = FALSE, stringsAsFactors = FALSE, colClasses = "character")
 cols <- c(a[["unit-col"]], a[["time-col"]], a[["event-col"]]); os_check_columns(d, cols)
 if (anyDuplicated(cols) || anyDuplicated(names(d))) stop("OS_INVALID_DESIGN: clinical columns must be distinct", call. = FALSE)
 ids <- d[[cols[1]]]
 if (anyNA(ids) || any(!nzchar(trimws(ids))) || anyDuplicated(ids) || !setequal(ids, colnames(E)))
  stop("OS_INVALID_DESIGN: exact unique biological sample identities must match every expression column", call. = FALSE)
 ids <- sort(ids, method = "radix"); d <- d[match(ids, d[[cols[1]]]), , drop = FALSE]; E <- E[, ids, drop = FALSE]
 time <- os_as_finite(d[[cols[2]]], "survival time"); event <- os_as_finite(d[[cols[3]]], "event")
 if (any(time <= 0) || any(!event %in% c(0, 1))) stop("OS_INVALID_INPUT: positive time and explicit event 0=censored,1=event required; no automatic recoding", call. = FALSE)
 if (sum(event) < a[["min-events"]]) stop("OS_INVALID_DESIGN: fewer events than the prespecified minimum", call. = FALSE)
 genes <- strsplit(a$genes, ",", fixed = TRUE)[[1]]
 if (!length(genes) || any(!nzchar(genes)) || anyDuplicated(genes) || !all(genes %in% rownames(E))) stop("OS_INVALID_DESIGN: exact unique prespecified genes required; map IDs upstream using an offline snapshot", call. = FALSE)
 if (length(genes) > 100L || ncol(E) > 5000L) stop("OS_INVALID_DESIGN: maximum 100 prespecified genes and 5000 subjects; no implicit downsampling", call. = FALSE)
 E <- E[genes, , drop = FALSE]
 if (!allow_constant && any(apply(E, 1, stats::sd) == 0)) stop("OS_INVALID_DESIGN: constant expression cannot estimate a Cox effect", call. = FALSE)
 cov <- if (identical(a$covariates, "none")) character() else strsplit(a$covariates, ",", fixed = TRUE)[[1]]
 if (anyDuplicated(cov) || any(!nzchar(cov)) || any(cov %in% cols)) stop("OS_INVALID_DESIGN: distinct prespecified covariates required", call. = FALSE)
 os_check_columns(d, cov)
 clinical <- data.frame(unit = ids, time = time, event = event, stringsAsFactors = FALSE)
 # Numeric covariates only: categorical coding must be explicitly designed upstream, never guessed.
 for (i in seq_along(cov)) clinical[[paste0("c", i)]] <- os_as_finite(d[[cov[i]]], paste("numeric covariate", cov[i]))
 list(E = E, clinical = clinical, covariates = cov, upstream = up, input_files = list(clinical = a$clinical))
}
