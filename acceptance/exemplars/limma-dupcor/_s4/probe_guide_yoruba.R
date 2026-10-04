# S4 probe: the guide_yoruba.R fixture against the printed sec 18.1.9 values.
`%||%` <- function(a, b) if (is.null(a)) b else a
suite <- normalizePath(".")
source("skills/limma-dupcor/tests/fixtures/guide_yoruba.R")
g <- yoruba_guide_lines(suite, "limma-dupcor")
pr <- yoruba_guide_printed(g)
print(pr$consensus); print(pr$dt); cat("printed rows", nrow(pr$tt), "\n")
inp <- yoruba_guide_inputs(suite, g)
for (ad in c(FALSE, TRUE)) {
  t0 <- Sys.time(); r <- yoruba_guide_fit(inp, adaptive.span = ad)
  cat("adaptive.span", ad, "time", format(Sys.time() - t0), "span", format(r$v$span %||% NA), "cor", r$cor1, r$cor2, "\n")
  print(r$dt)
  print(yoruba_compare_printed_tt(r$tt, pr$tt))
  cat("dt identical:", identical(unclass(r$dt)[, ], pr$dt[, ]), all(unclass(r$dt) == pr$dt), "\n")
  if (!ad) { bad <- which(abs(r$tt$B - pr$tt$B) > 0.0005); print(cbind(r$tt[bad, c("Symbol","B")], printed = pr$tt$B[bad])) }
}
