# Testing families (cross-module contract d). compareCluster, like the separate
# route, runs enrichGO once per list, so BH is always within a list. With
# ont = "ALL" and pool = FALSE enrichGO itself runs once per ontology
# (clusterProfiler 4.20.0 source), so each list x ontology has its own
# effective input, background and BH family; pool = TRUE and a single
# ontology give one family per list. Denominators must be unique within a
# family and p.adjust must equal BH over that family alone.
cx_families <- function(raw, a, groups, label = NULL) {
  per_ont <- is.null(label) && identical(a$ontology, "ALL") && isFALSE(a$pool)
  lab <- if (!is.null(label)) rep(label, nrow(raw)) else if (per_ont) paste("GO", as.character(raw$ONTOLOGY)) else
    rep(if (identical(a$ontology, "ALL")) "GO ALL pooled" else paste("GO", a$ontology), nrow(raw))
  grp <- as.character(raw$Cluster)
  den <- function(z) as.integer(vapply(strsplit(as.character(z), "/", fixed = TRUE), `[`, "", 2))
  rows <- list()
  for (g in groups) for (f in intersect(c("GO BP", "GO CC", "GO MF", "GO ALL pooled", label), unique(lab[grp == g]))) {
    i <- grp == g & lab == f
    gi <- unique(den(raw$GeneRatio[i])); bi <- unique(den(raw$BgRatio[i]))
    if (length(gi) != 1L || length(bi) != 1L)
      stop(sprintf("OS_INVALID_RESULT: list %s, %s disagrees on effective input or background denominator.", g, f), call. = FALSE)
    if (max(abs(stats::p.adjust(raw$pvalue[i], method = "BH") - raw$p.adjust[i])) > 1e-12)
      stop(sprintf("OS_INVALID_RESULT: adjusted P of list %s, %s is not BH over that family.", g, f), call. = FALSE)
    scope <- if (per_ont) sprintf("BH over the %d tested %s terms of list %s only (pool = FALSE)", sum(i), f, g) else
      if (identical(f, "GO ALL pooled")) sprintf("BH over all %d tested BP, CC and MF terms of list %s (pool = TRUE)", sum(i), g) else
        sprintf("BH over the %d tested %s terms of list %s", sum(i), f, g)
    rows[[length(rows) + 1L]] <- data.frame(group = g, test_family = f, n_effective_input = gi, n_effective_background = bi,
      n_tested_terms = sum(i), n_significant_bh05 = sum(i & !is.na(raw$p.adjust) & raw$p.adjust < 0.05),
      adjustment_scope = scope, stringsAsFactors = FALSE)
  }
  list(table = do.call(rbind, rows), row_family = lab)
}

