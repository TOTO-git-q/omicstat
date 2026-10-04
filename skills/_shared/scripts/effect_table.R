# effect_table.R -- the tidy effect-estimate table every skill in this suite
# produces and every renderer consumes. ASCII only on purpose: R on Windows
# with a GBK locale mangles UTF-8 source.
#
# Column structure is the canonical set named in
# research/phase2/P0-assoc-workflow.md section 7 (analysis_id/term/estimate/
# ci_low/ci_high/p_value/p_adjusted/n_unweighted/n_events/design_df/
# model_spec_hash) -- the same names scripts/forest.R (this suite's shared
# forest-plot renderer) expects, so an effect table can be piped into
# forest_plot() with zero glue code. (An earlier draft of this file used a
# different literal column list -- term/level/model/estimate/lower/upper/p/
# p_adj/n/n_event/stratum/... -- reconciled with the P0 section 7 names by
# treating `model` as the analysis label; that draft is gone, see
# docs/CONVENTIONS.md for the canonical list and as_forest_input() below for
# the back-compat shim.) Columns beyond the P0 section 7 set (level,
# effect_type, ci_level, p_adj_method, weighted, stratum_var, stratum,
# test_name, notes) are this
# suite's own extensions, kept because every renderer/skill relies on them;
# stratum_var sits alongside stratum so a subgroup row names both which
# variable split the data and which level it fell in. Two more (row_role,
# contrast; 2026-08-14) are OPTIONAL in a stronger sense than the rest: a
# table may omit them as COLUMNS entirely (not just leave them NA per row)
# with no validation consequence -- see the `core` field on
# EFFECT_TABLE_SCHEMA below and docs/effect_table_schema.md.
#
# Full semantics for every column are in
# skills/_shared/docs/effect_table_schema.md -- that document and
# EFFECT_TABLE_SCHEMA below must be kept in sync; the doc is written by hand
# but its column table is meant to be a transcription of this object; the
# smoke test in tests/test_effect_table.R checks column-for-column parity so
# the two cannot silently drift apart.
#
# Layout vs. computation are deliberately decoupled: this file only builds,
# validates, and merges the tidy table. It contains no rounding, no P-value
# formatting, no three-line-table logic -- that is render_md.R/render_docx.R's
# job precisely so a change to journal formatting rules never touches a
# number, and a change to a number (re-running a model) never touches layout
# code.

`%||%` <- function(a, b) if (is.null(a) || length(a) == 0 || (length(a) == 1 && is.na(a))) b else a

# --------------------------------------------------------------- schema -----

# The effect-scale vocabulary `effect_type` is expected to come from.
# validate_effect_table() only WARNS on a value outside this list (never
# errors) -- a new skill may legitimately need a scale not anticipated here,
# and the house rule is "never refuse to compute/store a number the field
# expects", not "reject anything unfamiliar".
#
# Membership here is purely a vocabulary list for that warning -- this file
# does not branch on effect_type anywhere (no per-type formatting, no
# per-type validation rule), so adding a name below never changes behaviour
# for any existing type. The vocabulary falls into two informal families,
# consistent with how callers already use `ratio=` (forest.R) / `x_trans=`
# to decide log-scale vs linear-scale plotting -- noted here for future
# additions, not enforced by this file:
#   ratio-scale, null value 1, plotted on a log axis: OR/HR/RR/IRR
#   difference/absolute-scale, null value 0, linear axis: beta/mean_diff/
#     median_diff/SMD/prop_diff
# The block added below (cpm-pipeline's discrimination/calibration/utility
# metrics, competing-risks' absolute risk, causal-mediation's prevalence,
# latent-class's entropy) is also difference/absolute-scale, but for most of
# these "null value" does not mean "no effect" the way 0 does for a mean
# difference -- c_index/brier/entropy/prevalence/risk are bounded summary
# statistics, not contrasts against a reference, so there is no ref-line-at-1
# (or at any single "null") convention for them the way ratio types get one.
# cal_slope is the nearest thing to an exception (perfect calibration = 1,
# not 0) but is still not ratio-scale (it is a regression slope, plotted
# linearly, never log-transformed) -- callers plotting it should pass
# ratio = FALSE and set ref_line = 1 explicitly rather than relying on any
# default here.
# 2026-08-14 addition: diagnostic-accuracy's own measures. sensitivity/
# specificity/ppv/npv are absolute [0,1] rates, same informal family as
# risk/prevalence above (bounded summary statistics, no ratio scale, no
# null-at-1 reference line). lr_pos/lr_neg (positive/negative likelihood
# ratio) and dor (diagnostic odds ratio) ARE ratio-scale, null value 1, log
# axis -- same family as OR/HR/RR/IRR above, listed here rather than folded
# into that first group only because they are diagnostic-accuracy-specific
# terminology, not because the scale differs.
EFFECT_TYPE_VOCAB <- c("OR", "HR", "RR", "IRR", "beta", "mean_diff", "median_diff",
                       "SMD", "prop_diff",
                       "c_index", "cal_slope", "cal_intercept", "net_benefit",
                       "brier", "risk", "prevalence", "entropy",
                       "sensitivity", "specificity", "ppv", "npv",
                       "lr_pos", "lr_neg", "dor",
                       "other")

