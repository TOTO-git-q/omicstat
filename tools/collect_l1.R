# collect_l1.R -- S0 layer L1 of ENGINEERING_PLAN 2.2: export the documentation
# that ships INSIDE the installed (locked or dev-tier) package, never the web
# version. ASCII only on purpose.
#
#   Rscript tools/collect_l1.R <module> <pkg>[,<pkg2>...] <fn>[,<fn2>...]
#   e.g. Rscript tools/collect_l1.R deseq2-wald DESeq2,apeglm DESeq,results,lfcShrink
#
# Writes acceptance/exemplars/<module>/L1/:
#   <pkg>/vignettes/*.{Rmd,R,txt}  vignette sources, purled code and the
#                                  rendered HTML as plain text (printed values
#                                  = PACK section C anchor candidates)
#   <pkg>/Rd/<fn>.txt              tools::Rd2txt of each function's help page
#   <pkg>/NEWS.txt, CITATION.txt   NEWS and the package's own citation(s)
#   <pkg>/formals.tsv              deparsed formals() of each function (the
#                                  "function default" column of PACK D)
#   manifest.tsv                   file, sha256, package, version, bioc, tier
# Functions are looked up in the listed packages in order; an unknown function
# is an error (OS_MISSING_FUNCTION), not a silent skip.
args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 3) stop("usage: Rscript tools/collect_l1.R <module> <pkg,...> <fn,...>", call. = FALSE)
module <- args[1]
pkgs <- strsplit(args[2], ",", fixed = TRUE)[[1]]
fns <- strsplit(args[3], ",", fixed = TRUE)[[1]]
here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])))
root <- dirname(here)
out <- file.path(root, "acceptance", "exemplars", module, "L1")
dir.create(out, recursive = TRUE, showWarnings = FALSE)
tier <- if (nzchar(Sys.getenv("OMICSTAT_CONTAINER"))) "container" else if (nzchar(Sys.getenv("OMICSTAT_R_LIBS"))) "native" else "dev"
bioc <- tryCatch(as.character(BiocManager::version()), error = function(e) NA_character_)

write_lines <- function(x, path) { con <- file(path, open = "wb"); on.exit(close(con)); writeBin(charToRaw(enc2utf8(paste0(paste(x, collapse = "\n"), "\n"))), con) }
html_text <- function(path) {
  h <- paste(readLines(path, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
  h <- gsub("(?s)<script.*?</script>|<style.*?</style>", "", h, perl = TRUE)
  h <- gsub("<(br|/p|/div|/h[1-6]|/li|/tr|/pre)[^>]*>", "\n", h, perl = TRUE)
  h <- gsub("<[^>]+>", "", h, perl = TRUE)
  ents <- c("&lt;" = "<", "&gt;" = ">", "&quot;" = "\"", "&#39;" = "'", "&nbsp;" = " ", "&amp;" = "&")
  for (e in names(ents)) h <- gsub(e, ents[[e]], h, fixed = TRUE)
  h <- gsub("\n[ \t]+\n", "\n\n", h)
  gsub("\n{3,}", "\n\n", h)
}

found <- setNames(rep(NA_character_, length(fns)), fns)
for (p in pkgs) {
  if (!requireNamespace(p, quietly = TRUE)) stop(sprintf("OS_MISSING_PACKAGE: %s is not installed.", p), call. = FALSE)
  pd <- file.path(out, p)
  dir.create(file.path(pd, "vignettes"), recursive = TRUE, showWarnings = FALSE)
  dir.create(file.path(pd, "Rd"), showWarnings = FALSE)
  docdir <- system.file("doc", package = p)
  for (f in list.files(docdir, pattern = "\\.(Rmd|Rnw|R|html)$", full.names = TRUE)) {
    if (basename(f) == "index.html") next
    if (grepl("\\.html$", f)) write_lines(html_text(f), file.path(pd, "vignettes", sub("\\.html$", ".rendered.txt", basename(f))))
    else file.copy(f, file.path(pd, "vignettes", basename(f)), overwrite = TRUE)
  }
  news <- system.file("NEWS", package = p)
  if (!nzchar(news)) news <- system.file("NEWS.md", package = p)
  if (nzchar(news)) file.copy(news, file.path(pd, "NEWS.txt"), overwrite = TRUE)
  cit <- tryCatch(format(utils::citation(p), style = "text"), error = function(e) character(0))
  if (length(cit)) write_lines(cit, file.path(pd, "CITATION.txt"))
  db <- tools::Rd_db(p)
  ns <- asNamespace(p)
  fm_rows <- character(0)
  for (fn in fns[is.na(found)]) {
    if (!exists(fn, envir = ns, inherits = FALSE)) next
    found[fn] <- p
    alias <- vapply(db, function(rd) fn %in% unlist(lapply(rd[vapply(rd, attr, "", "Rd_tag") == "\\alias"], as.character)), logical(1))
    if (any(alias)) {
      tf <- tempfile(fileext = ".txt")
      tools::Rd2txt(db[[which(alias)[1]]], out = tf, options = list(underline_titles = FALSE))
      file.copy(tf, file.path(pd, "Rd", paste0(fn, ".txt")), overwrite = TRUE)
    }
    f <- get(fn, envir = ns)
    fm <- if (is.function(f)) formals(f) else NULL
    if (isS4(f) || is.null(fm) || identical(names(fm), c("object", "..."))) {
      m <- tryCatch(get(paste0(fn, ".default"), envir = ns), error = function(e) NULL)
      if (!is.null(m)) fm <- formals(m)
    }
    for (a in names(fm)) fm_rows <- c(fm_rows, paste(fn, a, gsub("\t", " ", paste(deparse(fm[[a]]), collapse = "")), sep = "\t"))
  }
  if (length(fm_rows)) {
    old <- if (file.exists(file.path(pd, "formals.tsv"))) readLines(file.path(pd, "formals.tsv"))[-1] else character(0)
    write_lines(c("function\targument\tdefault", unique(c(old, fm_rows))), file.path(pd, "formals.tsv"))
  }
}
if (anyNA(found)) stop(sprintf("OS_MISSING_FUNCTION: not found in %s: %s", paste(pkgs, collapse = ", "), paste(names(found)[is.na(found)], collapse = ", ")), call. = FALSE)
files <- setdiff(list.files(out, recursive = TRUE), "manifest.tsv")
man <- data.frame(file = files,
                  sha256 = vapply(file.path(out, files), function(f) digest::digest(file = f, algo = "sha256"), ""),
                  package = sub("/.*$", "", files), stringsAsFactors = FALSE)
man$version <- vapply(man$package, function(p) as.character(utils::packageVersion(p)), "")
man$bioconductor <- bioc
man$tier <- tier
utils::write.table(man, file.path(out, "manifest.tsv"), sep = "\t", quote = FALSE, row.names = FALSE)
cat(sprintf("L1 for %s: %d files from %s (tier %s, Bioconductor %s) -> %s\n", module, nrow(man),
            paste(sprintf("%s %s", pkgs, vapply(pkgs, function(p) as.character(utils::packageVersion(p)), "")), collapse = ", "),
            tier, bioc, out))
