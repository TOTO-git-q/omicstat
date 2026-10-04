# Build gate: native offline H5AD round trip must work as uid 65534.
stopifnot(Sys.info()[['user']] != 'root')
py <- '/opt/omicstat/basilisk/1.24.0/zellkonverter/1.22.0/zellkonverterAnnDataEnv-0.12.3/bin/python'
packages <- system2(py,c('-m','pip','list','--format=freeze'),stdout=TRUE)
stopifnot(identical(sort(packages),sort(readLines('/opt/omicstat/env/basilisk_pkg_lock.txt'))))
cat('PASS: inherited basilisk Python package versions unchanged\n')
m <- matrix(c(1L, 0L, 3L, 4L), 2, dimnames=list(c('GENE1','GENE2'),c('cell1','cell2')))
x <- SingleCellExperiment::SingleCellExperiment(assays=list(counts=m))
x$cluster <- c('a','b')
f <- tempfile(fileext='.h5ad')
zellkonverter::writeH5AD(x, f, X_name='counts')
y <- zellkonverter::readH5AD(f, reader='python')
stopifnot(identical(dim(x),dim(y)), identical(dimnames(x),dimnames(y)),
          isTRUE(all.equal(unname(m),unname(as.matrix(SummarizedExperiment::assay(y,'counts'))))),
          identical(as.character(x$cluster),as.character(y$cluster)))
cat('PASS: non-root native H5AD write/read, axes, values and metadata\n')
