# limma-camera S2 + S4 smoke in the locked container (F1-F5, contracts b and c).
here <- dirname(normalizePath(sub('^--file=', '', grep('^--file=', commandArgs(FALSE), value = TRUE)[1])))
module_dir <- dirname(here); suite <- normalizePath(file.path(module_dir, '..', '..'))
shared <- file.path(suite, 'skills', '_shared', 'scripts')
for (f in c('args.R', 'calls_check.R', 'module_kit.R', 'handoff.R', 'ranked_list.R', 'enrich_rank_io.R')) source(file.path(shared, f))
source(file.path(here, 'fixtures', 'make_yoruba.R'))
source(file.path(here, 'registry_values_check.R'))
failures <- character(0)
check <- function(x, msg) { if (isTRUE(x)) cat('PASS:', msg, '\n') else { cat('FAIL:', msg, '\n'); failures <<- c(failures, msg) } }
sha <- function(p) digest::digest(file = p, algo = 'sha256')
has_code <- function(o, code) o$status != 0 && any(grepl(code, o$out, fixed = TRUE))
rel_eq <- function(x, y, tol = 1e-8) length(x) == length(y) && all(abs(x / y - 1) < tol)
printed_eq <- function(x, printed) abs(signif(x, 3) / printed - 1) < 1e-9
tmp <- file.path(Sys.getenv('OMICSTAT_TEST_TMP', tempdir()), 'limma-camera-smoke')
unlink(tmp, recursive = TRUE); dir.create(tmp, recursive = TRUE); setwd(tmp)
entry <- file.path(module_dir, 'scripts', 'run_limma_camera.R')
rscript <- file.path(R.home('bin'), 'Rscript')
run_entry <- function(script, ...) { o <- suppressWarnings(system2(rscript, c(shQuote(script), ...), stdout = TRUE, stderr = TRUE)); list(status = attr(o, 'status') %||% 0L, out = o) }
run <- function(...) run_entry(entry, ...)
draft <- function(d) paste(readLines(file.path(d, 'draft', 'methods_results.md'), warn = FALSE), collapse = '\n')
has_all <- function(txt, pats) all(vapply(pats, function(p) grepl(p, txt, fixed = TRUE), logical(1)))
gtab <- function(d) utils::read.csv(file.path(d, 'tables', 'gene_set_table.csv'), stringsAsFactors = FALSE)
reg <- file.path(module_dir, 'scripts', 'calls_registry.json'); scripts <- list.files(file.path(module_dir, 'scripts'), pattern = '[.]R$', full.names = TRUE)
cc <- check_calls(scripts, reg); check(cc$ok, paste('call registry', paste(cc$problems, collapse = '; ')))
dd <- check_default_drift(reg); check(dd$ok, paste('default drift', paste(dd$problems, collapse = '; ')))
# F4: every registered value is the actual fixed literal or an explicit flag/input binding, matched at every call site.
rv <- lc_registry_value_check(scripts, reg)
check(rv$ok && rv$n_checked >= 80 && !any(grepl('"explicit"', readLines(reg), fixed = TRUE)),
      sprintf('F4 registry values/bindings match all %d call-site arguments; no "explicit" placeholder %s', rv$n_checked, paste(rv$problems, collapse = '; ')))
py <- Sys.which('python3')
if (nzchar(py)) for (tool in c('check_defaults.py', 'check_flag_docs.py', 'lint_r.py')) {
  arg <- if (tool == 'lint_r.py') file.path(module_dir, 'scripts') else module_dir
  o <- suppressWarnings(system2(py, c(shQuote(file.path(suite, 'tools', tool)), shQuote(arg)), stdout = TRUE, stderr = TRUE))
  check((attr(o, 'status') %||% 0L) == 0L, paste(tool, paste(o, collapse = ' | ')))
}

# ---- F5: routing evaluation asset, separate from the 29/30 frequency corpus ----
ev_path <- file.path(suite, 'acceptance', 'exemplars', 'limma-camera', 'routing_eval_limma_camera.jsonl')
ev <- lapply(readLines(ev_path, warn = FALSE), jsonlite::fromJSON, simplifyVector = FALSE)
lit <- file.path(suite, 'acceptance', 'exemplars', 'limma-camera', 'literature')
corp <- vapply(readLines(file.path(lit, 'corpus.jsonl'), warn = FALSE), function(l) jsonlite::fromJSON(l)$pmid, '', USE.NAMES = FALSE)
ex <- lapply(readLines(file.path(lit, 'extraction.jsonl'), warn = FALSE), jsonlite::fromJSON, simplifyVector = FALSE)
app <- Filter(function(r) identical(r$parameter, '_applies') && r$pmid %in% corp, ex)
app <- app[!duplicated(vapply(app, `[[`, '', 'pmid'))]
n_yes <- sum(vapply(app, function(r) startsWith(r$value, 'yes'), logical(1)))
ids <- vapply(ev, `[[`, '', 'id')
check(length(corp) == 30L && length(app) == 30L && n_yes == 29L, sprintf('F5: frequency corpus unchanged: %d of %d apply', n_yes, length(app)))
neg <- Filter(function(r) identical(r$polarity, 'negative'), ev); pos <- Filter(function(r) identical(r$polarity, 'positive'), ev)
check(identical(ids, c('LC-EVAL-01', 'LC-EVAL-02', 'LC-EVAL-03')) && length(neg) == 2L && length(pos) == 1L &&
        all(vapply(neg, function(r) 'limma-camera' %in% unlist(r$must_not_route_to), logical(1))) &&
        identical(pos[[1]]$expected, 'limma-camera') && identical(pos[[1]]$limma_camera_route$method, 'cameraPR') &&
        all(vapply(ev, function(r) length(strsplit(r$source_sentence, '[[:space:]]+')[[1]]) <= 25L, logical(1))) &&
        grepl('camera', ev[[1]]$source_sentence, fixed = TRUE) && !ev[[1]]$pmid %in% corp &&
        grepl('FRY', ev[[2]]$source_sentence, fixed = TRUE) && ev[[2]]$pmid %in% corp &&
        startsWith(Filter(function(r) r$pmid == ev[[2]]$pmid, app)[[1]]$value, 'no') &&
        grepl('cameraPR', ev[[3]]$source_sentence, fixed = TRUE),
      'F5: routing evaluation asset: microscope-camera and FRY-gene negatives, cameraPR positive, context sources recorded')

