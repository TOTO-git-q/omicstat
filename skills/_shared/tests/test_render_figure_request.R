# test_render_figure_request.R -- tests for render_figure_request.R (the R
# render step of the Python lane, ENGINEERING_PLAN 10.5) and for the byte
# parity of the Python shared layer (skills/_shared/py/ospy) with args.R,
# feature_table.R, module_kit.R and handoff.R.
# ASCII only. Run with: Rscript test_render_figure_request.R (any working directory).
# Needs the figure layer (ggplot2 ...) and a python3 on PATH (standard library
# only) to write the Python-side fixture; without python3 the test SKIPs.

here <- tryCatch({
  a <- commandArgs(trailingOnly = FALSE)
  f <- sub("^--file=", "", a[grep("^--file=", a)])
  if (length(f)) dirname(normalizePath(f)) else getwd()
}, error = function(e) getwd())
S <- normalizePath(file.path(here, "..", "scripts"))
PY <- normalizePath(file.path(here, "..", "py"))
for (f in c("args.R", "engine_run.R", "module_kit.R", "feature_table.R", "handoff.R", "fig_all.R",
            "render_figure_request.R")) source(file.path(S, f))

failures <- character(0)
check <- function(cond, msg) {
  if (isTRUE(cond)) cat(sprintf("PASS: %s\n", msg))
  else { cat(sprintf("FAIL: %s\n", msg)); failures <<- c(failures, msg) }
}
err_code <- function(expr) tryCatch({ force(expr); "" }, error = function(e) sub(":.*$", "", conditionMessage(e)))
sha <- function(p) digest::digest(file = p, algo = "sha256")
python <- Sys.which(c("python3", "python"))
python <- python[nzchar(python)][1]
if (is.na(python)) {
  cat("SKIP: no python3 on PATH (needed to write the Python-lane fixture)\n")
  quit(status = 0)
}
tmp <- file.path(tempdir(), "omicstat_render_request_test"); unlink(tmp, recursive = TRUE); dir.create(tmp)
fx <- function(dir) {
  out <- system2(python, c(shQuote(file.path(PY, "tests", "make_render_fixture.py")), shQuote(dir)), stdout = TRUE, stderr = TRUE)
  st <- attr(out, "status") %||% 0L
  if (st != 0) stop(paste(c("fixture writer failed:", out), collapse = "\n"))
  dir
}
root <- fx(file.path(tmp, "a"))
run <- file.path(root, "run"); par <- file.path(root, "parity")

# ------------------------------------------------------------ cross-lane parity
R_SPEC <- os_arg_spec(
  usage = "python run_parity.py --outdir <dir> [options]",
  description = "Cross-lane help parity fixture.",
  flags = list(
    os_flag("outdir", "path", required = TRUE, help = "output directory"),
    os_flag("seed", "int", default = 20260925L, help = "random seed"),
    os_flag("resolution", "num", default = 0.5, range = c(0.01, 10), help = "Leiden resolution"),
    os_flag("min-genes", "int", default = 200L, range = c(0, 100000), help = "minimum genes per cell"),
    os_flag("tiny", "num", default = 1e-08, help = "a small number"),
    os_flag("flavor", "enum", default = "seurat_v3", values = c("seurat", "seurat_v3", "cell_ranger"), help = "HVG flavour"),
    os_flag("layer", "string", help = "counts layer"),
    os_flag("from-run", "path", must_exist = TRUE, help = "upstream run directory"),
    os_flag("input", "path", must_exist = TRUE, help = "input h5ad"),
    os_flag("strict", "bool", help = "bare switch: exit non-zero on a blocker")),
  exclusive = list(c("input", "from-run")))
py_help <- readLines(file.path(par, "help_py.txt"), warn = FALSE)
check(identical(py_help, os_help(R_SPEC)), "PARITY --help: ospy.args.os_help == args.R os_help, line for line")
check(nrow(os_help_parse(py_help)) == length(R_SPEC$flags), "PARITY os_help_parse reads every Python help line")

vals <- jsonlite::fromJSON(file.path(par, "ft_values.json"), simplifyVector = TRUE)
ft_r <- as_feature_table(vals)
write_feature_table(ft_r, file.path(par, "ft_r.csv"))
check(identical(sha(file.path(par, "ft_r.csv")), sha(file.path(par, "ft_py.csv"))),
      "PARITY feature table: Python and R write identical bytes for identical numbers")
