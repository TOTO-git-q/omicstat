# fig_fixtures.R -- deterministic synthetic inputs for the figure layer
# tests and gallery. ASCII only on purpose. These are SHAPE fixtures (right
# columns, realistic ranges), not biological data; numeric anchors for the
# analysis modules come from the vignettes (PACK section C).

fx_rng <- function(seed) { set.seed(seed, kind = "Mersenne-Twister", normal.kind = "Inversion", sample.kind = "Rejection") }

fx_feature_table <- function(n = 4000, seed = 1) {
  fx_rng(seed)
  sym <- c("CXCL8", "IL1B", "TNF", "CCL2", "SOCS3", "MT2A", "FOS", "JUN", "EGR1", "IER3",
           "KLF2", "DUSP1", "NR4A1", "HBB", "COL1A1", "ACTB", "GAPDH", "MKI67", "TOP2A", "CD74")
  ft <- data.frame(feature_id = sprintf("ENSG%011d", seq_len(n)),
                   symbol = c(sym, sprintf("GENE%d", (length(sym) + 1):n)),
                   contrast = "condition: treated vs control",
                   base_mean = round(10^stats::runif(n, 0.3, 5), 4),
                   stringsAsFactors = FALSE)
  eff <- stats::rnorm(n, 0, 0.35)
  de <- sample.int(n, 500)
  eff[de] <- eff[de] + sample(c(-1, 1), 500, TRUE) * stats::rgamma(500, 2.5, 1.3)
  eff[1:10] <- c(4.1, 3.6, 3.2, 2.9, 2.7, -3.8, -3.1, -2.6, -2.4, -2.2)
  se <- 0.15 + 1.2 / sqrt(ft$base_mean)
  ft$log2fc <- round(eff, 6)
  ft$log2fc_se <- round(se, 6)
  ft$stat <- round(eff / se, 6)
  ft$pvalue <- 2 * stats::pnorm(-abs(ft$stat))
  ft$padj <- stats::p.adjust(ft$pvalue, "BH")
  ft$padj[ft$base_mean < 3] <- NA
  ft$method <- "DESeq2 Wald"; ft$shrinkage <- "apeglm"; ft$n_group1 <- 4L; ft$n_group2 <- 4L
  ft$filtered_reason <- ifelse(is.na(ft$padj), "independent_filtering", "")
  ft
}

fx_expression <- function(ft, n_per = 4, seed = 2) {
  fx_rng(seed)
  n <- nrow(ft); s <- 2 * n_per
  base <- log2(ft$base_mean + 1)
  m <- matrix(stats::rnorm(n * s, rep(base, s), 0.35), n, s,
              dimnames = list(ft$feature_id, sprintf("S%02d", seq_len(s))))
  treated <- (n_per + 1):s
  m[, treated] <- m[, treated] + ft$log2fc
  batch_shift <- stats::rnorm(n, 0, 0.25)
  m[, seq(2, s, 2)] <- m[, seq(2, s, 2)] + batch_shift
  cd <- data.frame(sample = colnames(m), condition = rep(c("control", "treated"), each = n_per),
                   batch = rep(c("batch1", "batch2"), s / 2), stringsAsFactors = FALSE)
  list(mat = m, coldata = cd)
}

fx_enrichment <- function(seed = 3) {
  fx_rng(seed)
  terms <- c("inflammatory response", "response to lipopolysaccharide", "cytokine-mediated signaling pathway",
             "positive regulation of NF-kappaB transcription factor activity", "neutrophil chemotaxis",
             "cellular response to interleukin-1", "regulation of apoptotic signaling pathway",
             "response to hypoxia", "extracellular matrix organization", "collagen fibril organization",
             "mitotic cell cycle phase transition", "DNA replication", "chromosome segregation",
             "oxidative phosphorylation", "ribosome biogenesis", "antigen processing and presentation of peptide antigen via MHC class II",
             "T cell activation", "angiogenesis", "wound healing", "fatty acid metabolic process")
  k <- length(terms)
  et <- data.frame(term_id = sprintf("GO:%07d", 6954 + seq_len(k) * 37), term_name = terms, database = "GO BP",
                   set_size = sample(40:400, k), stringsAsFactors = FALSE)
  et$n_genes <- pmax(3L, round(et$set_size * stats::runif(k, 0.05, 0.2)))
  et$gene_ratio <- round(et$n_genes / 480, 4)
  et$nes <- round(c(2.6, 2.4, 2.3, 2.1, 2.0, 1.9, 1.7, 1.6, 1.5, 1.45, -2.5, -2.3, -2.2, -2.0, -1.9, -1.7, -1.6, 1.3, 1.2, -1.1), 3)
  et$pvalue <- signif(10^-(abs(et$nes) * stats::runif(k, 1.5, 3.5)), 4)
  et$padj <- signif(pmin(1, et$pvalue * 8), 4)
  et
}

fx_ranked <- function(ft, seed = 4) {
  s <- ft$stat; names(s) <- ft$symbol
  s[is.finite(s)]
}