fix <- make_yoruba(file.path(tmp, 'fixture'), suite, adaptive_span = TRUE)
if (is.null(fix)) { cat('FAIL: locked Yoruba F10/F11 fixture absent\n'); quit(status = 1) }
fixg <- make_yoruba(file.path(tmp, 'fixture_guide_era'), suite, adaptive_span = FALSE)
check(nrow(fix$v$E) == 16918L && ncol(fix$v$E) == 86L && abs(fix$correlation - 0.4454514) < 1e-6,
      'Yoruba suite route preprocessing: 16,918 genes, 86 samples, duplicate correlation 0.4454514 (adaptive.span = TRUE)')
n_male <- sum(fix$st$gender == 'Male'); n_female <- sum(fix$st$gender == 'Female')
bad_blocks <- fix$st
bad_blocks$cellline <- paste0('one_', bad_blocks$gender)
bad_block_file <- file.path(tmp, 'one_unit_per_group.csv')
utils::write.csv(bad_blocks, bad_block_file, row.names = FALSE)
bad_block_run <- run('--input', shQuote(fix$expression), '--samples', shQuote(bad_block_file),
                     '--input-scale', 'logcpm', '--group-col', 'gender', '--reference', 'Female', '--target', 'Male',
                     '--block-col', 'cellline', '--correlation', '0.4', '--question', 'self-contained',
                     '--self-contained-method', 'fry', '--collection', 'limma_gender_genes',
                     '--outdir', shQuote(file.path(tmp, 'one_unit_refused')))
check(has_code(bad_block_run, 'OS_PSEUDOREPLICATION'), 'direct expression cannot count repeated libraries as independent units')
gg <- os_genesets_read(suite, 'limma_gender_genes')$sets

# ---- F1 printed anchor: the User's Guide's own code (usersguide.rendered.txt:7395-7500) with the guide-era voom span ----
# limma 3.66.0 changed voom's default to adaptive.span = TRUE (L1 NEWS.txt:28-39); the static guide was printed with
# span = 0.5, so adaptive.span = FALSE is written out (docs/build/S4_ANCHOR_TRACE.md). Version-matched PRINTED anchor.
y <- fixg$y; Targets <- fixg$st
design <- stats::model.matrix(~ gender + concentration, data = Targets)                                   # :7395
v <- limma::voom(y, design, adaptive.span = FALSE)                                                          # :7398
cor <- limma::duplicateCorrelation(v, design, block = Targets$cellline)                                     # :7400
check(printed_eq(cor$consensus, 0.446), sprintf('A-printed: consensus correlation round 1 %.7f = printed 0.446 (:7402)', cor$consensus))
v <- limma::voom(y, design, plot = FALSE, block = Targets$cellline, correlation = cor$consensus, adaptive.span = FALSE)  # :7406
cor <- limma::duplicateCorrelation(v, design, block = Targets$cellline)                                     # :7408
check(printed_eq(cor$consensus, 0.446), sprintf('A-printed: consensus correlation round 2 %.7f = printed 0.446 (:7410)', cor$consensus))
genv <- new.env(); load(file.path(suite, 'acceptance', 'data', 'limma_GenderGenes.RData'), envir = genv)  # :7486 (locked F11 copy of the URL)
Ymale <- v$genes$GeneID %in% genv$msYgenes; Xescape <- v$genes$GeneID %in% genv$XiEgenes                  # :7487-7488
index <- list(Y = Ymale, X = Xescape)                                                                       # :7491
cam <- limma::camera(v, index, design, 2)                                                                   # :7497
check(identical(as.integer(cam[c('Y', 'X'), 'NGenes']), c(13L, 54L)) && identical(cam[c('Y', 'X'), 'Direction'], c('Up', 'Down')) &&
        printed_eq(cam['Y', 'PValue'], 2.40e-262) && printed_eq(cam['Y', 'FDR'], 4.80e-262) &&
        printed_eq(cam['X', 'PValue'], 5.58e-26) && printed_eq(cam['X', 'FDR'], 5.58e-26),
      sprintf('A-printed camera (:7498-7500): Y 13 Up P %.6e FDR %.6e; X 54 Down P %.6e = printed 2.40e-262 / 4.80e-262 / 5.58e-26',
              cam['Y', 'PValue'], cam['Y', 'FDR'], cam['X', 'PValue']))
basep <- c('--input', shQuote(fixg$expression), '--weights', shQuote(fixg$weights), '--samples', shQuote(fixg$samples),
           '--input-scale', 'logcpm', '--group-col', 'gender', '--reference', 'Female', '--target', 'Male', '--covariates', 'concentration',
           '--collection', 'limma_gender_genes')