qv <- jsonlite::fromJSON(file.path(par, "qc_values.json"), simplifyVector = FALSE)
qc_r <- os_qc_finalize(lapply(qv, function(r) os_qc_rule(r$id, r$check, r$triggered, r$severity, r$message,
                                                           r$action %||% "", r$evidence %||% "")), "draft/x.md")
os_write_qc_results(qc_r, file.path(par, "qcr"))
check(identical(sha(file.path(par, "qcr", "qc", "qc_results.csv")), sha(file.path(par, "qc_py.csv"))),
      "PARITY qc/qc_results.csv: identical bytes")

h <- read_handoff(run, expect = list(adata = "AnnData", feature_table = "feature_table"))
check(identical(h$ecosystem, "scverse") && identical(h$upstream_runs, "py-run-1") && h$objects$adata$type == "AnnData",
      "PARITY handoff: R reads a Python-written scverse/AnnData handoff (neutral back-end view)")
check(identical(err_code(read_handoff(run, front_end_ecosystem = "seurat")), "OS_ECOSYSTEM_MIXED"),
      "PARITY handoff: a Seurat front end refuses the scverse chain")

# ------------------------------------------------------------ render
rec <- os_render_figure_request(run)
figs <- vapply(rec$figures, `[[`, "", "id")
check(identical(figs, c("volcano", "umap_clusters", "umap_cd3e", "marker_heatmap")), "all four requested figures rendered")
for (id in figs) {
  stem <- file.path(run, "figures", id)
  check(file.exists(paste0(stem, ".pdf")) && file.exists(paste0(stem, ".png")) && file.exists(paste0(stem, ".figure_spec.json")),
        sprintf("%s: pdf + png + figure_spec.json through os_finalize_figure", id))
}
spec <- jsonlite::fromJSON(file.path(run, "figures", "umap_clusters.figure_spec.json"))
check(identical(spec$figure_type, "embedding") && identical(spec$journal, "nature") && grepl("600 cells", spec$caption),
      "figure_spec of the embedding: type, journal preset, auto caption with n")
check(identical(jsonlite::fromJSON(file.path(run, "figures", "volcano.figure_spec.json"))$figure_type, "volcano"), "volcano spec")
fr <- jsonlite::fromJSON(file.path(run, "provenance", "figure_render.json"), simplifyVector = FALSE)
check(identical(fr$schema, "omicstat.figure-render.v1") && identical(fr$request$path, "figure_data/figure_request.json") &&
        identical(fr$request$sha256, sha(file.path(run, "figure_data", "figure_request.json"))) &&
        identical(fr$figure_style_version, OS_FIG_STYLE_VERSION) && length(fr$figures) == 4,
      "provenance/figure_render.json records the step (request sha256, style version, figures)")
check(all(vapply(fr$figures, function(f) identical(f$spec$sha256, sha(file.path(run, f$spec$path))), logical(1))),
      "figure_render.json: spec sha256 values match the files")
check(file.exists(file.path(run, "qc", "render_warnings.csv")) && !file.exists(file.path(run, "qc", "engine_warnings.csv")),
      "render log is qc/render_warnings.csv (the Python engine log is not overwritten)")
reg <- jsonlite::fromJSON(file.path(run, "objects", "colour_registry.json"), simplifyVector = FALSE)
check(identical(sort(names(reg$families$cluster)), c("B cells", "Monocytes", "T cells")),
      "colour_registry_out: cluster colours written for the chain")
h2 <- read_handoff(run, expect = list(colour_registry = "colour_registry", adata = "AnnData"))
check(identical(h2$objects$colour_registry$sha256, sha(file.path(run, "objects", "colour_registry.json"))) &&
        identical(h2$upstream_runs, "py-run-1") && identical(h2$ecosystem, "scverse"),
      "handoff.json gains the colour registry; chain and ecosystem kept")
py_read <- system2(python, c("-c", shQuote(sprintf(paste0(
  "import sys; sys.path.insert(0, %s); from ospy import handoff as H; ",
  "h = H.read_handoff(%s, expect={'colour_registry': 'colour_registry'}, front_end_ecosystem='scverse'); ",
  "print(sorted(h['objects']))"), deparse(PY), deparse(run)))), stdout = TRUE, stderr = TRUE)
check(identical(py_read, "['adata', 'colour_registry', 'feature_table']"),
      "PARITY handoff: Python reads the handoff after the R step updated it")

