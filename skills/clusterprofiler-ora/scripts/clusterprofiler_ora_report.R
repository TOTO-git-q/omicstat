co_pkg_version <- function(p) as.character(utils::packageVersion(p))

# Software and annotation releases that determine the result (PACK W, F3).
co_software <- function(simplify, custom = FALSE) {
  om <- AnnotationDbi::metadata(org.Hs.eg.db::org.Hs.eg.db)
  mv <- function(m, k) as.character(m$value[match(k, m$name)])
  if (isTRUE(custom))
    return(list(clusterProfiler = co_pkg_version("clusterProfiler"), enrichment_function = "clusterProfiler::enricher",
                enrichit = co_pkg_version("enrichit"), ora_engine = "enrichit::ora_gson",
                gene_sets = "user-supplied GMT (provenance/user_gene_sets.json)",
                org.Hs.eg.db = co_pkg_version("org.Hs.eg.db"), orgdb_use = "symbol display table only",
                orgdb_entrez_source_date = mv(om, "EGSOURCEDATE"), AnnotationDbi = co_pkg_version("AnnotationDbi")))
  gm <- AnnotationDbi::metadata(GO.db::GO.db)
  s <- list(clusterProfiler = co_pkg_version("clusterProfiler"), enrichment_function = "clusterProfiler::enrichGO",
            enrichit = co_pkg_version("enrichit"), ora_engine = "enrichit::ora_gson",
            GO.db = co_pkg_version("GO.db"), GO_source_date = mv(gm, "GOSOURCEDATE"), GO_source_url = mv(gm, "GOSOURCEURL"),
            org.Hs.eg.db = co_pkg_version("org.Hs.eg.db"), orgdb_entrez_source_date = mv(om, "EGSOURCEDATE"),
            orgdb_go_source_date = mv(om, "GOSOURCEDATE"), AnnotationDbi = co_pkg_version("AnnotationDbi"))
  if (isTRUE(simplify)) s <- c(s, list(simplify_function = "clusterProfiler::simplify", GOSemSim = co_pkg_version("GOSemSim")))
  s
}