cx_render <- function(r,x,a,ref,coll=NULL) {
  custom <- !is.null(coll)
  dbl <- if (custom) coll$label else paste("GO",a$ontology)
  fam <- cx_families(r$raw,a,x$metadata$group,label=if (custom) dbl else NULL)
  tab <- os_enrich_canonical(r$raw,database=dbl,group=as.character(r$raw$Cluster))
  tab$test_family <- fam$row_family
  tab$population <- x$metadata$population[match(tab$group,x$metadata$group)]
  tab$selection_rule <- x$metadata$selection_rule[match(tab$group,x$metadata$group)]
  path <- file.path(a$outdir,"tables","enrichment_full.csv"); os_enrich_write_csv(tab,path)
  ft <- fam$table
  fam_path <- file.path(a$outdir,"tables","test_families.csv"); os_enrich_write_csv(ft,fam_path)
  defs <- x$metadata
  mapped <- if (custom) unique(unlist(coll$sets,use.names=FALSE)) else AnnotationDbi::keys(org.Hs.eg.db::org.Hs.eg.db,keytype=a[["key-type"]])
  defs$n_input <- vapply(x$genes,length,integer(1))
  defs$n_mapped_input <- vapply(x$genes,function(z) length(intersect(z,mapped)),integer(1))
  defs$n_candidate_background <- vapply(x$backgrounds,length,integer(1))
  defs$n_mapped_background <- vapply(x$backgrounds,function(z) length(intersect(z,mapped)),integer(1))
  one <- function(g,col) { s <- ft[ft$group==g,,drop=FALSE]; if (nrow(s)!=1L) NA_integer_ else as.integer(s[[col]]) }
  by_fam <- function(g,col) { s <- ft[ft$group==g,,drop=FALSE]; if (!nrow(s)) NA_character_ else
    paste(sprintf("%s=%d",sub("^GO ","",s$test_family),s[[col]]),collapse=";") }
  # One effective count only when the list has one testing family; otherwise NA
  # here and the per-family values below / in tables/test_families.csv.
  defs$n_effective_background <- vapply(defs$group,one,integer(1),col="n_effective_background")
  defs$n_effective_input <- vapply(defs$group,one,integer(1),col="n_effective_input")
  defs$effective_input_by_family <- vapply(defs$group,by_fam,"",col="n_effective_input")
  defs$effective_background_by_family <- vapply(defs$group,by_fam,"",col="n_effective_background")
  defs$adjustment_scope <- vapply(defs$group,function(g) paste(ft$adjustment_scope[ft$group==g],collapse="; "),"")
  defs$n_tested_terms <- vapply(defs$group,function(g) sum(tab$group==g),integer(1))
  defs$n_significant_bh05 <- vapply(defs$group,function(g) sum(tab$group==g&tab$significant_bh05),integer(1))
  defs_path <- file.path(a$outdir,"tables","list_definitions.csv"); os_enrich_write_csv(defs,defs_path)
  fig <- NULL
  if (x$same_population && any(tab$significant_bh05)) {
    ftab <- tab
    if (identical(a$ontology,"ALL")) ftab$term_name <- paste0("[",ftab$ONTOLOGY,"] ",ftab$term_name)
    plt <- if (custom) os_enrich_compare(ftab,groups_order=x$metadata$group,top_n_per_group=a[["top-n-per-group"]],
                                         padj_threshold=0.05,database_label=dbl,journal=a$journal)+ggplot2::scale_x_discrete(drop=FALSE) else
      os_cp_compare_dotplot(ftab,x$metadata$group,a[["top-n-per-group"]],a$ontology,a$journal)
    if (custom) plt <- os_with_meta(plt,caption=paste0(attr(plt,"os_meta")$caption," ",length(x$metadata$group),
      " lists share one eligible universe. This chart does not test differences between lists."))
    if (identical(a$ontology,"ALL"))
      plt <- os_with_meta(plt,caption=paste(attr(plt,"os_meta")$caption,if (isTRUE(a$pool))
        "BP, CC and MF were pooled into one test and one BH family per list (pool = TRUE)." else
        "Each ontology was tested with its own effective input and background and BH-adjusted separately within each list (pool = FALSE); see tables/test_families.csv."))
    fig <- os_finalize_figure(plt,file.path(a$outdir,"figures","compare_dotplot"),journal=a$journal)
  }
  dir.create(file.path(a$outdir,"results"),recursive=TRUE,showWarnings=FALSE)
  jsonlite::write_json(list(module=CX_MODULE,module_version=CX_MODULE_VERSION,mode=r$mode,database=if (custom) dbl else "GO",
                            ontology=if (custom) NULL else a$ontology,pool=a$pool,key_type=a[["key-type"]],
                            n_lists=nrow(defs),n_tested_rows=nrow(tab),n_significant_bh05=sum(tab$significant_bh05),
                            test_families=ft,adjustment="BH within each list and testing family (tables/test_families.csv)",
                            pvalueCutoff_compute=1,qvalueCutoff_compute=1,pAdjustMethod="BH",
                            software=cx_software(custom),refdata=ref),
                       file.path(a$outdir,"results","clusterprofiler_compare_results.json"),
                       auto_unbox=TRUE,pretty=TRUE,null="null",na="null")
  list(table=path,definitions=defs_path,families=fam_path,figure=fig,family_table=ft)
}

cx_software <- function(custom=FALSE) {
  pv <- function(p) as.character(utils::packageVersion(p))
  if (isTRUE(custom))
    return(list(clusterProfiler=pv("clusterProfiler"),comparison_function="clusterProfiler::compareCluster (fun = enricher)",
                enrichment_function="clusterProfiler::enricher",enrichit=pv("enrichit"),ora_engine="enrichit::ora_gson",
                gene_sets="user-supplied GMT (provenance/user_gene_sets.json)"))
  gm <- AnnotationDbi::metadata(GO.db::GO.db)
  list(clusterProfiler=pv("clusterProfiler"),comparison_function="clusterProfiler::compareCluster",
       enrichment_function="clusterProfiler::enrichGO",enrichit=pv("enrichit"),ora_engine="enrichit::ora_gson",
       GO.db=pv("GO.db"),GO_source_date=as.character(gm$value[match("GOSOURCEDATE",gm$name)]),
       org.Hs.eg.db=pv("org.Hs.eg.db"))
}