a1p <- file.path(tmp, 'a1_guide_era'); op <- run(basep, '--question', 'competitive', '--outdir', shQuote(a1p))
tp <- if (op$status == 0) gtab(a1p) else NULL
check(op$status == 0 && printed_eq(tp$pvalue[tp$term_id == 'Y'], 2.40e-262) && printed_eq(tp$padj[tp$term_id == 'Y'], 4.80e-262) &&
        printed_eq(tp$pvalue[tp$term_id == 'X'], 5.58e-26) && printed_eq(tp$padj[tp$term_id == 'X'], 5.58e-26) &&
        rel_eq(tp$pvalue[match(c('Y', 'X'), tp$term_id)], cam[c('Y', 'X'), 'PValue']),
      'A-printed engine: the module on the guide-era voom E + weights reproduces the printed camera row and the guide-code values')

# ---- suite route (locked 3.68.5 voom default adaptive.span = TRUE): REPLAY anchor ----
base <- c('--input', shQuote(fix$expression), '--weights', shQuote(fix$weights), '--samples', shQuote(fix$samples), '--input-scale', 'logcpm',
          '--group-col', 'gender', '--reference', 'Female', '--target', 'Male', '--covariates', 'concentration',
          '--collection', 'limma_gender_genes')
a1 <- file.path(tmp, 'a1'); o <- run(base, '--question', 'competitive', '--outdir', shQuote(a1))
check(o$status == 0, paste('Yoruba camera suite-route run', paste(tail(o$out, 1), collapse = '')))
if (o$status == 0) {
  t <- gtab(a1)
  y1 <- t[t$term_id == 'Y', ]; x1 <- t[t$term_id == 'X', ]
  check(y1$n_genes == 13L && y1$direction == 'Up' && x1$n_genes == 54L && x1$direction == 'Down', 'Y 13 Up; X 54 Down')
  check(abs(y1$pvalue / 1.79122449658387e-262 - 1) < 1e-8 && abs(x1$pvalue / 6.02018304198957e-26 - 1) < 1e-8,
        'suite-route locked replay: Y P 1.79122449658387e-262, X P 6.02018304198957e-26 (adaptive.span = TRUE)')
  direct <- limma::camera(y = fix$v$E, index = limma::ids2indices(list(Y = gg$Y, X = gg$X), rownames(fix$v$E)), design = fix$design,
    contrast = 2, weights = fix$v$weights, use.ranks = FALSE, allow.neg.cor = FALSE,
    inter.gene.cor = 0.01, trend.var = FALSE, sort = TRUE, directional = TRUE)
  check(rel_eq(c(y1$pvalue, x1$pvalue), direct[c('Y', 'X'), 'PValue']), 'independent direct camera replay matches engine')
  # F2: the final camera draft reports input scale/weights, design/contrast/replicate unit, preset correlation.
  d1 <- draft(a1); j1 <- jsonlite::fromJSON(file.path(a1, 'results', 'limma_camera_results.json'))
  check(has_all(d1, c('declared logcpm scale', 'with observation-level precision weights from --weights', 'The design was ~ gender + concentration',
                      'the tested coefficient was groupMale', 'Male versus Female', sprintf('(%d Male and %d Female samples)', n_male, n_female),
                      'independent unit (no block)', 'inter.gene.cor = 0.01 (a prespecified preset', 'use.ranks = FALSE',
                      'Direction Up means the set\'s genes tend to be higher in Male than in Female')) &&
          identical(j1$design_columns, colnames(fix$design) |> sub(pattern = '^gender', replacement = 'group')) &&
          identical(j1$weights, 'observation-level precision weights from --weights'),
        'F2 camera draft: scale, weights, design, coefficient, n per group, replicate unit, preset correlation and direction meaning')
  # S5 R3: camera tests every matched set, and the counts say so consistently.
  check(j1$n_input_sets == 2L && j1$n_matched_sets == 2L && j1$n_unmatched_sets == 0L && j1$n_selected_sets == 2L &&
          j1$n_tested_sets == 2L && j1$n_not_selected_sets == 0L && nrow(t) == 2L &&
          has_all(d1, c('supplied 2 sets; 2 overlapped the 16918 input features (0 without overlap could not be tested).',
                        'camera tested all 2 overlapping sets.', 'Of 2 tested gene sets,')),
        'S5-R3 camera: collection 2, matched 2, selected 2, tested 2 in JSON, table and draft')
  dz <- utils::read.csv(file.path(a1, 'tables', 'design.csv'), check.names = FALSE)
  check(max(abs(as.matrix(dz[, -1]) - unname(fix$design))) == 0 && identical(dz$sample, fix$st$sample), 'F2: the design actually used is saved (tables/design.csv)')
  # F3: barcode with worm and set-highlight MD, legends/axis titles (PNG looked at separately).
  sp <- jsonlite::fromJSON(file.path(a1, 'figures', 'gene_set_bar.figure_spec.json'))
  bc <- jsonlite::fromJSON(file.path(a1, 'figures', 'barcode_1.figure_spec.json'))
  md <- jsonlite::fromJSON(file.path(a1, 'figures', 'md_set_highlight.figure_spec.json'))
  check(grepl('2 of 2', sp$caption, fixed = TRUE) && grepl('0.05', sp$caption, fixed = TRUE), 'figure caption states n and BH threshold')
  check(file.exists(file.path(a1, 'figures', 'barcode_2.png')) && grepl('relative enrichment worm', bc$caption, fixed = TRUE) &&
          grepl('13 set members', bc$caption, fixed = TRUE) && grepl('16918 features ranked by moderated t', bc$caption, fixed = TRUE) &&
          grepl('Y (n = 13), X (n = 54)', md$caption, fixed = TRUE) && grepl('## Figure legends', d1, fixed = TRUE),
        'F3: barcode (with worm) for Y and X and MD plot with Y/X highlighted, captions with n; legends in the draft')
  check(identical(read_handoff(a1, expect = list(expression_matrix = 'expression_matrix', gene_sets = 'gene_sets'))$module, 'limma-camera'), 'typed handoff readable')
  gold_paths <- c('tables/gene_set_table.csv', 'tables/gene_set_selection.csv', 'tables/method_raw.csv', 'tables/design.csv', 'results/limma_camera_results.json',
                  'figures/gene_set_bar.png', 'figures/gene_set_bar.figure_spec.json', 'figures/barcode_1.png',
                  'figures/barcode_1.figure_spec.json', 'figures/md_set_highlight.png')
  if (Sys.getenv('OMICSTAT_WRITE_GOLDEN') == '1') os_golden_write(module_dir, a1, gold_paths)
  gc <- os_golden_check(module_dir, a1)
  check(gc$status %in% c('PASS', 'SKIP'), paste('golden', gc$status, paste(gc$problems, collapse = ',')))
  if (length(readLines(file.path(module_dir, 'tests', 'golden_manifest.csv'))) > 1) check(gc$status == 'PASS', 'same-signature golden byte hashes')
  a2 <- file.path(tmp, 'a2'); o2 <- run('--spec', shQuote(file.path(a1, 'provenance', 'resolved_spec.json')), '--outdir', shQuote(a2))
  check(o2$status == 0 && sha(file.path(a1, 'tables', 'gene_set_table.csv')) == sha(file.path(a2, 'tables', 'gene_set_table.csv')) &&
        sha(file.path(a1, 'figures', 'gene_set_bar.png')) == sha(file.path(a2, 'figures', 'gene_set_bar.png')) &&
        sha(file.path(a1, 'figures', 'barcode_1.png')) == sha(file.path(a2, 'figures', 'barcode_1.png')), 'spec replay byte-identical table and PNGs')
  up <- file.path(tmp, 'upstream'); dir.create(file.path(up, 'objects'), recursive = TRUE)
  file.copy(fix$expression, file.path(up, 'objects', 'expression.csv')); file.copy(fix$samples, file.path(up, 'objects', 'samples.csv'))
  write_handoff(up, run_id = 'upstream', module = 'fixture', module_version = '1.0.0', objects = list(
    expression_matrix = list(path = file.path(up, 'objects', 'expression.csv'), type = 'expression_matrix'),
    sample_table = list(path = file.path(up, 'objects', 'samples.csv'), type = 'sample_table')))
  of <- run('--from-run', shQuote(up), '--weights', shQuote(fix$weights), '--input-scale', 'logcpm', '--group-col', 'gender', '--reference', 'Female', '--target', 'Male', '--covariates', 'concentration', '--collection', 'limma_gender_genes', '--question', 'competitive', '--outdir', shQuote(file.path(tmp, 'fromrun')))
  check(of$status == 0 && sha(file.path(a1, 'tables', 'gene_set_table.csv')) == sha(file.path(tmp, 'fromrun', 'tables', 'gene_set_table.csv')), 'from-run expression and sample handoff')
  write('tamper', file.path(up, 'objects', 'expression.csv'), append = TRUE)
  ot <- run('--from-run', shQuote(up), '--input-scale', 'logcpm', '--group-col', 'gender', '--reference', 'Female', '--target', 'Male', '--question', 'competitive', '--collection', 'limma_gender_genes', '--outdir', shQuote(file.path(tmp, 'tamper')))
  check(has_code(ot, 'OS_HANDOFF_MISMATCH'), 'tampered handoff refused')
}
e0 <- run(base[-(which(base == '--input-scale') + 0:1)], '--question', 'competitive', '--outdir', shQuote(file.path(tmp, 'no_scale')))
check(has_code(e0, 'OS_MISSING_PARAMETER'), 'F2: expression input without --input-scale refused')

