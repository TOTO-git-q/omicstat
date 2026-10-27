# Source tests copied from pinned descriptive-distribution. Numerical core only.
# Executed inside a private environment by run_distribution_contracts.R.
same <- function(a, b, tol = 1e-10) stopifnot(isTRUE(all.equal(a, b, tolerance = tol, check.attributes = FALSE)))
fails <- function(expr, code) {
 caught <- tryCatch({force(expr); NULL}, error = function(e) e)
 stopifnot(inherits(caught, "descdist_error"), identical(caught$code, code))
}
none <- list(method = "none")
base_spec <- function(analysis = "distribution_comparison") list(
 spec_version = "descdist.v1", analysis = analysis, id = "person", outcome = "value",
 group = "arm", group_levels = c("A", "B"), reference_group = "A",
 quantile_grid = c(0.1, 0.5, 0.9), inference = none, make_figures = FALSE)
synthetic <- data.frame(person = sprintf("synthetic_%04d", 1:400),
 arm = rep(c("A", "B"), each = 200), value = c(1:200, (1:200) + 2), stringsAsFactors = FALSE)
metric <- function(result, statistic, group = "B") result$metrics[
 result$metrics$statistic == statistic & result$metrics$group == group, , drop = FALSE]
boot <- base_spec(); boot$inference <- list(method = "iid_stratified_bootstrap", replicates = 200L, seed = 104729L)
check("inverse empirical quantile preserves ties", {
  z <- dd_weighted(c(0, 0, 2, 2, 2, 9, 9, 10), rep(1, 8), c(.25, .5, .75))
  same(z$quantile, c(0, 2, 9))
})

check("weighted inverse is not averaging adjacent values", {
  z <- dd_weighted(c(0, 100), c(.5, .5), c(.5, .5001), c(-1, 0, 99, 100))
  same(z$quantile, c(0, 100)); same(z$cdf, c(0, .5, .5, 1))
})

check("global weight rescaling is invariant", {
  a <- dd_weighted(c(1, 2, 3), c(1, 2, 3), c(.2, .5, .9))
  b <- dd_weighted(c(1, 2, 3), c(1, 2, 3) * 1e200, c(.2, .5, .9))
  same(a, b)
})

check("zero weights have no contribution", {
  same(dd_weighted(c(1, 999), c(1, 0), .5)$quantile, 1)
  fails(dd_weighted(c(1, 2), c(0, 0)), "OS_GPC_INVALID_WEIGHTS")
})

check("shifted distributions recover all fixed contrasts", {
  r <- dd_analyze(synthetic, base_spec())
  same(metric(r, "mean_difference")$estimate, 2)
  same(metric(r, "quantile_difference")$estimate, c(2, 2, 2))
  same(metric(r, "smd")$estimate, 2 / sd(1:200))
})

check("difference sign follows explicit reference", {
  s <- base_spec(); s$reference_group <- "B"
  same(metric(dd_analyze(synthetic, s), "mean_difference", "A")$estimate, -2)
})

check("row order does not change descriptive results", {
  same(dd_analyze(synthetic, base_spec())$metrics,
       dd_analyze(synthetic[400:1, ], base_spec())$metrics)
})

check("no probability endpoint or data-dependent grid", {
  s <- base_spec(); s$quantile_grid <- c(0, .5, 1)
  fails(dd_analyze(synthetic, s), "OS_GPC_INVALID_SPEC")
  s$quantile_grid <- c(.5, .5); fails(dd_analyze(synthetic, s), "OS_GPC_INVALID_SPEC")
})

check("unknown parameters and invalid scalars fail", {
  s <- base_spec(); s$automatic_cutoff <- TRUE
  fails(dd_analyze(synthetic, s), "OS_GPC_INVALID_SPEC")
  s <- base_spec(); s$min_cell_n <- 9
  fails(dd_analyze(synthetic, s), "OS_GPC_INVALID_SPEC")
  s <- base_spec(); s$inference <- list(method = "none", seed = TRUE)
  fails(dd_analyze(synthetic, s), "OS_GPC_INVALID_SPEC")
})

check("IDs checked before complete case filtering", {
  d <- synthetic; d$person[2] <- d$person[1]; d$value[2] <- NA
  fails(dd_analyze(d, base_spec()), "OS_GPC_NON_UNIQUE_PERSON")
})

check("confirmed internal row_key is the default identifier", {
  d <- synthetic; names(d)[names(d) == "person"] <- "row_key"
  s <- base_spec(); s$id <- NULL
  same(metric(dd_analyze(d, s), "mean_difference")$estimate, 2)
})

check("unknown group is not silently dropped", {
  d <- synthetic; d$arm[1] <- "unplanned"
  fails(dd_analyze(d, base_spec()), "OS_GPC_UNDECLARED_GROUP")
})

check("nonfinite or censored numeric values rejected", {
  for (bad in c("<5", "Inf", "NaN", "word")) {
    d <- synthetic; d$value <- as.character(d$value); d$value[1] <- bad
    fails(dd_analyze(d, base_spec()), "OS_GPC_INVALID_COLUMN")
  }
})

check("complete cases are explicit", {
  d <- synthetic; d$value[1] <- NA
  r <- dd_analyze(d, base_spec())
  stopifnot("OS_GPC_COMPLETE_CASE_EXCLUSIONS" %in% unlist(r$guardrails$warnings))
  same(metric(r, "mean", "A")$n, 199)
})

check("small group suppresses counts and derived contrasts", {
  d <- synthetic[c(1:9, 201:400), ]
  r <- dd_analyze(d, base_spec())
  stopifnot(all(is.na(metric(r, "mean", "A")$n)), all(is.na(metric(r, "mean_difference")$estimate)),
            all(is.na(metric(r, "quantile_difference")$estimate)))
})

