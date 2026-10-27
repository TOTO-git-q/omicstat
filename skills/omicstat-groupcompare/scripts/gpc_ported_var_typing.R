# Independent source port from TOTO-git-q/medstat@12292d020ef4a8575a3a1db880b81786ee3547fa
# skills/_shared/scripts/var_typing.R; source numerical equivalence awaits native R4.6.1.
# See PORT_ADAPTATIONS.json. Loaded only into an isolated private environment.
# var_typing.R -- variable type classification and the descriptive-stat /
# test-selection mapping table, shared across all medstat skills.
# ASCII only on purpose: R on Windows with a GBK locale mangles UTF-8 source.
#
# Single source of truth for two decisions every skill in this suite needs
# and must make identically:
#   1. classify_variable() -- what IS this variable (continuous/binary/
#      categorical/ordinal) and, for continuous variables, is it normal.
#   2. recommend_test()    -- given a variable's type (and the comparison
#      context: how many groups, paired or not, ordered or not), which
#      descriptive statistic and which test does convention expect.
#
# Routing rule for normality (decision, not a guess): |skewness| > 1 is the
# PRIMARY criterion. Shapiro-Wilk and the Q-Q correlation (Filliben-style) are
# always computed and returned for reference/reporting, but neither ever picks
# the branch. Rationale, with numbers, is in
# research/phase2/P0-baseline-table.md section 1.2:
#   - at n>300ish, Shapiro's power approaches 1 and it rejects data that is
#     visibly, substantively normal (empirical: a 98% N(0,1) + 2% N(0,1.6)
#     mixture -- indistinguishable by eye -- gets Shapiro p=0.017 at n=5000,
#     while skewness is -0.05 and the Filliben r is 0.9996);
#   - at n<20, Shapiro is underpowered (83.6% detection of a genuinely skewed
#     lognormal at n=20 over 500 simulated repeats), so a non-significant
#     Shapiro there is not evidence of normality either;
#   - the Filliben-style Q-Q correlation stays put (0.953-0.966) across four
#     orders of magnitude of n on the same lognormal(0, 0.4), while Shapiro p
#     collapses from 1.14e-03 to 7.89e-45 over the same range.
# classify_variable() therefore: treats n<20 as "not enough evidence, default
# to skewed/non-normal (conservative)"; otherwise routes on |skewness|>1;
# always reports shapiro_p and filliben_r alongside for the Methods section
# and reviewer questions, per the house rule that the reader who expects a
# number should get one, not a refusal.
#
# classify_variable() never infers "categorical" from a low unique-value count
# on a numeric vector (the classic unique_count<=5 heuristic misclassifies
# small-sample continuous variables -- P0-baseline-table.md section 8.3
# NEVER list). A numeric vector with more than two distinct values is always
# "continuous" unless the caller overrides with force_type. Exactly two
# distinct values (numeric, character, factor, or logical) is unambiguously
# "binary" regardless of how many groups.

`%||%` <- function(a, b) if (is.null(a) || length(a) == 0 || (length(a) == 1 && is.na(a))) b else a

VALID_VAR_TYPES <- c("continuous", "binary", "categorical", "ordinal", "constant")

# --------------------------------------------------------- normality math ----

# Sample skewness: Fisher-Pearson g1 (population moments, no small-sample bias
# correction). Matches moments::skewness()'s default -- cross-checked on this
# machine against survival::pbc: bili = 2.707849, age = 0.086538, both to 6
# significant figures, and both consistent with the ranges already reported in
# P0-baseline-table.md section 1.2. Implemented directly (no moments/e1071
# dependency) so this file has no package requirement beyond base R.
skewness_g1 <- function(x) {
  x <- x[is.finite(x)]
  n <- length(x)
  if (n < 3) return(NA_real_)
  m <- mean(x)
  m2 <- sum((x - m)^2) / n
  m3 <- sum((x - m)^3) / n
  if (m2 <= 0) return(NA_real_)
  m3 / m2^1.5
}