m <- run(base, '--question', 'self-contained', '--self-contained-method', 'mroast', '--block-col', 'cellline', '--correlation', as.character(fix$correlation), '--outdir', shQuote(file.path(tmp, 'mroast')))
mt <- if (m$status == 0) gtab(file.path(tmp, 'mroast')) else NULL
check(m$status == 0 && all(mt$pvalue == 1e-04) && setequal(mt$direction, c('Up', 'Down')), 'guide mroast 9999 anchor: Y/X P=1e-04, Up/Down')
if (m$status == 0) check(has_all(draft(file.path(tmp, 'mroast')), c(sprintf('block cellline (%d blocks) with within-block correlation %s (prespecified with --correlation)',
                                                                          length(unique(fix$st$cellline)), format(signif(fix$correlation, 6))),
                                                                  'set.statistic = "mean", nrot = 9999', 'midp = TRUE', 'adjust.method = "BH"', 'the tested coefficient was groupMale')) &&
                           file.exists(file.path(tmp, 'mroast', 'figures', 'md_set_highlight.png')),
                         'F2 mroast draft: block, correlation and its source, rotation settings, design; F3 figures')
f <- run(base, '--question', 'self-contained', '--self-contained-method', 'fry', '--block-col', 'cellline', '--correlation', as.character(fix$correlation), '--outdir', shQuote(file.path(tmp, 'fry')))
check(f$status == 0 && nrow(gtab(file.path(tmp, 'fry'))) == 2L &&
        has_all(draft(file.path(tmp, 'fry')), c('standardize = "posterior.sd"', 'block cellline', 'with observation-level precision weights')),
      'fry self-contained route; F2 draft names fry settings, block and weights')