# second render of the same request: byte-identical figure data / specs
rec2 <- os_render_figure_request(run)
check(identical(vapply(rec2$figures, function(f) f$spec$sha256, ""), vapply(rec$figures, function(f) f$spec$sha256, "")),
      "re-rendering gives identical figure_spec.json bytes")
png_sha <- function(r) vapply(r$figures, function(f) f$files$png$sha256 %||% "", "")
check(identical(png_sha(rec2), png_sha(rec)), "re-rendering gives identical PNG bytes")

# ------------------------------------------------------------ refusals
bad <- fx(file.path(tmp, "b")); brun <- file.path(bad, "run")
cat("1,2\n", file = file.path(brun, "figure_data", "volcano__ft.csv"), append = TRUE)
check(identical(err_code(os_render_figure_request(brun)), "OS_FIGURE_DATA_MISMATCH"), "a changed data file is OS_FIGURE_DATA_MISMATCH")
edit_req <- function(dir, fn) {
  p <- file.path(dir, "figure_data", "figure_request.json")
  r <- jsonlite::fromJSON(p, simplifyVector = FALSE); r <- fn(r)
  writeLines(jsonlite::toJSON(r, auto_unbox = TRUE, null = "null", pretty = TRUE, digits = NA), p)
}
c1 <- fx(file.path(tmp, "c"))
edit_req(file.path(c1, "run"), function(r) { r$figures[[1]]$builder <- "system"; r })
check(identical(err_code(os_render_figure_request(file.path(c1, "run"))), "OS_FIGURE_REQUEST_INVALID"), "a builder outside the allowlist is refused")
c2 <- fx(file.path(tmp, "d"))
edit_req(file.path(c2, "run"), function(r) { r$figures[[2]]$data$emb$path <- "../../a/run/figure_data/umap_clusters__emb.csv"; r })
check(identical(err_code(os_render_figure_request(file.path(c2, "run"))), "OS_FIGURE_REQUEST_INVALID"), "a data path outside the run is refused")
c3 <- fx(file.path(tmp, "e"))
edit_req(file.path(c3, "run"), function(r) { r$figures[[1]]$out_stem <- "tables/volcano"; r })
check(identical(err_code(os_render_figure_request(file.path(c3, "run"))), "OS_FIGURE_REQUEST_INVALID"), "an out_stem outside figures/ is refused")
c4 <- fx(file.path(tmp, "f"))
edit_req(file.path(c4, "run"), function(r) { r$schema <- "other"; r })
check(identical(err_code(os_render_figure_request(file.path(c4, "run"))), "OS_FIGURE_REQUEST_INVALID"), "an unknown schema tag is refused")

# ------------------------------------------------------------ CLI
rscript <- file.path(R.home("bin"), "Rscript")
c5 <- fx(file.path(tmp, "g"))
out <- system2(rscript, c(shQuote(file.path(S, "render_figure_request.R")), "--run-dir", shQuote(file.path(c5, "run"))),
               stdout = TRUE, stderr = TRUE)
check(is.null(attr(out, "status")) && identical(tail(out, 1),
      "4 figure(s) rendered from figure_data/figure_request.json; read provenance/figure_render.json first"),
      "CLI: exit 0 and the closing line")
fr5 <- jsonlite::fromJSON(file.path(c5, "run", "provenance", "figure_render.json"), simplifyVector = FALSE)
check(identical(fr5$script_sha256, sha(file.path(S, "render_figure_request.R"))), "CLI run records the script sha256")
hl <- system2(rscript, c(shQuote(file.path(S, "render_figure_request.R")), "--help"), stdout = TRUE, stderr = TRUE)
check(any(grepl("^  --run-dir <path> +required", hl)) && any(grepl("^  --request <string> +default: figure_data/figure_request.json", hl)),
      "CLI --help follows the args.R convention")
out <- suppressWarnings(system2(rscript, c(shQuote(file.path(S, "render_figure_request.R")), "--run-dir", shQuote(file.path(tmp, "nope"))),
                                stdout = TRUE, stderr = TRUE))
check(identical(attr(out, "status"), 1L) && any(grepl("OS_INVALID_PARAMETER: --run-dir", out, fixed = TRUE)), "CLI: typed error and exit 1")
check(!file.exists("Rplots.pdf"), "no stray Rplots.pdf")

unlink(tmp, recursive = TRUE)
if (length(failures)) {
  cat(sprintf("\n%d RENDER-REQUEST CHECK(S) FAILED\n", length(failures)))
  quit(status = 1)
}
cat("ALL RENDER-REQUEST CHECKS PASSED\n")