# Q-Q correlation against normal quantiles (sorted x vs qnorm(ppoints(n))).
# Reported as a steadier large-n companion to shapiro_p_ref(), not as a
# routing criterion (see file header). Called "filliben_r" per the naming
# already fixed in P0-baseline-table.md section 8.4's classify_variable()
# spec; it is the plain Q-Q correlation, not Filliben's original probability
# plot correlation coefficient with median-rank plotting positions -- close in
# practice but not bit-identical, and downstream text should say "Q-Q
# correlation" rather than cite Filliben (1975) for the exact number.
filliben_r <- function(x) {
  x <- x[is.finite(x)]
  n <- length(x)
  if (n < 3) return(NA_real_)
  suppressWarnings(stats::cor(x = sort(x), y = stats::qnorm(p = stats::ppoints(n = n))))
}

# Shapiro-Wilk, reference output only -- computed and returned so Methods can
# say "assessed by skewness; Shapiro-Wilk reported for reference" (the
# section 7.1 template), never consulted by classify_variable() to pick a
# branch. shapiro.test() errors above n=5000, so above `cap` a fixed-seed
# subsample is tested instead of refusing to report a number; the global RNG
# stream is saved and restored so calling this does not perturb a caller's
# own reproducibility.
shapiro_p_ref <- function(x, seed = 20250813L, cap = 5000L) {
  x <- x[is.finite(x)]
  n <- length(x)
  if (n < 3) return(NA_real_)
  if (n > cap) {
    has_seed <- exists(".Random.seed", envir = .GlobalEnv)
    old_seed <- if (has_seed) get(".Random.seed", envir = .GlobalEnv) else NULL
    set.seed(seed)
    x <- sample(x, cap)
    if (has_seed) assign(".Random.seed", old_seed, envir = .GlobalEnv)
    else if (exists(".Random.seed", envir = .GlobalEnv)) rm(".Random.seed", envir = .GlobalEnv)
  }
  tryCatch(stats::shapiro.test(x = x)$p.value, error = function(e) NA_real_)
}

# ------------------------------------------------------ type auto-detect ----

# Internal. xc is x with NAs already dropped; n_unique is length(unique(xc)).
.auto_var_type <- function(xc, n_unique) {
  if (n_unique <= 1) return("constant")
  if (is.logical(xc)) return("binary")
  if (is.character(xc)) xc <- factor(xc)
  if (is.factor(xc)) {
    if (n_unique == 2) return("binary")
    if (is.ordered(xc)) return("ordinal")
    return("categorical")
  }
  if (is.numeric(xc) || is.integer(xc)) {
    if (n_unique == 2) return("binary")
    return("continuous")
  }
  stop(sprintf(
    "OS_GPC_UNSUPPORTED_VECTOR_TYPE: class %s is not numeric/integer/logical/character/factor; pass force_type explicitly.",
    paste(class(xc), collapse = "/")), call. = FALSE)
}

# --------------------------------------------------------------- public -----