co_render <- function(r, x, a, ref) {
  custom <- identical(a$database, "custom")
  dbl <- if (custom) ref$label else paste("GO", a$ontology)
  tab <- os_enrich_canonical(r$raw, database = dbl)
  tab$test_family <- r$family
  p <- file.path(a$outdir, "tables", "enrichment_full.csv")
  os_enrich_write_csv(tab, p)
  fam <- r$families
  fam$n_padj_below_alpha <- vapply(fam$test_family, function(f) sum(tab$test_family == f & !is.na(tab$padj) & tab$padj < a$alpha), integer(1))
  fam_path <- file.path(a$outdir, "tables", "test_families.csv")
  os_enrich_write_csv(fam, fam_path)
  sym_path <- file.path(a$outdir, "tables", "gene_symbol_map.csv")
  os_enrich_write_csv(r$symbols, sym_path)
  smap <- stats::setNames(ifelse(is.na(r$symbols$symbol), r$symbols$feature_id, r$symbols$symbol), r$symbols$feature_id)
  readable <- data.frame(term_id = tab$term_id, term_name = tab$term_name, test_family = tab$test_family,
                         Count = tab$Count, geneID = tab$geneID, stringsAsFactors = FALSE)
  readable$geneID_symbol <- vapply(strsplit(tab$geneID, "/", fixed = TRUE), function(z) {
    s <- smap[z]; s[is.na(s)] <- z[is.na(s)]; paste(s, collapse = "/") }, "")
  readable_path <- file.path(a$outdir, "tables", "enrichment_full_symbols.csv")
  os_enrich_write_csv(readable, readable_path)
  simp_path <- NULL; rel_path <- NULL
  if (!is.null(r$simplified)) {
    simp_path <- file.path(a$outdir, "tables", "enrichment_simplified_display.csv")
    os_enrich_write_csv(os_enrich_canonical(r$simplified, database = paste("GO", a$ontology)), simp_path)
    rel_path <- file.path(a$outdir, "tables", "simplify_relation.csv")
    os_enrich_write_csv(r$relation, rel_path)
  }
  fig <- NULL
  if (any(tab$significant_bh05) && any(!is.na(tab$padj) & tab$padj < a$alpha)) {
    ftab <- tab
    if (identical(a$ontology, "ALL")) ftab$term_name <- paste0("[", ftab$ONTOLOGY, "] ", ftab$term_name)
    plt <- if (custom) os_user_dotplot_floor(os_enrich_dotplot(ftab, x = "gene_ratio", top_n = a[["top-n"]], padj_threshold = a$alpha,
                                                               database_label = dbl, journal = a$journal)) else
      os_cp_ora_dotplot(ftab, a[["top-n"]], a$alpha, a$ontology, a$journal)
    if (identical(a$ontology, "ALL"))
      plt <- os_with_meta(plt, caption = paste(attr(plt, "os_meta")$caption, co_family_caption(fam, a$pool)))
    fig <- os_finalize_figure(plt, file.path(a$outdir, "figures", "ora_dotplot"), journal = a$journal)
  }
  n_sym <- sum(r$symbols$mapping == "mapped")
  simp_info <- if (is.null(r$simplified)) list(applied = FALSE) else list(
    applied = TRUE, cutoff = 0.7, by = "p.adjust", select_fun = "min", measure = "Wang", semData = "NULL (computed by clusterProfiler per ontology)",
    rule = "within each group of terms with Wang similarity > 0.7 the term with the smallest BH adjusted P is kept; ties by the larger number of GO ancestors; ALL is simplified per ontology",
    n_terms = nrow(r$raw), n_retained = nrow(r$simplified), n_merged = nrow(r$relation),
    similarity_source = r$similarity_source)
  dir.create(file.path(a$outdir, "results"), recursive = TRUE, showWarnings = FALSE)
  jsonlite::write_json(list(module = CO_MODULE, module_version = CO_VERSION, database = if (custom) dbl else "GO",
                            ontology = if (custom) NULL else a$ontology,
                            pool = a$pool, selection_rule = x$origin, n_candidate_background = r$n_candidate,
                            n_mapped_background = r$n_mapped_background, n_input = r$n_input,
                            n_mapped_input = r$n_mapped_input, n_effective_background = r$n_effective_background,
                            n_effective_input = r$n_effective, n_tested_terms = nrow(tab),
                            n_significant_bh05 = sum(tab$significant_bh05),
                            test_families = fam, pAdjustMethod = "BH",
                            pvalueCutoff_compute = 1, qvalueCutoff_compute = 1, fdr_alpha = a$alpha,
                            symbol_mapping = list(n_genes = nrow(r$symbols), n_mapped = n_sym, key_type = a[["key-type"]],
                                                  mapper = "enrichit::EXTID2NAME (the setReadable mapping)"),
                            simplify = simp_info, software = co_software(a$simplify, custom),
                            refdata = ref), file.path(a$outdir, "results", "clusterprofiler_ora_results.json"),
                       auto_unbox = TRUE, pretty = TRUE, null = "null", na = "null", digits = I(15))
  list(table = p, families = fam_path, symbols = sym_path, readable = readable_path,
       simplified = simp_path, relation = rel_path, figure = fig, n_symbol_mapped = n_sym)
}

co_family_caption <- function(fam, pool) {
  if (isTRUE(pool)) return(sprintf("BP, CC and MF were pooled into one test (input %d, background %d) and one BH family.",
                                   fam$n_effective_input[1], fam$n_effective_background[1]))
  paste0("Ontologies were tested and BH-adjusted separately (pool = FALSE): ",
         paste(sprintf("%s input %d / background %d", sub("^GO ", "", fam$test_family), fam$n_effective_input,
                       fam$n_effective_background), collapse = "; "), ".")
}

