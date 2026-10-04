# fig_fixtures_ext.R -- deterministic synthetic inputs for the extended figure
# types (fig_sc_extra.R, fig_enrich_network.R, heatmap splits). ASCII only.
# SHAPE fixtures, not biological data. Every generator seeds its own RNG and
# restores the caller's RNG state (kind and .Random.seed) on exit, so sourcing
# or calling these never perturbs another test's random stream.

fxe_with_seed <- function(seed, expr) {
  kind <- RNGkind()
  had <- exists(".Random.seed", envir = globalenv(), inherits = FALSE)
  old <- if (had) get(".Random.seed", envir = globalenv(), inherits = FALSE) else NULL
  on.exit({
    do.call(RNGkind, as.list(kind))
    if (had) assign(".Random.seed", old, envir = globalenv())
    else if (exists(".Random.seed", envir = globalenv(), inherits = FALSE)) rm(".Random.seed", envir = globalenv())
  })
  set.seed(seed, kind = "Mersenne-Twister", normal.kind = "Inversion", sample.kind = "Rejection")
  force(expr)
}

# Single-cell fixture: 6 clusters on a 2-D embedding, a cell-type annotation
# that mostly (not perfectly) follows the clusters, a sample column and an
# expression matrix (genes x cells, zero-inflated log-normalized values).
fxe_sc <- function(n = 2400, seed = 31) fxe_with_seed(seed, {
  cl <- c("C1", "C2", "C3", "C4", "C5", "C6")
  w <- c(0.26, 0.2, 0.18, 0.14, 0.12, 0.1)
  cluster <- sample(cl, n, TRUE, prob = w)
  cx <- c(-5, -2.5, 3, 5.5, 0.5, 6); cy <- c(2, 5.5, 4.5, 0, -4, -5)
  i <- match(cluster, cl)
  ct_of <- c(C1 = "T cell", C2 = "T cell", C3 = "B cell", C4 = "Monocyte", C5 = "NK cell", C6 = "Monocyte")
  celltype <- unname(ct_of[cluster])
  flip <- stats::runif(n) < 0.06
  celltype[flip] <- sample(c("T cell", "B cell", "Monocyte", "NK cell"), sum(flip), TRUE)
  genes <- c("CD3E", "IL7R", "MS4A1", "CD79A", "LYZ", "CD14", "GNLY", "NKG7")
  own <- c(CD3E = "C1", IL7R = "C2", MS4A1 = "C3", CD79A = "C3", LYZ = "C4", CD14 = "C6", GNLY = "C5", NKG7 = "C5")
  expr <- matrix(0, length(genes), n, dimnames = list(genes, sprintf("cell_%05d", seq_len(n))))
  for (g in genes) {
    hi <- cluster == own[[g]]
    p_on <- ifelse(hi, 0.85, 0.12)
    on <- stats::runif(n) < p_on
    mu <- ifelse(hi, 2.4, 0.8)
    expr[g, ] <- round(ifelse(on, pmax(0, stats::rnorm(n, mu, 0.55)), 0), 4)
  }
  emb <- data.frame(cell = colnames(expr), x = round(cx[i] + stats::rnorm(n, 0, 1.0), 5),
                    y = round(cy[i] + stats::rnorm(n, 0, 1.0), 5), cluster = cluster, celltype = celltype,
                    sample = sample(sprintf("P%d", 1:4), n, TRUE), stringsAsFactors = FALSE)
  list(emb = emb, expr = expr, genes = genes)
})

# Marker table (cluster, gene, avg_exp, pct_exp) computed from fxe_sc():
# avg_exp is the mean expression z-scored across clusters.
fxe_markers <- function(sc = fxe_sc()) {
  cl <- sort(unique(sc$emb$cluster), method = "radix")
  rows <- list()
  for (g in sc$genes) {
    v <- sc$expr[g, ]
    m <- vapply(cl, function(k) mean(v[sc$emb$cluster == k]), numeric(1))
    pct <- vapply(cl, function(k) 100 * mean(v[sc$emb$cluster == k] > 0), numeric(1))
    rows[[g]] <- data.frame(cluster = cl, gene = g, avg_exp = round(as.numeric(scale(m)), 6),
                            pct_exp = round(pct, 4), stringsAsFactors = FALSE)
  }
  md <- do.call(rbind, rows); rownames(md) <- NULL
  list(md = md, gene_order = sc$genes)
}

# Gene sets for the enrichment-network figures: the 20 fx_enrichment() terms
# drawn from 4 thematic gene pools (so terms of one theme overlap and form
# clusters) plus a few genes shared across themes. Returns the gene sets
# (term_id -> symbols) and a log2 fold change per symbol.
fxe_gene_sets <- function(et, seed = 32) fxe_with_seed(seed, {
  pool <- sprintf("G%03d", 1:160)
  pool[1:24] <- c("CXCL8", "IL1B", "TNF", "CCL2", "SOCS3", "NFKBIA", "IL6", "PTGS2", "CXCL2", "CCL3",
                  "MKI67", "TOP2A", "CDK1", "CCNB1", "BUB1", "PLK1", "COL1A1", "COL3A1", "FN1", "SPARC",
                  "NDUFA4", "COX7C", "ATP5F1E", "UQCRH")
  theme <- c(1, 1, 1, 1, 1, 1, 1, 1, 3, 3, 2, 2, 2, 4, 4, 1, 1, 3, 3, 4)
  pools <- list(c(1:10, 25:60), c(11:16, 61:90), c(17:20, 91:120), c(21:24, 121:160))
  sets <- list()
  for (k in seq_len(nrow(et))) {
    pp <- pool[pools[[theme[k]]]]
    size <- min(length(pp), 6 + (k * 7) %% 17)
    g <- sort(unique(c(pp[seq_len(4)], sample(pp, size), sample(pool, 1))), method = "radix")
    sets[[et$term_id[k]]] <- g
  }
  genes <- sort(unique(unlist(sets)), method = "radix")
  fc <- stats::setNames(round(stats::rnorm(length(genes), 0, 1.4), 4), genes)
  up <- c("CXCL8", "IL1B", "TNF", "CCL2", "IL6"); fc[intersect(up, genes)] <- c(3.8, 3.1, 2.6, 2.2, 2.9)[seq_along(intersect(up, genes))]
  list(sets = sets, fc = fc)
})
