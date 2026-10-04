# run_smoke_test.R -- module sva-batch. ASCII only on purpose.
# requires: sva limma Biobase BiocParallel bladderbatch zebrafishRNASeq ggplot2 ggrepel patchwork ragg svglite jsonlite digest
# Checks (ENGINEERING_PLAN 7.2 S2): anchors (PACK C: printed values where they
# reproduce, replay anchors where a historical vignette number does not --
# see references/method-basis.md), flag effectiveness, typed errors and
# blockers, call-registry consistency, default drift, default consistency,
# flag-doc coverage, lint, determinism, --spec replay, --from-run chaining
# (incl. the P-1 cross-module refusal via deseq2-wald), golden baseline, no
# Rplots.pdf. OMICSTAT_WRITE_GOLDEN=1 rewrites tests/golden_manifest.csv.
here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])))
module_dir <- dirname(here)
suite <- normalizePath(file.path(module_dir, "..", ".."))
shared <- file.path(suite, "skills", "_shared", "scripts")
source(file.path(shared, "calls_check.R"))
source(file.path(shared, "module_kit.R"))
source(file.path(shared, "handoff.R"))
source(file.path(here, "fixtures", "make_bladderbatch.R"))
source(file.path(here, "fixtures", "make_zfgenes.R"))
source(file.path(here, "fixtures", "make_combat_seq_sim.R"))
suppressMessages({ library(sva); library(limma) })
have_bcp <- requireNamespace("BiocParallel", quietly = TRUE)
failures <- character(0)
check <- function(cond, msg) { if (isTRUE(cond)) cat("PASS:", msg, "\n") else { cat("FAIL:", msg, "\n"); failures <<- c(failures, msg) } }
near <- function(a, b, tol = 1e-6) isTRUE(all(abs(a - b) <= tol * pmax(1, abs(b))))
# Documented KNOWN FAILING anchor (strict assertion kept; evidence in
# acceptance/exemplars/sva-batch/S4_FIXES.md "Known failing anchors"): a
# failure prints a KNOWN-FAILING ANCHOR line and is listed at the end; a pass
# prints PASS plus a note that the record must be updated.
known_failing <- character(0)
check_known_failing <- function(cond, msg) {
  if (isTRUE(cond)) cat("PASS:", msg, "(documented as KNOWN FAILING in S4_FIXES.md -- it now passes; update the record)\n")
  else { cat("KNOWN-FAILING ANCHOR:", msg, "\n"); known_failing <<- c(known_failing, msg) }
}
# Printed-precision comparison: a value printed as "-13.45607" or
# "1.207560e-69" must lie within half a unit of its last printed digit.
printed_tol <- function(s) {
  mant <- sub("[eE].*$", "", s)
  ex <- if (grepl("[eE]", s)) as.numeric(sub("^.*[eE]", "", s)) else 0
  dec <- if (grepl(".", mant, fixed = TRUE)) nchar(sub("^[^.]*[.]", "", mant)) else 0
  0.5 * 10^(-dec) * 10^ex
}
matches_printed <- function(x, s) length(x) == 1L && is.finite(x) && abs(x - as.numeric(s)) <= printed_tol(s) * (1 + 1e-9)
sorted_factor <- function(v) factor(as.character(v), levels = sort(unique(as.character(v)), method = "radix"))

tmp <- file.path(Sys.getenv("OMICSTAT_TEST_TMP", tempdir()), "sva-batch-smoke")
unlink(tmp, recursive = TRUE); dir.create(tmp, recursive = TRUE)
old_wd <- setwd(tmp)   # cwd independence: never run from the module directory
entry <- file.path(module_dir, "scripts", "run_sva_batch.R")
rscript <- file.path(R.home("bin"), "Rscript")
run <- function(...) {
  out <- suppressWarnings(system2(rscript, c(shQuote(entry), ...), stdout = TRUE, stderr = TRUE))
  list(status = attr(out, "status") %||% 0L, out = out)
}
res_json <- function(d) jsonlite::fromJSON(file.path(d, "results", "sva_batch_results.json"))
sha <- function(p) digest::digest(file = p, algo = "sha256")
read_mat <- function(p) os_read_matrix(p, "test matrix")

# ---- static checks ------------------------------------------------------------
scripts <- list.files(file.path(module_dir, "scripts"), pattern = "[.]R$", full.names = TRUE)
reg <- file.path(module_dir, "scripts", "calls_registry.json")
cc <- check_calls(scripts, reg)
check(cc$ok, paste("call registry consistent", paste(cc$problems, collapse = "; ")))
dd <- check_default_drift(reg)
check(dd$ok, paste("no default drift", paste(dd$problems, collapse = "; ")))
py <- Sys.which("python3")
tools_dir <- file.path(suite, "tools")
if (nzchar(py)) {
  for (tool in c("check_defaults.py", "check_flag_docs.py")) {
    o <- suppressWarnings(system2(py, c(shQuote(file.path(tools_dir, tool)), shQuote(module_dir)), stdout = TRUE, stderr = TRUE))
    check((attr(o, "status") %||% 0L) == 0L, paste(tool, paste(o, collapse = " | ")))
  }
  o <- suppressWarnings(system2(py, c(shQuote(file.path(tools_dir, "lint_r.py")), shQuote(file.path(module_dir, "scripts"))), stdout = TRUE, stderr = TRUE))
  check((attr(o, "status") %||% 0L) == 0L, paste("engine hygiene lint", paste(o, collapse = " | ")))
} else cat("SKIP: check_defaults.py / check_flag_docs.py / lint_r.py need python3\n")