# Closed enum for the OPTIONAL `row_role` column (2026-08-14 addition, see
# EFFECT_TABLE_SCHEMA below and docs/effect_table_schema.md). Unlike
# EFFECT_TYPE_VOCAB, an out-of-vocabulary row_role value is a hard error, not
# a warning -- row_role is new enough that nothing outside this vocabulary
# could already be relying on a looser rule, and the whole point of the
# column is a machine-checkable study/pooled distinction, not a free-text
# hint.
ROW_ROLE_VOCAB <- c("study", "pooled", "subgroup_pooled", "sensitivity")

# Reader-facing labels for the canonical effect-table schema. NA means that a
# provenance or machine-routing field is omitted from a reader-facing table.
# The render layer merges estimate/ci_low/ci_high into one column and may use
# the effect type (for example, "HR (95% CI)") in place of "Estimate".
EFFECT_TABLE_DISPLAY_NAMES <- c(
  term = "Variable",
  level = "Level",
  analysis_id = NA_character_,
  effect_type = NA_character_,
  estimate = "Estimate",
  ci_low = "95% CI",
  ci_high = "95% CI",
  ci_level = NA_character_,
  p_value = "P value",
  p_adjusted = "Adjusted P",
  p_adj_method = NA_character_,
  n_unweighted = "No. of participants",
  n_events = "Events",
  design_df = NA_character_,
  weighted = NA_character_,
  stratum_var = NA_character_,
  stratum = "Stratum",
  test_name = NA_character_,
  model_spec_hash = NA_character_,
  notes = "Notes",
  row_role = NA_character_,
  contrast = NA_character_
)

