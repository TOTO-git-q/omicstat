FG_MODULE <- "fgsea-prerank"
FG_MODULE_VERSION <- "1.1.0"
FG_VERSION <- FG_MODULE_VERSION

fgsea_prerank_compute <- function(rank, collection, a) {
  stats <- rank$stats
  pathways <- collection$sets
  size <- lengths(lapply(pathways, intersect, names(stats)))
  keep <- size >= a[["min-size"]] & size <= a[["max-size"]]
  if (!any(keep)) stop("OS_EMPTY_DATA: no gene set remains after rank intersection and size limits.", call. = FALSE)
  set.seed(a$seed)
  raw <- fgsea::fgseaMultilevel(pathways = pathways, stats = stats,
                               sampleSize = 101, minSize = a[["min-size"]], maxSize = a[["max-size"]],
                               eps = 1e-50, scoreType = "std", nproc = 1, gseaParam = 1,
                               BPPARAM = NULL, nPermSimple = 1000, absEps = NULL)
  d <- as.data.frame(raw)
  # PACK T: sorted by NES within the significant and the non-significant
  # group (significant = BH adjusted P < alpha first; NES descending; ties by
  # pathway; NA NES / padj last).
  sig <- !is.na(d$padj) & d$padj < a$alpha
  d <- d[order(!sig, -d$NES, d$pathway, na.last = TRUE, method = "radix"), , drop = FALSE]
  d$leadingEdge <- vapply(d$leadingEdge, paste, collapse = ";", FUN.VALUE = "")
  et <- data.frame(term_id = d$pathway, term_name = d$pathway, database = a$collection,
                   set_size = d$size, es = d$ES, nes = d$NES, pvalue = d$pval,
                   padj = d$padj, log2err = d$log2err, leading_edge = d$leadingEdge,
                   stringsAsFactors = FALSE)
  list(table = et, stats = stats, pathways = pathways, n_sets_input = length(pathways),
       n_sets_retained = sum(keep), n_sets_excluded = sum(!keep),
       n_tied = rank$n_tied, n_zero = rank$n_zero)
}
