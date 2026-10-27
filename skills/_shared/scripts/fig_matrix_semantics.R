# Matrix semantics are independent of layout. Analysis values are never taken
# from a clipped or masked display; all joins and permutations use explicit IDs.
OS_MATRIX_SEMANTIC_VERSION <- "omicstat.matrix-semantics.v1"
.os_matrix_error <- function(message) stop(paste0("OS_INVALID_INPUT: ", message), call. = FALSE)
.os_matrix_ids <- function(m) {
  if (!is.matrix(m) || !is.numeric(m) || any(dim(m) < 1L)) .os_matrix_error("a nonempty numeric matrix is required")
  .os_require_ids(rownames(m), "matrix row IDs"); .os_require_ids(colnames(m), "matrix column IDs")
  invisible(TRUE)
}
.os_cell_keys <- function(rows, cols) paste0(nchar(rows, type = "bytes"), ":", rows, nchar(cols, type = "bytes"), ":", cols)
.os_matrix_table <- function(m, state = NULL) {
  d <- data.frame(row_id = rep(rownames(m), ncol(m)), col_id = rep(colnames(m), each = nrow(m)), value = as.vector(m), stringsAsFactors = FALSE)
  if (!is.null(state)) d$state <- as.vector(state)
  d
}
.os_matrix_states <- function(m) {
  s <- matrix("observed", nrow(m), ncol(m), dimnames = dimnames(m))
  s[is.finite(m) & m == 0] <- "true_zero"; s[is.na(m)] <- "missing"; s[is.infinite(m)] <- "infinite"
  a <- attr(m, "os_alignment")
  if (!is.null(a)) {
    s[rownames(m) %in% unlist(a$gap_rows), ] <- "unmeasured"
    s[, colnames(m) %in% unlist(a$gap_cols)] <- "unmeasured"
  }
  s
}

# RMS follows scale(center=FALSE): sqrt(sum(x^2)/(n-1)), not centred SD.
# Every finite cell in an undefined normalization stays unavailable, not zero.
os_matrix_normalize <- function(mat, normalization = "identity") {
  .os_matrix_ids(mat)
  allowed <- c("identity", outer(c("row", "col"), c("zscore", "rms", "max", "rank"), paste, sep = "_"))
  if (length(normalization) != 1L || !normalization %in% allowed) .os_matrix_error("unknown matrix normalization")
  state <- .os_matrix_states(mat); value <- mat
  if (normalization == "identity") return(list(raw = mat, values = value, state = state,
    definition = list(version = OS_MATRIX_SEMANTIC_VERSION, method = "identity", axis = "none", formula = "x", parameters = NULL)))
  axis <- if (startsWith(normalization, "row_")) "row" else "column"
  method <- sub("^(row|col)_", "", normalization)
  x <- if (axis == "row") mat else t(mat); s <- if (axis == "row") state else t(state)
  z <- x * NA_real_; center <- divisor <- stats::setNames(rep(NA_real_, nrow(x)), rownames(x))
  reason <- rep("available", nrow(x))
  for (i in seq_len(nrow(x))) {
    v <- x[i, ]; finite <- is.finite(v)
    why <- if (any(!finite)) "undefined_nonfinite_reference" else if (method %in% c("zscore", "rms") && length(v) < 2L) "undefined_single_sample" else NULL
    if (is.null(why)) {
      center[i] <- if (method == "zscore") mean(v) else 0
      divisor[i] <- switch(method, zscore = stats::sd(v), rms = sqrt(sum(v^2)/(length(v)-1)), max = max(v), rank = 1)
      if (method == "max" && any(v < 0)) .os_matrix_error("max normalization requires nonnegative values; declare another transform for signed values")
      if (!is.finite(divisor[i]) || divisor[i] == 0) why <- if (method == "zscore") "undefined_constant" else "undefined_zero_divisor"
    }
    if (is.null(why)) {
      z[i, ] <- if (method == "rank") rank(v, ties.method = "average") else (v-center[i])/divisor[i]
      s[i, finite] <- ifelse(z[i, finite] == 0, "transformed_zero", "observed")
    } else { s[i, finite] <- why; reason[i] <- why }
  }
  formula <- switch(method, zscore = "(x - mean(x)) / sample_sd(x)", rms = "x / sqrt(sum(x^2) / (n - 1)); no centering", max = "x / max(x); nonnegative input", rank = "rank(x, ties.method='average'); full supplied axis")
  list(raw = mat, values = if (axis == "row") z else t(z), state = if (axis == "row") s else t(s),
    definition = list(version = OS_MATRIX_SEMANTIC_VERSION, method = normalization, axis = axis, formula = formula,
      parameters = data.frame(id = rownames(x), center = center, divisor = divisor, state = reason, n_reference = ncol(x), stringsAsFactors = FALSE)))
}