r <- run(base, '--question', 'self-contained', '--self-contained-method', 'roast', '--set-id', 'Y', '--block-col', 'cellline', '--correlation', as.character(fix$correlation), '--nrot', '1999', '--outdir', shQuote(file.path(tmp, 'roast')))
rq <- if (r$status == 0) utils::read.csv(file.path(tmp, 'roast', 'qc', 'qc_results.csv')) else NULL
check(r$status == 0 && any(rq$id == 'LC-04' & rq$triggered == 'TRUE') &&
        has_all(draft(file.path(tmp, 'roast')), c('roast tested the single prespecified set Y', 'nrot = 1999', 'Development-only')) &&
        file.exists(file.path(tmp, 'roast', 'figures', 'barcode_1.png')) && !file.exists(file.path(tmp, 'roast', 'figures', 'barcode_2.png')),
      'roast development route flagged; F2 draft; F3 one barcode for the one set')
# S5 R3 regression: the collection holds Y and X, both overlap the input, roast is
# asked for Y only -> exactly one set is tested; X is neither "tested" nor "without overlap".
if (r$status == 0) {
  rd <- draft(file.path(tmp, 'roast')); rt <- gtab(file.path(tmp, 'roast'))
  rj <- jsonlite::fromJSON(file.path(tmp, 'roast', 'results', 'limma_camera_results.json'))
  rb <- jsonlite::fromJSON(file.path(tmp, 'roast', 'figures', 'gene_set_bar.figure_spec.json'))
  rm_ <- jsonlite::fromJSON(file.path(tmp, 'roast', 'figures', 'md_set_highlight.figure_spec.json'))
  check(identical(rt$term_id, 'Y') && rt$n_genes == 13L &&
          rj$n_input_sets == 2L && rj$n_matched_sets == 2L && rj$n_unmatched_sets == 0L && rj$n_selected_sets == 1L &&
          rj$n_tested_sets == 1L && rj$n_not_selected_sets == 1L &&
          has_all(rd, c('supplied 2 sets; 2 overlapped the 16918 input features (0 without overlap could not be tested).',
                        'roast was run on the one set selected with --set-id (Y), so 1 set was tested; the other 1 overlapping set (X) was not selected and was not tested.',
                        'Of 1 tested gene set,', '1 of 1 tested sets shown')) &&
          !grepl('Of 2 tested', rd, fixed = TRUE) && !grepl('were tested', rd, fixed = TRUE) &&
          grepl('1 of 1 tested sets shown', rb$caption, fixed = TRUE) && grepl('Y (n = 13)', rm_$caption, fixed = TRUE) &&
          !grepl('X (n = 54)', rm_$caption, fixed = TRUE),
        sprintf('S5-R3 single roast with Y and X in the collection: only Y tested (table %d row, JSON matched %d / selected %d / tested %d), X reported as not selected',
                nrow(rt), rj$n_matched_sets, rj$n_selected_sets, rj$n_tested_sets))
}
rank <- file.path(tmp, 'ranked.csv'); scores <- rowMeans(fix$v$E[, fix$st$gender == 'Male', drop = FALSE]) - rowMeans(fix$v$E[, fix$st$gender == 'Female', drop = FALSE]); ord <- order(-scores, names(scores), method = 'radix')
utils::write.csv(data.frame(feature_id = names(scores)[ord], symbol = '', score = unname(scores[ord])), rank, row.names = FALSE)
pr <- run('--ranked-list', shQuote(rank), '--question', 'competitive', '--direction', shQuote('higher mean log2 CPM in Male than in Female'), '--rank-metric', 'other', '--metric-name', 'mean_difference', '--collection', 'limma_gender_genes', '--outdir', shQuote(file.path(tmp, 'cameraPR')))
check(pr$status == 0 && jsonlite::fromJSON(file.path(tmp, 'cameraPR', 'results', 'limma_camera_results.json'))$method == 'cameraPR', 'rank-only cameraPR route')
if (pr$status == 0) {
  dp <- draft(file.path(tmp, 'cameraPR'))
  check(has_all(dp, c('ranked by the mean_difference', 'a positive score means higher mean log2 CPM in Male than in Female',
                      'cameraPR used inter.gene.cor = 0.01', 'shifted toward the positive end of the ranking',
                      'of the user-declared contrast', 'a negative score means the opposite direction')) &&
          !grepl('not applicable', dp, fixed = TRUE) && !grepl('opposite of:', dp, fixed = TRUE) &&
          file.exists(file.path(tmp, 'cameraPR', 'figures', 'barcode_1.png')) && !file.exists(file.path(tmp, 'cameraPR', 'figures', 'md_set_highlight.png')),
        'F2 cameraPR draft: ranking name and direction, no "not applicable"; F3 barcode from the ranking, no MD (no expression)')
  tpr <- gtab(file.path(tmp, 'cameraPR'))
  zero <- tpr$term_id[tpr$padj == 0]
  check(length(zero) >= 1L && grepl(sprintf('(%s) had a P value below double precision', paste(zero, collapse = ', ')), dp, fixed = TRUE) &&
          !grepl('BH adjusted P = 0;', dp, fixed = TRUE) && grepl('BH adjusted P < 2.23e-308 (below double precision', dp, fixed = TRUE),
        sprintf('cameraPR: underflowed P (%s returned as 0 by limma) reported as P < 2.23e-308, never "P = 0"', paste(zero, collapse = ', ')))
}
e <- run('--ranked-list', shQuote(rank), '--question', 'self-contained', '--self-contained-method', 'fry', '--direction', shQuote('positive means Male higher'), '--collection', 'limma_gender_genes', '--outdir', shQuote(file.path(tmp, 'bad_rank')))
check(has_code(e, 'OS_UNSUPPORTED_DESIGN'), 'rank-only self-contained test refused')
e2 <- run(base, '--question', 'competitive', '--nrot', '9999', '--outdir', shQuote(file.path(tmp, 'bad_nrot')))
check(has_code(e2, 'OS_CONFLICTING_PARAMETERS'), 'nrot on camera refused')
e3 <- run(base[-c(length(base) - 1L, length(base))], '--question', 'competitive', '--outdir', shQuote(file.path(tmp, 'bad_ref')))
check(has_code(e3, 'OS_REFDATA_MISSING'), 'unresolved Hallmark collection refused')

