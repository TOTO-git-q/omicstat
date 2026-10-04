# test_engine_contract.R -- tests for args.R, engine_run.R, design_check.R.
# ASCII only. Run with: Rscript test_engine_contract.R (any working directory).
# Same PASS/FAIL protocol as the other _shared tests. Base R only.

here <- tryCatch({
  a <- commandArgs(trailingOnly = FALSE)
  f <- sub("^--file=", "", a[grep("^--file=", a)])
  if (length(f)) dirname(normalizePath(f)) else getwd()
}, error = function(e) getwd())
S <- file.path(here, "..", "scripts")
source(file.path(S, "args.R")); source(file.path(S, "engine_run.R")); source(file.path(S, "design_check.R"))

failures <- character(0)
check <- function(cond, msg) {
  if (isTRUE(cond)) cat(sprintf("PASS: %s\n", msg))
  else { cat(sprintf("FAIL: %s\n", msg)); failures <<- c(failures, msg) }
}
err_msg <- function(expr) tryCatch({ force(expr); "" }, error = function(e) conditionMessage(e))
err_code <- function(expr) sub(":.*$", "", err_msg(expr))
tmp <- file.path(tempdir(), "omicstat_engine_contract_test"); unlink(tmp, recursive = TRUE); dir.create(tmp)
existing <- file.path(tmp, "in.txt"); writeLines("x", existing)

# ------------------------------------------------------------------ args.R
SPEC <- os_arg_spec(
  usage = "Rscript run_x_y.R --outdir <dir> [options]",
  description = "test module",
  flags = list(
    os_flag("outdir", "path", required = TRUE, help = "output directory"),
    os_flag("input", "path", must_exist = TRUE, help = "input file"),
    os_flag("from-run", "path", help = "upstream run"),
    os_flag("seed", "int", default = 20260925L, help = "random seed"),
    os_flag("alpha", "num", default = 0.05, range = c(0, 1), help = "FDR level"),
    os_flag("lfc", "num", default = 0, help = "log2 fold-change threshold"),
    os_flag("label", "string", default = "treated vs control", help = "contrast label"),
    os_flag("journal", "enum", default = "nature", values = c("nature", "cell", "science", "generic"), help = "figure preset"),
    os_flag("strict", "bool", help = "fail on blockers"),
    os_flag("paired-by", "string", requires = "input", help = "pairing column")),
  exclusive = list(c("input", "from-run")))

a <- os_parse_args(SPEC, c("--outdir", tmp, "--seed", "7", "--alpha=0.1", "--lfc", "-1.5", "--journal", "cell",
                           "--strict", "--input", existing, "--paired-by", "subject"))
check(identical(a$seed, 7L) && identical(a$alpha, 0.1) && identical(a$lfc, -1.5) && identical(a$journal, "cell"),
      "AR typed values: int, num (--flag=value), negative num, enum")
check(isTRUE(a$strict) && identical(a$input, existing) && identical(a$outdir, tmp) && identical(a[["paired-by"]], "subject"),
      "AR switch, path and string values")
check(setequal(attr(a, "given"), c("outdir", "seed", "alpha", "lfc", "journal", "strict", "input", "paired-by")), "AR given attribute")
d <- os_parse_args(SPEC, c("--outdir", tmp))
check(identical(d$seed, 20260925L) && identical(d$alpha, 0.05) && identical(d$journal, "nature") && identical(d$strict, FALSE) &&
        identical(d$label, "treated vs control") && "from-run" %in% names(d) && is.null(d[["from-run"]]),
      "AR defaults filled with their declared types (absent optional -> NULL element)")
check(isTRUE(os_parse_args(SPEC, c("--help"))$help), "AR --help short-circuits required-flag validation")
check(isTRUE(os_parse_args(SPEC, c("--seed", "abc", "--help"))$help), "AR --help wins over an invalid value")