os_align_matrices <- function(mats, axis = c("rows", "cols"), ids = NULL) {
  axis <- match.arg(axis)
  if (!is.list(mats) || !length(mats)) .os_matrix_error("alignment needs a nonempty list of matrices")
  invisible(lapply(mats, .os_matrix_ids))
  get_ids <- if (axis == "rows") rownames else colnames
  if (is.null(ids)) ids <- unique(unlist(lapply(mats, get_ids), use.names = FALSE))
  ids <- .os_require_ids(ids, "shared matrix IDs")
  if (any(!unlist(lapply(mats, get_ids)) %in% ids)) .os_matrix_error("shared IDs must retain every supplied object; select a subset explicitly upstream")
  lapply(mats, function(m) {
    r <- if (axis == "rows") ids else rownames(m); c <- if (axis == "cols") ids else colnames(m)
    out <- matrix(NA_real_, length(r), length(c), dimnames = list(r, c)); out[rownames(m), colnames(m)] <- m
    old <- attr(m, "os_alignment")
    attr(out, "os_alignment") <- list(source_rows = old$source_rows %||% as.list(rownames(m)), source_cols = old$source_cols %||% as.list(colnames(m)),
      gap_rows = as.list(union(unlist(old$gap_rows), setdiff(r, rownames(m)))),
      gap_cols = as.list(union(unlist(old$gap_cols), setdiff(c, colnames(m)))),
      original_missing_count = old$original_missing_count %||% sum(is.na(m)), policy = "ID union with explicit unmeasured gaps; no imputation")
    out
  })
}

.os_validate_distance_matrix <- function(mat) {
  .os_matrix_ids(mat)
  if (nrow(mat) != ncol(mat) || !setequal(rownames(mat), colnames(mat))) .os_matrix_error("distance matrix must have the same unique IDs on both axes")
  dm <- mat[rownames(mat), rownames(mat), drop = FALSE]
  if (any(!is.finite(dm)) || any(dm < 0) || any(diag(dm) != 0) || !isTRUE(all.equal(unname(dm), unname(t(dm)), tolerance = 1e-12)))
    .os_matrix_error("distance matrix must be finite, nonnegative, symmetric and have an exact zero diagonal")
  dm
}

.os_validate_hclust <- function(hc, ids) {
  n <- length(ids)
  if (!inherits(hc, "hclust") || !setequal(.os_require_ids(hc$labels, "tree IDs"), ids) ||
      !is.matrix(hc$merge) || !identical(dim(hc$merge), c(n-1L, 2L)) ||
      anyNA(hc$merge) || any(hc$merge != as.integer(hc$merge)) ||
      length(hc$height) != n-1L || any(!is.finite(hc$height)) || any(hc$height < 0) ||
      length(hc$order) != n || !setequal(hc$order, seq_len(n))) .os_matrix_error("invalid precomputed hclust structure or IDs")
  nodes <- vector("list", n-1L); used <- integer()
  for (i in seq_len(n-1L)) {
    a <- hc$merge[i, ]
    if (any(a == 0) || any(a < -n) || any(a >= i) || any(a %in% used) || anyDuplicated(a)) .os_matrix_error("tree merge reuses or references an invalid child")
    used <- c(used, a)
    nodes[[i]] <- unlist(lapply(a, function(k) if (k < 0) -k else nodes[[k]]), use.names = FALSE)
  }
  if (!setequal(nodes[[n-1L]], seq_len(n))) .os_matrix_error("tree does not contain each leaf once")
  for (node in nodes) { p <- match(node, hc$order); if (diff(range(p))+1L != length(p)) .os_matrix_error("leaf order crosses the supplied tree topology") }
  invisible(TRUE)
}

.os_tree_rotate <- function(hc, ids) {
  if (is.null(hc)) .os_matrix_error("a leaf rotation requires an existing tree")
  .os_require_ids(ids, "leaf rotation IDs")
  if (!setequal(ids, hc$labels)) .os_matrix_error("leaf rotation must contain every tree ID exactly once")
  out <- hc; out$order <- match(ids, hc$labels); .os_validate_hclust(out, hc$labels)
  out
}
.os_tree_record <- function(hc) {
  if (is.null(hc)) return(NULL)
  list(labels = as.list(hc$labels), merge = lapply(seq_len(nrow(hc$merge)), function(i) as.list(hc$merge[i, ])),
       height = as.list(hc$height), leaf_ids = as.list(hc$labels[hc$order]), metric = hc$dist.method %||% "unknown",
       linkage = hc$method %||% "unknown", branch_support = "not supplied")
}
.os_matrix_axis_order <- function(ids, order, role, keys, clustered, what) {
  if (!role %in% c("unordered", "time", "design")) .os_matrix_error(paste(what, "has unknown axis role"))
  if (!is.null(keys)) {
    if (is.list(keys)) keys <- unlist(keys)
    if (!setequal(.os_require_ids(names(keys), paste(what, "axis key IDs")), ids) || anyNA(keys)) .os_matrix_error("axis keys must map exactly to their IDs")
    keys <- keys[ids]
  }
  if (role == "time" && is.null(keys)) .os_matrix_error("time axes need explicit numeric time keys, independent of labels")
  if (role == "time" && (!is.numeric(keys) || any(!is.finite(keys)))) .os_matrix_error("time keys must be finite numeric values")
  if (role != "unordered" && clustered) warning(paste0("OS_FIG_ORDER_SEMANTICS: clustering a ", role, " axis changes its original order; original keys are retained."), call. = FALSE)
  if (is.null(order) && role == "time" && !clustered) order <- ids[order(keys, seq_along(ids))]
  if (is.null(order)) return(NULL)
  order <- .os_require_ids(order, paste(what, "display order IDs"))
  if (!setequal(order, ids)) .os_matrix_error("display order must retain all original axis IDs exactly once")
  if (clustered) .os_matrix_error("use a validated tree rotation rather than overriding clustered leaf order")
  match(order, ids)
}