# ---- contract c: corrected data and corrected lineage are refused ----
cu <- file.path(tmp, 'corrected_up'); dir.create(file.path(cu, 'objects'), recursive = TRUE)
invisible(file.copy(fix$expression, file.path(cu, 'objects', 'expression.csv'))); invisible(file.copy(fix$samples, file.path(cu, 'objects', 'samples.csv')))
write_handoff(cu, run_id = 'lineage', module = 'gsva-score', module_version = 'fixture', state = list(batch_corrected_lineage = TRUE), objects = list(
  expression_matrix = list(path = file.path(cu, 'objects', 'expression.csv'), type = 'expression_matrix'),
  sample_table = list(path = file.path(cu, 'objects', 'samples.csv'), type = 'sample_table')))
oc <- run('--from-run', shQuote(cu), '--input-scale', 'logcpm', '--group-col', 'gender', '--reference', 'Female', '--target', 'Male', '--question', 'competitive', '--collection', 'limma_gender_genes', '--outdir', shQuote(file.path(tmp, 'lineage_out')))
check(has_code(oc, 'OS_BATCH_CORRECTED_INPUT'), 'contract c: an object of a batch-corrected lineage is refused (OS_BATCH_CORRECTED_INPUT)')

# ---- contract b: REAL limma-voom and limma-dupcor upstream runs ----
vr <- file.path(tmp, 'voom_run')
ov <- run_entry(file.path(suite, 'skills', 'limma-voom', 'scripts', 'run_limma_voom.R'), '--counts', shQuote(fix$counts), '--samples', shQuote(fix$samples),
                '--condition', 'gender', '--reference', 'Female', '--target', 'Male', '--covariates', 'concentration', '--outdir', shQuote(vr))
