# args.R -- declarative command-line flags for run_*.R entry scripts.
# ASCII only on purpose. See docs/CONVENTIONS.md sec 14.
#
# ONE spec drives parsing, validation and --help, so the help text, the
# defaults and the checks cannot drift apart:
#
#   SPEC <- os_arg_spec(
#     usage = "Rscript run_x_y.R --outdir <dir> [options]",
#     description = "One line on what the module does.",
#     flags = list(
#       os_flag("outdir", "path", required = TRUE, help = "output directory"),
#       os_flag("seed", "int", default = 20260925L, help = "random seed"),
#       os_flag("alpha", "num", default = 0.05, range = c(0, 1), help = "FDR level"),
#       os_flag("journal", "enum", default = "nature", values = c("nature", "cell"), help = "figure preset"),
#       os_flag("strict", "bool", help = "bare switch: fail on a blocker"),
#       os_flag("input", "path", must_exist = TRUE, help = "counts matrix"),
#       os_flag("from-run", "path", must_exist = TRUE, help = "upstream run directory")),
#     exclusive = list(c("input", "from-run")))
#   args <- os_parse_args(SPEC, commandArgs(trailingOnly = TRUE))
#   if (isTRUE(args$help)) { os_print_help(SPEC); quit(status = 0) }
#
# Types: int, num, string, path, enum (needs `values`), bool (a bare switch:
# present = TRUE, absent = FALSE; never takes a value). `range = c(lo, hi)`
# (inclusive) applies to int/num. `requires = "<other flag>"` means the flag
# may only be given together with the other one. `exclusive` lists groups of
# flags of which at most one may be given.
#
# os_parse_args() returns a named list with one element per flag (name
# without the leading "--"; absent optional flags carry their default, which
# may be NULL), plus `help` (TRUE/FALSE). attr(x, "given") names the flags
# given on the command line. Typed errors (docs/CONVENTIONS.md sec 3):
#   OS_UNKNOWN_FLAG            token that is not a declared flag
#   OS_MISSING_PARAMETER       required flag absent; flag without its value;
#                              a flag given without the flag it requires
#   OS_INVALID_PARAMETER       value of the wrong type / not in the enum /
#                              out of range / path not found ("expected ..., got ...")
#   OS_CONFLICTING_PARAMETERS  two flags of an exclusive group; a flag given twice
# --help short-circuits: no other validation runs, so help always works.
#
# --help line convention (machine-read by tools/check_defaults.py and the MCP
# flag whitelist; see CONVENTIONS.md sec 14):
#   "  --<name> <TYPE>  required|default: <value>  <help text>"
# TYPE is int, num, string, path, switch (bool) or the enum values joined by
# "|"; a range is written inside the brackets as "<num in [0, 1]>". Defaults
# print as: integers plainly, numbers with up to 15 significant digits,
# switches as "off", an absent default as "none". Columns are separated by
# two or more spaces, so a default may not contain two consecutive spaces.

`%||%` <- function(a, b) if (is.null(a) || length(a) == 0 || (length(a) == 1 && is.na(a))) b else a

OS_ARG_TYPES <- c("int", "num", "string", "path", "enum", "bool")

os_flag <- function(name, type, required = FALSE, default = NULL, help = "", values = NULL,
                    range = NULL, requires = NULL, must_exist = FALSE) {
  f <- list(name = name, type = type, required = isTRUE(required), default = default, help = help,
            values = values, range = range, requires = requires, must_exist = isTRUE(must_exist))
  class(f) <- "os_flag"
  f
}

.os_spec_error <- function(fmt, ...) stop(sprintf(paste0("OS_INVALID_ARG_SPEC: ", fmt), ...), call. = FALSE)