EFFECT_TABLE_SCHEMA <- data.frame(
  column = c("term", "level", "analysis_id", "effect_type", "estimate", "ci_low", "ci_high",
             "ci_level", "p_value", "p_adjusted", "p_adj_method", "n_unweighted", "n_events", "design_df",
             "weighted", "stratum_var", "stratum", "test_name", "model_spec_hash", "notes",
             "row_role", "contrast"),
  type = c("character", "character", "character", "character", "numeric", "numeric", "numeric",
           "numeric", "numeric", "numeric", "character", "integer", "integer", "numeric",
           "logical", "character", "character", "character", "character", "character",
           "character", "character"),
  required = c(TRUE, FALSE, TRUE, TRUE, TRUE, FALSE, FALSE,
               FALSE, FALSE, FALSE, FALSE, TRUE, FALSE, FALSE,
               TRUE, FALSE, FALSE, FALSE, FALSE, FALSE,
               FALSE, FALSE),
  # `core`: TRUE for the original 20 columns, which must exist as a column in
  # any table validate_effect_table()/add_effect_rows() will accept (this is
  # the pre-existing, unchanged rule -- see the missing_cols check below).
  # FALSE for row_role/contrast (2026-08-14 addition): these two may be
  # entirely ABSENT from a table -- not just NA-valued -- and validation
  # treats that exactly as it did before these columns existed. This is a
  # different axis from `required` (which only governs whether a value in an
  # ALREADY-PRESENT column may be NA per row); `core` governs whether the
  # column itself must be present at all. Every one of the original 20
  # columns is `core = TRUE` regardless of its `required` value (e.g. `level`
  # is required = FALSE but still must exist as a column) -- that pairing
  # predates this addition and is intentionally left alone.
  core = c(rep(TRUE, 20), FALSE, FALSE),
  description = c(
    "Variable or contrast name, e.g. 'bmi', 'Q4_vs_Q1', 'sexFemale'.",
    "Level within `term` for a leveled/categorical contrast; NA for a single continuous per-unit term.",
    "Which model/analysis produced this row, e.g. 'crude','model1','model3','rcs_threshold','subgroup_male'. This is the P0-assoc-workflow.md section 7 analysis_id column (also doubles as the Model 1/2/3 label in that report's section 1).",
    "Effect-measure scale; expected to be one of EFFECT_TYPE_VOCAB (OR/HR/RR/IRR/beta/mean_diff/median_diff/SMD/prop_diff/other); other values are accepted with a warning, not rejected.",
    "Point estimate, on the scale named by effect_type.",
    "Lower bound of the interval at ci_level; NA if not computed.",
    "Upper bound of the interval at ci_level; NA if not computed.",
    "Confidence level of ci_low/ci_high as a proportion (default 0.95 at row-construction time). Never assume 0.95 silently when reading someone else's table.",
    "Raw two-sided P value for this term.",
    "Multiplicity-adjusted P value; NA -- not omitted -- when no adjustment was performed. House rule: FDR/Bonferroni default OFF; when it is on, report both p_value and p_adjusted, never only p_adjusted.",
    "Adjustment method used to produce p_adjusted, e.g. 'BH','bonferroni'; NA when p_adjusted is NA.",
    "Unweighted analytic N underlying this estimate.",
    "Event/case count for survival or binary outcomes; NA when not applicable.",
    "Survey design degrees of freedom (degf(design)); NA for non-survey models.",
    "TRUE if this estimate came from a survey-weighted model/design.",
    "Name of the variable defining a stratum/subgroup split, e.g. 'sex'; NA outside subgroup analyses.",
    "The stratum level this row belongs to, e.g. 'Male'; NA outside subgroup analyses.",
    "Actual R test/model function used, e.g. 'svycoxph','wilcox.test','chisq.test'; free text, for provenance and for Methods drafting.",
    "Hash of the covariate set + complete-case set behind this estimate, so a figure and a table can be auto-checked as coming from the same model spec (P0-assoc-workflow.md section 7).",
    "Free-text caveat surfaced to the renderer/Methods draft, e.g. 'Fisher exact, expected count <5'.",
    "OPTIONAL (2026-08-14 addition); may be entirely absent from a table with no validation consequence. When present, classifies this row within its analysis_id for an aggregate-data (meta-analytic) effect table that mixes individual-study rows with a pooled/summary row: one of 'study' (a single contributing study's own estimate), 'pooled' (the meta-analytic pooled estimate), 'subgroup_pooled' (a pooled estimate within one subgroup/stratum of a subgroup meta-analysis), or 'sensitivity' (a pooled estimate from a sensitivity/leave-one-out re-run). validate_effect_table() rejects any other non-NA value as OS_SCHEMA_INVALID, but ONLY when the row_role column is present at all.",
    "OPTIONAL (2026-08-14 addition); may be entirely absent from a table with no validation consequence. Free-text semantic tag for what this row's estimate contrasts against, e.g. 'per_unit', 'vs_reference', 'highest_vs_lowest'. Not a closed vocabulary (unlike row_role) -- validate_effect_table() does not check its values, only its type when the column is present."
  ),
  stringsAsFactors = FALSE
)