check(ov$status == 0, paste('contract b: real limma-voom upstream run', paste(tail(ov$out, 1), collapse = '')))
if (ov$status == 0) {
  el <- readRDS(file.path(vr, 'objects', 'elist.rds')); vfit <- readRDS(file.path(vr, 'objects', 'fit.rds'))
  coef <- jsonlite::fromJSON(file.path(vr, 'objects', 'handoff.json'))$state$coefficient
  cv <- file.path(tmp, 'camera_voom'); ocv <- run('--from-run', shQuote(vr), '--question', 'competitive', '--collection', 'limma_gender_genes', '--outdir', shQuote(cv))
  check(ocv$status == 0, paste('contract b: camera consumes the limma-voom hand-off', paste(tail(ocv$out, 2), collapse = ' ')))
  if (ocv$status == 0) {
    tv <- gtab(cv)
    ix <- limma::ids2indices(list(X = gg$X, Y = gg$Y), rownames(el$E))
    dv <- limma::camera(y = el$E, index = ix, design = vfit$design, contrast = which(colnames(vfit$design) == coef), weights = el$weights,
                        use.ranks = FALSE, allow.neg.cor = FALSE, inter.gene.cor = 0.01, trend.var = FALSE, sort = TRUE, directional = TRUE)
    dv2 <- limma::camera(el, ix, vfit$design, which(colnames(vfit$design) == coef))
    check(!is.null(el$weights) && rel_eq(tv$pvalue[match(rownames(dv), tv$term_id)], dv$PValue, 1e-12) &&
            rel_eq(dv2[rownames(dv), 'PValue'], dv$PValue, 1e-12),
          'contract b: camera on the EList E + weights with the fitted design and recorded coefficient equals camera(EList, index, design, coef)')
    d <- draft(cv); jv <- jsonlite::fromJSON(file.path(cv, 'results', 'limma_camera_results.json'))
    check(has_all(d, c('The input was the EList handed on by limma-voom', 'voom log2 counts per million', 'with its observation-level precision weights',
                       'the upstream design and coefficient unchanged', 'The design was ~concentration + gender (the fitted design of limma-voom run voom_run',
                       sprintf('tested coefficient was %s', coef), 'Male versus Female')) &&
            identical(jv$design_columns, colnames(vfit$design)) && identical(jv$contrast, coef) &&
            file.exists(file.path(cv, 'figures', 'md_set_highlight.png')) && grepl('upstream limma-voom fit', jv$display_statistic, fixed = TRUE),
          'contract b / F2: Methods name the EList, its scale and weights, the fitted design and coefficient; F3 figures from the upstream fit')
  }
  e4 <- run('--from-run', shQuote(vr), '--question', 'competitive', '--covariates', 'concentration', '--collection', 'limma_gender_genes', '--outdir', shQuote(file.path(tmp, 'voom_clash')))
  e5 <- run('--from-run', shQuote(vr), '--question', 'competitive', '--reference', 'Male', '--target', 'Female', '--collection', 'limma_gender_genes', '--outdir', shQuote(file.path(tmp, 'voom_clash2')))
  check(has_code(e4, 'OS_CONFLICTING_PARAMETERS') && has_code(e5, 'OS_CONFLICTING_PARAMETERS'), 'contract b: no silent rebuild of a different design (covariates / contrast conflicts refused)')
  prv <- file.path(tmp, 'cameraPR_voom')
  opr <- run('--from-run', shQuote(vr), '--upstream-object', 'ranked_list', '--question', 'competitive', '--collection', 'limma_gender_genes', '--outdir', shQuote(prv))
  check(opr$status == 0 && has_all(draft(prv), c('ranked by the limma moderated t-statistic of the gender: Male vs Female contrast from limma-voom',
                                                  'a positive score means higher expression in Male than in Female')),
        'cameraPR consumes the real limma-voom ranked_list metadata (metric, contrast, direction)')
  if (opr$status == 0) check(grepl('features ranked by moderated t (grey area)', jsonlite::fromJSON(file.path(prv, 'figures', 'barcode_1.figure_spec.json'))$caption, fixed = TRUE),
                             'F3: cameraPR barcode axis uses the short statistic name (the long metric name overlapped the panel tag)')
  e6 <- run('--from-run', shQuote(vr), '--upstream-object', 'ranked_list', '--question', 'competitive', '--direction', 'x', '--collection', 'limma_gender_genes', '--outdir', shQuote(file.path(tmp, 'pr_clash')))
  check(has_code(e6, 'OS_CONFLICTING_PARAMETERS'), 'cameraPR: a --direction that would override the ranked_list metadata is refused')
}
dr <- file.path(tmp, 'dupcor_run')
od <- run_entry(file.path(suite, 'skills', 'limma-dupcor', 'scripts', 'run_limma_dupcor.R'), '--mode', 'rna', '--counts', shQuote(fix$counts), '--samples', shQuote(fix$samples),
                '--condition', 'gender', '--reference', 'Female', '--target', 'Male', '--covariates', 'concentration', '--block', 'cellline',
                '--block-description', shQuote('HapMap cell line (individual)'), '--outdir', shQuote(dr))
check(od$status == 0, paste('contract b: real limma-dupcor upstream run', paste(tail(od$out, 1), collapse = '')))
if (od$status == 0) {
  hs <- jsonlite::fromJSON(file.path(dr, 'objects', 'handoff.json'))$state
  e7 <- run('--from-run', shQuote(dr), '--question', 'competitive', '--collection', 'limma_gender_genes', '--outdir', shQuote(file.path(tmp, 'camera_dupcor_refused')))
  check(has_code(e7, 'OS_UNSUPPORTED_DESIGN'), 'contract b: camera on a limma-dupcor upstream (block) refused without acknowledgement')
  ca <- file.path(tmp, 'camera_dupcor_ack')
  oa <- run('--from-run', shQuote(dr), '--question', 'competitive', '--acknowledge-block-ignored', '--collection', 'limma_gender_genes', '--outdir', shQuote(ca))
  qa <- if (oa$status == 0) utils::read.csv(file.path(ca, 'qc', 'qc_results.csv')) else NULL
  check(oa$status == 0 && any(qa$id == 'LC-06' & qa$triggered == 'TRUE') &&
          has_all(draft(ca), c('camera has no block argument', 'acknowledged with --acknowledge-block-ignored', sprintf('block %s', hs$block$column))),
        'contract b: acknowledged camera on a dupcor upstream runs, flags LC-06 and states the unmodelled block')
  fd <- file.path(tmp, 'fry_dupcor')
  of2 <- run('--from-run', shQuote(dr), '--question', 'self-contained', '--self-contained-method', 'fry', '--collection', 'limma_gender_genes', '--outdir', shQuote(fd))
  check(of2$status == 0, paste('contract b: fry consumes the limma-dupcor hand-off with its block', paste(tail(of2$out, 2), collapse = ' ')))
  if (of2$status == 0) {
    el2 <- readRDS(file.path(dr, 'objects', 'elist.rds')); dfit <- readRDS(file.path(dr, 'objects', 'fit.rds'))
    st2 <- utils::read.csv(file.path(dr, 'objects', 'sample_table.csv'), stringsAsFactors = FALSE)
    ix2 <- limma::ids2indices(list(X = gg$X, Y = gg$Y), rownames(el2$E))
    df2 <- limma::fry(y = el2$E, index = ix2, design = dfit$design, contrast = which(colnames(dfit$design) == hs$coefficient), geneid = NULL,
                      gene.weights = NULL, standardize = 'posterior.sd', sort = 'directional', block = st2[[hs$block$column]],
                      correlation = hs$block$consensus_correlation, weights = el2$weights)
    tf <- gtab(fd)
    check(rel_eq(tf$pvalue[match(rownames(df2), tf$term_id)], df2$PValue, 1e-12) &&
            has_all(draft(fd), c(sprintf('block %s (%d blocks) with within-block correlation %s (consensus correlation estimated by limma-dupcor run dupcor_run)',
                                         hs$block$column, hs$block$n_blocks, format(signif(hs$block$consensus_correlation, 6))), 'The input was the EList handed on by limma-dupcor')),
          'contract b: fry uses the upstream block and consensus correlation (equals a direct fry) and says so')
  }
}