check(err_code(os_parse_args(SPEC, c("--outdir", tmp, "--bogus", "1"))) == "OS_UNKNOWN_FLAG", "AR unknown flag -> OS_UNKNOWN_FLAG")
check(err_code(os_parse_args(SPEC, c("--outdir", tmp, "stray"))) == "OS_UNKNOWN_FLAG", "AR stray value -> OS_UNKNOWN_FLAG")
check(err_code(os_parse_args(SPEC, c("--seed", "1"))) == "OS_MISSING_PARAMETER", "AR required flag absent -> OS_MISSING_PARAMETER")
check(err_code(os_parse_args(SPEC, c("--outdir"))) == "OS_MISSING_PARAMETER", "AR flag without value (end) -> OS_MISSING_PARAMETER")
check(err_code(os_parse_args(SPEC, c("--outdir", tmp, "--seed", "--strict"))) == "OS_MISSING_PARAMETER", "AR flag without value (next flag) -> OS_MISSING_PARAMETER")
check(err_code(os_parse_args(SPEC, c("--outdir", tmp, "--paired-by", "subject"))) == "OS_MISSING_PARAMETER", "AR requires unmet -> OS_MISSING_PARAMETER")
m <- err_msg(os_parse_args(SPEC, c("--outdir", tmp, "--seed", "1.5")))
check(startsWith(m, "OS_INVALID_PARAMETER") && grepl("expected an integer, got '1.5'", m, fixed = TRUE), "AR non-integer -> OS_INVALID_PARAMETER expected-vs-got")
check(err_code(os_parse_args(SPEC, c("--outdir", tmp, "--seed", "99999999999"))) == "OS_INVALID_PARAMETER", "AR integer overflow -> OS_INVALID_PARAMETER")
check(err_code(os_parse_args(SPEC, c("--outdir", tmp, "--alpha", "abc"))) == "OS_INVALID_PARAMETER", "AR non-number -> OS_INVALID_PARAMETER")
m <- err_msg(os_parse_args(SPEC, c("--outdir", tmp, "--alpha", "1.5")))
check(startsWith(m, "OS_INVALID_PARAMETER") && grepl("[0, 1]", m, fixed = TRUE), "AR out of range -> OS_INVALID_PARAMETER naming the range")
m <- err_msg(os_parse_args(SPEC, c("--outdir", tmp, "--journal", "lancet")))
check(startsWith(m, "OS_INVALID_PARAMETER") && grepl("one of nature|cell|science|generic, got 'lancet'", m, fixed = TRUE), "AR enum -> OS_INVALID_PARAMETER listing values")
check(err_code(os_parse_args(SPEC, c("--outdir", tmp, "--input", file.path(tmp, "nope.txt")))) == "OS_INVALID_PARAMETER", "AR missing path -> OS_INVALID_PARAMETER")
check(err_code(os_parse_args(SPEC, c("--outdir", ""))) == "OS_INVALID_PARAMETER", "AR empty path -> OS_INVALID_PARAMETER")
check(err_code(os_parse_args(SPEC, c("--outdir", tmp, "--strict=yes"))) == "OS_INVALID_PARAMETER", "AR switch with a value -> OS_INVALID_PARAMETER")
check(err_code(os_parse_args(SPEC, c("--outdir", tmp, "--input", existing, "--from-run", tmp))) == "OS_CONFLICTING_PARAMETERS", "AR exclusive group -> OS_CONFLICTING_PARAMETERS")
check(err_code(os_parse_args(SPEC, c("--outdir", tmp, "--seed", "1", "--seed", "2"))) == "OS_CONFLICTING_PARAMETERS", "AR flag given twice -> OS_CONFLICTING_PARAMETERS")
check(err_code(os_arg_spec("u", list(os_flag("seed", "int", default = "x")))) == "OS_INVALID_ARG_SPEC", "AR spec: invalid default rejected")
check(err_code(os_arg_spec("u", list(os_flag("a", "num", default = 5, range = c(0, 1))))) == "OS_INVALID_ARG_SPEC", "AR spec: default outside range rejected")
check(err_code(os_arg_spec("u", list(os_flag("a", "path", required = TRUE, default = "x")))) == "OS_INVALID_ARG_SPEC", "AR spec: required + default rejected")
check(err_code(os_arg_spec("u", list(os_flag("a", "enum")))) == "OS_INVALID_ARG_SPEC", "AR spec: enum without values rejected")
check(err_code(os_arg_spec("u", list(os_flag("a", "int"), os_flag("a", "num")))) == "OS_INVALID_ARG_SPEC", "AR spec: duplicated flag rejected")

