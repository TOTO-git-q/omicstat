a <- commandArgs(FALSE);here <- dirname(normalizePath(sub("^--file=","",a[grepl("^--file=",a)][1])))
source(file.path(here,"../scripts/idmap.R"))
root <- tempfile("idmap-parity-");dir.create(root)
stopifnot(identical(system2("python3",c(shQuote(file.path(here,"../py/tests/make_idmap_parity_fixture.py")),shQuote(root))),0L))
for (p in c("first","drop","expand")) {
  r <- suppressWarnings(os_idmap(c("A","B","missing","A"),"SYMBOL","ENTREZID","Homo sapiens","test_human",p,registry=file.path(root,"registry.json")))
  py <- jsonlite::fromJSON(file.path(root,paste0(p,".json")))
  stopifnot(isTRUE(all.equal(r$mappings,py$mappings,check.attributes=FALSE)),
            isTRUE(all.equal(r$report,py$report,check.attributes=FALSE)),
            identical(r$qc$triggered,py$qc$triggered),r$qc$loss_fraction==py$qc$loss_fraction)
}
cat("ALL PASSED: R/Python ID mapping outcomes match for all three policies\n")