# classify_variable(x, var_name, force_type)
#
# x:          a vector -- numeric, integer, logical, character, factor, or
#             ordered factor. NAs are allowed and counted.
# var_name:   optional label carried through to the output for logging/joins;
#             does not affect the classification.
# force_type: one of VALID_VAR_TYPES. When supplied, auto-detection is
#             skipped entirely and this is the type -- this is how a caller
#             declares "this numeric code is actually a category" (the CLI
#             layer's --factor-vars is expected to set this), since
#             classify_variable() itself will never guess that from a numeric
#             vector's unique-value count (see file header).
#
# Returns a list:
#   var_name, type, n, n_missing, pct_missing, n_unique,
#   normal, skewness, filliben_r, shapiro_p, summary_stat, notes
# `normal`/`skewness`/`filliben_r`/`shapiro_p`/`summary_stat` are meaningful
# only when type=="continuous"; they are NA (summary_stat: NA_character_)
# otherwise. `notes` is a character vector, possibly empty, of caveats a
# renderer or Methods draft should surface (e.g. "n<20, defaulted to skewed").
classify_variable <- function(x, var_name = NULL, force_type = NULL) {
  n <- length(x)
  is_na <- is.na(x)
  n_missing <- sum(is_na)
  pct_missing <- if (n > 0) 100 * n_missing / n else NA_real_
  xc <- x[!is_na]
  n_unique <- length(unique(xc))
  notes <- character(0)

  if (!is.null(force_type)) {
    type <- match.arg(force_type, VALID_VAR_TYPES)
  } else {
    type <- .auto_var_type(xc, n_unique)
  }

  if (type == "continuous") {
    # A factor forced to continuous must be read through its LABELS, not its
    # internal integer level codes -- as.numeric(factor(c("5","6","100"))) is
    # the level-rank sequence (e.g. 1,2,3), not c(5,6,100), and the guard
    # below (any(is.na(xn) & !is.na(xc))) never catches this because a
    # factor always coerces to SOME number, just the wrong one. Routing
    # through as.character() first makes as.numeric() read the label text,
    # and any genuinely non-numeric label still trips the guard as before.
    if (is.factor(xc)) xc <- as.character(xc)
    xn <- suppressWarnings(as.numeric(xc))
    if (any(is.na(xn) & !is.na(xc))) {
      stop("OS_GPC_NON_NUMERIC_CONTINUOUS: force_type='continuous' but the vector does not coerce cleanly to numeric.", call. = FALSE)
    }
    n_eff <- length(xn)
    sk <- skewness_g1(xn)
    fr <- filliben_r(xn)
    sp <- shapiro_p_ref(xn)
    if (n_eff < 3) {
      normal <- NA
      notes <- c(notes, sprintf("n=%d (<3): normality not assessable", n_eff))
    } else if (n_eff < 20) {
      normal <- FALSE
      notes <- c(notes, sprintf(
        "n=%d (<20): Shapiro is underpowered at this size; defaulted to skewed/non-normal (conservative). Confirm with a Q-Q plot before overriding.",
        n_eff))
    } else if (is.na(sk)) {
      normal <- NA
      notes <- c(notes, "skewness not computable (zero variance)")
    } else {
      normal <- abs(sk) <= 1
      if (n_eff > 300 && !is.na(sp) && sp < 0.05 && isTRUE(normal)) {
        notes <- c(notes, sprintf(
          "Shapiro-Wilk P=%.3g flags non-normal at this sample size (n=%d) but |skewness|=%.2f<=1; skewness is the routing criterion here (n>300ish makes Shapiro oversensitive -- see P0-baseline-table.md 1.2), reported for reference.",
          sp, n_eff, abs(sk)))
      }
    }
    summary_stat <- if (isTRUE(normal)) "mean_sd" else if (isFALSE(normal)) "median_iqr" else NA_character_
  } else {
    sk <- NA_real_; fr <- NA_real_; sp <- NA_real_; normal <- NA; summary_stat <- NA_character_
    if (type == "constant") notes <- c(notes, "zero or one distinct non-missing value; no descriptive/test routing applies")
  }

  list(
    var_name = var_name %||% NA_character_,
    type = type,
    n = as.integer(n), n_missing = as.integer(n_missing), pct_missing = pct_missing,
    n_unique = as.integer(n_unique),
    normal = normal, skewness = sk, filliben_r = fr, shapiro_p = sp,
    summary_stat = summary_stat,
    notes = notes
  )
}

