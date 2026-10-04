#!/usr/bin/env Rscript
# test_render.R -- fits a real logistic model on survival::nafld1, builds an
# effect_table.R from it, and renders one real markdown table and one real
# docx table from it (plus one generic-data.frame table each, to exercise the
# "any data.frame" path independent of the effect_table.R schema). Checks
# that files are actually produced and that the numbers surfacing in the
# rendered text match the fitted model, not a retyped copy. No network.
# Exits non-zero if any check fails.
#
#   Rscript tests/test_render.R

suppressPackageStartupMessages({ library(survival) })

here <- local({
  a <- commandArgs(trailingOnly = FALSE)
  f <- sub("^--file=", "", a[grep("^--file=", a)])
  if (length(f)) dirname(normalizePath(f)) else getwd()
})
source(file.path(here, "..", "scripts", "effect_table.R"))
source(file.path(here, "..", "scripts", "render_md.R"))
source(file.path(here, "..", "scripts", "render_docx.R"))

fails <- character(0)
check <- function(label, ok, detail = "") {
  cat(sprintf("  [%s] %s%s\n", if (isTRUE(ok)) "ok" else "FAIL", label,
              if (nzchar(detail)) paste0(" -- ", detail) else ""))
  if (!isTRUE(ok)) fails <<- c(fails, label)
}

outdir <- file.path(tempdir(), "omicstat_render_test")
dir.create(outdir, showWarnings = FALSE, recursive = TRUE)

# ------------------------------------------------- 1. a real fitted model ---
cat("1. fit a real model on nafld1 and build an effect_table from it\n")
d <- nafld1
d <- d[!is.na(d$bmi) & !is.na(d$age) & !is.na(d$male), ]
d$dead5 <- as.integer(d$status == 1 & d$futime <= 5 * 365.25)
fit <- glm(dead5 ~ age + male + bmi, data = d, family = binomial())
sm <- summary(fit)
cf <- coef(fit); ci <- suppressMessages(confint(fit))
n_fit <- length(fit$fitted.values)
n_event <- sum(d$dead5)

et <- new_effect_table()
for (term in c("age", "male", "bmi")) {
  et <- add_effect_rows(et, term = term, analysis_id = "logistic_dead5", effect_type = "OR",
                        estimate = exp(cf[[term]]), ci_low = exp(ci[term, 1]), ci_high = exp(ci[term, 2]),
                        p_value = sm$coefficients[term, "Pr(>|z|)"], n_unweighted = n_fit, n_events = n_event)
}
check("effect_table built from the real model has 3 rows", nrow(et) == 3)
check("effect_table passes validation", validate_effect_table(et)$ok)
check("age OR matches exp(coef) to full precision (no retyping)", et$estimate[et$term == "age"] == exp(cf[["age"]]))

# ------------------------------------------------------- 2. markdown -------
cat("2. render_effect_table_md() on the real effect_table\n")
md_path <- file.path(outdir, "table1.md")
lines <- render_effect_table_md(et, title = "Table 1. Odds of 5-year mortality (nafld1)",
                                style = "ama", path = md_path)
check("markdown file was written", file.exists(md_path))
check("returned lines are non-empty", length(lines) > 5)
txt <- paste(lines, collapse = "\n")
check("title made it into the markdown", grepl("Table 1\\. Odds", txt))
check("age term row present", grepl("^\\| age \\|", txt, perl = TRUE) || grepl("\\| age \\|", txt))
age_or_str <- formatC(exp(cf[["age"]]), format = "f", digits = 2)
check("the rendered OR string matches the fitted model's OR (no hand retyping)", grepl(age_or_str, txt, fixed = TRUE))

# generic data.frame path (not effect_table-shaped)
generic_md <- file.path(outdir, "generic.md")
gdf <- data.frame(Variable = c("Age, y", "Male, n (%)"), Value = c("54.3 (12.1)", "8210 (46.8)"))
render_md_table(gdf, title = "Table 2. Baseline characteristics", path = generic_md)
check("generic data.frame markdown file was written", file.exists(generic_md))