os_arg_spec <- function(usage, flags, description = NULL, exclusive = list()) {
  for (name in c("study-contract", "study-contract-sha256")) {
    if (!any(vapply(flags, function(f) identical(f$name, name), logical(1))))
      flags <- c(flags, list(os_flag(name, if (name == "study-contract") "path" else "string",
        must_exist = name == "study-contract", help = "shared StudyContract byte binding; see _shared/docs/STUDY_CONTRACT.md")))
  }
  if (!any(vapply(flags, function(f) identical(f$name, "help"), logical(1)))) {
    flags <- c(flags, list(os_flag("help", "bool", help = "show this help and exit")))
  }
  nm <- vapply(flags, `[[`, "", "name")
  if (anyDuplicated(nm)) .os_spec_error("duplicated flag(s) %s", paste(unique(nm[duplicated(nm)]), collapse = ", "))
  bad <- nm[!grepl("^[A-Za-z0-9][A-Za-z0-9-]*$", nm)]
  if (length(bad)) .os_spec_error("flag names must match [A-Za-z0-9][A-Za-z0-9-]* (got %s)", paste(bad, collapse = ", "))
  for (f in flags) {
    if (!f$type %in% OS_ARG_TYPES) .os_spec_error("--%s has type '%s' (allowed: %s)", f$name, f$type, paste(OS_ARG_TYPES, collapse = ", "))
    if (identical(f$type, "enum") && !length(f$values)) .os_spec_error("--%s is an enum without values", f$name)
    if (!is.null(f$range) && (!f$type %in% c("int", "num") || length(f$range) != 2 || f$range[1] > f$range[2]))
      .os_spec_error("--%s: range must be c(lo, hi) on an int/num flag", f$name)
    if (f$required && !is.null(f$default)) .os_spec_error("--%s is required and also has a default", f$name)
    if (identical(f$type, "bool") && (f$required || !is.null(f$default))) .os_spec_error("--%s is a bool switch: no default, never required", f$name)
    if (!is.null(f$requires) && !all(f$requires %in% nm)) .os_spec_error("--%s requires an undeclared flag", f$name)
    if (!is.null(f$default)) {
      # The default must pass the same validation as a command-line value.
      chk <- tryCatch({ .os_coerce(f, .os_fmt_value(f$default), check_exists = FALSE); "" }, error = function(e) conditionMessage(e))
      if (nzchar(chk)) .os_spec_error("default of --%s does not validate (%s)", f$name, chk)
    }
    if (grepl(" {2,}", .os_fmt_value(f$default %||% ""))) .os_spec_error("default of --%s contains two consecutive spaces", f$name)
  }
  for (g in exclusive) if (!all(g %in% nm)) .os_spec_error("exclusive group names an undeclared flag (%s)", paste(g, collapse = ", "))
  spec <- list(usage = usage, description = description, flags = stats::setNames(flags, nm), exclusive = exclusive)
  class(spec) <- "os_arg_spec"
  spec
}

.os_fmt_value <- function(x) {
  if (is.null(x)) return("none")
  if (is.logical(x)) return(if (isTRUE(x)) "on" else "off")
  if (is.integer(x)) return(as.character(x))
  if (is.numeric(x)) return(format(x, digits = 15, scientific = FALSE, trim = TRUE))
  as.character(x)
}

.os_type_label <- function(f) {
  base <- switch(f$type, bool = "switch", enum = paste(f$values, collapse = "|"), f$type)
  if (!is.null(f$range)) base <- sprintf("%s in [%s, %s]", base, .os_fmt_value(f$range[1]), .os_fmt_value(f$range[2]))
  base
}

.os_invalid <- function(f, expected, got, note = "") {
  stop(sprintf("OS_INVALID_PARAMETER: --%s: expected %s, got '%s'%s", f$name, expected, got, note), call. = FALSE)
}

