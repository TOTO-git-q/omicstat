#!/usr/bin/env Rscript
# test_effect_table.R -- exercises the effect_table.R schema: construction,
# validation (including that a genuinely bad table is REJECTED, not silently
# patched), and merging. No network, no external data file. Exits non-zero if
# any check fails.
#
#   Rscript tests/test_effect_table.R

here <- local({
  a <- commandArgs(trailingOnly = FALSE)
  f <- sub("^--file=", "", a[grep("^--file=", a)])
  if (length(f)) dirname(normalizePath(f)) else getwd()
})
source(file.path(here, "..", "scripts", "effect_table.R"))

fails <- character(0)
check <- function(label, ok, detail = "") {
  cat(sprintf("  [%s] %s%s\n", if (isTRUE(ok)) "ok" else "FAIL", label,
              if (nzchar(detail)) paste0(" -- ", detail) else ""))
  if (!isTRUE(ok)) fails <<- c(fails, label)
}
errored <- function(expr) tryCatch({ force(expr); FALSE }, error = function(e) TRUE)
# Runs expr, returns list(value, warned) without letting the warning print --
# used below to confirm as_forest_input() still emits its deprecation notice.
warned <- function(expr) {
  w <- FALSE
  v <- withCallingHandlers(expr, warning = function(cond) {
    w <<- TRUE
    invokeRestart("muffleWarning")
  })
  list(value = v, warned = w)
}

# --------------------------------------------------------- 1. schema shape --
cat("1. schema shape\n")
sch <- effect_table_schema()
# 22 = the original 20 core columns + row_role/contrast (2026-08-14 addition,
# both core = FALSE -- see the "opt-in columns" checks in section 8 below).
check("schema has 22 documented columns", nrow(sch) == 22, sprintf("got %d", nrow(sch)))
check("schema columns are unique", !any(duplicated(sch$column)))
# Canonical column set per research/phase2/P0-assoc-workflow.md section 7 /
# scripts/forest.R, see docs/CONVENTIONS.md.
must_present <- c("term", "level", "analysis_id", "estimate", "ci_low", "ci_high",
                  "p_value", "p_adjusted", "n_unweighted", "n_events", "stratum")
check("canonical P0 section 7 columns all present", all(must_present %in% sch$column))
check("every schema row has a non-empty description", all(nzchar(sch$description)))
check("row_role/contrast are documented as core = FALSE (opt-in columns)",
      all(!sch$core[sch$column %in% c("row_role", "contrast")]))
check("every other schema column is core = TRUE",
      all(sch$core[!sch$column %in% c("row_role", "contrast")]))

et0 <- new_effect_table()
check("new_effect_table() has 0 rows", nrow(et0) == 0)
# new_effect_table() only builds CORE columns (2026-08-14: row_role/contrast
# are opt-in, added only when a caller actually uses them -- see section 8).
check("new_effect_table() columns match the schema's CORE columns, in order",
      identical(names(et0), sch$column[sch$core]))
check("new_effect_table() has exactly 20 columns (unaffected by the row_role/contrast addition)",
      ncol(et0) == 20, sprintf("got %d", ncol(et0)))

# ------------------------------------------------------- 2. construction ---
cat("2. add_effect_rows(): single and vectorised construction\n")
et <- add_effect_rows(term = "bmi", analysis_id = "model3", effect_type = "HR", estimate = 1.5,
                      ci_low = 1.2, ci_high = 1.9, p_value = 0.001, n_unweighted = 1000L,
                      n_events = 120L, weighted = FALSE)
check("single row added", nrow(et) == 1)
check("estimate stored as numeric", is.numeric(et$estimate) && et$estimate == 1.5)
check("ci_level defaults to 0.95", et$ci_level == 0.95)

et <- add_effect_rows(et, term = "race", analysis_id = "model3", effect_type = "OR",
                      level = c("Black", "Other"), estimate = c(1.1, 0.9),
                      ci_low = c(0.8, 0.6), ci_high = c(1.5, 1.3),
                      p_value = c(0.5, 0.6), n_unweighted = c(1000L, 1000L), n_events = c(120L, 120L))
check("vectorised add_effect_rows recycles across levels", nrow(et) == 3)
check("level column populated for the categorical rows", identical(et$level[2:3], c("Black", "Other")))

v <- validate_effect_table(et)
check("well-formed table validates ok", v$ok, paste(v$errors, collapse = "; "))

# ------------------------------------------------------- 3. bad tables -----
cat("3. validate_effect_table() rejects a bad table (not silently repaired)\n")

