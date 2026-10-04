# design_check.R -- input checks of the experimental design, shared by every
# module that compares groups. ASCII only on purpose. See docs/CONVENTIONS.md
# sec 16.
#
#   os_check_sample_condition(sample_table, sample_col, condition_col)
#       every sample maps to exactly one condition; else OS_INVALID_DESIGN
#       naming each offending sample and its conditions. Returns the
#       one-row-per-sample map (sample, condition) invisibly.
#   os_align_pairs(df, id_col, group_col, groups)
#       pairs the rows of groups[1] and groups[2] STRICTLY by id (inner join;
#       never by row order). Duplicated ids within a group -> OS_INVALID_DESIGN;
#       rows with an NA id are dropped and counted (warning
#       OS_DESIGN_NA_ID_DROPPED); no pair at all -> OS_INVALID_DESIGN.
#   os_replicate_counts(sample_table, condition_col, sample_col = NULL)
#       biological replicates per condition (distinct samples, or rows when
#       sample_col is NULL).
#   os_classify_replicates(counts, blocker_below, warning_below)
#       adds status blocker / warning / ok. Thresholds are ALWAYS passed in by
#       the module's QC layer (they belong to the module PACK), never defaulted here.

`%||%` <- function(a, b) if (is.null(a) || length(a) == 0 || (length(a) == 1 && is.na(a))) b else a

.os_need_cols <- function(df, cols, what) {
  miss <- setdiff(cols, names(df))
  if (length(miss)) stop(sprintf("OS_MISSING_COLUMN: %s lacks column(s) %s (has: %s)", what, paste(miss, collapse = ", "),
                                 paste(names(df), collapse = ", ")), call. = FALSE)
}

.os_sort <- function(x) sort(unique(x), method = "radix")

os_check_sample_condition <- function(sample_table, sample_col, condition_col) {
  .os_need_cols(sample_table, c(sample_col, condition_col), "sample table")
  s <- as.character(sample_table[[sample_col]])
  cnd <- as.character(sample_table[[condition_col]])
  if (anyNA(s) || any(!nzchar(s))) {
    stop(sprintf("OS_INVALID_DESIGN: %d row(s) of the sample table have no %s", sum(is.na(s) | !nzchar(s)), sample_col), call. = FALSE)
  }
  if (anyNA(cnd)) {
    stop(sprintf("OS_INVALID_DESIGN: %s is missing for sample(s) %s", condition_col,
                 paste(.os_sort(s[is.na(cnd)]), collapse = ", ")), call. = FALSE)
  }
  per <- tapply(cnd, s, function(x) .os_sort(x), simplify = FALSE)
  multi <- per[vapply(per, length, integer(1)) > 1]
  if (length(multi)) {
    ids <- .os_sort(names(multi))
    lines <- vapply(ids, function(i) sprintf("  %s -> %s", i, paste(multi[[i]], collapse = " | ")), "")
    stop(paste(c(sprintf("OS_INVALID_DESIGN: %d sample(s) map to more than one %s:", length(ids), condition_col), lines),
               collapse = "\n"), call. = FALSE)
  }
  ids <- .os_sort(s)
  invisible(data.frame(sample = ids, condition = vapply(ids, function(i) per[[i]], ""), row.names = NULL, stringsAsFactors = FALSE))
}

os_align_pairs <- function(df, id_col, group_col, groups) {
  .os_need_cols(df, c(id_col, group_col), "paired table")
  if (length(groups) != 2 || anyNA(groups) || groups[1] == groups[2]) {
    stop("OS_INVALID_PARAMETER: groups must be two distinct group labels", call. = FALSE)
  }
  g <- as.character(df[[group_col]])
  absent <- setdiff(groups, g)
  if (length(absent)) stop(sprintf("OS_INVALID_DESIGN: group(s) %s absent from %s", paste(absent, collapse = ", "), group_col), call. = FALSE)
  id <- as.character(df[[id_col]])
  keep_rows <- g %in% groups
  na_id <- keep_rows & (is.na(id) | !nzchar(id))
  n_na <- sum(na_id)
  if (n_na) warning(sprintf("OS_DESIGN_NA_ID_DROPPED: %d row(s) of groups %s have no %s and were dropped",
                            n_na, paste(groups, collapse = "/"), id_col), call. = FALSE)
  keep_rows <- keep_rows & !na_id
  sides <- lapply(groups, function(gr) {
    sub <- df[keep_rows & g == gr, , drop = FALSE]
    sid <- as.character(sub[[id_col]])
    dup <- .os_sort(sid[duplicated(sid)])
    if (length(dup)) stop(sprintf("OS_INVALID_DESIGN: %s '%s' has duplicated %s: %s (pairing needs one row per id per group)",
                                  group_col, gr, id_col, paste(dup, collapse = ", ")), call. = FALSE)
    sub
  })
  ids1 <- as.character(sides[[1]][[id_col]]); ids2 <- as.character(sides[[2]][[id_col]])
  common <- .os_sort(intersect(ids1, ids2))
  if (!length(common)) stop(sprintf("OS_INVALID_DESIGN: no %s is present in both %s and %s", id_col, groups[1], groups[2]), call. = FALSE)
  value_cols <- setdiff(names(df), c(id_col, group_col))
  pairs <- data.frame(id = common, stringsAsFactors = FALSE)
  names(pairs) <- id_col
  for (k in 1:2) {
    side <- sides[[k]][match(common, as.character(sides[[k]][[id_col]])), value_cols, drop = FALSE]
    names(side) <- paste0(value_cols, ".", groups[k])
    pairs <- cbind(pairs, side)
  }
  rownames(pairs) <- NULL
  list(pairs = pairs, n_pairs = length(common), n_na_id_dropped = n_na,
       unpaired = stats::setNames(list(.os_sort(setdiff(ids1, ids2)), .os_sort(setdiff(ids2, ids1))), groups))
}

os_replicate_counts <- function(sample_table, condition_col, sample_col = NULL) {
  .os_need_cols(sample_table, c(condition_col, sample_col), "sample table")
  cnd <- sample_table[[condition_col]]
  lev <- if (is.factor(cnd)) levels(cnd) else .os_sort(as.character(cnd[!is.na(cnd)]))
  cnd <- as.character(cnd)
  n <- vapply(lev, function(l) {
    rows <- !is.na(cnd) & cnd == l
    if (is.null(sample_col)) sum(rows) else length(unique(as.character(sample_table[[sample_col]][rows])))
  }, integer(1))
  data.frame(condition = lev, n_replicates = unname(n), stringsAsFactors = FALSE)
}

os_classify_replicates <- function(counts, blocker_below, warning_below) {
  if (!is.numeric(blocker_below) || !is.numeric(warning_below) || blocker_below > warning_below) {
    stop("OS_INVALID_PARAMETER: need numeric blocker_below <= warning_below", call. = FALSE)
  }
  n <- counts$n_replicates
  counts$status <- ifelse(n < blocker_below, "blocker", ifelse(n < warning_below, "warning", "ok"))
  counts
}