# ================================================================================
# A: anchors
# ================================================================================
bb <- make_bladderbatch(file.path(tmp, "bladderbatch"), suite)
if (is.null(bb)) {
  cat("SKIP: bladderbatch not in the acceptance data layer (A1-A3)\n")
} else {
  bsamples <- utils::read.csv(bb$samples, stringsAsFactors = FALSE)
  raw_mat <- read_mat(bb$exprs)

  # ---- A1: ComBat on bladderbatch (known batch = batch, protected = cancer) ----
  a1 <- file.path(tmp, "a1")
  r <- run("--input", shQuote(bb$exprs), "--samples", shQuote(bb$samples), "--method", "combat",
          "--batch", "batch", "--study-var", "cancer", "--outdir", shQuote(a1))
  check(r$status == 0, paste("A1 bladderbatch ComBat run exits 0", paste(utils::tail(r$out, 3), collapse = " | ")))
  if (r$status == 0) {
    j <- res_json(a1)
    btab <- table(bsamples$batch, bsamples$cancer)
    n_empty <- sum(btab == 0)
    check(identical(j$confounding_status, if (n_empty > 0) "partial" else "ok") && isTRUE(j$joint_design$study_estimable) &&
            identical(as.integer(j$joint_design$empty_batch_study_cells), as.integer(n_empty)),
          sprintf(paste0("A1 joint design check: bladderbatch batch x cancer has %d empty cell(s) (%s) -> status %s with every cancer ",
                         "coefficient checked estimable (%s)"), n_empty, paste(apply(btab, 1, paste, collapse = "/"), collapse = "; "),
                  j$confounding_status, j$joint_design$estimability_check))
    eng <- read_mat(file.path(a1, "tables", "corrected_matrix.csv"))
    batch_f <- sorted_factor(bsamples$batch); study_f <- sorted_factor(bsamples$cancer)
    mod <- stats::model.matrix(~study_f)
    # F4 oracle: capture ComBat's OWN internal gamma.hat / delta.hat /
    # gamma.bar / t2 / a.prior / b.prior from the function frame at exit
    # (trace(), test session only; the engine never calls sva internals).
    cb_int <- new.env()
    suppressMessages(trace("ComBat", where = asNamespace("sva"), print = FALSE,
                           exit = substitute(for (nm in c("gamma.hat", "delta.hat", "gamma.bar", "t2", "a.prior", "b.prior", "gamma.star", "delta.star"))
                             assign(nm, get(nm), envir = E), list(E = cb_int))))
    direct <- if (have_bcp) {
      sva::ComBat(dat = raw_mat, batch = batch_f, mod = mod, par.prior = TRUE, prior.plots = FALSE,
                 mean.only = FALSE, ref.batch = NULL, BPPARAM = BiocParallel::SerialParam())
    } else NULL
    suppressMessages(untrace("ComBat", where = asNamespace("sva")))
    # ---- A1 F4: PACK F ComBat prior diagnostic ------------------------------
    check(all(file.exists(file.path(a1, "figures", paste0("combat_prior.", c("pdf", "png", "figure_spec.json"))))) &&
            file.exists(file.path(a1, "tables", "combat_prior.csv")), "A1 F4 figures/combat_prior.{pdf,png,figure_spec.json} and tables/combat_prior.csv written on the parametric ComBat path")
    if (exists("gamma.hat", envir = cb_int, inherits = FALSE)) {
      source(file.path(module_dir, "scripts", "sva_batch_core.R"), local = (mod_env <- new.env()))
      pd <- mod_env$sb_combat_prior(raw_mat, batch_f, mod)
      check(identical(dim(pd$gamma.hat), dim(cb_int$gamma.hat)) && near(pd$gamma.hat, cb_int$gamma.hat, 1e-10) && near(pd$delta.hat, cb_int$delta.hat, 1e-10),
            sprintf("A1 F4 module gamma.hat / delta.hat (%d batches x %d features) equal ComBat's own internals captured by trace() (max |diff| %.2e / %.2e)",
                    nrow(pd$gamma.hat), ncol(pd$gamma.hat), max(abs(pd$gamma.hat - cb_int$gamma.hat)), max(abs(pd$delta.hat - cb_int$delta.hat))))
      check(near(pd$gamma.bar, cb_int$gamma.bar, 1e-10) && near(pd$t2, cb_int$t2, 1e-10) && near(pd$a.prior, cb_int$a.prior, 1e-10) && near(pd$b.prior, cb_int$b.prior, 1e-10),
            sprintf("A1 F4 module hyper-parameters equal ComBat's internals: gamma.bar, t2, a.prior (%s), b.prior (%s)",
                    paste(signif(cb_int$a.prior, 6), collapse = "/"), paste(signif(cb_int$b.prior, 6), collapse = "/")))
      # Reproduce ComBat's adjusted matrix from the module's own estimates,
      # with sva's own posterior solver (sva:::it.sol) and ComBat's back-transformation.
      gs <- ds <- matrix(NA_real_, nrow(pd$gamma.hat), ncol(pd$gamma.hat))
      for (i in seq_len(nrow(pd$gamma.hat))) {
        sol <- sva:::it.sol(pd$s.data[, pd$batches[[i]]], pd$gamma.hat[i, ], pd$delta.hat[i, ], pd$gamma.bar[i], pd$t2[i], pd$a.prior[i], pd$b.prior[i])
        gs[i, ] <- sol[1, ]; ds[i, ] <- sol[2, ]
      }
      bd <- pd$s.data
      for (i in seq_along(pd$batches)) {
        ii <- pd$batches[[i]]
        bd[, ii] <- (bd[, ii] - t(pd$batch.design[ii, ] %*% gs)) / (sqrt(ds[i, ]) %*% t(rep(1, length(ii))))
      }
      bd <- (bd * (sqrt(pd$var.pooled) %*% t(rep(1, ncol(bd))))) + pd$stand.mean
      rebuilt <- raw_mat; rebuilt[pd$keep, ] <- bd
      check(near(rebuilt, direct, 1e-9) && near(rebuilt[rownames(eng), colnames(eng)], eng, 1e-6),
            sprintf("A1 F4 ComBat's adjusted matrix is reproduced from the module's gamma.hat/delta.hat/priors via sva:::it.sol (max |diff| vs direct ComBat %.2e)", max(abs(rebuilt - direct))))
      hy <- utils::read.csv(file.path(a1, "tables", "combat_prior.csv"), stringsAsFactors = FALSE)
      check(identical(as.character(hy$batch), levels(batch_f)) && near(hy$a_prior, cb_int$a.prior, 1e-8) && near(hy$b_prior, cb_int$b.prior, 1e-8) &&
              near(hy$gamma_bar, cb_int$gamma.bar, 1e-8) && near(hy$tau2, cb_int$t2, 1e-8),
            "A1 F4 engine tables/combat_prior.csv carries ComBat's hyper-parameters for every batch")
      dg <- pd$prior[pd$prior$parameter == "delta", ]
      ref_d <- unlist(lapply(seq_along(levels(batch_f)), function(i) { x <- dg$x[dg$batch == levels(batch_f)[i]]; sva:::dinvgamma(x, cb_int$a.prior[i], cb_int$b.prior[i]) }))
      ok_d <- is.finite(ref_d)
      check(sum(ok_d) > 0 && near(dg$density[ok_d], ref_d[ok_d], 1e-8),
            sprintf("A1 F4 prior curve: the module's log-scale inverse gamma density equals sva:::dinvgamma on the grid (%d finite points)", sum(ok_d)))
      specs <- list.files(file.path(a1, "figures"), pattern = "^combat_prior(_[0-9]+)?[.]figure_spec[.]json$", full.names = TRUE)
      caps <- vapply(specs, function(f) paste(unlist(jsonlite::fromJSON(f)$caption), collapse = " "), "")
      nb_cap <- sum(as.integer(sub("^.* for ([0-9]+) batches.*$", "\\1", caps)))
      check(length(specs) >= 1 && nb_cap == nlevels(batch_f) && all(grepl(sprintf("%d features", ncol(pd$gamma.hat)), caps, fixed = TRUE)) &&
              all(grepl("par.prior = TRUE", caps, fixed = TRUE)) &&
              all(file.exists(sub("[.]figure_spec[.]json$", ".png", specs))),
            sprintf("A1 F4 combat_prior figure(s) (%d, split by the journal height limit) cover all %d batches; captions state method, batches and features: %s",
                    length(specs), nlevels(batch_f), paste(caps, collapse = " || ")))
    } else check(FALSE, "A1 F4 trace() captured ComBat's internals")
    if (!is.null(direct)) {
      check(near(eng[rownames(direct), colnames(direct)], direct, tol = 1e-6),
            "A1 REPLAY: engine's ComBat output matches a direct ComBat() call with the same protected design (mod = ~cancer; the vignette's own sec 7 example used mod = ~1, an unprotected intercept -- PACK P-2 requires the study variable, so this replay matches what the engine is required to build, not the vignette's simplified example)")
    } else cat("SKIP: A1 replay needs BiocParallel\n")
    q <- utils::read.csv(file.path(a1, "qc", "qc_results.csv"), stringsAsFactors = FALSE)
    check(!any(q$blocking), "A1 no QC blocker on a clean known-batch design")
    for (ext in c("pdf", "png", "figure_spec.json")) check(file.exists(file.path(a1, "figures", paste0("batch_pca.", ext))), paste("A1 figures/batch_pca.", ext))
  }

  # ---- A2: sva on bladderbatch, default --num-sv-method be -------------------
  a2 <- file.path(tmp, "a2")
  r <- run("--input", shQuote(bb$exprs), "--samples", shQuote(bb$samples), "--method", "sva",
          "--study-var", "cancer", "--outdir", shQuote(a2))
  check(r$status == 0, paste("A2 bladderbatch sva run exits 0", paste(utils::tail(r$out, 3), collapse = " | ")))
  if (r$status == 0) {
    j <- res_json(a2)
    check(identical(j$n_sv, 9L), sprintf("A2 REPLAY: num.sv(method = \"be\", B = 20, seed = 20260925) on the full bladderbatch matrix estimates n.sv = 9 (locked to sva 3.60.0 + bladderbatch 1.50.0); got %s", j$n_sv))
    check(any(grepl("Number of significant surrogate variables is:\\s*9", r$out)), "A2 console prints sva's own confirmation message with n.sv = 9")
  }

  # ---- A3: sva sensitivity option --num-sv-method leek -----------------------
  a3 <- file.path(tmp, "a3")
  r <- run("--input", shQuote(bb$exprs), "--samples", shQuote(bb$samples), "--method", "sva",
          "--study-var", "cancer", "--num-sv-method", "leek", "--outdir", shQuote(a3))
  check(r$status == 0, "A3 bladderbatch sva --num-sv-method leek exits 0")
  if (r$status == 0) {
    j <- res_json(a3)
    check(identical(j$n_sv, 2L), sprintf(paste0("A3 locked-container value: the engine's num.sv(method = \"leek\") on the TSV-round-tripped bladderbatch matrix gives n.sv = 2, ",
                                                 "EQUAL to the vignette sec 4 printed '[1] 2' -- but see A6a: the leek estimate flips on 1e-16 eigenvalue noise, so this ",
                                                 "equality is not by itself a reproduction of the printed value; got %s"), j$n_sv))
  }

  # ==========================================================================
  # A6: the sva vignette's OWN sec 3-6 code, run here in the test session
  # (L1_bioc3.23/sva/vignettes/sva.Rnw:63-141; rendered text
  # sva.rendered.txt:117-226). Independent of the engine: no engine or
  # _shared helper touches these objects except os_acceptance_data() to load
  # the registered bladderbatch 1.50.0 data set.
  # ==========================================================================
  bladderEset <- os_acceptance_data(suite, "bladderbatch", "bladderdata")
  pheno = Biobase::pData(bladderEset)                         # sva.Rnw:63
  edata = Biobase::exprs(bladderEset)                         # sva.Rnw:67
  mod = model.matrix(~as.factor(cancer), data=pheno)          # sva.Rnw:74
  mod0 = model.matrix(~1,data=pheno)                          # sva.Rnw:79
  # Printed topTableF(eb, adjust = "BH"), sva.rendered.txt:203-226 (10 rows).
  printed_tt <- utils::read.table(header = TRUE, stringsAsFactors = FALSE, colClasses = "character", text = "
id C1 C2 C3 AveExpr F P.Value adj.P.Val
207783_x_at -13.45607 0.26592438 -13.19015 12.938786 8622.518 1.207560e-69 1.419991e-65
201492_s_at -13.27593 0.15357563 -13.12236 13.336090 8605.631 1.274506e-69 1.419991e-65
208834_x_at -12.76410 0.06133735 -12.70276 13.160201 6939.513 4.749075e-67 3.527454e-63
212869_x_at -13.77956 0.26008134 -13.51948 13.452076 6593.349 1.939725e-66 1.080572e-62
212284_x_at -13.59977 0.29135804 -13.30841 13.070844 5495.721 2.893183e-64 1.289376e-60
208825_x_at -12.70978 0.08250572 -12.62728 13.108072 5414.768 4.349452e-64 1.615314e-60
211445_x_at -10.15890 -0.06633392 -10.22523 9.853817 5256.113 9.845000e-64 3.133945e-60
213084_x_at -12.59344 0.03015195 -12.56329 13.046529 4790.119 1.260101e-62 3.509854e-59
201429_s_at -13.33685 0.28358042 -13.05327 12.941208 4465.021 8.673707e-62 2.147514e-58
214327_x_at -12.60146 0.20934756 -12.39211 11.832607 4312.095 2.256881e-61 5.029008e-58")
  tt_cols <- c("C1", "C2", "C3", "AveExpr", "F", "P.Value", "adj.P.Val")
  # The vignette's sec 4-6 chain from a given n.sv, verbatim apart from the
  # data argument (so the same code serves the engine replay below).
  vignette_chain <- function(dat, n.sv, sv = NULL) {
    svobj = if (is.null(sv)) sva(dat,mod,mod0,n.sv=n.sv) else list(sv = sv, n.sv = ncol(sv))   # sva.Rnw:96
    modSv = cbind(mod,svobj$sv)                                                                # sva.Rnw:113
    mod0Sv = cbind(mod0,svobj$sv)                                                              # sva.Rnw:114
    pValuesSv = f.pvalue(dat,modSv,mod0Sv)                                                     # sva.Rnw:116
    fit = lmFit(dat,modSv)                                                                     # sva.Rnw:127
    contrast.matrix <- cbind("C1"=c(-1,1,0,rep(0,svobj$n.sv)),"C2"=c(0,-1,1,rep(0,svobj$n.sv)),"C3"=c(-1,0,1,rep(0,svobj$n.sv)))
    fitContrasts = contrasts.fit(fit,contrast.matrix)                                          # sva.Rnw:134
    eb = eBayes(fitContrasts)                                                                  # sva.Rnw:140
    tt = suppressMessages(suppressWarnings(topTableF(eb, adjust="BH")))                        # sva.Rnw:141 (topTableF prints an obsolescence note in limma 3.68.5)
    list(sv = svobj$sv, pValuesSv = pValuesSv, tt = tt)
  }
  printed_ok <- function(tt) {
    if (!identical(rownames(tt), printed_tt$id)) return(FALSE)
    all(vapply(seq_len(nrow(printed_tt)), function(i) all(vapply(tt_cols, function(cn) matches_printed(tt[i, cn], printed_tt[i, cn]), logical(1))), logical(1)))
  }

  # ---- A6a: PRINTED anchor, verbatim: n.sv = num.sv(edata,mod,method="leek") (sva.Rnw:89; printed "[1] 2", sva.rendered.txt:141)
  n.sv = num.sv(edata,mod,method="leek")
  check_known_failing(identical(as.numeric(n.sv), 2), sprintf(paste0(
    "A6a PRINTED: the vignette's own num.sv(edata,mod,method=\"leek\") in this session gives n.sv = %s; printed 2 (sva.rendered.txt:141). ",
    "Cause (S4_FIXES.md): leek counts eigenvalues of a projected matrix above a threshold a*(jn)^(-1/3)*57 that starts at a = 0, and 3 of them ",
    "are exact zeros in theory (rank of mod) that come out as +/-1e-16 rounding noise; 1e-12 input perturbations give 2/4/5"), n.sv))
  a6a <- vignette_chain(edata, n.sv)
  check_known_failing(printed_ok(a6a$tt), sprintf(paste0(
    "A6a PRINTED: the vignette's verbatim sec 4-6 chain with its in-session n.sv = %s reproduces the printed topTableF (sva.rendered.txt:203-226, ",
    "10 rows x 7 columns at printed precision); top row got %s C1 = %.7g"), n.sv, rownames(a6a$tt)[1], a6a$tt[1, "C1"]))

  # ---- A6b: PRINTED anchor, the vignette's chain from its own PRINTED n.sv = 2 (sva.rendered.txt:141 -> sva.Rnw:96-141)
  a6b <- vignette_chain(edata, 2)
  check(printed_ok(a6b$tt), sprintf(paste0(
    "A6b PRINTED anchor: vignette sva(edata,mod,mod0,n.sv=2) -> modSv/mod0Sv -> lmFit/contrasts.fit/eBayes/topTableF reproduces all 10 printed rows ",
    "x 7 columns (C1..adj.P.Val) at printed precision, e.g. 207783_x_at C1 = %.10g (printed -13.45607), P = %.7g (printed 1.207560e-69)"),
    a6b$tt["207783_x_at", "C1"], a6b$tt["207783_x_at", "P.Value"]))

  # ---- A6c: REPLAY of the engine's surrogate variables entering full/null models
  # The engine (A3: --method sva --num-sv-method leek, and A2: default be)
  # hands its SVs on in tables/sv_table.csv for a downstream DE design. The
  # test re-runs sva() directly on the SAME matrix the engine read (the TSV)
  # with the engine's n.sv, and puts the engine's SVs into the vignette's
  # modSv/mod0Sv chain.
  tsv_mat <- raw_mat[rownames(edata), colnames(edata)]
  for (lbl in c("a3", "a2")) {
    dd_run <- file.path(tmp, lbl)
    if (!file.exists(file.path(dd_run, "tables", "sv_table.csv"))) { check(FALSE, sprintf("A6c %s sv_table.csv exists", lbl)); next }
    sv_eng <- utils::read.csv(file.path(dd_run, "tables", "sv_table.csv"), stringsAsFactors = FALSE)
    rownames(sv_eng) <- sv_eng$sample
    sv_eng <- as.matrix(sv_eng[colnames(edata), grep("^SV[0-9]+$", names(sv_eng)), drop = FALSE])
    k <- ncol(sv_eng)
    direct_sv <- sva(tsv_mat, mod, mod0, n.sv = k, controls = NULL, method = "irw", vfilter = NULL, B = 5, numSVmethod = "be")$sv
    check(k > 0 && near(unname(sv_eng), unname(direct_sv), tol = 1e-8),
          sprintf("A6c REPLAY (%s, n.sv = %d): engine sv_table equals a direct sva(dat, mod = ~cancer, mod0 = ~1, n.sv = %d) on the same matrix (max |diff| = %.2e)",
                  lbl, k, k, if (k > 0) max(abs(sv_eng - direct_sv)) else NA_real_))
    rep_eng <- vignette_chain(tsv_mat, k, sv = unname(sv_eng))
    rep_dir <- vignette_chain(tsv_mat, k, sv = direct_sv)
    check(near(rep_eng$pValuesSv, rep_dir$pValuesSv, tol = 1e-6) && identical(rownames(rep_eng$tt), rownames(rep_dir$tt)) &&
            near(as.matrix(rep_eng$tt[, tt_cols]), as.matrix(rep_dir$tt[, tt_cols]), tol = 1e-6),
          sprintf("A6c REPLAY (%s): engine SVs in modSv/mod0Sv give the same f.pvalue P-values (all %d features) and topTableF as the direct SVs", lbl, nrow(tsv_mat)))
    if (identical(lbl, "a3")) {
      check(k == 2L && printed_ok(rep_eng$tt),
            "A6c PRINTED via engine: the engine's leek SVs (n.sv = 2) in the vignette's full/null models reproduce the printed topTableF (10 rows x 7 columns)")
      check(k == 2L && near(abs(unname(sv_eng)), abs(unname(a6b$sv)), tol = 1e-6),
            sprintf("A6c engine SVs (TSV input) vs A6b vignette SVs (in-memory edata; the TSV round trip changes cells by <= 5e-14): max |diff| = %.2e",
                    if (k == 2L) max(abs(abs(sv_eng) - abs(a6b$sv))) else NA_real_))
    }
  }
}

zf <- make_zfgenes(file.path(tmp, "zfgenes"), suite)
if (is.null(zf)) {
  cat("SKIP: zebrafishRNASeq not in the acceptance data layer (A4)\n")
} else {
  # ---- A4: svaseq on zebrafishRNASeq (PACK C printed value) ------------------
  a4 <- file.path(tmp, "a4")
  r <- run("--input", shQuote(zf$counts), "--samples", shQuote(zf$samples), "--method", "svaseq",
          "--study-var", "group", "--outdir", shQuote(a4))
  check(r$status == 0, paste("A4 zebrafishRNASeq svaseq run exits 0", paste(utils::tail(r$out, 3), collapse = " | ")))
  if (r$status == 0) {
    j <- res_json(a4)
    check(identical(j$n_sv, 1L), sprintf("A4 num.sv(method = \"be\") on zfGenes estimates n.sv = 1, matching the vignette sec 13's own (there manually fixed) n.sv = 1; got %s", j$n_sv))
    check(any(grepl("Number of significant surrogate variables is:\\s*1", r$out)),
          "A4 PRINTED anchor: console reproduces the vignette's own 'Number of significant surrogate variables is: 1' (sec 13)")
    check(any(grepl("[0-9]+ of 8 rules triggered; read .+ first$", r$out)),
         paste("A4 closing line format:", utils::tail(r$out, 1)))   # sva's own unbuffered "Iteration (out of 5):" print can share a line with it
  }
}

# ---- A5: ComBat_seq on the vignette's own simulated example (REPLAY anchor) ----
cs <- make_combat_seq_sim(file.path(tmp, "combatseq"), 20260925L)
a5 <- file.path(tmp, "a5")
r <- run("--input", shQuote(cs$counts), "--samples", shQuote(cs$samples), "--method", "combat_seq",
        "--batch", "batch", "--study-var", "group", "--outdir", shQuote(a5))
check(r$status == 0, paste("A5 ComBat_seq simulated run exits 0", paste(utils::tail(r$out, 3), collapse = " | ")))
if (r$status == 0) {
  for (msg in c("Found 2 batches", "Using full model in ComBat-seq.", "Adjusting for 1 covariate(s) or covariate level(s)",
               "Estimating dispersions", "Fitting the GLM model", "Shrinkage off - using GLM estimates for parameters", "Adjusting the data")) {
    check(any(grepl(msg, r$out, fixed = TRUE)), sprintf("A5 REPLAY: console reproduces the vignette sec 8 ComBat_seq message '%s' verbatim", msg))
  }
  csamples <- utils::read.csv(cs$samples, stringsAsFactors = FALSE)
  craw <- read_mat(cs$counts)
  eng <- read_mat(file.path(a5, "tables", "corrected_matrix.csv"))
  direct <- sva::ComBat_seq(counts = craw, batch = sorted_factor(csamples$batch), group = sorted_factor(csamples$group),
                           covar_mod = NULL, full_mod = TRUE, shrink = FALSE, shrink.disp = FALSE, gene.subset.n = NULL)
  check(identical(eng[rownames(direct), colnames(direct)], direct), "A5 REPLAY: engine's ComBat_seq output is byte-identical to a direct ComBat_seq() call with the same args")
  storage.mode(eng) <- "integer"
  check(all(eng == round(eng)), "A5 ComBat_seq output preserves the integer nature of the count matrix (vignette sec 8)")
}

# ================================================================================
# D: determinism, --spec replay, --from-run, cross-module P-1 refusal
# ================================================================================
d1 <- file.path(tmp, "d1")
r <- run("--spec", shQuote(file.path(a5, "provenance", "resolved_spec.json")), "--outdir", shQuote(d1))
check(r$status == 0, "D1 --spec replay exits 0")
if (r$status == 0) {
  for (f in c("tables/corrected_matrix.csv", "tables/batch_report.md", "results/sva_batch_results.json",
             "figures/batch_pca.figure_spec.json", "figures/batch_pca.png", "draft/methods_results.md")) {
    check(identical(sha(file.path(a5, f)), sha(file.path(d1, f))), paste("D1 byte-identical on replay:", f))
  }
}

up <- file.path(tmp, "upstream"); dir.create(file.path(up, "objects"), recursive = TRUE)
invisible(file.copy(cs$counts, file.path(up, "objects", "counts.tsv")))
invisible(file.copy(cs$samples, file.path(up, "objects", "sample_table.csv")))
write_handoff(up, "upstream", "deseq2-qc", "1.0.0",
             objects = list(count_matrix = list(path = file.path(up, "objects", "counts.tsv"), type = "count_matrix"),
                            sample_table = list(path = file.path(up, "objects", "sample_table.csv"), type = "sample_table")))
d2 <- file.path(tmp, "d2")
r <- run("--from-run", shQuote(up), "--method", "combat_seq", "--batch", "batch", "--study-var", "group", "--outdir", shQuote(d2))
check(r$status == 0 && identical(sha(file.path(a5, "tables", "corrected_matrix.csv")), sha(file.path(d2, "tables", "corrected_matrix.csv"))),
     "D2 --from-run gives the same corrected matrix as --input/--samples")
if (r$status == 0) {
  h <- jsonlite::fromJSON(file.path(d2, "objects", "handoff.json"))
  check(identical(unlist(h$upstream_runs), c("upstream", "d2")), "D2 upstream_runs chain recorded")
  hobj <- h$objects[h$objects$name == "count_matrix", ]
  check(identical(hobj$type, "batch_corrected_matrix"), "D2 the canonical 'count_matrix' handoff object is deliberately typed batch_corrected_matrix (PACK P-1)")
}
cat("tamper\n", file = file.path(up, "objects", "sample_table.csv"), append = TRUE)
r <- run("--from-run", shQuote(up), "--method", "combat_seq", "--batch", "batch", "--study-var", "group", "--outdir", shQuote(file.path(tmp, "d3")))
check(r$status != 0 && any(grepl("OS_HANDOFF_MISMATCH", r$out)), "D3 a changed upstream object is refused (OS_HANDOFF_MISMATCH)")

# ---- D4: PACK P-1 cross-module refusal -- deseq2-wald refuses a sva-batch run ----
dw_entry <- file.path(suite, "skills", "deseq2-wald", "scripts", "run_deseq2_wald.R")
if (file.exists(dw_entry)) {
  out <- suppressWarnings(system2(rscript, c(shQuote(dw_entry), "--from-run", shQuote(a5), "--reference", "0", "--target", "1",
                                             "--outdir", shQuote(file.path(tmp, "d4"))), stdout = TRUE, stderr = TRUE))
  st <- attr(out, "status") %||% 0L
  check(st != 0 && any(grepl("OS_BATCH_CORRECTED_INPUT", out)),
       "D4 deseq2-wald --from-run <sva-batch run> is refused with OS_BATCH_CORRECTED_INPUT (PACK S1 P-1, cross-module)")
} else cat("SKIP: D4 needs skills/deseq2-wald (reference module)\n")

# ================================================================================
# E: typed errors and blockers (small synthetic fixture)
# ================================================================================
set.seed(1)
syn <- matrix(stats::rnbinom(400 * 8, mu = 200, size = 5), 400, 8, dimnames = list(sprintf("g%03d", 1:400), sprintf("S%d", 1:8)))
write_mat <- function(m, path) utils::write.csv(data.frame(feature_id = rownames(m), m, check.names = FALSE), path, row.names = FALSE)
write_mat(syn, file.path(tmp, "syn_counts.csv"))
st <- data.frame(sample = colnames(syn), batch = rep(c("b1", "b2"), each = 4), grp = rep(c("x", "y"), 4),
                cov1 = rep(c(0, 1), each = 4), stringsAsFactors = FALSE)
utils::write.csv(st, file.path(tmp, "syn_samples.csv"), row.names = FALSE)
sbase <- c("--input", shQuote(file.path(tmp, "syn_counts.csv")), "--samples", shQuote(file.path(tmp, "syn_samples.csv")))

r <- run(sbase, "--method", "combat_seq", "--study-var", "grp", "--outdir", shQuote(file.path(tmp, "e1")))
check(r$status != 0 && any(grepl("OS_MISSING_PARAMETER.*--batch", r$out)), "E1 combat_seq without --batch -> OS_MISSING_PARAMETER")

r <- run(sbase, "--method", "svaseq", "--batch", "batch", "--study-var", "grp", "--outdir", shQuote(file.path(tmp, "e2")))
check(r$status != 0 && any(grepl("OS_CONFLICTING_PARAMETERS", r$out)), "E2 svaseq given --batch -> OS_CONFLICTING_PARAMETERS")

r <- run(sbase, "--method", "combat_seq", "--batch", "batch", "--study-var", "cov1", "--study-var-type", "continuous", "--outdir", shQuote(file.path(tmp, "e3")))
check(r$status != 0 && any(grepl("OS_UNSUPPORTED_DESIGN", r$out)), "E3 combat_seq + continuous --study-var -> OS_UNSUPPORTED_DESIGN")

st_conf <- st; st_conf$batch <- st_conf$grp   # batch IS the study variable: fully confounded
utils::write.csv(st_conf, file.path(tmp, "conf_samples.csv"), row.names = FALSE)
r <- run("--input", shQuote(file.path(tmp, "syn_counts.csv")), "--samples", shQuote(file.path(tmp, "conf_samples.csv")),
        "--method", "combat_seq", "--batch", "batch", "--study-var", "grp", "--outdir", shQuote(file.path(tmp, "e4")))
check(r$status != 0 && any(grepl("OS_INVALID_DESIGN", r$out)), "E4 --batch identical to --study-var (full confounding) -> OS_INVALID_DESIGN")

st_dup <- st; st_dup$dup <- ifelse(st_dup$grp == "x", "p", "q")   # relabelled duplicate of --study-var's own grouping
utils::write.csv(st_dup, file.path(tmp, "dup_samples.csv"), row.names = FALSE)
r <- run("--input", shQuote(file.path(tmp, "syn_counts.csv")), "--samples", shQuote(file.path(tmp, "dup_samples.csv")),
        "--method", "sva", "--study-var", "grp", "--covariates", "dup", "--outdir", shQuote(file.path(tmp, "e5")))
check(r$status != 0 && any(grepl("OS_INVALID_DESIGN", r$out)),
     "E5 sva: --covariates perfectly collinear with --study-var (same grouping, different labels) -> OS_INVALID_DESIGN")

# ---- E9-E11 (F2): the JOINT design with all protected variables is validated before sva is called ----
# cov1 equals the batch (b1 -> 0, b2 -> 1): ComBat/ComBat_seq would stop with
# the package's own untyped "At least one covariate is confounded with batch!".
for (m in c("combat", "combat_seq")) {
  e9 <- file.path(tmp, paste0("e9_", m))
  r <- run(sbase, "--method", m, "--batch", "batch", "--study-var", "grp", "--covariates", "cov1", "--outdir", shQuote(e9))
  check(r$status != 0 && any(grepl("OS_INVALID_DESIGN: --covariates cov1 confounded with --batch", r$out, fixed = TRUE)) &&
          !any(grepl("confounded with batch!", r$out, fixed = TRUE)) && !file.exists(file.path(e9, "tables", "corrected_matrix.csv")),
        sprintf("E9 %s: --covariates cov1 identical to --batch -> typed OS_INVALID_DESIGN before ComBat runs (no raw package error, no output); got: %s",
                m, paste(utils::tail(r$out, 2), collapse = " | ")))
}
# A three-level study variable whose level c occurs only in batch b2 and
# shares it with no other level: c vs a is not estimable jointly with batch.
st_ne <- st; st_ne$grp3 <- c("a", "a", "b", "b", "c", "c", "c", "c")
utils::write.csv(st_ne, file.path(tmp, "ne_samples.csv"), row.names = FALSE)
r <- run("--input", shQuote(file.path(tmp, "syn_counts.csv")), "--samples", shQuote(file.path(tmp, "ne_samples.csv")),
        "--method", "combat_seq", "--batch", "batch", "--study-var", "grp3", "--outdir", shQuote(file.path(tmp, "e10")))
check(r$status != 0 && any(grepl("OS_INVALID_DESIGN: --batch and --study-var are partially confounded", r$out, fixed = TRUE)) &&
        any(grepl("coefficient(s) c (against the reference level) are NOT estimable", r$out, fixed = TRUE)),
      paste("E10 partial confounding with a NON-estimable study contrast (level c only in batch b2) -> typed OS_INVALID_DESIGN naming it:", paste(utils::tail(r$out, 1), collapse = " | ")))
# Unbalanced but connected: a only in b1, c only in b2, b in both -> every
# study coefficient estimable, 2 empty cells -> "partial" + SB-05, run completes.
st_pe <- st; st_pe$grp3 <- c("a", "a", "b", "b", "c", "c", "b", "b")
utils::write.csv(st_pe, file.path(tmp, "pe_samples.csv"), row.names = FALSE)
e11 <- file.path(tmp, "e11")
r <- run("--input", shQuote(file.path(tmp, "syn_counts.csv")), "--samples", shQuote(file.path(tmp, "pe_samples.csv")),
        "--method", "combat_seq", "--batch", "batch", "--study-var", "grp3", "--outdir", shQuote(e11))
check(r$status == 0, paste("E11 partially confounded but estimable design runs:", paste(utils::tail(r$out, 2), collapse = " | ")))
if (r$status == 0) {
  j <- res_json(e11); q <- utils::read.csv(file.path(e11, "qc", "qc_results.csv"), stringsAsFactors = FALSE)
  dr <- paste(readLines(file.path(e11, "draft", "methods_results.md")), collapse = " ")
  br <- paste(readLines(file.path(e11, "tables", "batch_report.md")), collapse = " ")
  chk <- "joint design batch + covariates + study variable: rank 4 of 4 columns; all 2 study-variable coefficient(s) estimable"
  check(identical(j$confounding_status, "partial") && isTRUE(j$joint_design$study_estimable) && identical(as.integer(j$joint_design$empty_batch_study_cells), 2L) &&
          isTRUE(q$triggered[q$id == "SB-05"]) && grepl(chk, dr, fixed = TRUE) && grepl(chk, br, fixed = TRUE) &&
          grepl("partially confounded (2 empty batch x study-variable cell(s))", dr, fixed = TRUE) && !grepl("remains estimable", dr, fixed = TRUE),
        "E11 partial status, SB-05 warning, and the draft/batch report state the actual estimability check result (rank 4 of 4, 2 study coefficients) instead of an unchecked claim")
}
st_1l <- st; st_1l$lab <- "L1"
utils::write.csv(st_1l, file.path(tmp, "onelevel_samples.csv"), row.names = FALSE)
r <- run("--input", shQuote(file.path(tmp, "syn_counts.csv")), "--samples", shQuote(file.path(tmp, "onelevel_samples.csv")),
        "--method", "combat_seq", "--batch", "batch", "--study-var", "grp", "--covariates", "lab", "--outdir", shQuote(file.path(tmp, "e12")))
check(r$status != 0 && any(grepl("OS_INVALID_DESIGN: covariate 'lab' has a single level", r$out, fixed = TRUE)), "E12 single-level --covariates -> typed OS_INVALID_DESIGN (not a raw model.matrix contrasts error)")

nonint <- syn; storage.mode(nonint) <- "double"; nonint[1, 1] <- 10.5
write_mat(nonint, file.path(tmp, "nonint.csv"))
e6 <- file.path(tmp, "e6")
r <- run("--input", shQuote(file.path(tmp, "nonint.csv")), "--samples", shQuote(file.path(tmp, "syn_samples.csv")),
        "--method", "combat_seq", "--batch", "batch", "--study-var", "grp", "--outdir", shQuote(e6))
q <- if (file.exists(file.path(e6, "qc", "qc_results.csv"))) utils::read.csv(file.path(e6, "qc", "qc_results.csv")) else NULL
check(r$status != 0 && any(grepl("OS_QC_BLOCKER: SB-01", r$out)) && isTRUE(q$triggered[q$id == "SB-01"]) &&
       any(grepl("draft withheld", readLines(file.path(e6, "draft", "methods_results.md")))),
     "E6 non-integer counts -> SB-01 blocker, qc table written, draft withheld")

st1 <- st; st1$batch <- rep("b1", 8)
utils::write.csv(st1, file.path(tmp, "one_batch.csv"), row.names = FALSE)
r <- run("--input", shQuote(file.path(tmp, "syn_counts.csv")), "--samples", shQuote(file.path(tmp, "one_batch.csv")),
        "--method", "combat_seq", "--batch", "batch", "--study-var", "grp", "--outdir", shQuote(file.path(tmp, "e7")))
check(r$status != 0 && any(grepl("OS_QC_BLOCKER: SB-03", r$out)), "E7 a single --batch level -> SB-03 blocker")

r <- run(sbase, "--method", "combat_seq", "--min-cont", "5", "--outdir", shQuote(file.path(tmp, "e8")))
check(r$status != 0 && any(grepl("OS_UNKNOWN_FLAG", r$out)), "E8 misspelled flag -> OS_UNKNOWN_FLAG")

# ================================================================================
# F: flag effectiveness (synthetic; more samples than the E fixture so
# num.sv(method = "leek") never asks sva() for more surrogate variables than
# the residual degrees of freedom can support -- irwsva.build() breaks down
# with NaNs otherwise, a real numerical limit of the package, not a bug here)
# ================================================================================
set.seed(2)
# --method sva expects log-scale/normalized data (D-S1), not raw counts (that
# is svaseq's job): log2(counts + 1) so num.sv/sva see the kind of continuous
# data they are meant for -- raw high-variance counts made "leek" wildly
# overestimate n.sv here, exhausting the residual degrees of freedom and
# breaking irwsva.build() with NaNs (a real numerical limit given a tiny
# design, not a bug; --method svaseq is the intended route for raw counts).
syn2 <- log2(matrix(stats::rnbinom(400 * 20, mu = 200, size = 5), 400, 20, dimnames = list(sprintf("g%03d", 1:400), sprintf("T%d", 1:20))) + 1)
write_mat(syn2, file.path(tmp, "syn2_counts.csv"))
st2 <- data.frame(sample = colnames(syn2), grp = rep(c("x", "y"), each = 10), cov1 = rep(c(0, 1), 10), stringsAsFactors = FALSE)
utils::write.csv(st2, file.path(tmp, "syn2_samples.csv"), row.names = FALSE)
sbase2 <- c("--input", shQuote(file.path(tmp, "syn2_counts.csv")), "--samples", shQuote(file.path(tmp, "syn2_samples.csv")))
f0 <- file.path(tmp, "f0"); f1 <- file.path(tmp, "f1"); f2 <- file.path(tmp, "f2"); f3 <- file.path(tmp, "f3")
r0 <- run(sbase2, "--method", "sva", "--study-var", "grp", "--outdir", shQuote(f0))
r1 <- run(sbase2, "--method", "sva", "--study-var", "grp", "--num-sv-method", "leek", "--outdir", shQuote(f1))
r2 <- run(sbase2, "--method", "sva", "--study-var", "grp", "--covariates", "cov1", "--outdir", shQuote(f2))
r3 <- run(sbase2, "--method", "sva", "--study-var", "grp", "--pca-ntop", "50", "--outdir", shQuote(f3))
if (all(vapply(list(r0, r1, r2, r3), function(x) x$status == 0, logical(1)))) {
  j0 <- res_json(f0); j1 <- res_json(f1); j2 <- res_json(f2)
  check(!identical(j0$n_sv, j1$n_sv) || !identical(j0$num_sv_method, j1$num_sv_method),
       sprintf("F1 --num-sv-method leek reaches the engine (be: n.sv=%s, leek: n.sv=%s)", j0$n_sv, j1$n_sv))
  check(!identical(j0$n_sv, j2$n_sv) || !isTRUE(all.equal(j0, j2)), "F2 --covariates changes the fitted design (n.sv or state differs)")
  sp3 <- jsonlite::fromJSON(file.path(f3, "figures", "batch_pca.figure_spec.json"))
  ntop_used <- sp3$data$panels$data$ntop[[1]]
  check(identical(as.integer(ntop_used), 50L), sprintf("F3 --pca-ntop 50 reaches the PCA figure (figure_spec ntop = %s)", ntop_used))
} else check(FALSE, "F synthetic runs exit 0")

# ================================================================================
# W (F3): batch report, results JSON and Methods carry the ACTUAL models and
# call parameters of the path that ran (not only the registry/source code)
# ================================================================================
w_texts <- function(d) list(br = paste(readLines(file.path(d, "tables", "batch_report.md")), collapse = "\n"),
                            dr = paste(readLines(file.path(d, "draft", "methods_results.md")), collapse = " "),
                            j = jsonlite::fromJSON(file.path(d, "results", "sva_batch_results.json"), simplifyVector = FALSE))
has_all <- function(txt, pats) all(vapply(pats, function(p) grepl(p, txt, fixed = TRUE), logical(1)))
w_cases <- list(
  a1 = list(br = c("- Protected design: mod = model.matrix(~ cancer)", "- Fitted model: ~ -1 + batch + cancer",
                   "sva::ComBat(par.prior = TRUE, prior.plots = FALSE, mean.only = FALSE, ref.batch = NULL)"),
            dr = c("The protected design was mod = model.matrix(~ cancer); ComBat fits, per feature, ~ -1 + batch + cancer.",
                   "par.prior = TRUE (parametric empirical Bayes), mean.only = FALSE (location and scale adjusted) and ref.batch = NULL"),
            j = function(j) isTRUE(j$calls$ComBat$par.prior) && identical(j$calls$ComBat$mean.only, FALSE) && is.null(j$calls$ComBat$ref.batch) &&
                  identical(j$models$protected_design, "mod = model.matrix(~ cancer)")),
  a2 = list(br = c("- Null model ~ 1", "sva::num.sv(method = \"be\", vfilter = NULL, B = 20, seed = 20260925) -> n.sv = 9",
                   "sva::sva(controls = NULL, method = \"irw\", vfilter = NULL, B = 5, numSVmethod = \"be\", n.sv = 9)",
                   "limma::removeBatchEffect(x = input matrix, batch = NULL, batch2 = NULL, group = NULL, covariates = SV1 + SV2 + SV3 + SV4 + SV5 + SV6 + SV7 + SV8 + SV9, design = full model (mod))"),
            dr = c("The full model was ~ cancer and the null model ~ 1", "num.sv(method = \"be\", B = 20, seed = 20260925, vfilter = NULL)",
                   "sva was run with method = \"irw\", B = 5 iterations, vfilter = NULL, controls = NULL", "covariates = the 9 surrogate variable(s), design = the full model, batch = NULL"),
            j = function(j) identical(j$calls$num.sv$B, 20L) && identical(j$calls$num.sv$seed, 20260925L) && identical(j$calls$sva$B, 5L) &&
                  identical(j$models$null_model, "null model ~ 1")),
  a3 = list(br = c("method \"leek\": asymptotic estimate; B and seed are passed but only the \"be\" branch uses them"),
            dr = c("num.sv(method = \"leek\", B = 20, seed = 20260925, vfilter = NULL) (B and seed are used only by the permutation method \"be\")"),
            j = function(j) identical(j$calls$num.sv$method, "leek")),
  a4 = list(br = c("sva::svaseq(controls = NULL, method = \"irw\", vfilter = NULL, B = 5, numSVmethod = \"be\", constant = 1, n.sv = 1)"),
            dr = c("svaseq was run with method = \"irw\", B = 5 iterations, vfilter = NULL, controls = NULL and constant = 1 (log(counts + 1))"),
            j = function(j) identical(j$calls$svaseq$constant, 1L) || identical(j$calls$svaseq$constant, 1)),
  a5 = list(br = c("- Protected design: group = group; covar_mod = NULL", "sva::ComBat_seq(full_mod = TRUE, shrink = FALSE, shrink.disp = FALSE, gene.subset.n = NULL)",
                   "covar_mod columns: none (NULL)"),
            dr = c("ComBat_seq was run with full_mod = TRUE, shrink = FALSE, shrink.disp = FALSE (GLM estimates without empirical Bayes shrinkage) and gene.subset.n = NULL; covar_mod = NULL."),
            j = function(j) isTRUE(j$calls$ComBat_seq$full_mod) && identical(j$calls$ComBat_seq$shrink, FALSE) && identical(j$calls$ComBat_seq$shrink.disp, FALSE)),
  f2 = list(br = c("- Protected design: mod = model.matrix(~ cov1 + grp)", "- Null model ~ cov1"),
            dr = c("The full model was ~ cov1 + grp and the null model ~ cov1"),
            j = function(j) identical(j$models$fitted_model, "full model ~ cov1 + grp")))
for (nm in names(w_cases)) {
  d <- file.path(tmp, nm)
  if (!file.exists(file.path(d, "results", "sva_batch_results.json"))) { cat("SKIP: W", nm, "(run not available)\n"); next }
  w <- w_texts(d); cs <- w_cases[[nm]]
  check(has_all(w$br, cs$br), sprintf("W %s batch_report.md states the actual models and call parameters (%s)", nm, paste(cs$br, collapse = " || ")))
  check(has_all(w$dr, cs$dr), sprintf("W %s Methods draft states the actual models and call parameters (%s)", nm, paste(cs$dr, collapse = " || ")))
  check(isTRUE(cs$j(w$j)), sprintf("W %s results JSON carries models/calls with the values the calls received", nm))
}

# F4: the prior diagnostic exists only on the parametric ComBat path.
for (nm in c("a2", "a4", "a5")) {
  d <- file.path(tmp, nm)
  if (!file.exists(file.path(d, "tables", "batch_report.md"))) next
  br <- paste(readLines(file.path(d, "tables", "batch_report.md")), collapse = " ")
  check(!file.exists(file.path(d, "figures", "combat_prior.png")) && !file.exists(file.path(d, "tables", "combat_prior.csv")) &&
          grepl("## ComBat prior diagnostic Not applicable:", gsub("[[:space:]]+", " ", br)),
        sprintf("F4 %s (no parametric ComBat prior on this path): no combat_prior figure/table, and the batch report says why", nm))
}

# ================================================================================
# G: golden baseline (lock 5) -- A5 (deterministic simulated ComBat_seq)
# ================================================================================
golden <- c("tables/corrected_matrix.csv", "tables/batch_report.md", "results/sva_batch_results.json",
           "figures/batch_pca.figure_spec.json")
if (nzchar(Sys.getenv("OMICSTAT_WRITE_GOLDEN"))) { os_golden_write(module_dir, a5, golden); cat("golden manifest written\n") }
gc <- os_golden_check(module_dir, a5)
if (gc$status == "SKIP") cat("SKIP: golden baseline --", gc$reason, "\n") else check(gc$status == "PASS", paste("G golden baseline", paste(gc$problems, collapse = ", ")))

setwd(old_wd)
check(!file.exists(file.path(tmp, "Rplots.pdf")) && !file.exists(file.path(module_dir, "Rplots.pdf")), "no Rplots.pdf device leak")
for (kf in known_failing) cat("KNOWN-FAILING ANCHOR (documented in S4_FIXES.md):", kf, "\n")
if (length(failures)) { cat(length(failures), "check(s) FAILED\n"); quit(status = 1) } else {
  cat(sprintf("SMOKE PASSED%s\n", if (length(known_failing)) sprintf(" (with %d documented KNOWN-FAILING anchor(s), listed above)", length(known_failing)) else ""))
}