bad_bounds <- add_effect_rows(term = "x", analysis_id = "m1", effect_type = "OR", estimate = 5,
                              ci_low = 1, ci_high = 2, n_unweighted = 50L, validate = FALSE)
v <- validate_effect_table(bad_bounds)
check("estimate outside [ci_low, ci_high] is rejected", !v$ok)
check("error names the offending row", any(grepl("row\\(s\\) 1", v$errors)))
check("assert_effect_table() throws for this table", errored(assert_effect_table(bad_bounds)))

bad_order <- add_effect_rows(term = "x", analysis_id = "m1", effect_type = "OR", estimate = 1.5,
                             ci_low = 2, ci_high = 1, n_unweighted = 50L, validate = FALSE)
check("ci_low > ci_high is rejected", !validate_effect_table(bad_order)$ok)

bad_p <- add_effect_rows(term = "x", analysis_id = "m1", effect_type = "OR", estimate = 1,
                         ci_low = 0.5, ci_high = 2, p_value = 1.5, n_unweighted = 50L, validate = FALSE)
check("p_value outside [0,1] is rejected", !validate_effect_table(bad_p)$ok)

bad_ci_level <- add_effect_rows(term = "x", analysis_id = "m1", effect_type = "OR", estimate = 1,
                                ci_level = 1.5, n_unweighted = 50L, validate = FALSE)
check("ci_level outside (0,1] is rejected", !validate_effect_table(bad_ci_level)$ok)

bad_n <- add_effect_rows(term = "x", analysis_id = "m1", effect_type = "OR", estimate = 1,
                         n_unweighted = -5L, validate = FALSE)
check("negative n_unweighted is rejected", !validate_effect_table(bad_n)$ok)

bad_nevent <- add_effect_rows(term = "x", analysis_id = "m1", effect_type = "OR", estimate = 1,
                              n_unweighted = 10L, n_events = 20L, validate = FALSE)
check("n_events exceeding n_unweighted is rejected", !validate_effect_table(bad_nevent)$ok)

missing_n <- add_effect_rows(term = "y", analysis_id = "m1", effect_type = "OR", estimate = 1, validate = FALSE)
v <- validate_effect_table(missing_n)
check("missing required n_unweighted is rejected", !v$ok)
check("error names the required column", any(grepl("'n_unweighted'", v$errors)))

missing_col_table <- et0[, setdiff(names(et0), "term")]
v <- validate_effect_table(missing_col_table)
check("a table missing a required schema column is rejected outright", !v$ok)

not_a_df <- validate_effect_table(list(a = 1))
check("non-data.frame input is rejected, not crashed on", !not_a_df$ok)

empty_ok <- validate_effect_table(et0)
check("an empty (0-row) table is valid (nothing to contradict itself)", empty_ok$ok)
check("but flagged with a zero-rows warning", any(grepl("zero rows", empty_ok$warnings)))

# ---------------------------------------------------- 4. soft warnings -----
cat("4. warnings that do not fail validation\n")
weird_type <- add_effect_rows(term = "z", analysis_id = "m1", effect_type = "made_up_scale",
                              estimate = 1, n_unweighted = 10L, validate = FALSE)
v <- validate_effect_table(weird_type)
check("effect_type outside vocabulary is a warning, not an error", v$ok && length(v$warnings) > 0)

p_adj_no_method <- add_effect_rows(term = "z", analysis_id = "m1", effect_type = "OR", estimate = 1,
                                   p_value = 0.2, p_adjusted = 0.4, n_unweighted = 10L, validate = FALSE)
v <- validate_effect_table(p_adj_no_method)
check("p_adjusted without p_adj_method is a warning, not an error", v$ok && any(grepl("p_adj_method", v$warnings)))

# --------------------------------------------------------- 5. merging ------
cat("5. combine_effect_tables()\n")
tabA <- add_effect_rows(term = "bmi", analysis_id = "model3", effect_type = "HR", estimate = 1.5,
                        ci_low = 1.2, ci_high = 1.9, p_value = 0.001, n_unweighted = 1000L, n_events = 120L)
tabB <- add_effect_rows(term = "age", analysis_id = "model3", effect_type = "HR", estimate = 1.02,
                        ci_low = 1.00, ci_high = 1.04, p_value = 0.03, n_unweighted = 1000L, n_events = 120L)