fx_embedding <- function(n = 6000, seed = 5) {
  fx_rng(seed)
  types <- c("CD4 T", "CD8 T", "NK", "B", "Plasma", "CD14 Mono", "FCGR3A Mono", "cDC", "pDC", "Platelet")
  w <- c(0.24, 0.15, 0.08, 0.13, 0.02, 0.2, 0.07, 0.04, 0.02, 0.05)
  ct <- sample(types, n, TRUE, prob = w)
  cx <- c(-6, -4, -1, 5, 7, -2, 1, 3, 4.5, 8); cy <- c(3, 6, 7.5, 5, 7.8, -4, -6, -2, 1, -5)
  i <- match(ct, types)
  data.frame(cell = sprintf("cell_%05d", seq_len(n)), x = round(cx[i] + stats::rnorm(n, 0, 0.9), 5),
             y = round(cy[i] + stats::rnorm(n, 0, 0.9), 5), celltype = ct,
             sample = sample(sprintf("P%d", 1:6), n, TRUE), stringsAsFactors = FALSE)
}

fx_markers <- function(seed = 6) {
  fx_rng(seed)
  types <- c("B", "CD14 Mono", "CD4 T", "CD8 T", "FCGR3A Mono", "NK", "Platelet", "cDC", "pDC", "Plasma")
  genes <- c("MS4A1", "CD79A", "CD14", "LYZ", "IL7R", "CCR7", "CD8A", "GZMK", "FCGR3A", "MS4A7",
             "GNLY", "NKG7", "PPBP", "PF4", "FCER1A", "CST3", "LILRA4", "IRF7", "JCHAIN", "MZB1")
  md <- expand.grid(cluster = types, gene = genes, stringsAsFactors = FALSE)
  own <- rep(types[c(1, 2, 3, 4, 5, 6, 7, 8, 9, 10)], each = 2)
  hit <- md$cluster == own[match(md$gene, genes)]
  md$pct_exp <- round(ifelse(hit, stats::runif(nrow(md), 70, 98), stats::runif(nrow(md), 0, 25)), 2)
  raw <- ifelse(hit, stats::runif(nrow(md), 1.5, 3), stats::runif(nrow(md), 0, 0.6))
  md$avg_exp <- stats::ave(raw, md$gene, FUN = function(v) as.numeric(scale(v)))
  # cells per cluster (fixed, no RNG): fx_embedding() weights x 6,000 cells
  n_cells <- c(B = 780L, "CD14 Mono" = 1200L, "CD4 T" = 1440L, "CD8 T" = 900L, "FCGR3A Mono" = 420L,
               NK = 480L, Platelet = 300L, cDC = 240L, pDC = 120L, Plasma = 120L)
  md$n_cells <- unname(n_cells[md$cluster])
  list(md = md, gene_order = genes, cluster_order = types)
}

fx_proportions <- function(emb) {
  cond <- c(P1 = "control", P2 = "control", P3 = "control", P4 = "disease", P5 = "disease", P6 = "disease")
  tab <- as.data.frame(table(sample = emb$sample, celltype = emb$celltype), stringsAsFactors = FALSE)
  names(tab)[3] <- "n"
  tab$condition <- unname(cond[tab$sample])
  tab
}

fx_qc <- function(n = 3000, seed = 7) {
  fx_rng(seed)
  data.frame(sample = sample(sprintf("P%d", 1:6), n, TRUE), nFeature = round(10^stats::rnorm(n, 3.1, 0.2)),
             nCount = round(10^stats::rnorm(n, 3.6, 0.25)), percent_mt = round(abs(stats::rnorm(n, 4, 3)), 3),
             condition = NA_character_, stringsAsFactors = FALSE)
}

fx_module_trait <- function(seed = 8) {
  fx_rng(seed)
  mods <- c("MEturquoise", "MEblue", "MEbrown", "MEyellow", "MEgreen", "MEred", "MEblack", "MEgrey")
  traits <- c("Treatment", "Age", "BMI", "Score")
  r <- matrix(round(stats::runif(length(mods) * length(traits), -0.85, 0.85), 3), length(mods), dimnames = list(mods, traits))
  p <- matrix(signif(pmin(1, 2 * stats::pnorm(-abs(r) * 5)), 3), length(mods), dimnames = dimnames(r))
  list(r = r, p = p)
}

fx_soft_threshold <- function() {
  pw <- c(1:10, seq(12, 20, 2))
  data.frame(power = pw, signed_r2 = round(1 - 0.95 * exp(-pw / 3.2) - 0.05, 4),
             mean_k = round(2000 * exp(-pw / 2.2) + 5, 3))
}

fx_maf <- function(seed = 9) {
  fx_rng(seed)
  genes <- c("TP53", "KRAS", "PIK3CA", "APC", "EGFR", "PTEN", "ARID1A", "KMT2D", "BRAF", "SMAD4", "CDKN2A", "NF1")
  f <- c(0.55, 0.35, 0.3, 0.28, 0.2, 0.18, 0.15, 0.14, 0.1, 0.1, 0.08, 0.07)
  samples <- sprintf("T%03d", 1:60)
  cls <- c("Missense_Mutation", "Nonsense_Mutation", "Frame_Shift_Del", "Frame_Shift_Ins", "Splice_Site", "In_Frame_Del")
  rows <- list()
  for (i in seq_along(genes)) {
    hit <- samples[stats::runif(length(samples)) < f[i]]
    for (s in hit) {
      k <- if (stats::runif(1) < 0.08) 2 else 1
      rows[[length(rows) + 1]] <- data.frame(sample = s, gene = genes[i],
                                             variant_class = sample(cls, k, TRUE, prob = c(0.6, 0.12, 0.1, 0.06, 0.07, 0.05)))
    }
  }
  list(maf = do.call(rbind, rows), samples = samples)
}