effect_table_schema <- function() EFFECT_TABLE_SCHEMA

.empty_col <- function(type) {
  switch(type,
    character = character(0),
    numeric = numeric(0),
    integer = integer(0),
    logical = logical(0),
    stop(sprintf("OS_SCHEMA_INTERNAL: unknown column type '%s'", type), call. = FALSE))
}

.coerce_schema <- function(df) {
  for (i in seq_len(nrow(EFFECT_TABLE_SCHEMA))) {
    cn <- EFFECT_TABLE_SCHEMA$column[i]; ty <- EFFECT_TABLE_SCHEMA$type[i]
    if (!cn %in% names(df)) next
    df[[cn]] <- switch(ty,
      character = as.character(df[[cn]]),
      numeric = as.numeric(df[[cn]]),
      integer = as.integer(df[[cn]]),
      logical = as.logical(df[[cn]]),
      df[[cn]])
  }
  df
}

# --------------------------------------------------------- construction -----

# new_effect_table(): an empty (0-row) table with every CORE schema column
# present and correctly typed. rbind()-ing rows of the wrong type onto this
# will error immediately rather than silently coercing character estimates --
# that is deliberate.
#
# Only `core` columns (EFFECT_TABLE_SCHEMA$core; the original 20) are built
# here -- row_role/contrast (2026-08-14 addition) are NOT, on purpose: they
# are opt-in columns (see add_effect_rows()'s row_role=/contrast= parameters
# below) that should appear in a table's actual column set only when a
# caller actually uses them, so that a caller who never touches either one
# gets the EXACT pre-2026-08-14 column set here (this matters beyond cosmetic
# names(): several skills utils::write.csv() an effect table's own columns
# straight through, so an unconditionally-added, always-NA column would
# silently widen every module's exported .csv, not just the ones that opted
# in).
new_effect_table <- function() {
  core <- EFFECT_TABLE_SCHEMA[EFFECT_TABLE_SCHEMA$core, ]
  cols <- stats::setNames(lapply(core$type, .empty_col), core$column)
  do.call(data.frame, c(cols, list(stringsAsFactors = FALSE)))
}