.os_coerce <- function(f, raw, check_exists = TRUE) {
  v <- switch(f$type,
    int = {
      ok <- grepl("^[+-]?[0-9]+$", raw) && abs(as.numeric(raw)) <= .Machine$integer.max
      if (!ok) .os_invalid(f, "an integer", raw)
      as.integer(raw)
    },
    num = {
      x <- if (grepl("^[+-]?([0-9]+\\.?[0-9]*|\\.[0-9]+)([eE][+-]?[0-9]+)?$", raw)) as.numeric(raw) else NA_real_
      if (!is.finite(x)) .os_invalid(f, "a finite number", raw)
      x
    },
    enum = {
      if (!raw %in% f$values) .os_invalid(f, paste("one of", paste(f$values, collapse = "|")), raw)
      raw
    },
    string = {
      if (!nzchar(raw)) .os_invalid(f, "a non-empty string", raw)
      raw
    },
    path = {
      if (!nzchar(raw)) .os_invalid(f, "a non-empty path", raw)
      if (check_exists && f$must_exist && !file.exists(raw)) .os_invalid(f, "an existing file or directory", raw, " (not found)")
      raw
    },
    .os_invalid(f, "a declared type", f$type))
  if (!is.null(f$range) && (v < f$range[1] || v > f$range[2])) {
    .os_invalid(f, sprintf("a value in [%s, %s]", .os_fmt_value(f$range[1]), .os_fmt_value(f$range[2])), raw)
  }
  v
}

os_parse_args <- function(spec, argv = commandArgs(trailingOnly = TRUE)) {
  stopifnot(inherits(spec, "os_arg_spec"))
  known <- paste0("--", names(spec$flags))
  raw <- list(); given <- character(0); i <- 1L
  while (i <= length(argv)) {
    tok <- argv[i]
    key <- sub("=.*$", "", tok)
    inline <- if (grepl("=", tok, fixed = TRUE) && startsWith(tok, "--")) sub("^[^=]*=", "", tok) else NULL
    if (!key %in% known) {
      what <- if (startsWith(tok, "--")) tok else sprintf("%s (a value without a flag)", tok)
      stop(sprintf("OS_UNKNOWN_FLAG: %s (known: %s)", what, paste(known, collapse = " ")), call. = FALSE)
    }
    name <- sub("^--", "", key)
    f <- spec$flags[[name]]
    if (name %in% given) stop(sprintf("OS_CONFLICTING_PARAMETERS: --%s given twice", name), call. = FALSE)
    given <- c(given, name)
    if (identical(f$type, "bool")) {
      if (!is.null(inline)) .os_invalid(f, "a bare switch without a value", inline)
      raw[[name]] <- TRUE; i <- i + 1L; next
    }
    if (!is.null(inline)) { raw[[name]] <- inline; i <- i + 1L; next }
    if (i == length(argv) || startsWith(argv[i + 1L], "--")) {
      stop(sprintf("OS_MISSING_PARAMETER: --%s needs a value (<%s>)", name, .os_type_label(f)), call. = FALSE)
    }
    raw[[name]] <- argv[i + 1L]; i <- i + 2L
  }
  out <- list()
  if ("help" %in% given) {
    out$help <- TRUE
    attr(out, "given") <- given
    return(out)
  }
  for (f in spec$flags) {
    if (identical(f$type, "bool")) { out[[f$name]] <- isTRUE(raw[[f$name]]); next }
    if (f$name %in% given) out[[f$name]] <- .os_coerce(f, raw[[f$name]])
    else if (f$required) stop(sprintf("OS_MISSING_PARAMETER: --%s is required (<%s>)", f$name, .os_type_label(f)), call. = FALSE)
    else out[f$name] <- list(f$default)
  }
  for (f in spec$flags) {
    if (f$name %in% given && length(f$requires)) {
      miss <- setdiff(f$requires, given)
      if (length(miss)) stop(sprintf("OS_MISSING_PARAMETER: --%s requires %s", f$name, paste0("--", miss, collapse = " and ")), call. = FALSE)
    }
  }
  for (g in spec$exclusive) {
    hit <- intersect(g, given)
    if (length(hit) > 1) stop(sprintf("OS_CONFLICTING_PARAMETERS: %s are mutually exclusive (give at most one)", paste0("--", hit, collapse = ", ")), call. = FALSE)
  }
  attr(out, "given") <- given
  os_study_contract_bind(out)
  out
}