# help <-> spec round trip
h <- os_help(SPEC)
hp <- os_help_parse(h)
check(identical(hp$name, names(SPEC$flags)), "AR help lists every flag in spec order (incl. implicit --help)")
mcp_flags <- sort(unique(sub("^--", "", unlist(regmatches(h, gregexpr("--[A-Za-z0-9][A-Za-z0-9-]*", h))))))
check(identical(mcp_flags, sort(names(SPEC$flags))), "AR MCP flag regex on --help yields exactly the spec flags")
check(identical(hp$required, unname(vapply(SPEC$flags, `[[`, logical(1), "required"))), "AR help round trip: required")
want_def <- vapply(SPEC$flags, function(f) if (f$required) NA_character_ else if (f$type == "bool") "off" else .os_fmt_value(f$default), "")
check(identical(hp$default, unname(want_def)), "AR help round trip: defaults")
check(identical(hp$type_label[hp$name == "journal"], "nature|cell|science|generic") &&
        identical(hp$type_label[hp$name == "alpha"], "num in [0, 1]") && identical(hp$type_label[hp$name == "strict"], "switch"),
      "AR help round trip: type labels (enum, range, switch)")
# Feeding every printed default back as an explicit value parses to the same object.
explicit <- unlist(lapply(seq_len(nrow(hp)), function(i) {
  f <- SPEC$flags[[hp$name[i]]]
  if (f$type == "bool" || f$required || hp$default[i] == "none") NULL else c(paste0("--", hp$name[i]), hp$default[i])
}))
e <- os_parse_args(SPEC, c("--outdir", tmp, explicit))
check(identical(unclass(e)[names(d)], unclass(d)[names(d)]), "AR printed defaults parse back to the declared defaults")
check(any(grepl("^Mutually exclusive: --input, --from-run$", h)) && any(grepl("^--paired-by requires --input$", h)), "AR help lists exclusive groups and requires")

# named-value coverage
check(isTRUE(os_check_named_values(c(control = "#000000", treated = "#FFFFFF"), c("treated", "control"), "--colours")), "AR named values covering every level pass")
m <- err_msg(os_check_named_values(c(control = "#000000", treatd = "#FFFFFF", rescue = NA), c("control", "treated", "rescue"), "--colours"))
check(startsWith(m, "OS_INVALID_PARAMETER: --colours must name every level; 2 of 3") && grepl("[x] control", m, fixed = TRUE) &&
        grepl("[ ] treated", m, fixed = TRUE) && grepl("[ ] rescue", m, fixed = TRUE) && grepl("treatd", m, fixed = TRUE),
      "AR named values: missing levels -> [x]/[ ] table naming the typo")
check(startsWith(err_msg(os_check_named_values(c("#000000", "#FFFFFF"), c("a", "b"))), "OS_INVALID_PARAMETER"), "AR unnamed values rejected")
check(all(utf8ToInt(m) < 128), "AR coverage table is ASCII")

# ------------------------------------------------------------ engine_run.R
out1 <- file.path(tmp, "run1")
log <- os_engine_log_new(out1)
old_warn <- getOption("warn"); old_len <- getOption("warning.length")
echo <- utils::capture.output(type = "message", {
  v <- os_engine_capture({
    warning("first warning")
    message("a note")
    options(warn = -1)        # a stage that tampers with warn must not leak it
    warning("second warning")
    42
  }, "compute", log)
})
check(identical(v, 42), "EC capture returns the stage value")
tab <- os_engine_table(log)
check(identical(tab$stage, rep("compute", 3)) && identical(tab$type, c("warning", "message", "warning")) &&
        identical(tab$message, c("first warning", "a note", "second warning")), "EC warnings and messages recorded with stage, in order")
check(sum(grepl("^OS_ENGINE_WARNING: \\[compute\\] first warning$", echo)) == 1 &&
        sum(grepl("^OS_ENGINE_WARNING: \\[compute\\] second warning$", echo)) == 1, "EC each warning echoed once to stderr with OS_ENGINE_WARNING")