check("declared empty group is retained as inestimable, not replaced", {
  r <- dd_analyze(synthetic[synthetic$arm == "A", ], base_spec())
  stopifnot(is.na(metric(r, "mean", "B")$estimate), is.na(metric(r, "mean", "B")$n),
            is.na(metric(r, "mean_difference")$estimate), is.na(metric(r, "smd")$estimate))
})

check("a clean run has no findings and no blocking count", {
  g <- dd_analyze(synthetic, base_spec())$guardrails
  stopifnot(identical(g$status, "completed"), length(g$findings) == 0L, identical(g$blocking, 0L))
})

check("every suppression code is explained by a finding naming code, message and group", {
  r <- dd_analyze(synthetic[c(1:9, 201:400), ], base_spec())
  g <- r$guardrails; stopifnot(identical(g$status, "completed_with_suppression"), length(g$findings) > 0L)
  codes <- vapply(g$findings, function(z) z$code, character(1))
  warned <- unique(unlist(strsplit(unlist(g$warnings), ";", fixed = TRUE)))
  stopifnot(all(warned %in% codes), "OS_GPC_GROUP_N_BELOW_MINIMUM" %in% codes)
  hit <- g$findings[[which(codes == "OS_GPC_GROUP_N_BELOW_MINIMUM" & vapply(g$findings, function(z) identical(z$group, "A"), logical(1)))[1L]]]
  stopifnot(nzchar(hit$message), !isTRUE(hit$blocking), "mean" %in% unlist(hit$statistics), 0.5 %in% unlist(hit$grid))
  # every withheld metric row is covered by a finding for its group and one of its codes
  w <- r$metrics[nzchar(r$metrics$suppression), , drop = FALSE]
  for (k in seq_len(nrow(w))) {
    cs <- strsplit(w$suppression[k], ";", fixed = TRUE)[[1L]]
    stopifnot(any(vapply(g$findings, function(z) z$code %in% cs && identical(z$group, w$group[k]), logical(1))))
  }
  # findings never carry counts or numeric person-level values
  txt <- paste(unlist(lapply(g$findings, function(z) z$message)), collapse = " ")
  stopifnot(!grepl("[0-9]", txt))
})

check("wholly suppressed result carries a blocking finding", {
  r <- dd_analyze(synthetic[c(1:5, 201:205), ], base_spec())
  g <- r$guardrails
  codes <- vapply(g$findings, function(z) z$code, character(1))
  stopifnot("OS_GPC_NO_RELEASABLE_ESTIMATES" %in% codes, identical(g$blocking, 1L),
            isTRUE(g$findings[[which(codes == "OS_GPC_NO_RELEASABLE_ESTIMATES")]]$blocking))
})

check("nonstandard fixed labels retain exact reference and ordering", {
  d <- synthetic; d$arm <- ifelse(d$arm == "A", "reference|F:1", "comparaison 空格")
  s <- base_spec(); s$group_levels <- c("reference|F:1", "comparaison 空格"); s$reference_group <- s$group_levels[1]
  r <- dd_analyze(d, s)
  same(metric(r, "mean_difference", "comparaison 空格")$estimate, 2)
})

check("quantile tails have additional support guard", {
  d <- synthetic[c(1:20, 201:220), ]
  r <- dd_analyze(d, base_spec())
  z <- metric(r, "quantile", "A")
  stopifnot(is.na(z$estimate[1]), is.finite(z$estimate[2]), is.na(z$estimate[3]))
})

check("neighboring released quantiles cannot isolate rare positive increments", {
  s <- base_spec(); s$quantile_grid <- c(.1, .105, .15)
  r <- dd_analyze(synthetic, s)
  z <- metric(r, "quantile", "A")
  stopifnot(is.finite(z$estimate[1]), is.na(z$estimate[2]), is.finite(z$estimate[3]))
})

check("seeded bootstrap is reproducible and preserves caller RNG", {
  rng_seed <- 19L; set.seed(rng_seed); before <- .Random.seed
  a <- dd_analyze(synthetic, boot)
  stopifnot(identical(before, .Random.seed))
  b <- dd_analyze(synthetic[400:1, ], boot)
  same(a$metrics, b$metrics)
  z <- metric(a, "mean_difference")
  stopifnot(z$ci_lower < z$ci_upper, z$bootstrap_valid == 200, z$ci_status == "pointwise_percentile_95")
})

check("constant resamples do not claim guaranteed precision", {
  d <- synthetic; d$value <- ifelse(d$arm == "A", 1, 2)
  r <- dd_analyze(d, boot)
  z <- metric(r, "mean_difference")
  stopifnot(is.na(z$ci_lower), z$ci_status == "degenerate_resamples_no_precision_claim",
            is.na(metric(r, "smd")$estimate))
})

check("bootstrap keeps stable metric identity with an empty comparison group", {
  r <- dd_analyze(synthetic[synthetic$arm == "A", ], boot)
  stopifnot(is.na(metric(r, "mean_difference")$ci_lower), is.na(metric(r, "smd")$estimate))
})

check("core return contains only aggregate result material", {
  r <- dd_analyze(synthetic, base_spec())
  stopifnot(!any(c("data", "draws", "ids") %in% names(r)), !any(grepl("synthetic_", unlist(r$metrics))))
  count <- r$metrics$n; stopifnot(all(is.na(count) | count >= 10))
})

check("interval columns are ordered lower then upper", {
  cols <- names(dd_analyze(synthetic, base_spec())$metrics)
  stopifnot(match("ci_lower", cols) + 1L == match("ci_upper", cols))
})