# add_effect_rows(): append one or more rows. Every argument recycles against
# the others the way data.frame() recycles, so a single call for a
# categorical variable can pass a vector of `level`/`estimate`/`ci_low`/
# `ci_high` against a scalar `term`/`analysis_id`. Required columns
# (see EFFECT_TABLE_SCHEMA$required) have no default other than NA -- passing
# nothing for `n_unweighted`, for instance, produces a row that will fail
# validate_effect_table(), on purpose: construction and validation are
# separate steps, so a caller can build a table incrementally and only pay
# for the schema check once, at the end, via assert_effect_table().
#
# et:       an existing effect table to append to; NULL starts a new one.
# validate: when TRUE (default), runs validate_effect_table() on the result
#           and emits an R warning (not an error) for any problem found, so
#           mistakes surface immediately without blocking incremental builds.
add_effect_rows <- function(et = NULL, term, analysis_id, effect_type, estimate,
                             level = NA_character_, ci_low = NA_real_, ci_high = NA_real_,
                             ci_level = 0.95, p_value = NA_real_, p_adjusted = NA_real_,
                             p_adj_method = NA_character_, n_unweighted = NA_integer_,
                             n_events = NA_integer_, design_df = NA_real_,
                             weighted = FALSE, stratum_var = NA_character_,
                             stratum = NA_character_, test_name = NA_character_,
                             model_spec_hash = NA_character_, notes = NA_character_,
                             row_role = NULL, contrast = NULL,
                             validate = TRUE) {
  if (is.null(et)) et <- new_effect_table()
  # row_role/contrast (2026-08-14 addition) default to NULL, not NA_character_
  # like every other optional argument here -- that is what lets this
  # function tell "caller never mentioned this" apart from "caller wants this
  # row's role/contrast recorded as missing", and therefore only add the
  # column to the built table AT ALL when a caller actually opts in for THIS
  # call. A caller that never passes either one gets output with the exact
  # pre-2026-08-14 column set (see new_effect_table()'s own comment for why
  # that matters beyond cosmetics -- several skills write an effect table's
  # own columns straight to .csv).
  new_rows <- tryCatch({
      cols <- list(term = term, level = level, analysis_id = analysis_id, effect_type = effect_type,
                   estimate = estimate, ci_low = ci_low, ci_high = ci_high, ci_level = ci_level,
                   p_value = p_value, p_adjusted = p_adjusted, p_adj_method = p_adj_method,
                   n_unweighted = n_unweighted, n_events = n_events,
                   design_df = design_df, weighted = weighted, stratum_var = stratum_var,
                   stratum = stratum, test_name = test_name, model_spec_hash = model_spec_hash,
                   notes = notes)
      if (!is.null(row_role)) cols$row_role <- row_role
      if (!is.null(contrast)) cols$contrast <- contrast
      do.call(data.frame, c(cols, list(stringsAsFactors = FALSE)))
    },
    error = function(e) stop(sprintf(
      "OS_SCHEMA_BUILD_FAILED: could not assemble new row(s) -- %s. All arguments must recycle to a common length.",
      conditionMessage(e)), call. = FALSE))
  new_rows <- .coerce_schema(new_rows)
  # Only the `core` columns (the original 20) must already exist on `et` --
  # row_role/contrast (2026-08-14 addition, core = FALSE) are allowed to be
  # absent from an `et` built before this addition existed (e.g. a table
  # assembled by hand rather than via new_effect_table()).
  core_cols <- EFFECT_TABLE_SCHEMA$column[EFFECT_TABLE_SCHEMA$core]
  missing_cols <- setdiff(core_cols, names(et))
  if (length(missing_cols)) {
    stop(sprintf("OS_SCHEMA_INVALID: `et` is missing required column(s): %s -- build it with new_effect_table(), not from scratch.",
                 paste(missing_cols, collapse = ", ")), call. = FALSE)
  }
  # Union `et`'s columns with `new_rows`'s columns and backfill NA on
  # whichever side lacks one, exactly the way combine_effect_tables()
  # already treats any caller-defined extra column -- this is what lets
  # row_role/contrast start appearing partway through an incremental build
  # (et didn't have them yet, this call's row_role=/contrast= introduces
  # them) or stop being passed on a later call (et already has them from an
  # earlier call in this chain, this call's row_role/contrast stay NULL)
  # without either side erroring on a column-set mismatch at rbind().
  union_cols <- union(names(et), names(new_rows))
  for (m in setdiff(union_cols, names(et))) et[[m]] <- rep(NA, nrow(et))
  for (m in setdiff(union_cols, names(new_rows))) new_rows[[m]] <- rep(NA, nrow(new_rows))
  out <- rbind(et[union_cols], new_rows[union_cols])
  rownames(out) <- NULL
  if (isTRUE(validate)) {
    v <- validate_effect_table(out)
    if (!v$ok) {
      warning(sprintf("OS_SCHEMA_WARNING: table fails validation after add_effect_rows() -- %s",
                      paste(v$errors, collapse = "; ")), call. = FALSE)
    }
  }
  out
}

# ------------------------------------------------------------ validation ----