cx_draft <- function(r,x,a,module_dir,render) {
  t <- os_read_templates(file.path(module_dir,"references","reporting-templates.md"))
  if (identical(a$database,"custom")) return(cx_draft_custom(r,x,a,render,t))
  sw <- cx_software(); ft <- render$family_table
  per_list <- vapply(x$metadata$group,function(g) { s <- ft[ft$group==g,,drop=FALSE]
    paste0(g," ",paste(sprintf("%s %d/%d",sub("^GO ","",s$test_family),s$n_effective_input,s$n_effective_background),collapse=", ")) },"")
  scope <- if (identical(a$ontology,"ALL") && isFALSE(a$pool))
    "enrichGO was run once per list and, with pool = FALSE, once per ontology within each list, so each list and ontology had its own effective input and background and its own BH adjustment and q-values (list: ontology input/background = " else
    if (identical(a$ontology,"ALL"))
      "enrichGO was run once per list with BP, CC and MF pooled (pool = TRUE), so BH adjustment and q-values covered all three ontologies within each list separately (list: input/background = " else
      "enrichGO was run once per list, so BH adjustment and q-values were computed within each list separately (list: input/background = "
  v <- list(n_lists=nrow(x$metadata),ontology=a$ontology,
            pool=if (is.null(a$pool)) "FALSE" else as.character(a$pool),
            key_type=a[["key-type"]],min_size=a[["min-size"]],max_size=a[["max-size"]],
            mode=r$mode,tested=nrow(r$raw),sig=sum(!is.na(r$raw$p.adjust)&r$raw$p.adjust<0.05),
            annotation_version=sw$org.Hs.eg.db,cp_version=sw$clusterProfiler,enrichit_version=sw$enrichit,
            godb_version=sw$GO.db,go_date=sw$GO_source_date,
            scope_sentence=paste0(scope,paste(per_list,collapse="; "),")."),
            population_note=if (x$same_population) "All lists had the same declared selectable population and identical eligible universe; compareCluster used that explicit common universe." else "Selectable populations or eligible universes differed; each list was tested separately against its own background and no pooled comparison figure was made.")
  os_write_text(c("# Methods","",os_fill_template(t$methods,v),"","# Results","",os_fill_template(t$results,v),
                  "","No statistical test of a difference in enrichment between lists was performed."),
                file.path(a$outdir,"draft","methods_results.md"))
}

# --database custom (template methods_custom); the gene-set provenance
# sentence is inserted by os_user_genesets_draft().
cx_draft_custom <- function(r,x,a,render,t) {
  sw <- cx_software(TRUE); ft <- render$family_table
  per_list <- vapply(x$metadata$group,function(g) { s <- ft[ft$group==g,,drop=FALSE]
    sprintf("%s %d/%d",g,s$n_effective_input[1],s$n_effective_background[1]) },"")
  v <- list(n_lists=nrow(x$metadata),label=ft$test_family[1],key_type=a[["key-type"]],
            min_size=a[["min-size"]],max_size=a[["max-size"]],mode=r$mode,tested=nrow(r$raw),
            sig=sum(!is.na(r$raw$p.adjust)&r$raw$p.adjust<0.05),cp_version=sw$clusterProfiler,enrichit_version=sw$enrichit,
            scope_sentence=paste0("enricher was run once per list, so BH adjustment and q-values were computed within each list separately (list: input/background = ",
                                  paste(per_list,collapse="; "),")."),
            population_note=if (x$same_population) "All lists had the same declared selectable population and identical eligible universe; compareCluster (fun = enricher) used that explicit common universe." else "Selectable populations or eligible universes differed; each list was tested separately with enricher against its own background and no pooled comparison figure was made.")
  os_write_text(c("# Methods","",os_fill_template(t$methods_custom,v),"","# Results","",os_fill_template(t$results_custom,v),
                  "","No statistical test of a difference in enrichment between lists was performed."),
                file.path(a$outdir,"draft","methods_results.md"))
}