comb <- combine_effect_tables(tabA, tabB)
check("combine_effect_tables(a, b) row-binds", nrow(comb) == 2)
check("combine_effect_tables() re-validates the result", validate_effect_table(comb)$ok)

comb_list <- combine_effect_tables(list(tabA, tabB))
check("list-form call gives the same result as dots-form", identical(comb$term, comb_list$term))

tabC <- tabA
tabC$extra_flag <- TRUE
combC <- combine_effect_tables(tabC, tabB)
check("an extra caller-defined column is kept", "extra_flag" %in% names(combC))
check("rows missing the extra column get NA, not an error", is.na(combC$extra_flag[combC$term == "age"]))

check("combining a bad table with a good one is rejected",
      errored(combine_effect_tables(bad_bounds, tabA)))

# ------------------------------------------ 6. as_forest_input() (deprecated) --
cat("6. as_forest_input(): deprecated no-op passthrough (columns already match forest.R)\n")
# EFFECT_TABLE_SCHEMA now uses forest.R's own column names directly (see
# docs/CONVENTIONS.md), so as_forest_input() no longer renames anything -- it
# just validates and returns et unchanged, with a deprecation warning.
res <- warned(as_forest_input(tabA))
fin <- res$value
check("as_forest_input() still emits a deprecation warning", res$warned)
check("as_forest_input() is a pure passthrough (identical to its input)", identical(fin, tabA))
check("ci_low/ci_high are already present (no rename needed)", all(c("ci_low", "ci_high") %in% names(fin)))
check("p_value/p_adjusted are already present (no rename needed)", all(c("p_value", "p_adjusted") %in% names(fin)))
check("n_unweighted/n_events are already present (no rename needed)", all(c("n_unweighted", "n_events") %in% names(fin)))
check("forest.R's hard-required base columns are all present",
      all(c("term", "estimate", "ci_low", "ci_high") %in% names(fin)))
check("values are unchanged (no recomputation)", identical(fin$ci_low, tabA$ci_low))
check("as_forest_input() rejects a bad table too", errored(as_forest_input(bad_bounds)))

# ------------------------------ 7. regression: NA estimate + notes ---------
cat("7. estimate may be NA when notes explains why (audit:code regression; a reference-group row)\n")
ref_row <- add_effect_rows(term = "race", analysis_id = "model3", effect_type = "OR",
                           level = c("White (ref)", "Black"), estimate = c(NA_real_, 1.2),
                           ci_low = c(NA_real_, 0.9), ci_high = c(NA_real_, 1.6),
                           n_unweighted = c(1000L, 1000L),
                           notes = c("reference category, no estimate", NA_character_),
                           validate = FALSE)
v_ref <- validate_effect_table(ref_row)
check("a reference row (estimate=NA, notes explains why) validates ok, matching docs/effect_table_schema.md",
      v_ref$ok, paste(v_ref$errors, collapse = "; "))
ref_row_no_note <- add_effect_rows(term = "race", analysis_id = "model3", effect_type = "OR",
                                   level = "White (ref)", estimate = NA_real_, n_unweighted = 1000L,
                                   validate = FALSE)
v_ref_bad <- validate_effect_table(ref_row_no_note)
check("estimate=NA WITHOUT a notes explanation is still rejected (the exception cannot hide an unexplained gap)",
      !v_ref_bad$ok)

# ------------------------ 8. row_role/contrast: opt-in schema columns ------
cat("8. row_role/contrast (2026-08-14 addition): opt-in columns, checked only when present\n")

# 8a. EFFECT_TYPE_VOCAB additions (diagnostic-accuracy measures) render/
# validate cleanly, at both ends of the new entries' scale families.
dx_types <- add_effect_rows(term = "sens", analysis_id = "primary_cutpoint", effect_type = "sensitivity",
                            estimate = 0.85, ci_low = 0.80, ci_high = 0.90, n_unweighted = 500L,
                            validate = FALSE)
dx_types <- add_effect_rows(dx_types, term = "npv", analysis_id = "primary_cutpoint", effect_type = "npv",
                            estimate = 0.92, ci_low = 0.88, ci_high = 0.95, n_unweighted = 500L,
                            validate = FALSE)
dx_types <- add_effect_rows(dx_types, term = "dor", analysis_id = "primary_cutpoint", effect_type = "dor",
                            estimate = 12.5, ci_low = 8.1, ci_high = 19.3, n_unweighted = 500L,
                            validate = FALSE)