# validate_effect_table(): never throws. Returns list(ok, errors, warnings).
# `errors` are the things that make the table internally inconsistent or
# structurally broken (missing columns, estimate outside its own CI, p
# outside [0,1], negative n, ...) -- the house's one non-negotiable rule is
# "numbers must be self-consistent", and this function is where that is
# actually checked, mechanically, rather than trusted. `warnings` are things
# worth a second look but not disqualifying (effect_type outside the
# documented vocabulary, p_adj given without p_adj_method, a fully empty
# table).
validate_effect_table <- function(et) {
  errors <- character(0)
  warnings <- character(0)

  if (!is.data.frame(et)) {
    return(list(ok = FALSE, errors = "OS_SCHEMA_INVALID: not a data.frame", warnings = warnings))
  }
  # Only `core` columns (the original 20) are mandatory to even be PRESENT.
  # row_role/contrast (2026-08-14 addition, core = FALSE) may be entirely
  # absent with no validation consequence -- see the `core` column comment on
  # EFFECT_TABLE_SCHEMA above.
  missing_cols <- setdiff(EFFECT_TABLE_SCHEMA$column[EFFECT_TABLE_SCHEMA$core], names(et))
  if (length(missing_cols)) {
    errors <- c(errors, sprintf("OS_SCHEMA_INVALID: missing required column(s): %s",
                                paste(missing_cols, collapse = ", ")))
    return(list(ok = FALSE, errors = errors, warnings = warnings))
  }
  if (nrow(et) == 0) {
    return(list(ok = TRUE, errors = errors, warnings = c(warnings, "table has zero rows")))
  }

  # type checks first: everything below indexes into these columns assuming
  # the right vector class, so a wrong type must be caught before it causes a
  # confusing downstream error instead of a clear one.
  for (i in seq_len(nrow(EFFECT_TABLE_SCHEMA))) {
    cn <- EFFECT_TABLE_SCHEMA$column[i]; ty <- EFFECT_TABLE_SCHEMA$type[i]
    if (!cn %in% names(et)) next  # optional column (row_role/contrast) genuinely absent -- nothing to type-check
    col <- et[[cn]]
    ok_type <- switch(ty,
      character = is.character(col),
      numeric = is.numeric(col),
      integer = is.numeric(col),   # accept plain numeric holding whole numbers; class "integer" is not required
      logical = is.logical(col),
      TRUE)
    if (!ok_type) errors <- c(errors, sprintf("OS_SCHEMA_INVALID: column '%s' should be %s, got %s", cn, ty, class(col)[1]))
  }
  if (length(errors)) return(list(ok = FALSE, errors = errors, warnings = warnings))

  must_have <- EFFECT_TABLE_SCHEMA$column[EFFECT_TABLE_SCHEMA$required]
  for (cn in must_have) {
    col <- et[[cn]]
    bad <- is.na(col)
    if (is.character(col)) bad <- bad | !nzchar(trimws(ifelse(is.na(col), "x", col)))
    if (identical(cn, "estimate")) {
      # Documented exception (docs/effect_table_schema.md's column table):
      # estimate MAY be NA for a row that is genuinely not estimable -- a
      # reference-group row in a categorical contrast (e.g. "White (ref)"),
      # a model that failed to converge -- as long as `notes` explains why.
      # "required" here means "must not be silently missing with no
      # explanation", not "must always carry a number"; a row with estimate
      # NA and notes ALSO NA/empty is still rejected below, so this cannot
      # be used to sneak an unexplained gap past validation.
      has_note <- !is.na(et$notes) & nzchar(trimws(ifelse(is.na(et$notes), "", et$notes)))
      bad <- bad & !has_note
    }
    if (any(bad)) {
      errors <- c(errors, sprintf("OS_SCHEMA_INVALID: required column '%s' is NA/empty in row(s) %s",
                                  cn, paste(which(bad), collapse = ",")))
    }
  }

  if (any(!is.na(et$effect_type) & !(et$effect_type %in% EFFECT_TYPE_VOCAB))) {
    bad_vals <- unique(et$effect_type[!is.na(et$effect_type) & !(et$effect_type %in% EFFECT_TYPE_VOCAB)])
    warnings <- c(warnings, sprintf("effect_type has value(s) outside the documented vocabulary (%s): %s",
                                    paste(EFFECT_TYPE_VOCAB, collapse = "/"), paste(bad_vals, collapse = ", ")))
  }

  # row_role (2026-08-14 addition): checked ONLY when the column is present
  # at all (see the `core` comment above) -- a table that never sets it is
  # validated exactly as before this column existed. Unlike effect_type, an
  # out-of-vocabulary value here is an ERROR, not a warning (see
  # ROW_ROLE_VOCAB's own comment for why).
  if ("row_role" %in% names(et)) {
    bad_role <- !is.na(et$row_role) & !(et$row_role %in% ROW_ROLE_VOCAB)
    if (any(bad_role)) {
      errors <- c(errors, sprintf(
        "OS_SCHEMA_INVALID: row_role has value(s) outside the documented enum (%s) in row(s) %s",
        paste(ROW_ROLE_VOCAB, collapse = "/"), paste(which(bad_role), collapse = ",")))
    }
  }

  for (cn in c("p_value", "p_adjusted")) {
    v <- et[[cn]]
    bad <- !is.na(v) & (v < 0 | v > 1)
    if (any(bad)) errors <- c(errors, sprintf("OS_SCHEMA_INVALID: column '%s' has out-of-[0,1] value(s) in row(s) %s",
                                              cn, paste(which(bad), collapse = ",")))
  }

  bad_ci <- !is.na(et$ci_level) & (et$ci_level <= 0 | et$ci_level > 1)
  if (any(bad_ci)) errors <- c(errors, sprintf("OS_SCHEMA_INVALID: ci_level outside (0,1] in row(s) %s",
                                               paste(which(bad_ci), collapse = ",")))

  both <- !is.na(et$ci_low) & !is.na(et$ci_high)
  bad_order <- both & (et$ci_low > et$ci_high + 1e-8)
  if (any(bad_order)) errors <- c(errors, sprintf("OS_SCHEMA_INVALID: ci_low > ci_high in row(s) %s",
                                                  paste(which(bad_order), collapse = ",")))

  have_all3 <- both & !is.na(et$estimate)
  tol <- 1e-6 * pmax(1, abs(et$estimate))
  bad_bounds <- have_all3 & (et$estimate < et$ci_low - tol | et$estimate > et$ci_high + tol)
  if (any(bad_bounds)) errors <- c(errors, sprintf(
    "OS_SCHEMA_INVALID: estimate falls outside [ci_low, ci_high] in row(s) %s -- numbers must be self-consistent",
    paste(which(bad_bounds), collapse = ",")))

  p_adj_missing_method <- !is.na(et$p_adjusted) & is.na(et$p_adj_method)
  if (any(p_adj_missing_method)) warnings <- c(warnings, sprintf("p_adjusted given without p_adj_method in row(s) %s",
                                                                 paste(which(p_adj_missing_method), collapse = ",")))

  neg_n <- !is.na(et$n_unweighted) & et$n_unweighted < 0
  if (any(neg_n)) errors <- c(errors, sprintf("OS_SCHEMA_INVALID: negative n_unweighted in row(s) %s", paste(which(neg_n), collapse = ",")))

  bad_ne <- !is.na(et$n_events) & (et$n_events < 0 | (!is.na(et$n_unweighted) & et$n_events > et$n_unweighted))
  if (any(bad_ne)) errors <- c(errors, sprintf("OS_SCHEMA_INVALID: n_events negative or exceeds n_unweighted in row(s) %s",
                                               paste(which(bad_ne), collapse = ",")))

  list(ok = length(errors) == 0, errors = errors, warnings = warnings)
}