# ----------------------------------------------------------- 3. docx -------
cat("3. render_effect_table_docx() on the real effect_table\n")
docx_path <- file.path(outdir, "table1.docx")
out <- render_effect_table_docx(et, path = docx_path, title = "Table 1. Odds of 5-year mortality (nafld1)", style = "ama")
check("docx file was written", file.exists(docx_path))
check("docx file is non-trivial in size (not an empty stub)", file.size(docx_path) > 2000,
      sprintf("size=%d", file.size(docx_path)))
check("render_effect_table_docx() returns the path it wrote", identical(out, docx_path))

generic_docx <- file.path(outdir, "generic.docx")
render_docx_table(gdf, title = "Table 2. Baseline characteristics", path = generic_docx, footnote = "Test footnote.")
check("generic data.frame docx file was written", file.exists(generic_docx))
check("generic docx file is non-trivial in size", file.size(generic_docx) > 2000)

# ------------------------------------------------- 4. formatting helpers ---
cat("4. formatting helper spot checks\n")
check("format_p ama drops the leading zero", format_p(0.032, "ama") == ".03")
check("format_p ama sub-threshold", format_p(0.0002, "ama") == "<.001")
check("format_p lancet keeps the leading zero", format_p(0.032, "lancet") == "0.032")
check("format_p lancet sub-threshold uses 0.0001 cutoff", format_p(0.00005, "lancet") == "<0.0001")
check("format_p generic keeps the leading zero", format_p(0.032, "generic") == "0.03")
check("format_p never returns NA for an in-range value", !is.na(format_p(0.5, "generic")))
check("format_ci falls back to the point estimate when CI is missing", format_ci(1.5, NA, NA) == "1.50")
check("format_ci returns na_string when estimate itself is missing", format_ci(NA_real_) == "--")
# Regression check (Phase 0 integration verification, 2026-08-13): ci_separator()
# used to fall through to " to " for style="generic" (this suite's default),
# contradicting both this file's own header comment ("generic: ... comma-
# separated CI") and docs/render_conventions.md's style table. Only "ama" was
# special-cased; "generic" must be too.
check("ci_separator('generic') is a comma, per this file's own documented default", ci_separator("generic") == ", ")
check("ci_separator('ama') is a comma", ci_separator("ama") == ", ")
check("ci_separator('nejm') is 'to'", ci_separator("nejm") == " to ")
check("ci_separator('lancet') is 'to'", ci_separator("lancet") == " to ")
check("format_ci with the generic style's separator uses a comma, not 'to'",
      format_ci(1.52, 1.21, 1.91, sep = ci_separator("generic")) == "1.52 (1.21, 1.91)")

# Regression (audit:contracts): format_p("nejm") used to fall through to the
# generic branch (WITH a leading zero), contradicting this file's own header,
# docs/render_conventions.md's style table, and p_label("nejm")$leading_zero
# == FALSE all at once.
check("format_p nejm drops the leading zero, same numeric rule as ama", format_p(0.032, "nejm") == ".03")
check("format_p nejm sub-threshold matches ama", format_p(0.0002, "nejm") == "<.001")
check("format_p nejm and ama are numerically identical across a small grid",
      identical(format_p(c(0.0005, 0.004, 0.032, 0.5), "nejm"), format_p(c(0.0005, 0.004, 0.032, 0.5), "ama")))
check("p_label('nejm')$leading_zero is FALSE, consistent with format_p('nejm') now having no leading zero",
      identical(p_label("nejm")$leading_zero, FALSE))