check(any(grepl("a note", echo)) && !any(grepl("OS_ENGINE_WARNING.*a note", echo)), "EC messages still print normally, not as warnings")
check(identical(getOption("warn"), old_warn) && identical(getOption("warning.length"), old_len), "EC options(warn, warning.length) restored after the stage")
csv <- file.path(out1, "qc", "engine_warnings.csv")
w <- utils::read.csv(csv, stringsAsFactors = FALSE)
check(identical(names(w), c("stage", "type", "message")) && nrow(w) == 3, "EC qc/engine_warnings.csv written (stage, type, message)")
invisible(utils::capture.output(type = "message",
  em <- err_msg(os_engine_capture({ warning("before failing"); stop("OS_DEGENERATE: boom") }, "render", log))))
check(identical(em, "OS_DEGENERATE: boom"), "EC errors propagate unchanged (never muffled)")
w <- utils::read.csv(csv, stringsAsFactors = FALSE)
check(identical(tail(w$type, 2), c("warning", "error")) && identical(tail(w$stage, 1), "render") && identical(tail(w$message, 1), "OS_DEGENERATE: boom"),
      "EC error recorded and CSV flushed before propagating")
check(identical(getOption("warn"), old_warn) && identical(getOption("warning.length"), old_len), "EC options restored after an error")
check(identical(unname(os_engine_counts(log)), c(3L, 1L, 1L)), "EC counts by type")
log2 <- os_engine_log_new(NULL)
em <- err_msg(os_engine_capture(os_engine_capture(stop("inner"), "inner", log2), "outer", log2))
check(identical(em, "inner") && identical(os_engine_table(log2)$stage, "inner"), "EC nested captures record an error once, at the innermost stage")
old <- options(warn = 2)
invisible(utils::capture.output(type = "message", em <- err_msg(os_engine_capture(warning("strict mode"), "qc", log2))))
options(old)
check(grepl("strict mode", em) && "warning" %in% os_engine_table(log2)$type, "EC under warn = 2 a warning is recorded and still becomes an error")
clean <- os_engine_log_new(file.path(tmp, "clean"))
os_engine_capture(invisible(1), "compute", clean)
check(identical(readLines(file.path(tmp, "clean", "qc", "engine_warnings.csv")), "\"stage\",\"type\",\"message\""), "EC clean run writes a header-only CSV")

# ------------------------------------------------------------ design_check.R
st <- data.frame(sample = c("s1", "s2", "s3", "s4", "s1"), condition = c("ctl", "ctl", "trt", "trt", "ctl"), stringsAsFactors = FALSE)
mp <- os_check_sample_condition(st, "sample", "condition")
check(identical(mp$sample, c("s1", "s2", "s3", "s4")) && identical(mp$condition, c("ctl", "ctl", "trt", "trt")), "DC sample->condition map (repeated rows of one sample are fine)")
bad <- rbind(st, data.frame(sample = c("s2", "s4"), condition = c("trt", "ctl")))
m <- err_msg(os_check_sample_condition(bad, "sample", "condition"))
check(startsWith(m, "OS_INVALID_DESIGN: 2 sample(s)") && grepl("s2 -> ctl | trt", m, fixed = TRUE) && grepl("s4 -> ctl | trt", m, fixed = TRUE) &&
        !grepl("s1 ->", m, fixed = TRUE), "DC sample in two conditions -> OS_INVALID_DESIGN naming exactly the offending samples")
check(err_code(os_check_sample_condition(transform(st, condition = c(NA, "ctl", "trt", "trt", NA)), "sample", "condition")) == "OS_INVALID_DESIGN", "DC NA condition -> OS_INVALID_DESIGN")
check(err_code(os_check_sample_condition(st, "sample", "group")) == "OS_MISSING_COLUMN", "DC missing column -> OS_MISSING_COLUMN")

pd <- data.frame(subject = c("p1", "p2", "p3", "p4", "p1", "p2", "p3", "p5"),
                 time = c(rep("pre", 4), rep("post", 4)), value = c(1, 2, 3, 4, 11, 12, 13, 15), stringsAsFactors = FALSE)