v_dx <- validate_effect_table(dx_types)
check("new EFFECT_TYPE_VOCAB entries (sensitivity/npv/dor) are in-vocabulary -- no warning raised",
      v_dx$ok && !any(grepl("effect_type has value", v_dx$warnings)),
      paste(c(v_dx$errors, v_dx$warnings), collapse = "; "))

# 8b. new_effect_table() output is unaffected -- exactly 20 columns, same
# names, same order, as before row_role/contrast existed.
et0b <- new_effect_table()
check("new_effect_table() still returns exactly the 20 pre-existing columns (no automatic row_role/contrast)",
      identical(names(et0b), c("term", "level", "analysis_id", "effect_type", "estimate", "ci_low",
                               "ci_high", "ci_level", "p_value", "p_adjusted", "p_adj_method",
                               "n_unweighted", "n_events", "design_df", "weighted", "stratum_var",
                               "stratum", "test_name", "model_spec_hash", "notes")))

# 8c. add_effect_rows() WITHOUT row_role/contrast produces byte-identical
# column shape to before this addition (the opt-in contract's core claim).
plain <- add_effect_rows(term = "bmi", analysis_id = "model3", effect_type = "HR", estimate = 1.5,
                         ci_low = 1.2, ci_high = 1.9, n_unweighted = 1000L)
check("add_effect_rows() without row_role/contrast produces a 20-column table",
      ncol(plain) == 20, sprintf("got %d: %s", ncol(plain), paste(names(plain), collapse = ",")))

# 8d. add_effect_rows(row_role=) opts a single call into the column; a
# validation-time-only mechanism would have missed this, so this checks
# construction, not just validate_effect_table() on a hand-built table.
with_role <- add_effect_rows(term = "study_a", analysis_id = "pooled_hr", effect_type = "HR",
                             estimate = 1.3, ci_low = 1.1, ci_high = 1.5, n_unweighted = 200L,
                             row_role = "study")
check("add_effect_rows(row_role=) adds the row_role column to the built table",
      "row_role" %in% names(with_role) && identical(with_role$row_role, "study"))
check("row_role opt-in does not also add contrast (independent opt-ins)",
      !("contrast" %in% names(with_role)))

# 8e. mid-chain opt-in: earlier rows built without row_role backfill to NA,
# not dropped or erroring, when a later row in the same chain supplies it.
chain <- add_effect_rows(term = "study_a", analysis_id = "pooled_hr", effect_type = "HR",
                         estimate = 1.1, ci_low = 0.9, ci_high = 1.3, n_unweighted = 50L)
chain <- add_effect_rows(chain, term = "pooled", analysis_id = "pooled_hr", effect_type = "HR",
                         estimate = 1.15, ci_low = 1.0, ci_high = 1.3, n_unweighted = 250L,
                         row_role = "pooled")
check("mid-chain row_role opt-in: table now has the column",
      "row_role" %in% names(chain))
check("mid-chain row_role opt-in: the earlier row (built before the column existed in this chain) is NA",
      is.na(chain$row_role[chain$term == "study_a"]))
check("mid-chain row_role opt-in: the row that supplied it keeps its value",
      identical(chain$row_role[chain$term == "pooled"], "pooled"))
v_chain <- validate_effect_table(chain)
check("mid-chain-built table with a backfilled-NA row_role cell still validates ok", v_chain$ok,
      paste(v_chain$errors, collapse = "; "))

# 8f. row_role enum: rejected when present and out of vocabulary, accepted
# for every documented value, and validate_effect_table() is silent about it
# entirely when the column is absent (the opt-in contract's validation half).
bad_role <- add_effect_rows(term = "x", analysis_id = "m1", effect_type = "HR", estimate = 1,
                            ci_low = 0.9, ci_high = 1.1, n_unweighted = 10L,
                            row_role = "made_up_role", validate = FALSE)
v_bad_role <- validate_effect_table(bad_role)
check("row_role outside ROW_ROLE_VOCAB is REJECTED (an error, not a warning, unlike effect_type)",
      !v_bad_role$ok && any(grepl("row_role", v_bad_role$errors)))
for (rr in c("study", "pooled", "subgroup_pooled", "sensitivity")) {
  good_role <- add_effect_rows(term = "x", analysis_id = "m1", effect_type = "HR", estimate = 1,
                               ci_low = 0.9, ci_high = 1.1, n_unweighted = 10L,
                               row_role = rr, validate = FALSE)
  v_good <- validate_effect_table(good_role)
  check(sprintf("row_role = '%s' (documented ROW_ROLE_VOCAB member) validates ok", rr), v_good$ok,
       paste(v_good$errors, collapse = "; "))
}
check("validate_effect_table() never mentions row_role when the column is absent (plain table from section 2)",
      !any(grepl("row_role", c(validate_effect_table(et)$errors, validate_effect_table(et)$warnings))))

