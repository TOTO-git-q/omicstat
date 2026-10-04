# Extend the shared scanner for the accepted native-argument dispatch forms.
.os_direct_call_sites <- .os_call_sites
.os_call_sites <- function(file) {
  sites <- .os_direct_call_sites(file)
  pd <- utils::getParseData(parse(file, keep.source = TRUE), includeText = TRUE)
  walk <- function(x) {
    if (!is.call(x)) return(invisible(NULL))
    head <- x[[1]]
    if (is.symbol(head) && as.character(head) %in% c("os_bioc_call", "do.call") && length(x) >= 3) {
      target <- x[[2]]
      if (is.call(target) && identical(target[[1]], as.name("::")) && length(target) == 3) {
        args <- if (as.character(head) == "os_bioc_call") names(as.list(x))[-seq_len(min(3, length(x)))] else character(0)
        # A dynamic do.call argument list cannot prove named arguments. Empty
        # registry args are allowed; nonempty ones still fail C1.
        line <- pd$line1[pd$token == "SYMBOL_PACKAGE" & pd$text == as.character(target[[2]])][1]
        sites[[length(sites) + 1]] <<- list(file = basename(file), line = line,
          pkg = as.character(target[[2]]), fn = as.character(target[[3]]), args = args)
      }
    }
    children <- as.list(x)[-1]
    for (i in seq_along(children)) {
      if (identical(children[i], list(quote(expr = )))) next
      if (is.call(children[[i]])) walk(children[[i]])
    }
    invisible(NULL)
  }
  for (expr in parse(file)) walk(expr)
  sites
}