# --help text as a character vector (one element per line).
os_help <- function(spec) {
  stopifnot(inherits(spec, "os_arg_spec"))
  left <- vapply(spec$flags, function(f) sprintf("--%s <%s>", f$name, .os_type_label(f)), "")
  mid <- vapply(spec$flags, function(f) {
    if (f$required) "required" else paste("default:", if (identical(f$type, "bool")) "off" else .os_fmt_value(f$default))
  }, "")
  body <- sprintf("  %s  %s  %s", formatC(left, width = -max(nchar(left))), formatC(mid, width = -max(nchar(mid))),
                  vapply(spec$flags, `[[`, "", "help"))
  body <- sub(" +$", "", body)
  notes <- character(0)
  for (g in spec$exclusive) notes <- c(notes, sprintf("Mutually exclusive: %s", paste0("--", g, collapse = ", ")))
  for (f in spec$flags) if (length(f$requires)) notes <- c(notes, sprintf("--%s requires %s", f$name, paste0("--", f$requires, collapse = " and ")))
  c(paste("Usage:", spec$usage), spec$description, "Options:", body, notes)
}

os_print_help <- function(spec) cat(os_help(spec), sep = "\n")

# Parse --help lines back into a data frame (name, type_label, required,
# default); the inverse of os_help() used by tests. tools/check_defaults.py
# implements the same regex in Python.
OS_HELP_LINE_RE <- "^ +--([A-Za-z0-9][A-Za-z0-9-]*) <([^>]*)> {2,}(required|default: (.*?))( {2,}(.*))?$"
os_help_parse <- function(lines) {
  lines <- lines[grepl(OS_HELP_LINE_RE, lines, perl = TRUE)]
  m <- regmatches(lines, regexec(OS_HELP_LINE_RE, lines, perl = TRUE))
  data.frame(name = vapply(m, `[`, "", 2), type_label = vapply(m, `[`, "", 3),
             required = vapply(m, `[`, "", 4) == "required",
             default = vapply(m, function(x) if (x[4] == "required") NA_character_ else x[5], ""),
             stringsAsFactors = FALSE)
}

# Named colour / label mappings must cover every level. Stops with a
# checklist ("[x]" covered, "[ ]" missing; extra names listed) otherwise.
os_check_named_values <- function(values, required_levels, what = "mapping") {
  levels <- unique(as.character(required_levels[!is.na(required_levels)]))
  nms <- names(values) %||% character(0)
  vals <- as.character(unlist(values, use.names = FALSE))
  covered <- vapply(levels, function(l) {
    j <- which(nms == l)
    length(j) > 0 && !is.na(vals[j[1]]) && nzchar(vals[j[1]])
  }, logical(1))
  if (all(covered)) return(invisible(TRUE))
  extra <- setdiff(nms[nzchar(nms)], levels)
  tab <- sprintf("  [%s] %s", ifelse(covered, "x", " "), levels)
  msg <- c(sprintf("OS_INVALID_PARAMETER: %s must name every level; %d of %d level(s) missing:", what, sum(!covered), length(levels)),
           tab, if (length(extra)) sprintf("  (names matching no level: %s)", paste(extra, collapse = ", ")))
  stop(paste(msg, collapse = "\n"), call. = FALSE)
}

# Resolve the companion relative to this source, independent of current directory.
local({
  files <- vapply(sys.frames(), function(f) if (is.null(f$ofile)) "" else f$ofile, "")
  here <- dirname(normalizePath(tail(files[nzchar(files)], 1), mustWork = TRUE))
  if (!exists("os_study_contract_read", mode = "function")) source(file.path(here, "study_contract.R"), local = .GlobalEnv)
})
