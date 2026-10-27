args <- commandArgs(FALSE); here <- dirname(normalizePath(sub("^--file=", "", args[grepl("^--file=",args)][1])))
source(file.path(here,"../scripts/fig_all.R"))
source(file.path(here,"fixtures/fig_fixtures_standardization.R"))
out <- Sys.getenv("OMICSTAT_FIGURE_TEST_OUT", file.path(tempdir(),"standardization-figures"))
dir.create(out,recursive=TRUE,showWarnings=FALSE)
sha <- function(p) digest::digest(file=p,algo="sha256")
for (j in c("nature","cell")) {
  for (nm in names(fx_standardization_builders(j))) {
    f <- fx_standardization_builders(j)[[nm]]; p <- f()
    lint <- os_fig_lint(p,j)
    stopifnot(!any(lint$severity %in% c("blocker","warning")))
    r <- lapply(c("a","b"),function(k) os_save_figure(f(),file.path(out,j,k,nm),formats=c("png","pdf"),root=file.path(out,j,k),journal=j))
    stopifnot(identical(sha(r[[1]]$files$png),sha(r[[2]]$files$png)),
              identical(os_pdf_content_sha256(r[[1]]$files$pdf),os_pdf_content_sha256(r[[2]]$files$pdf)),
              identical(sha(r[[1]]$spec),sha(r[[2]]$spec)),
              identical(r[[1]]$spec_obj$evidence_refs[[1]]$status,"pending"))
    cat("PASS",j,nm,"byte replay, lint and evidence metadata\n")
  }
}
bad <- data.frame(group=c("A","A"),value=1:2,unit=c("same","same"))
stopifnot(grepl("OS_INVALID_INPUT",tryCatch(os_group_points(bad,"unit","Value"),error=conditionMessage)))
stopifnot(grepl("OS_INVALID_INPUT",tryCatch(os_lasso_path(data.frame(lambda=0,coefficient=1,feature="A")),error=conditionMessage)))
cat("ALL PASSED: standardization figures and refusals\n")
