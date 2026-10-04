# calls_check.R -- lock 3 of ENGINEERING_PLAN (3.3): call registry
# consistency and default-drift checks. ASCII only on purpose.
#
# calls_registry.json (per module, scripts/calls_registry.json):
#   { "module": "deseq2-wald",
#     "package_versions": {"DESeq2": "1.x.y"},
#     "calls": [ {"fn": "DESeq2::DESeq",
#                 "args": {"test": {"value": "Wald", "source": "vignette", "pack": "D-01",
#                                   "function_default": "c(\"Wald\", \"LRT\")"}, ...}} ] }
#
# check_calls(scripts, registry):
#   C1 every call site of a registered function names EVERY registered
#      argument explicitly (the "explicit parameter" rule) -- even when the
#      value equals the function default;
#   C2 any pkg::fn call to a package listed in package_versions that is NOT
#      registered fails (whitelist: allowed_unregistered);
#   C3 every registered function is called at least once (a stale registry
#      entry is an error too).
# Pure accessors that cannot change a result (resultsNames, sizeFactors,
# assay, colData, ...) are listed in the registry's "accessors" array and are
# exempt from C2; they carry no arguments to register.
# check_default_drift(registry): for every arg carrying "function_default",
#   deparse(formals(fn)[[arg]]) in the LOCKED environment must equal it.

`%||%` <- function(a, b) if (is.null(a) || length(a) == 0 || (length(a) == 1 && is.na(a))) b else a

.os_call_sites <- function(file) {
  pd <- utils::getParseData(parse(file, keep.source = TRUE), includeText = TRUE)
  pd <- pd[order(pd$line1, pd$col1), ]
  fn_rows <- which(pd$token == "SYMBOL_FUNCTION_CALL")
  sites <- list()
  for (i in fn_rows) {
    fn <- pd$text[i]
    expr_id <- pd$parent[i]                 # expr wrapping the function name
    ns_pkg <- NA_character_
    sib <- pd[pd$parent == expr_id, ]
    if (any(sib$token %in% c("NS_GET", "NS_GET_INT"))) ns_pkg <- sib$text[sib$token == "SYMBOL_PACKAGE"][1]
    call_id <- pd$parent[pd$id == expr_id]   # the call expression
    args <- pd$text[pd$parent == call_id & pd$token == "SYMBOL_SUB"]
    sites[[length(sites) + 1]] <- list(file = basename(file), line = pd$line1[i], pkg = ns_pkg, fn = fn, args = args)
  }
  sites
}

check_calls <- function(scripts, registry, allowed_unregistered = character(0)) {
  reg <- if (is.character(registry)) jsonlite::fromJSON(registry, simplifyVector = FALSE) else registry
  sites <- unlist(lapply(scripts, .os_call_sites), recursive = FALSE)
  problems <- character(0)
  reg_fns <- vapply(reg$calls, `[[`, "", "fn")
  allowed_unregistered <- c(allowed_unregistered, unlist(reg$accessors %||% list()))
  pkgs <- names(reg$package_versions %||% list())
  for (cl in reg$calls) {
    parts <- strsplit(cl$fn, "::", fixed = TRUE)[[1]]
    pkg <- parts[1]; fn <- parts[2]
    hits <- Filter(function(s) identical(s$fn, fn) && (is.na(s$pkg) || identical(s$pkg, pkg)), sites)
    if (!length(hits)) { problems <- c(problems, sprintf("C3 registered function %s is never called", cl$fn)); next }
    need <- names(cl$args %||% list())
    for (h in hits) {
      miss <- setdiff(need, h$args)
      if (length(miss)) problems <- c(problems, sprintf("C1 %s:%d %s does not name registered argument(s): %s",
                                                        h$file, h$line, cl$fn, paste(miss, collapse = ", ")))
    }
  }
  for (s in sites) {
    if (is.na(s$pkg) || !s$pkg %in% pkgs) next
    full <- paste0(s$pkg, "::", s$fn)
    if (!full %in% c(reg_fns, allowed_unregistered)) problems <- c(problems, sprintf("C2 %s:%d unregistered call %s", s$file, s$line, full))
  }
  list(ok = !length(problems), problems = problems, n_sites = length(sites))
}

check_default_drift <- function(registry) {
  reg <- if (is.character(registry)) jsonlite::fromJSON(registry, simplifyVector = FALSE) else registry
  problems <- character(0)
  for (cl in reg$calls) {
    parts <- strsplit(cl$fn, "::", fixed = TRUE)[[1]]
    if (!requireNamespace(parts[1], quietly = TRUE)) { problems <- c(problems, sprintf("D0 package %s not installed", parts[1])); next }
    f <- tryCatch(getExportedValue(parts[1], parts[2]), error = function(e) NULL)
    if (is.null(f)) { problems <- c(problems, sprintf("D0 %s not found", cl$fn)); next }
    fm <- formals(f)
    # S3 generics (prcomp, results, ...) carry their arguments on the default
    # method: fall back to <fn>.default (or the method named in the registry
    # entry's "method" field) when an argument is not on the generic itself.
    meth <- cl$method %||% paste0(parts[2], ".default")
    fm_def <- tryCatch(formals(get(meth, envir = asNamespace(parts[1]))), error = function(e) NULL)
    for (a in names(cl$args %||% list())) {
      if (!a %in% names(fm) && !is.null(fm_def) && a %in% names(fm_def)) fm <- c(fm, fm_def[a])
      want <- cl$args[[a]]$function_default
      if (is.null(want)) next
      got <- if (a %in% names(fm)) paste(deparse(fm[[a]]), collapse = "") else "<absent>"
      if (!identical(got, want)) problems <- c(problems, sprintf("D1 %s(%s): locked default is %s, PACK D recorded %s", cl$fn, a, got, want))
    }
  }
  list(ok = !length(problems), problems = problems)
}