# ---- user-supplied gene sets: --collection user (CONVENTIONS "User-supplied gene-set collections") ----
source(file.path(suite, 'skills', '_shared', 'scripts', 'user_genesets.R'))
source(file.path(suite, 'skills', '_shared', 'tests', 'user_genesets_testkit.R'))
rz <- function(...) { o <- run(...); structure(o$out, status = o$status) }
fid <- rownames(fix$v$E)
idt <- if (all(grepl('^[0-9]+$', fid))) 'ENTREZID' else if (all(grepl('^ENS[A-Z]*G[0-9]+$', fid))) 'ENSEMBL' else 'SYMBOL'
low_fn <- switch(idt, ENTREZID = function(i) as.character(990000000 + i), ENSEMBL = function(i) sprintf('ENSG99%09d', i), function(i) paste0('ZZFAKE', i))
ugs_sets <- ugs_kegg_like_sets(fid[1:300], fid[-(1:300)])
ugs <- ugs_fixture(file.path(tmp, 'user_sets'), ugs_sets, idt, lowfn = low_fn)
ubase <- c(base[seq_len(length(base) - 2L)], '--question', 'competitive', '--collection', 'user', '--gene-sets', shQuote(ugs$gmt), '--feature-id-type', idt)
cu <- file.path(tmp, 'user_anchor')
o <- run(ubase, '--gene-sets-provenance', shQuote(ugs$prov), '--outdir', shQuote(cu))
check(o$status == 0, paste('user: user GMT camera run', paste(tail(o$out, 2), collapse = ' | ')))
if (o$status == 0) {
  ut <- gtab(cu)
  ud <- limma::camera(y = fix$v$E, index = limma::ids2indices(ugs_sets, rownames(fix$v$E)), design = fix$design,
    contrast = 2, weights = fix$v$weights, use.ranks = FALSE, allow.neg.cor = FALSE,
    inter.gene.cor = 0.01, trend.var = FALSE, sort = TRUE, directional = TRUE)
  check(setequal(ut$term_id, rownames(ud)) && rel_eq(ut$pvalue, ud[ut$term_id, 'PValue']) && all(c('hsa04110', 'KEGG_APOPTOSIS') %in% ut$term_id),
        sprintf('user: camera P values equal a direct limma::camera call on the user sets (%d sets, KEGG-style IDs)', nrow(ud)))
  ugs_check_recorded(check, cu, 'user camera', length(ugs_sets))
}
ugs_refused(check, rz(ubase[-length(ubase)], if (idt == 'SYMBOL') 'ENTREZID' else 'SYMBOL', '--gene-sets-provenance', shQuote(ugs$prov),
                      '--outdir', shQuote(file.path(tmp, 'user_idtype'))), 'OS_GENE_SET_ID_MISMATCH', 'user: gene-set ID type vs --feature-id-type')
ugs_refused(check, rz(ubase, '--gene-sets-provenance', shQuote(ugs$bad_sha), '--outdir', shQuote(file.path(tmp, 'user_sha'))),
            'OS_REFDATA_MISMATCH', 'user: sha256 differing from provenance')
ugs_refused(check, rz(ubase[seq_len(length(ubase) - 4L)], '--gene-sets', shQuote(ugs$low), '--gene-sets-provenance', shQuote(ugs$low_prov),
                      '--feature-id-type', idt, '--outdir', shQuote(file.path(tmp, 'user_low'))), 'OS_GENE_SET_LOW_OVERLAP', 'user: under 10% overlap with the matrix')
check(!file.exists(file.path(tmp, 'Rplots.pdf')), 'no Rplots.pdf device leak')

# R3 selection ledger: no-overlap, not-selected and tested are distinct states.
if (r$status == 0) {
  roast_draft <- draft(file.path(tmp,"roast"))
  check(grepl("raw UpOrDown P",roast_draft,fixed=TRUE) && !grepl("BH adjusted P",roast_draft,fixed=TRUE), "single-set roast reports raw P without claiming adjustment")
  for (id in c('gene_set_bar', 'barcode_1')) {
    fig <- jsonlite::fromJSON(file.path(tmp, 'roast', 'figures', paste0(id, '.figure_spec.json')))
    check(grepl('raw UpOrDown P', fig$caption, fixed=TRUE) && !grepl('adjusted P', fig$caption, fixed=TRUE),
          paste('single-set roast saved figure caption reports raw P:', id))
    if (id == 'gene_set_bar') check(identical(fig$thresholds$pvalue, 0.05) && is.null(fig$thresholds$padj),
                                   'single-set roast figure threshold is raw P')
  }
  ledger <- utils::read.csv(file.path(tmp, "roast", "tables", "gene_set_selection.csv"), stringsAsFactors = FALSE)
  check(nrow(ledger) == 2L && sum(ledger$matched) == 2L &&
        sum(ledger$selected) == 1L && sum(ledger$tested) == 1L &&
        identical(ledger$status[ledger$term_id == "X"], "not_selected") &&
        identical(ledger$status[ledger$term_id == "Y"], "tested"),
        "R3 selection ledger agrees with the result table and JSON")
}
if (length(failures)) quit(status = 1) else cat('SMOKE PASSED\n')
