# registry_values_check.R -- S3 F4 (limma-camera): every registered argument of
# scripts/calls_registry.json carries its actual value or an explicit binding,
# and that record matches EVERY call site:
#   kind "fixed": `code` is the literal written at the call site and `value`
#                 is that literal (eval(code) == value);
#   kind "flag":  `code` reads the flag named in `flag` (a$<flag> or
#                 a[["<flag>"]]) and `value` is the flag default;
#   kind "input": `code` is the variable bound to the input named in `binding`.
# `function_default` is a separate field (checked by check_default_drift()).
# The literal string "explicit" is never a value. ASCII only.
lc_call_site_args <- function(file) {
  pd <- utils::getParseData(parse(file, keep.source = TRUE), includeText = TRUE)
  sites <- list()
  for (i in which(pd$token == "SYMBOL_FUNCTION_CALL")) {
    expr_id <- pd$parent[i]
    sib <- pd[pd$parent == expr_id, ]
    pkg <- if (any(sib$token %in% c("NS_GET", "NS_GET_INT"))) sib$text[sib$token == "SYMBOL_PACKAGE"][1] else NA_character_
    call_id <- pd$parent[pd$id == expr_id]
    kids <- pd[pd$parent == call_id, ]
    kids <- kids[order(kids$line1, kids$col1), ]
    args <- list()
    for (k in which(kids$token == "SYMBOL_SUB")) {
      j <- k + 1L
      while (j <= nrow(kids) && kids$token[j] == "EQ_SUB") j <- j + 1L
      args[[kids$text[k]]] <- gsub("[[:space:]]+", " ", kids$text[j])
    }
    sites[[length(sites) + 1L]] <- list(fn = paste0(pkg, "::", pd$text[i]), file = basename(file), line = pd$line1[i], args = args)
  }
  sites
}

lc_registry_value_check <- function(scripts, registry) {
  reg <- jsonlite::fromJSON(registry, simplifyVector = FALSE)
  sites <- unlist(lapply(scripts, lc_call_site_args), recursive = FALSE)
  problems <- character(0)
  n_checked <- 0L
  for (cl in reg$calls) {
    hits <- Filter(function(s) identical(s$fn, cl$fn), sites)
    if (!length(hits)) problems <- c(problems, sprintf("%s has no call site", cl$fn))
    for (nm in names(cl$args)) {
      e <- cl$args[[nm]]
      if (identical(e$value, "explicit")) problems <- c(problems, sprintf("%s(%s): value is the placeholder 'explicit'", cl$fn, nm))
      if (!isTRUE(e$kind %in% c("fixed", "flag", "input"))) { problems <- c(problems, sprintf("%s(%s): kind must be fixed/flag/input", cl$fn, nm)); next }
      if (is.null(e$code) || !nzchar(e$code)) { problems <- c(problems, sprintf("%s(%s): no code", cl$fn, nm)); next }
      if (identical(e$kind, "fixed")) {
        want <- if (is.null(e$value)) NULL else unlist(e$value)
        got <- eval(parse(text = e$code), envir = baseenv())
        if (!isTRUE(all.equal(got, want)) && !(is.null(got) && is.null(want)))
          problems <- c(problems, sprintf("%s(%s): fixed code %s does not evaluate to value %s", cl$fn, nm, e$code, deparse(want)))
      } else if (identical(e$kind, "flag")) {
        fl <- sub("^--", "", e$flag %||% "")
        if (!nzchar(fl) || !(identical(e$code, paste0("a$", fl)) || identical(e$code, sprintf('a[["%s"]]', fl))))
          problems <- c(problems, sprintf("%s(%s): flag binding %s does not read --%s", cl$fn, nm, e$code, fl))
        if (is.null(e$value)) problems <- c(problems, sprintf("%s(%s): flag binding lacks the flag default as value", cl$fn, nm))
        else if (!isTRUE(all.equal(unlist(e$value), unlist(reg$flag_defaults[[paste0("--", fl)]]))))
          problems <- c(problems, sprintf("%s(%s): flag value %s differs from flag_defaults --%s", cl$fn, nm, deparse(unlist(e$value)), fl))
      } else if (is.null(e$binding) || !nzchar(e$binding)) {
        problems <- c(problems, sprintf("%s(%s): input binding is not described", cl$fn, nm))
      }
      for (h in hits) {
        n_checked <- n_checked + 1L
        if (!identical(h$args[[nm]], e$code))
          problems <- c(problems, sprintf("%s:%d %s(%s = %s) differs from registry code %s", h$file, h$line, cl$fn, nm,
                                          h$args[[nm]] %||% "<absent>", e$code))
      }
    }
  }
  list(ok = !length(problems), problems = problems, n_checked = n_checked)
}
