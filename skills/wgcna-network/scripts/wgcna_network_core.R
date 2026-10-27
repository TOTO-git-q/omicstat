# Advanced native values are JSON; {"rds":"path"} supports native matrix/list objects.
wg_option <- function(a,name,default) {
 if(is.null(a[[name]])) return(default)
 value <- jsonlite::fromJSON(a[[name]])
 if(is.list(value) && identical(names(value),"rds")) value <- readRDS(value$rds)
 value
}
wg_native_function <- function(a,name,default) {
 value <- a[[name]] %||% default
 parts <- strsplit(value,"::",fixed=TRUE)[[1]]
 if(length(parts)!=2L) stop("Supply package::function for native correlation")
 getExportedValue(parts[1],parts[2])
}
# Locked WGCNA network computation; all formals explicit.
WG_MODULE_VERSION <- "1.1.0"
suppressPackageStartupMessages(library(WGCNA))
wg_cor <- function(x, y, a = list()) {
  WGCNA::cor(
    x = x,
    y = y,
    use = wg_option(a,"cor-use","p"),
    method = wg_option(a,"cor-method","pearson"),
    weights.x = wg_option(a,"cor-weights-x",NULL),
    weights.y = wg_option(a,"cor-weights-y",NULL),
    quick = wg_option(a,"cor-quick",0),
    cosine = wg_option(a,"cor-cosine",FALSE),
    cosineX = wg_option(a,"cor-cosine-x",wg_option(a,"cor-cosine",FALSE)),
    cosineY = wg_option(a,"cor-cosine-y",wg_option(a,"cor-cosine",FALSE)),
    drop = FALSE,
    nThreads = 1,
    verbose = 0,
    indent = 0)
}
wgcna_network_compute <- function(a, mat, st) {
  datExpr <- as.data.frame(t(mat))
  gsg <- WGCNA::goodSamplesGenes(
    datExpr = datExpr,
    weights = wg_option(a,"gsg-weights",NULL),
    minFraction = wg_option(a,"gsg-min-fraction",1/2),
    minNSamples = wg_option(a,"gsg-min-nsamples",4),
    minNGenes = wg_option(a,"gsg-min-ngenes",4),
    tol = wg_option(a,"gsg-tol",NULL),
    minRelativeWeight = wg_option(a,"gsg-min-relative-weight",0.1),
    verbose = 0,
    indent = 0)
  if (!gsg$allOK) stop("OS_INVALID_INPUT: goodSamplesGenes rejected samples/genes; preprocess explicitly.", call. = FALSE)
  powers <- as.numeric(strsplit(a$powers, ",", fixed = TRUE)[[1]])
  if (any(!is.finite(powers)) || any(powers <= 0) || anyDuplicated(powers) || !a$power %in% powers)
    stop("OS_INVALID_PARAMETER: powers must be unique positive numbers including --power.", call. = FALSE)
  minSize <- a[["min-module-size"]] %||% min(20, ncol(datExpr)/2)
  sft <- WGCNA::pickSoftThreshold(
    data = datExpr,
    dataIsExpr = TRUE,
    weights = wg_option(a,"soft-weights",NULL),
    RsquaredCut = wg_option(a,"soft-rsquared-cut",0.85),
    powerVector = powers,
    removeFirst = wg_option(a,"soft-remove-first",FALSE),
    nBreaks = wg_option(a,"soft-n-breaks",10),
    blockSize = NULL,
    corFnc = wg_native_function(a,"soft-cor-fnc","WGCNA::cor"),
    corOptions = wg_option(a,"soft-cor-options",list(use = "p")),
    networkType = a[["network-type"]],
    moreNetworkConcepts = FALSE,
    gcInterval = NULL,
    verbose = 0,
    indent = 0)
  net <- WGCNA::blockwiseModules(
    datExpr = datExpr,
    weights = NULL,
    checkMissingData = TRUE,
    blocks = NULL,
    maxBlockSize = a[["max-block-size"]],
    blockSizePenaltyPower = 5,
    nPreclusteringCenters = as.integer(min(ncol(datExpr)/20, 100 * ncol(datExpr)/a[["max-block-size"]])),
    randomSeed = a$seed,
    loadTOM = FALSE,
    corType = wg_option(a,"network-cor-type","pearson"),
    maxPOutliers = wg_option(a,"network-max-poutliers",1),
    quickCor = wg_option(a,"network-quick-cor",0),
    pearsonFallback = wg_option(a,"network-pearson-fallback","individual"),
    cosineCorrelation = wg_option(a,"network-cosine-correlation",FALSE),
    power = a$power,
    networkType = a[["network-type"]],
    replaceMissingAdjacencies = wg_option(a,"network-replace-missing-adjacencies",FALSE),
    TOMType = a[["tom-type"]],
    TOMDenom = wg_option(a,"network-tomdenom","min"),
    suppressTOMForZeroAdjacencies = wg_option(a,"network-suppress-tomfor-zero-adjacencies",FALSE),
    suppressNegativeTOM = wg_option(a,"network-suppress-negative-tom",FALSE),
    getTOMs = NULL,
    saveTOMs = FALSE,
    saveTOMFileBase = "blockwiseTOM",
    deepSplit = a[["deep-split"]],
    detectCutHeight = wg_option(a,"network-detect-cut-height",0.995),
    minModuleSize = minSize,
    maxCoreScatter = NULL,
    minGap = NULL,
    maxAbsCoreScatter = NULL,
    minAbsGap = NULL,
    minSplitHeight = NULL,
    minAbsSplitHeight = NULL,
    useBranchEigennodeDissim = FALSE,
    minBranchEigennodeDissim = a[["merge-height"]],
    stabilityLabels = NULL,
    stabilityCriterion = c("Individual fraction", "Common fraction"),
    minStabilityDissim = NULL,
    pamStage = wg_option(a,"network-pam-stage",TRUE),
    pamRespectsDendro = a[["pam-respects-dendro"]] == "true",
    reassignThreshold = a[["reassign-threshold"]],
    minCoreKME = wg_option(a,"network-min-core-kme",0.5),
    minCoreKMESize = wg_option(a,"network-min-core-kmesize",minSize/3),
    minKMEtoStay = wg_option(a,"network-min-kmeto-stay",0.3),
    mergeCutHeight = a[["merge-height"]],
    impute = wg_option(a,"network-impute",TRUE),
    trapErrors = FALSE,
    numericLabels = FALSE,
    nThreads = 1,
    useInternalMatrixAlgebra = FALSE,
    useCorOptionsThroughout = TRUE,
    verbose = 0,
    indent = 0)
  MEs <- (WGCNA::moduleEigengenes(
    expr = datExpr,
    colors = net$colors,
    impute = wg_option(a,"eigengene-impute",TRUE),
    nPC = wg_option(a,"eigengene-n-pc",1),
    align = wg_option(a,"eigengene-align","along average"),
    excludeGrey = wg_option(a,"eigengene-exclude-grey",FALSE),
    grey = "grey",
    subHubs = wg_option(a,"eigengene-sub-hubs",TRUE),
    trapErrors = FALSE,
    returnValidOnly = FALSE,
    softPower = a$power,
    scale = wg_option(a,"eigengene-scale",TRUE),
    verbose = 0,
    indent = 0))$eigengenes
  traits <- strsplit(a$traits, ",", fixed = TRUE)[[1]]
  tr <- as.matrix(st[, traits, drop = FALSE]); storage.mode(tr) <- "double"
  r <- wg_cor(MEs, tr, a)
  pair_n <- crossprod(!is.na(as.matrix(MEs)), !is.na(tr))
  infer <- identical(wg_option(a,"cor-method","pearson"), "pearson") &&
    all(vapply(c("cor-cosine", "cor-cosine-x", "cor-cosine-y"),
      function(k) isFALSE(wg_option(a,k,wg_option(a,"cor-cosine",FALSE))), logical(1))) &&
    is.null(wg_option(a,"cor-weights-x",NULL)) && is.null(wg_option(a,"cor-weights-y",NULL))
  p <- if (infer) WGCNA::corPvalueStudent(
    cor = r,
    nSamples = pair_n) else matrix(NA_real_, nrow(r), ncol(r), dimnames = dimnames(r))
  assoc <- expand.grid(module = rownames(r), trait = colnames(r), stringsAsFactors = FALSE)
  assoc$estimate <- as.vector(r); assoc$p_value <- as.vector(p)
  assoc$p_adjusted <- stats::p.adjust(assoc$p_value, method = a[["trait-p-adjust"]] %||% "BH")
  assoc$n_unweighted <- as.vector(pair_n)
  # module_traits.csv keeps its sealed schema; the inference mode and the
  # pairwise complete counts are written to the module_traits_inference sidecar.
  inference <- if (infer) "pearson_student_t" else "descriptive_no_p"
  inference_table <- data.frame(module = assoc$module, trait = assoc$trait, inference = inference,
    n_pairwise_complete = as.integer(as.vector(pair_n)), n_samples = nrow(datExpr),
    p_value_source = if (infer) "WGCNA::corPvalueStudent(cor, nSamples = n_pairwise_complete)" else "none (descriptive correlation)",
    stringsAsFactors = FALSE)
  kme <- wg_cor(datExpr, MEs, a)
  membership <- kme[cbind(seq_len(ncol(datExpr)), match(paste0("ME", net$colors), colnames(MEs)))]
  gene <- data.frame(feature_id = colnames(datExpr), module = net$colors, module_membership = membership)
  gene$hub_rank <- ave(-abs(membership), gene$module, FUN = function(x) rank(x, ties.method = "min"))
  gene$hub_rank[gene$module == "grey"] <- NA
  gs <- wg_cor(datExpr, tr, a)
  for (j in seq_along(traits)) gene[[paste0("gene_significance_", traits[j])]] <- gs[, j]
  sizes <- as.data.frame(table(net$colors)); names(sizes) <- c("module", "n_genes")
  diag <- data.frame(power = sft$fitIndices[, 1], signed_r2 = -sign(sft$fitIndices[, 3]) * sft$fitIndices[, 2], mean_k = sft$fitIndices[, 5])
  native_controls <- list(goodSamplesGenes=list("weights"=wg_option(a,"gsg-weights",NULL),"minFraction"=wg_option(a,"gsg-min-fraction",1/2),"minNSamples"=wg_option(a,"gsg-min-nsamples",4),"minNGenes"=wg_option(a,"gsg-min-ngenes",4),"tol"=wg_option(a,"gsg-tol",NULL),"minRelativeWeight"=wg_option(a,"gsg-min-relative-weight",0.1)),pickSoftThreshold=list("weights"=wg_option(a,"soft-weights",NULL),"RsquaredCut"=wg_option(a,"soft-rsquared-cut",0.85),"removeFirst"=wg_option(a,"soft-remove-first",FALSE),"nBreaks"=wg_option(a,"soft-n-breaks",10),"corFnc"=a[["soft-cor-fnc"]] %||% "WGCNA::cor","corOptions"=wg_option(a,"soft-cor-options",list(use = "p"))),blockwiseModules=list("corType"=wg_option(a,"network-cor-type","pearson"),"maxPOutliers"=wg_option(a,"network-max-poutliers",1),"quickCor"=wg_option(a,"network-quick-cor",0),"pearsonFallback"=wg_option(a,"network-pearson-fallback","individual"),"cosineCorrelation"=wg_option(a,"network-cosine-correlation",FALSE),"TOMDenom"=wg_option(a,"network-tomdenom","min"),"replaceMissingAdjacencies"=wg_option(a,"network-replace-missing-adjacencies",FALSE),"suppressTOMForZeroAdjacencies"=wg_option(a,"network-suppress-tomfor-zero-adjacencies",FALSE),"suppressNegativeTOM"=wg_option(a,"network-suppress-negative-tom",FALSE),"detectCutHeight"=wg_option(a,"network-detect-cut-height",0.995),"pamStage"=wg_option(a,"network-pam-stage",TRUE),"minCoreKME"=wg_option(a,"network-min-core-kme",0.5),"minCoreKMESize"=wg_option(a,"network-min-core-kmesize",minSize/3),"minKMEtoStay"=wg_option(a,"network-min-kmeto-stay",0.3),"impute"=wg_option(a,"network-impute",TRUE)),moduleEigengenes=list("impute"=wg_option(a,"eigengene-impute",TRUE),"nPC"=wg_option(a,"eigengene-n-pc",1),"align"=wg_option(a,"eigengene-align","along average"),"excludeGrey"=wg_option(a,"eigengene-exclude-grey",FALSE),"subHubs"=wg_option(a,"eigengene-sub-hubs",TRUE),"scale"=wg_option(a,"eigengene-scale",TRUE)),cor=list("use"=wg_option(a,"cor-use","p"),"method"=wg_option(a,"cor-method","pearson"),"weights.x"=wg_option(a,"cor-weights-x",NULL),"weights.y"=wg_option(a,"cor-weights-y",NULL),"cosine"=wg_option(a,"cor-cosine",FALSE),"cosineX"=wg_option(a,"cor-cosine-x",wg_option(a,"cor-cosine",FALSE)),"cosineY"=wg_option(a,"cor-cosine-y",wg_option(a,"cor-cosine",FALSE)),"quick"=wg_option(a,"cor-quick",0)),p.adjust=a[["trait-p-adjust"]] %||% "BH",adjustment_family=nrow(assoc))
  list(native_controls=native_controls,gene = gene, sizes = sizes, assoc = assoc, inference = inference, inference_table = inference_table, r = r, p = p, MEs = MEs, net = net,
       diagnostics = diag, samples = ncol(mat), genes = nrow(mat), minSize = minSize,
       sampleTree = stats::hclust(stats::dist(datExpr, method = "euclidean"), method = "average"))
}