# 8g. contrast: free text, no enum -- any non-empty string is accepted, only
# the type is checked (already covered generically), never the value.
with_contrast <- add_effect_rows(term = "bmi", analysis_id = "model3", effect_type = "HR",
                                 estimate = 1.4, ci_low = 1.1, ci_high = 1.7, n_unweighted = 300L,
                                 contrast = "highest_vs_lowest")
v_contrast <- validate_effect_table(with_contrast)
check("contrast accepts arbitrary free text with no vocabulary restriction", v_contrast$ok,
      paste(v_contrast$errors, collapse = "; "))
check("contrast value is stored unchanged", identical(with_contrast$contrast, "highest_vs_lowest"))

# 8h. a hand-built 20-column table (pre-dating this addition) still passes
# validate_effect_table() untouched, and add_effect_rows() can still append
# to it without requiring it to already carry row_role/contrast.
legacy_et <- et0b  # the fresh 20-column table from 8b
legacy_et <- add_effect_rows(legacy_et, term = "y", analysis_id = "m1", effect_type = "OR",
                             estimate = 1.2, ci_low = 1.0, ci_high = 1.4, n_unweighted = 80L)
check("add_effect_rows() onto a pre-existing 20-column (row_role/contrast-less) et works and stays 20 columns",
      ncol(legacy_et) == 20 && nrow(legacy_et) == 1)

# 8i. combine_effect_tables(): row_role present on one input only still
# merges cleanly, backfilling NA on the table that lacked it -- and the
# no-bloat guarantee (neither input uses it -> output stays 20 columns).
tab_role <- add_effect_rows(term = "s1", analysis_id = "pooled_hr", effect_type = "HR", estimate = 1.1,
                            ci_low = 1.0, ci_high = 1.2, n_unweighted = 40L, row_role = "study")
tab_norole <- add_effect_rows(term = "s2", analysis_id = "pooled_hr", effect_type = "HR", estimate = 1.2,
                              ci_low = 1.1, ci_high = 1.3, n_unweighted = 40L)
comb_mixed <- combine_effect_tables(tab_role, tab_norole)
check("combine_effect_tables() with mixed row_role presence keeps the column",
      "row_role" %in% names(comb_mixed))
check("combine_effect_tables() backfills NA on the input that lacked row_role",
      is.na(comb_mixed$row_role[comb_mixed$term == "s2"]))
check("combine_effect_tables() preserves the value from the input that had it",
      identical(comb_mixed$row_role[comb_mixed$term == "s1"], "study"))

tab_c <- add_effect_rows(term = "s3", analysis_id = "pooled_hr", effect_type = "HR", estimate = 1.05,
                         ci_low = 0.95, ci_high = 1.15, n_unweighted = 40L)
tab_d <- add_effect_rows(term = "s4", analysis_id = "pooled_hr", effect_type = "HR", estimate = 1.06,
                         ci_low = 0.96, ci_high = 1.16, n_unweighted = 40L)
comb_plain <- combine_effect_tables(tab_c, tab_d)
check("combine_effect_tables() with NEITHER input using row_role/contrast stays at 20 columns (no bloat)",
      ncol(comb_plain) == 20, sprintf("got %d", ncol(comb_plain)))

# 8j. combine_effect_tables() starting from a still-empty (0-row)
# new_effect_table() accumulator, one side opting into row_role -- this is
# the actual production shape competing-risks/scripts/run_cmprsk.R uses
# (comment: "et_all's own still-empty starting table"). A 0-row data.frame
# column backfill bug here (bare NA instead of rep(NA, nrow(df))) was caught
# and fixed during this change; this regression case pins it down.
et_accum <- new_effect_table()
comb_from_empty <- combine_effect_tables(et_accum, tab_role)
check("combine_effect_tables() from a 0-row accumulator with a row_role-using table works without error",
      nrow(comb_from_empty) == 1 && "row_role" %in% names(comb_from_empty))

# ----------------------------------------------------------- summary -------
cat("\n")
if (length(fails)) {
  cat(sprintf("FAILED: %d check(s) failed:\n", length(fails)))
  for (f in fails) cat("  -", f, "\n")
  quit(status = 1)
} else {
  cat("All checks passed.\n")
  quit(status = 0)
}
