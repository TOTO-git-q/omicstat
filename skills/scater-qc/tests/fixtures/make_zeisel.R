# Rebuild the offline ZeiselBrainData() object: split controls from endogenous.
make_zeisel <- function(suite) {
  files <- c("EH2580_zeisel-brain_counts.rds", "EH2581_zeisel-brain_rowdata.rds", "EH2582_zeisel-brain_coldata.rds")
  hashes <- c("4357e6850705c096c8c1276f32b415628dcc16c51ba2c61a36598948ca12a215", "39ab99d7e8d1387103214b0be92a2e4acd83d46715f5b876dbc5d014c678fb12", "652d0476cf3274d8d7804f5096b55580c6b298a2f4fa288f1d8934afad70405f")
  paths <- file.path(suite, "acceptance", "data", files)
  if (!all(file.exists(paths))) return(NULL)
  stopifnot(identical(unname(vapply(paths, function(p) digest::digest(file = p, algo = "sha256"), "")), hashes))
  x <- readRDS(paths[1]); rd <- readRDS(paths[2]); cd <- readRDS(paths[3])
  rd <- S4Vectors::DataFrame(as.data.frame(rd)); cd <- S4Vectors::DataFrame(as.data.frame(cd))
  rd$featureType[rd$featureType == "mito"] <- "endogenous"
  all <- SingleCellExperiment::SingleCellExperiment(assays = list(counts = x), rowData = rd, colData = cd)
  SingleCellExperiment::splitAltExps(all, rd$featureType, ref = "endogenous")
}