# ----------------------------------------------------------- 5. mutation-coverage gaps ----
cat("5. targeted assertions closing the mutation-coverage gap flagged by audit:code\n")
# audit:code found that swapping ci_low/ci_high, or substituting p_adjusted
# for p_value, in the render layer left every existing test still passing
# (they only grepl() for the point-estimate substring, never assert the
# whole formatted cell). These assert the full cell string so a swapped-
# argument regression cannot pass silently again.
et5 <- add_effect_rows(term = "bmi", analysis_id = "model3", effect_type = "HR", estimate = 1.52,
                       ci_low = 1.21, ci_high = 1.91, p_value = 0.00034, n_unweighted = 1000L, n_events = 120L)
disp5 <- format_effect_table_for_display(et5, style = "ama", digits = 2)
eff_col5 <- grep("^HR", names(disp5), value = TRUE)[1]
check("effect column is the full 'estimate (lower to upper)' string, not just a substring match",
      identical(disp5[[eff_col5]][1], sprintf("%.2f (%s%s%s)", et5$estimate, formatC(et5$ci_low, format = "f", digits = 2),
                                              ci_separator("ama"), formatC(et5$ci_high, format = "f", digits = 2))))
p_col5 <- grep("P", names(disp5), value = TRUE, fixed = TRUE)[1]
check("P-value column cell is format_p(p_value), a swap for p_adjusted would change this exact string",
      identical(disp5[[p_col5]][1], format_p(et5$p_value, style = "ama")))

# ----------------------------------------------------- 6. display names ---
cat("6. reader-facing display-name mapping\n")
et6 <- add_effect_rows(term = "bmi", level = "Q4", analysis_id = "model3", effect_type = "HR",
                       estimate = 1.52, ci_low = 1.21, ci_high = 1.91, p_value = 0.032,
                       p_adjusted = 0.048, p_adj_method = "BH", n_unweighted = 1000L,
                       n_events = 120L, stratum = "Women", notes = "Adjusted model",
                       model_spec_hash = "abcdef")
legacy6 <- format_effect_table_for_display(et6, style = "generic", digits = 2)
legacy6_expected <- c("Term", "Model", "HR (95% CI)", "N", "Events", "P", "BH-adjusted P", "Stratum", "Notes")
check("default call remains byte-identical to the legacy display headers",
      identical(names(legacy6), legacy6_expected))
legacy6_expected_md <- c(
  "| Term | Model | HR (95% CI) | N | Events | P | BH-adjusted P | Stratum | Notes |",
  "| --- | --- | --- | --- | --- | --- | --- | --- | --- |",
  "| bmi: Q4 | model3 | 1.52 (1.21, 1.91) | 1,000 | 120 | 0.03 | 0.05 | Women | Adjusted model |"
)
check("default call produces byte-identical legacy markdown",
      identical(render_md_table(legacy6), legacy6_expected_md))

reader6 <- format_effect_table_for_display(et6, style = "generic", digits = 2, reader_facing = TRUE)
check("suite display map renames reader-facing columns and drops provenance columns",
      identical(names(reader6), c("Variable", "Estimate", "No. of participants", "Events", "P value",
                                  "Adjusted P", "Stratum", "Notes")))
check("module display-name override wins over the suite default",
      identical(names(format_effect_table_for_display(et6, reader_facing = TRUE,
                                                       display_names = c(n_unweighted = "No. of SNPs"))),
                c("Variable", "Estimate", "No. of SNPs", "Events", "P value", "Adjusted P", "Stratum", "Notes")))
raw_schema6 <- EFFECT_TABLE_SCHEMA$column
reader_header6 <- paste(names(reader6), collapse = " | ")
check("reader-facing headers cannot contain raw schema identifiers",
      !grepl(paste0("(^|[^[:alnum:]_])(", paste(raw_schema6, collapse = "|"), ")([^[:alnum:]_]|$)"),
             reader_header6, perl = TRUE))

# ----------------------------------------------------------- summary -------
cat("\n")
if (length(fails)) {
  cat(sprintf("FAILED: %d check(s) failed:\n", length(fails)))
  for (f in fails) cat("  -", f, "\n")
  quit(status = 1)
} else {
  cat(sprintf("All checks passed. Rendered files are in %s\n", outdir))
  quit(status = 0)
}
