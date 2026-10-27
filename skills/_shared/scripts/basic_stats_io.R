# Biological-unit preparation for suite-owned endpoint analyses.
# Never interpret row count or technical wells as biological replication.
os_basic_units <- function(d, value_col, group_col, unit_col, technical_policy, technical_col = NULL) {
 os_check_columns(d, c(value_col, group_col, unit_col))
 z <- data.frame(unit = as.character(d[[unit_col]]), group = as.character(d[[group_col]]),
                 value = os_as_finite(d[[value_col]], value_col), stringsAsFactors = FALSE)
 for (k in c("unit", "group")) if (anyNA(z[[k]]) || any(!nzchar(trimws(z[[k]]))))
  stop("OS_INVALID_DESIGN: missing biological-unit or group identity", call. = FALSE)
 if (!technical_policy %in% c("reject", "mean")) stop("OS_INVALID_PARAMETER: unknown technical policy", call. = FALSE)
 if (technical_policy == "reject") {
  if (!is.null(technical_col)) stop("OS_CONFLICTING_PARAMETERS: technical-col requires technical-policy mean", call. = FALSE)
  if (anyDuplicated(z[c("unit", "group")])) stop("OS_INVALID_DESIGN: duplicate biological unit/group; technical repeats need explicit mean policy and identities", call. = FALSE)
  z$n_technical <- 1L
 } else {
  if (is.null(technical_col)) stop("OS_MISSING_PARAMETER: technical-policy mean requires technical-col", call. = FALSE)
  os_check_columns(d, technical_col); z$technical <- as.character(d[[technical_col]])
  if (anyNA(z$technical) || any(!nzchar(trimws(z$technical))) || anyDuplicated(z[c("unit", "group", "technical")]))
   stop("OS_INVALID_DESIGN: technical identities must be nonmissing and unique within biological unit/group", call. = FALSE)
  groups <- split(seq_len(nrow(z)), interaction(match(z$unit, unique(z$unit)), match(z$group, unique(z$group)), drop = TRUE))
  z <- do.call(rbind, lapply(groups, function(ii) data.frame(unit = z$unit[ii[1]], group = z$group[ii[1]],
      value = mean(z$value[ii]), n_technical = length(ii), stringsAsFactors = FALSE)))
 }
 z <- z[order(z$group, z$unit), , drop = FALSE]; rownames(z) <- NULL; z
}
os_basic_design <- function(d, design, group_order) {
 if (length(group_order) < 2L || anyDuplicated(group_order) || any(!nzchar(group_order)) || !setequal(group_order, unique(d$group)))
  stop("OS_INVALID_DESIGN: group-order must name each observed group exactly once", call. = FALSE)
 if (!design %in% c("independent", "paired")) stop("OS_INVALID_PARAMETER: unknown design", call. = FALSE)
 if (design == "independent" && anyDuplicated(d$unit))
  stop("OS_INVALID_DESIGN: independent groups must have disjoint biological units", call. = FALSE)
 if (design == "paired") {
  sets <- lapply(group_order, function(g) sort(d$unit[d$group == g]))
  if (!all(vapply(sets, identical, logical(1), sets[[1]])))
   stop("OS_INVALID_DESIGN: paired design requires complete identical unit sets; no silent complete-case deletion", call. = FALSE)
 }
 if (any(table(d$group) < 2L)) stop("OS_INVALID_DESIGN: inference requires at least two biological units per group", call. = FALSE)
 d$group <- factor(d$group, levels = group_order); d
}

os_basic_test <- function(expr) tryCatch(expr, error = function(e) {
 stop(paste("OS_INVALID_DESIGN: declared test is undefined:", conditionMessage(e)), call. = FALSE)
})