co_draft <- function(r, x, a, qc, render, module_dir) {
  t <- os_read_templates(file.path(module_dir, "references", "reporting-templates.md"))
  if (identical(a$database, "custom")) return(co_draft_custom(r, x, a, render, t))
  sw <- co_software(a$simplify)
  fam <- r$families
  fams_txt <- paste(sprintf("%s: %d input genes of a %d-gene background", sub("^GO ", "", fam$test_family),
                            fam$n_effective_input, fam$n_effective_background), collapse = "; ")
  family_sentence <- if (nrow(fam) == 1L && !identical(fam$test_family, "GO ALL pooled"))
    sprintf("%d selected genes remained in the GO input and %d genes in the GO testing universe (the GeneRatio and BgRatio denominators).",
            fam$n_effective_input, fam$n_effective_background) else if (nrow(fam) == 1L)
    sprintf("With pool = TRUE, BP, CC and MF terms formed one collection: %d selected genes remained in the GO input and %d genes in the GO testing universe.",
            fam$n_effective_input, fam$n_effective_background) else
    sprintf("With pool = FALSE, clusterProfiler tests each ontology separately, so each has its own effective input and testing universe (GeneRatio and BgRatio denominators): %s.", fams_txt)
  scope_sentence <- if (nrow(fam) > 1L)
    "P values were adjusted by BH within each ontology separately (three adjustment families); q-values were also computed per ontology." else
    sprintf("P values were adjusted by BH over all %d tested terms as one family.", fam$n_tested_terms)
  sig <- sum(!is.na(r$raw$p.adjust) & r$raw$p.adjust < a$alpha)
  family_results <- if (nrow(fam) > 1L) paste0(" By ontology: ", paste(sprintf("%s %d of %d", sub("^GO ", "", fam$test_family),
    vapply(fam$test_family, function(f) sum(r$family == f & !is.na(r$raw$p.adjust) & r$raw$p.adjust < a$alpha), integer(1)),
    fam$n_tested_terms), collapse = "; "), ".") else ""
  v <- list(ontology = a$ontology, pool = if (is.null(a$pool)) "FALSE" else as.character(a$pool),
            key_type = a[["key-type"]], rule = x$origin, candidate = r$n_candidate,
            mapped = r$n_mapped_background, input = r$n_input, mapped_input = r$n_mapped_input,
            family_sentence = family_sentence, scope_sentence = scope_sentence, family_results = family_results,
            tested = nrow(r$raw), alpha = a$alpha, sig = sig,
            min_size = a[["min-size"]], max_size = a[["max-size"]],
            cp_version = sw$clusterProfiler, enrichit_version = sw$enrichit, godb_version = sw$GO.db,
            go_date = sw$GO_source_date, annotation_version = sw$org.Hs.eg.db, eg_date = sw$orgdb_entrez_source_date,
            org_go_date = sw$orgdb_go_source_date, n_symbol = render$n_symbol_mapped)
  simp_text <- if (!a$simplify) "No term simplification was applied." else sprintf(paste0(
    "For display, redundant terms were summarised with clusterProfiler::simplify (Wang semantic similarity, GOSemSim %s, cutoff 0.7%s): ",
    "within each group of terms with similarity > 0.7 the term with the smallest BH adjusted P was kept (ties: more GO ancestors). ",
    "This reduced %d tested terms to %d representative terms; the %d merged terms, each with its representative, are listed in tables/simplify_relation.csv. ",
    "The full tested table is unchanged and simplification does not alter any P value."),
    sw$GOSemSim, if (identical(a$ontology, "ALL")) ", applied within each ontology" else "",
    nrow(r$raw), nrow(r$simplified), nrow(r$relation))
  os_write_text(c("# Methods", "", os_fill_template(t$methods, v), "", simp_text, "", "# Results", "",
                  os_fill_template(t$results, v),
                  if (is.null(render$figure)) os_enrich_empty_note(os_enrich_canonical(r$raw), a$alpha)),
                file.path(a$outdir, "draft", "methods_results.md"))
}

# --database custom: user-supplied gene sets (template methods_custom). The
# gene-set provenance sentence is inserted by os_user_genesets_draft().
co_draft_custom <- function(r, x, a, render, t) {
  sw <- co_software(FALSE, TRUE)
  fam <- r$families
  v <- list(label = fam$test_family, key_type = a[["key-type"]], rule = x$origin, candidate = r$n_candidate,
            annotated = r$n_mapped_background, input = r$n_input, annotated_input = r$n_mapped_input,
            effective_input = fam$n_effective_input, effective_background = fam$n_effective_background,
            min_size = a[["min-size"]], max_size = a[["max-size"]], tested = nrow(r$raw), alpha = a$alpha,
            sig = sum(!is.na(r$raw$p.adjust) & r$raw$p.adjust < a$alpha),
            cp_version = sw$clusterProfiler, enrichit_version = sw$enrichit, annotation_version = sw$org.Hs.eg.db,
            n_symbol = render$n_symbol_mapped)
  os_write_text(c("# Methods", "", os_fill_template(t$methods_custom, v), "", "# Results", "",
                  os_fill_template(t$results_custom, v),
                  if (is.null(render$figure)) os_enrich_empty_note(os_enrich_canonical(r$raw), a$alpha)),
                file.path(a$outdir, "draft", "methods_results.md"))
}