# expected_cell_min(tab): smallest expected cell count under independence, the
# quantity Fisher-vs-chi-square routing is defined on. Same formula
# chisq.test() uses internally (outer(rowSums, colSums)/n); exposed here so a
# caller can compute it once (or via table(x, group)) and pass it to
# recommend_test() without duplicating the arithmetic or accidentally using
# observed counts where expected counts are required.
expected_cell_min <- function(tab) {
  tab <- as.matrix(tab)
  if (any(dim(tab) < 2)) return(NA_real_)
  rs <- rowSums(tab); cs <- colSums(tab); n <- sum(tab)
  if (n == 0) return(NA_real_)
  min(outer(rs, cs) / n)
}

# recommend_test(): the decision-tree half of P0-baseline-table.md section
# 1.1/1.3, encoded once so baseline-table, assoc-workflow, and any later
# skill route to the same test instead of re-deriving the tree. Returns a
# recommendation only -- it does not touch data or run a test, keeping
# "what test" (this file) separate from "what did the test say"
# (effect_table.R) and "how does it render" (render_md.R/render_docx.R).
#
# var_type: "continuous" | "binary" | "categorical" | "ordinal" | "constant"
#           -- the ROW variable's type, typically classify_variable(x)$type.
#           "constant" (zero or one distinct non-missing value) short-
#           circuits to a descriptive-only recommendation -- there is no
#           between-group comparison to route to, and classify_variable()
#           legitimately returns this type (see its own VALID_VAR_TYPES /
#           the "constant" branch), so a baseline-table loop that classifies
#           every column and then calls recommend_test() on each one must
#           not crash on the first degenerate column it meets.
# n_groups: number of comparison groups (1 for a one-sample test).
# paired:   TRUE for matched pairs / repeated measures.
# normal:   TRUE/FALSE/NA, consulted only when var_type=="continuous", typically
#           classify_variable(x)$normal. NA is treated as the conservative
#           non-normal branch and flagged in `notes`.
# trend:    TRUE when the comparison groups are themselves ordered (dose
#           groups, exposure tertiles, ...), or var_type=="ordinal" -- routes
#           to the trend test regardless of n_groups/paired.
# expected_min: smallest expected cell count (see expected_cell_min()), used
#           only for binary/categorical/ordinal var_type to decide the
#           chi-square/Fisher split. NA skips the check and falls back to
#           chi-square with a note asking the caller to verify.
#
# Returns list(descriptive_stat, test_name, test_r_call, notes).
recommend_test <- function(var_type, n_groups = 2, paired = FALSE, normal = NA,
                            trend = FALSE, expected_min = NA_real_) {
  var_type <- match.arg(var_type, c("continuous", "binary", "categorical", "ordinal", "constant"))
  notes <- character(0)

  if (var_type == "constant") {
    return(list(descriptive_stat = "n_pct", test_name = NA_character_, test_r_call = NA_character_,
               notes = "zero or one distinct non-missing value (constant): no between-group comparison is possible; report n (%) descriptively only."))
  }

  if (var_type == "continuous") {
    if (is.na(normal)) {
      normal <- FALSE
      notes <- c(notes, "normal=NA supplied; defaulted to the non-normal (conservative) branch")
    }
    stat <- if (isTRUE(normal)) "mean_sd" else "median_iqr"
    test <- if (n_groups <= 1) {
      if (isTRUE(normal)) "one_sample_t" else "wilcoxon_signed_rank"
    } else if (n_groups == 2 && !paired) {
      if (isTRUE(normal)) "independent_t" else "mann_whitney_u"
    } else if (n_groups == 2 && paired) {
      if (isTRUE(normal)) "paired_t" else "wilcoxon_signed_rank"
    } else if (n_groups >= 3 && !paired) {
      if (isTRUE(normal)) "anova" else "kruskal_wallis"
    } else {
      if (isTRUE(normal)) "rm_anova" else "friedman"
    }
    rcall <- switch(test,
      one_sample_t          = "stats::t.test(x, mu = mu0)",
      wilcoxon_signed_rank  = "stats::wilcox.test(x, mu = mu0)  # or wilcox.test(x, y, paired=TRUE) for matched pairs",
      independent_t         = "stats::t.test(x ~ group)",
      mann_whitney_u        = "stats::wilcox.test(x ~ group)",
      paired_t              = "stats::t.test(x, y, paired = TRUE)",
      anova                 = "stats::oneway.test(x ~ group)  # or aov(x ~ group) for classic ANOVA table",
      kruskal_wallis        = "stats::kruskal.test(x ~ group)",
      rm_anova              = "stats::aov(x ~ group + Error(id/group))",
      friedman               = "stats::friedman.test(x, group, id)"
    )
    return(list(descriptive_stat = stat, test_name = test, test_r_call = rcall, notes = notes))
  }

  # binary / categorical / ordinal share the count-data branch.
  stat <- "n_pct"

  if (isTRUE(trend) || var_type == "ordinal") {
    notes2 <- notes
    if (!var_type %in% c("binary", "ordinal")) {
      notes2 <- c(notes2, "trend test requested for a variable that is neither binary nor ordinal; confirm the table is genuinely ordered before using a linear-trend statistic")
    }
    return(list(
      descriptive_stat = stat, test_name = "cochran_armitage_trend",
      test_r_call = "stats::prop.trend.test(x_events, x_n, score)  # binary row variable across ordered groups; for an ordinal row variable use a rank-based trend test, e.g. coin::independence_test(x ~ group, teststat='quad')",
      notes = notes2))
  }

  if (n_groups <= 1) {
    return(list(
      descriptive_stat = stat, test_name = "binomial_or_z_test",
      test_r_call = "stats::binom.test(x, n, p0)  # exact; stats::prop.test(x, n, p0) for the large-sample normal approximation",
      notes = notes))
  }

  if (isTRUE(paired)) {
    test <- if (n_groups == 2) "mcnemar" else "cochrans_q"
    if (n_groups == 2) {
      rcall <- "stats::mcnemar.test(tab)"
    } else {
      rcall <- "no base-R implementation; DescTools::CochranQTest() or RVAideMemoire::cochran.qtest() -- verify the package is installed before promising this test"
      notes <- c(notes, "Cochran's Q has no base-R implementation")
    }
    return(list(descriptive_stat = stat, test_name = test, test_r_call = rcall, notes = notes))
  }

  # unpaired, n_groups >= 2, not a trend comparison.
  is_2x2 <- var_type == "binary" && n_groups == 2
  if (!is.na(expected_min) && expected_min < 5) {
    # B3 fix (audit): routing is unchanged, but beyond 2x2 the exact network
    # algorithm (FEXACT) can exhaust its workspace -- on a 6x3 table with
    # n = 3000 it errored, gtsummary swallowed the error and Table 1 shipped a
    # blank P cell. The recommended call for a non-2x2 table is therefore the
    # Monte Carlo form, which baseline-table now actually dispatches.
    if (!is_2x2) {
      notes <- c(notes, "expected cell count <5 outside a 2x2 table: exact Fisher is computationally impractical beyond 2x2 -- Monte Carlo P via fisher.test(simulate.p.value=TRUE, B=10000) with a fixed seed, or collapse sparse categories")
    }
    return(list(
      descriptive_stat = stat, test_name = "fisher_exact",
      test_r_call = if (is_2x2) "stats::fisher.test(tab)" else
        "stats::fisher.test(tab, simulate.p.value = TRUE, B = 10000)  # Monte Carlo P; set a seed for reproducibility",
      notes = notes))
  }
  if (is.na(expected_min)) {
    notes <- c(notes, "expected_min not supplied; chi-square assumed valid -- verify no expected cell count is <5 (see expected_cell_min())")
  }
  list(
    descriptive_stat = stat, test_name = "chi_square",
    test_r_call = "stats::chisq.test(tab)  # base R defaults to Yates' continuity correction on 2x2 tables (correct=TRUE); gtsummary 2.5.1 defaults to correct=FALSE (P0-baseline-table.md 4.2) -- state which one you used",
    notes = notes)
}