# assert_effect_table(): validate_effect_table()'s throwing counterpart.
# Returns `et` invisibly on success so it can sit in a pipe; stops with every
# accumulated error (not just the first) on failure.
assert_effect_table <- function(et, label = "effect table") {
  v <- validate_effect_table(et)
  if (!v$ok) {
    stop(sprintf("OS_SCHEMA_INVALID: %s failed validation:\n  - %s",
                 label, paste(v$errors, collapse = "\n  - ")), call. = FALSE)
  }
  for (w in v$warnings) warning(sprintf("OS_SCHEMA_WARNING: %s (%s)", w, label), call. = FALSE)
  invisible(et)
}

# --------------------------------------------------------------- merging ----

# combine_effect_tables(): row-bind two or more effect tables into one,
# validating each input and the result. Accepts either `combine_effect_tables(a, b, c)`
# or `combine_effect_tables(list(a, b, c))`. Columns beyond the fixed schema
# (a skill-specific extension) are kept and unioned across inputs, filled
# with NA where a given table did not have that column -- so long as every
# input independently passes schema validation, an extra column never blocks
# a merge.
# ------------------------------------------------------- interop bridge ----

# as_forest_input(): DEPRECATED. Previously renamed this schema's columns
# (lower/upper/p/p_adj/n/n_event) to the names scripts/forest.R (this suite's
# shared forest-plot renderer) expects (ci_low/ci_high/p_value/p_adjusted/
# n_unweighted/n_events). EFFECT_TABLE_SCHEMA now uses the P0-assoc-workflow.md
# section 7 names directly (see docs/CONVENTIONS.md), so an effect table
# already has forest.R's column names and no rename is needed -- this function
# is kept only as a no-op passthrough so existing callers of
# as_forest_input(et) do not break. It still validates its input (so a caller
# who was relying on that validation keeps getting it) and still returns a
# table forest_plot() can consume unchanged, but new code should call
# forest_plot() directly on the effect table and skip this wrapper.
as_forest_input <- function(et) {
  assert_effect_table(et, label = "effect table passed to as_forest_input()")
  warning(paste("OS_DEPRECATED: as_forest_input() is a no-op now that effect_table.R's",
                "columns already match forest.R's expected names; call forest_plot()",
                "directly on the effect table instead of wrapping it in as_forest_input()."),
          call. = FALSE)
  et
}