OS_MATRIX_STATE_STYLES <- list(
  missing = list(shape = 4, colour = "#666666", label = "Missing input"),
  unmeasured = list(shape = 3, colour = "#666666", label = "Unmeasured / ID gap"),
  infinite = list(shape = 8, colour = "#CC6600", label = "Infinite input"),
  undefined_constant = list(shape = 5, colour = "#666666", label = "Undefined: constant reference"),
  undefined_single_sample = list(shape = 2, colour = "#666666", label = "Undefined: one reference value"),
  undefined_nonfinite_reference = list(shape = 6, colour = "#666666", label = "Undefined: nonfinite reference"),
  undefined_zero_divisor = list(shape = 0, colour = "#666666", label = "Undefined: zero divisor"),
  reference = list(shape = 15, colour = "#222222", label = "Structural reference"),
  nonsignificant = list(shape = 1, colour = "#666666", label = "Not significant (declared test)"),
  not_credible = list(shape = 0, colour = "#0072B2", label = "Not credible (declared posterior rule)"),
  failed = list(shape = 4, colour = "#D55E00", label = "Failed fit"),
  untested = list(shape = 3, colour = "#0072B2", label = "Untested"),
  excluded = list(shape = 7, colour = "#666666", label = "Excluded"),
  display_masked = list(shape = 1, colour = "#222222", label = "Display threshold mask"))

.os_matrix_cell_metadata <- function(mat, states, cell_metadata) {
  base <- .os_matrix_table(mat, states); keys <- .os_cell_keys(base$row_id, base$col_id)
  if (anyNA(states) || any(!states %in% c("observed", "true_zero", "transformed_zero", names(OS_MATRIX_STATE_STYLES)))) .os_matrix_error("unknown or missing cell state")
  if (any(states == "true_zero" & (!is.finite(mat) | mat != 0))) .os_matrix_error("true_zero contradicts the raw matrix")
  if (is.null(cell_metadata)) return(base)
  if (!is.data.frame(cell_metadata) || !all(c("row_id", "col_id", "test_metric", "threshold", "fit_id") %in% names(cell_metadata))) .os_matrix_error("cell metadata needs row_id, col_id, test_metric, threshold and fit_id")
  ck <- .os_cell_keys(as.character(cell_metadata$row_id), as.character(cell_metadata$col_id))
  if (anyNA(cell_metadata[, c("row_id", "col_id")]) || anyDuplicated(ck) || !setequal(ck, keys)) .os_matrix_error("cell metadata must join every cell exactly once by both IDs")
  d <- cell_metadata[match(keys, ck), , drop = FALSE]
  if (!is.character(d$test_metric) || anyNA(d$test_metric) || any(!nzchar(d$test_metric)) ||
      !is.character(d$fit_id) || anyNA(d$fit_id) || any(!nzchar(d$fit_id)) || !is.numeric(d$threshold) || any(is.infinite(d$threshold)))
    .os_matrix_error("cell test metric and fit ID must be explicit strings (unknown when unavailable); thresholds must be numeric or missing")
  if (any(base$state == "not_credible" & !d$test_metric %in% c("posterior_probability", "posterior_inclusion_probability", "posterior_credible_interval", "posterior_decision")))
    .os_matrix_error("not_credible is a posterior rule, not a P/FDR significance label")
  if (any(base$state == "nonsignificant" & !d$test_metric %in% c("raw_p", "adjusted_p", "qvalue", "fdr")))
    .os_matrix_error("nonsignificant requires an explicitly declared P/FDR metric")
  if ("state" %in% names(d) && !identical(as.character(d$state), as.character(base$state))) .os_matrix_error("cell metadata and value states disagree")
  if ("value" %in% names(d) && !isTRUE(all.equal(d$value, base$value, check.attributes = FALSE))) .os_matrix_error("cell metadata must not replace raw values")
  cbind(base, d[, setdiff(names(d), names(base)), drop = FALSE])
}
