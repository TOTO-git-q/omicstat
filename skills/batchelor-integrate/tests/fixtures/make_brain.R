source("skills/scater-qc/tests/fixtures/make_zeisel.R")
make_brain <- function(suite) {
 z<-make_zeisel(suite)
 paths<-file.path(suite,"acceptance/data",c("EH2578_tasic-brain_counts.rds","EH2579_tasic-brain_coldata.rds"))
 hashes<-c("cfb44779bc27f0de3eee8086f510afd2d31a8cf2e354c80c457a10b1c72c156c","3c667abcb2b6af1371e43799d050a705a2a243050e21a743c84941c01791efb6")
 stopifnot(identical(unname(vapply(paths,function(p)digest::digest(file=p,algo="sha256"),"")),hashes))
 t<-SingleCellExperiment::SingleCellExperiment(assays=list(counts=readRDS(paths[1])),colData=S4Vectors::DataFrame(as.data.frame(readRDS(paths[2]))))
 list(z=z,t=t)
}