combine_effect_tables <- function(...) {
  tabs <- list(...)
  if (length(tabs) == 1 && is.list(tabs[[1]]) && !is.data.frame(tabs[[1]])) tabs <- tabs[[1]]
  if (!length(tabs)) return(new_effect_table())
  for (i in seq_along(tabs)) {
    assert_effect_table(tabs[[i]], label = sprintf("table %d of %d passed to combine_effect_tables()", i, length(tabs)))
  }
  all_cols <- unique(unlist(lapply(tabs, names)))
  # Keep CORE schema columns first, in schema order, then any extras
  # (including row_role/contrast, 2026-08-14 addition, when at least one
  # input actually has them). Only `core` columns are force-prepended here --
  # unlike before this addition, EFFECT_TABLE_SCHEMA$column is no longer the
  # same set as "always present": prepending the FULL schema (including
  # row_role/contrast) would add those two columns to every combined table's
  # output even when no input used them, which is exactly the always-NA
  # column bloat new_effect_table()'s own comment explains why to avoid.
  core_cols <- EFFECT_TABLE_SCHEMA$column[EFFECT_TABLE_SCHEMA$core]
  all_cols <- c(core_cols, setdiff(all_cols, core_cols))
  tabs2 <- lapply(tabs, function(df) {
    missing <- setdiff(all_cols, names(df))
    # rep(NA, nrow(df)), not bare NA: a bare NA is length 1 and
    # `df[[m]] <- NA` errors ("replacement has 1 row, data has 0") when df
    # has zero rows -- a real path now that row_role/contrast (2026-08-14
    # addition) can be the "extra" column being backfilled, e.g.
    # competing-risks/scripts/run_cmprsk.R combines its still-empty
    # new_effect_table() accumulator with each event type's rows.
    for (m in missing) df[[m]] <- rep(NA, nrow(df))
    df[all_cols]
  })
  out <- do.call(rbind, tabs2)
  rownames(out) <- NULL
  assert_effect_table(out, label = "combined table")
  out
}
