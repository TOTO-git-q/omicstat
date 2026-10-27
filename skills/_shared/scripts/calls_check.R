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
# Two registry entries may share one function when its call sites take
# different argument sets (compareCluster with fun = "enrichGO" or
# "enricher"): an entry with "site_requires": [args] applies only to call
# sites naming all of those arguments, one with "site_excludes": [args] only
# to sites naming none of them. C1 and C3 then hold per entry.
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
    if (length(cl$site_requires)) hits <- Filter(function(s) all(unlist(cl$site_requires) %in% s$args), hits)
    if (length(cl$site_excludes)) hits <- Filter(function(s) !any(unlist(cl$site_excludes) %in% s$args), hits)
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

.os_expanded_method_formals <- function(method) {
  fm <- formals(method)
  if (!"..." %in% names(fm)) return(fm)
  # S4 wraps extra formals in a canonical .local closure. Inspect the AST only;
  # never evaluate a method body or infer defaults from an arbitrary wrapper.
  b <- body(method)
  if (!is.call(b) || !identical(b[[1]], as.name("{")) || length(b) != 3L)
    stop("S4 method has no canonical inspectable .local wrapper")
  assignment <- b[[2]]
  if (!is.call(assignment) || length(assignment) != 3L ||
      !identical(assignment[[1]], as.name("<-")) ||
      !identical(assignment[[2]], as.name(".local")))
    stop("S4 method has no canonical .local assignment")
  local <- assignment[[3]]
  expected_call <- as.call(c(list(as.name(".local")), lapply(names(fm), as.name)))
  if (!identical(b[[3]], expected_call))
    stop("S4 method wrapper does not directly forward its generic arguments")
  # Installed S4 wrappers embed a closure constant; parsed wrappers embed a
  # function expression. Both expose formals without evaluating the body.
  if (is.function(local)) return(formals(local))
  if (!is.call(local) || !identical(local[[1]], as.name("function")) ||
      !is.pairlist(local[[2]])) stop("S4 .local is not an inspectable function")
  local[[2]]
}

.os_s4_method_formals <- function(generic, signature) {
  if (!methods::is(generic, "standardGeneric")) stop("declared S4 signature on non-S4 function")
  signature <- unlist(signature, use.names = TRUE)
  if (!is.character(signature) || !identical(names(signature), generic@signature) ||
      anyNA(signature) || any(!nzchar(signature))) stop("exact named S4 signature required")
  method <- methods::selectMethod(generic, signature, useInherited = FALSE, optional = TRUE)
  if (is.null(method)) stop("declared exact S4 method not installed")
  .os_expanded_method_formals(method)
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
    if (!is.null(cl$s4_signature)) {
      resolved <- tryCatch(.os_s4_method_formals(f, cl$s4_signature), error = identity)
      if (inherits(resolved, "error")) {
        problems <- c(problems, sprintf("D0 %s S4 method: %s", cl$fn, conditionMessage(resolved)))
        next
      }
      fm <- resolved
    }
    # S3 generics (prcomp, results, ...) carry their arguments on the default
    # method: fall back to <fn>.default (or the method named in the registry
    # entry's "method" field) when an argument is not on the generic itself.
    meth <- cl$method %||% paste0(parts[2], ".default")
    fm_def <- if (is.null(cl$s4_signature)) tryCatch(formals(get(meth, envir = asNamespace(parts[1]))), error = function(e) NULL) else NULL
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