p0 <- os_align_pairs(pd, "subject", "time", c("pre", "post"))
check(identical(p0$pairs$subject, c("p1", "p2", "p3")) && identical(p0$pairs$value.post - p0$pairs$value.pre, c(10, 10, 10)),
      "DC pairs by id (inner join), columns suffixed by group")
check(identical(p0$unpaired$pre, "p4") && identical(p0$unpaired$post, "p5") && p0$n_pairs == 3, "DC unpaired ids reported per group")
same <- vapply(1:20, function(k) {
  set.seed(k)
  sh <- pd[sample(nrow(pd)), ]
  identical(os_align_pairs(sh, "subject", "time", c("pre", "post"))$pairs, p0$pairs)
}, logical(1))
check(all(same), "DC pairing invariant to row shuffling (20 permutations)")
dup <- rbind(pd, data.frame(subject = "p2", time = "post", value = 99))
m <- err_msg(os_align_pairs(dup, "subject", "time", c("pre", "post")))
check(startsWith(m, "OS_INVALID_DESIGN") && grepl("post", m) && grepl("p2", m), "DC duplicated id within a group -> OS_INVALID_DESIGN")
na <- rbind(pd, data.frame(subject = c(NA, NA), time = c("pre", "post"), value = c(0, 0)))
wmsg <- character(0)
pn <- withCallingHandlers(os_align_pairs(na, "subject", "time", c("pre", "post")),
                          warning = function(w) { wmsg <<- c(wmsg, conditionMessage(w)); invokeRestart("muffleWarning") })
check(pn$n_na_id_dropped == 2 && identical(pn$pairs, p0$pairs) && any(startsWith(wmsg, "OS_DESIGN_NA_ID_DROPPED: 2 row(s)")),
      "DC NA ids dropped with a count and a typed warning")
check(err_code(os_align_pairs(pd, "subject", "time", c("pre", "later"))) == "OS_INVALID_DESIGN", "DC absent group -> OS_INVALID_DESIGN")
check(err_code(os_align_pairs(pd[pd$subject %in% c("p4", "p5"), ], "subject", "time", c("pre", "post"))) == "OS_INVALID_DESIGN", "DC no common id -> OS_INVALID_DESIGN")

rc <- os_replicate_counts(st, "condition", "sample")
check(identical(rc$condition, c("ctl", "trt")) && identical(rc$n_replicates, c(2L, 2L)), "DC replicate counts = distinct samples per condition")
st2 <- data.frame(sample = paste0("s", 1:6), condition = factor(c("a", "b", "b", "c", "c", "c"), levels = c("c", "b", "a", "d")))
rc2 <- os_replicate_counts(st2, "condition")
check(identical(rc2$condition, c("c", "b", "a", "d")) && identical(rc2$n_replicates, c(3L, 2L, 1L, 0L)), "DC replicate counts follow factor levels, empty level = 0")
cl <- os_classify_replicates(rc2, blocker_below = 2, warning_below = 3)
check(identical(cl$status, c("ok", "warning", "blocker", "blocker")), "DC classify with thresholds passed in")
cl4 <- os_classify_replicates(rc2, blocker_below = 1, warning_below = 4)
check(identical(cl4$status, c("warning", "warning", "warning", "blocker")), "DC classify has no hard-coded thresholds")
check(err_code(os_classify_replicates(rc2, blocker_below = 3, warning_below = 2)) == "OS_INVALID_PARAMETER", "DC blocker threshold above warning threshold rejected")

# -------------------------------------------------------------------- ASCII
srcs <- file.path(S, c("args.R", "engine_run.R", "design_check.R"))
check(all(vapply(srcs, function(f) all(utf8ToInt(paste(readLines(f, warn = FALSE), collapse = "\n")) < 128), logical(1))), "new _shared scripts are ASCII only")

unlink(tmp, recursive = TRUE)
if (length(failures)) {
  cat(sprintf("%d check(s) FAILED:\n", length(failures))); for (f in failures) cat("  - ", f, "\n", sep = ""); quit(status = 1)
} else { cat("ALL ENGINE CONTRACT CHECKS PASSED\n"); quit(status = 0) }
