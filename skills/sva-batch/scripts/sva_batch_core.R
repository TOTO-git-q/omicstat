# sva_batch_core.R -- core layer of module sva-batch. ASCII only on purpose.
#
# Four methods (PACK D-S1): known batch on log-scale/array data -> ComBat;
# known batch on raw RNA-seq counts -> ComBat_seq; unknown source of
# variation on log-scale/array data -> sva; unknown source on raw counts ->
# svaseq. Every sva/limma call is registered in calls_registry.json with
# EVERY result-affecting argument written out, even where it equals the
# function default (lock 3). Values and sources: references/parameters.md
# and PACK section D / the S1 appendix.
#
# P-1 (frozen): the corrected/display matrix is NEVER a legitimate DE input;
# it is handed on with object type "batch_corrected_matrix" so read_handoff()
# refuses it for any other expected type (_shared/scripts/handoff.R).
# P-2 (frozen): the biological/study variable is a required, protected part
# of every correction; full confounding with a known batch stops the run;
# partial confounding is a QC warning.
# P-3 (frozen): number of surrogate variables via num.sv(method, B = 20,
# vfilter = NULL, seed = <--seed>); n.sv is always reported.

SB_MODULE <- "sva-batch"
SB_MODULE_VERSION <- "1.1.0"
SB_DEFAULT_SEED <- 20260925L
SB_METHODS <- c("combat", "combat_seq", "sva", "svaseq")
SB_COUNT_METHODS <- c("combat_seq", "svaseq")            # need raw integer counts (D-S1)
SB_KNOWN_BATCH_METHODS <- c("combat", "combat_seq")       # take --batch
SB_UNKNOWN_BATCH_METHODS <- c("sva", "svaseq")            # estimate surrogate variables instead
SB_NUM_SV_METHODS <- c("be", "leek")                      # PACK P-3
# PCA display default (os_pca_scores ntop); exposed as --pca-ntop.
SB_PCA_NTOP_DEFAULT <- 500L

# ---------------------------------------------------------------------------
# Parameter-level design checks (run BEFORE any statistics; typed errors that
# stop the run immediately, mirroring deseq2-wald's dw_check_design_args /
# dw_design not-full-rank stop -- these are never QC rows).
# ---------------------------------------------------------------------------

sb_check_method_args <- function(method, batch, study_var, study_var_type, covariates) {
  if (!method %in% SB_METHODS) stop(sprintf("OS_INVALID_PARAMETER: --method '%s' is not one of %s.", method, paste(SB_METHODS, collapse = ", ")), call. = FALSE)
  if (method %in% SB_KNOWN_BATCH_METHODS && is.null(batch)) {
    stop(sprintf("OS_MISSING_PARAMETER: --method %s needs a known --batch column.", method), call. = FALSE)
  }
  if (method %in% SB_UNKNOWN_BATCH_METHODS && !is.null(batch)) {
    stop(sprintf(paste0("OS_CONFLICTING_PARAMETERS: --method %s estimates surrogate variables for an UNKNOWN ",
                        "source of variation; it does not take a known --batch column (use --method combat or ",
                        "combat_seq for a known batch)."), method), call. = FALSE)
  }
  if (identical(study_var, batch)) stop("OS_CONFLICTING_PARAMETERS: --study-var and --batch cannot be the same column.", call. = FALSE)
  if (study_var %in% covariates) stop("OS_CONFLICTING_PARAMETERS: --study-var cannot also be a --covariates column.", call. = FALSE)
  if (!is.null(batch) && batch %in% covariates) stop("OS_CONFLICTING_PARAMETERS: --batch cannot also be a --covariates column.", call. = FALSE)
  if (identical(method, "combat_seq") && identical(study_var_type, "continuous")) {
    stop(paste0("OS_UNSUPPORTED_DESIGN: ComBat_seq splits the protected design into a categorical 'group' and a ",
               "'covar_mod' matrix; the PACK S1 appendix does not decide where a CONTINUOUS --study-var goes ",
               "(the 2026-09-27 appendix 'clarify' item). Nothing is guessed: use --method sva/svaseq (mod/mod0 ",
               "accept a continuous study variable) or supply a categorical --study-var-type."), call. = FALSE)
  }
  invisible(TRUE)
}

.sb_need_cols <- function(st, cols, what) {
  miss <- setdiff(cols, names(st))
  if (length(miss)) stop(sprintf("OS_MISSING_COLUMN: sample table has no %s column(s): %s.", what, paste(miss, collapse = ", ")), call. = FALSE)
}

# Known batch as a factor (sorted levels); NULL when the method has no known
# batch (sva/svaseq). Built once for the pre-fit QC rows (SB-03/SB-04) and
# reused unchanged inside sva_batch_compute().
sb_batch_factor <- function(st, batch) {
  if (is.null(batch)) return(NULL)
  .sb_need_cols(st, batch, "--batch")
  v <- st[[batch]]
  if (anyNA(v)) stop(sprintf("OS_INVALID_DESIGN: --batch '%s' has missing values.", batch), call. = FALSE)
  factor(v, levels = sort(unique(as.character(v)), method = "radix"))
}

# One factor column per --covariates entry, sorted levels (dw_design style).
sb_covariate_frame <- function(st, covariates) {
  .sb_need_cols(st, covariates, "--covariates")
  cd <- data.frame(row.names = rownames(st))
  for (cv in covariates) {
    v <- st[[cv]]
    if (anyNA(v)) stop(sprintf("OS_INVALID_DESIGN: covariate '%s' has missing values.", cv), call. = FALSE)
    cd[[cv]] <- factor(v, levels = sort(unique(as.character(v)), method = "radix"))
    if (nlevels(cd[[cv]]) < 2) {
      stop(sprintf("OS_INVALID_DESIGN: covariate '%s' has a single level; it carries no information to protect. Drop it from --covariates.", cv), call. = FALSE)
    }
  }
  cd
}

# The protected study variable as a factor (categorical) or numeric vector
# (continuous); OS_INVALID_PARAMETER if a continuous variable does not parse.
sb_study_component <- function(st, study_var, study_var_type) {
  .sb_need_cols(st, study_var, "--study-var")
  v <- st[[study_var]]
  if (anyNA(v)) stop(sprintf("OS_INVALID_DESIGN: --study-var '%s' has missing values.", study_var), call. = FALSE)
  if (identical(study_var_type, "continuous")) {
    num <- suppressWarnings(as.numeric(v))
    if (anyNA(num)) stop(sprintf("OS_INVALID_PARAMETER: --study-var-type continuous but '%s' has non-numeric value(s).", study_var), call. = FALSE)
    return(num)
  }
  f <- factor(v, levels = sort(unique(as.character(v)), method = "radix"))
  if (nlevels(f) < 2) stop(sprintf("OS_INVALID_DESIGN: --study-var '%s' has fewer than 2 levels; there is nothing to protect.", study_var), call. = FALSE)
  f
}

sb_full_rank <- function(mm, what) {
  if (qr(mm)$rank < ncol(mm)) {
    stop(sprintf(paste0("OS_INVALID_DESIGN: %s is not full rank (a covariate level is empty, or two columns are ",
                        "collinear). Remove the redundant covariate or level."), what), call. = FALSE)
  }
  invisible(TRUE)
}

# mod: full protected design (covariates + study variable); mod0: null model
# (covariates only) -- used by sva/svaseq (PACK P-2). mod0 must be strictly
# smaller than mod (the study variable must add independent information);
# both must be full rank. Immediate stop, mirrors dw_design's not-full-rank
# check: no QC row, decided before any statistics run.
sb_mod_mod0 <- function(cd_cov, study_component, sample_ids) {
  cd0 <- cd_cov
  rownames(cd0) <- sample_ids
  f0 <- if (ncol(cd0)) stats::as.formula(paste("~", paste(names(cd0), collapse = " + "))) else stats::as.formula("~1")
  mod0 <- stats::model.matrix(f0, data = cd0)
  cd1 <- cd0
  cd1$.study_var <- study_component
  f1 <- stats::as.formula(paste("~", paste(c(names(cd0), ".study_var"), collapse = " + ")))
  mod <- stats::model.matrix(f1, data = cd1)
  sb_full_rank(mod0, "the null model (--covariates)")
  sb_full_rank(mod, "the full model (--covariates + --study-var)")
  if (qr(mod)$rank <= qr(mod0)$rank) {
    stop(paste0("OS_INVALID_DESIGN: --study-var adds no independent information beyond --covariates (the full ",
               "model is not larger than the null model); check for collinearity between --study-var and ",
               "--covariates."), call. = FALSE)
  }
  list(mod = mod, mod0 = mod0)
}

# Combined protected design for ComBat (a single model matrix, covariates
# then the study variable, matching the vignette's modcombat / D-01 style).
sb_mod_combat <- function(cd_cov, study_component, sample_ids) {
  cd <- cd_cov
  rownames(cd) <- sample_ids
  cd$.study_var <- study_component
  f <- stats::as.formula(paste("~", paste(c(names(cd_cov), ".study_var"), collapse = " + ")))
  mod <- stats::model.matrix(f, data = cd)
  sb_full_rank(mod, "the protected design (--covariates + --study-var)")
  # Which protected variable each column carries (for sb_joint_check's
  # messages); dropped again before the matrix reaches ComBat.
  tl <- c("(Intercept)", attr(stats::terms(f), "term.labels"))[attr(mod, "assign") + 1L]
  attr(mod, "sb_term") <- tl
  attr(mod, "sb_var") <- ifelse(tl == "(Intercept)", "(Intercept)", ifelse(tl == ".study_var", "--study-var", "--covariates"))
  mod
}

# Joint design check (PACK S1 P-2; S4 F2), combat/combat_seq only, run
# BEFORE any sva call. It rebuilds exactly the design ComBat and ComBat_seq
# test internally (sva 3.60.0 source: `batchmod <- model.matrix(~-1 +
# batch)`; `design <- cbind(batchmod, mod)`; columns that are all 1 -- the
# intercept -- dropped; `qr(design)$rank < ncol(design)` -> the package's
# own untyped stop "The covariate is confounded with batch" / "At least one
# covariate is confounded with batch"), from the protected design `prot`
# (intercept + --covariates + --study-var, sb_mod_combat()), and decides
# per column whether its coefficient is estimable (sb_estimable_cols).
# Outcomes: no study-variable coefficient estimable -> full confounding;
# some but not all -> a study-variable contrast is not estimable; all study
# columns estimable but the design is still rank deficient -> a covariate
# is confounded with the batch. All three are typed OS_INVALID_DESIGN stops.
# A full-rank design with empty batch x study-variable cells is "partial":
# every study-variable contrast was checked estimable, but some rest on the
# additive batch model (SB-05 warning; reported, never blocking).

# Coefficient j of X is estimable iff the unit vector e_j lies in the row
# space of X, i.e. is orthogonal to every null vector of X.
sb_estimable_cols <- function(X, tol = 1e-8) {
  s <- svd(X, nu = 0, nv = ncol(X))
  r <- sum(s$d > max(s$d) * 1e-10)
  est <- rep(TRUE, ncol(X))
  if (r < ncol(X)) {
    nul <- s$v[, (r + 1):ncol(X), drop = FALSE]
    est <- apply(abs(nul), 1, max) < tol
  }
  stats::setNames(est, colnames(X))
}

sb_joint_check <- function(batch_factor, prot, study_component) {
  batchmod <- stats::model.matrix(~ -1 + batch_factor)
  colnames(batchmod) <- paste0("batch:", levels(batch_factor))
  var_of <- c(rep("--batch", ncol(batchmod)), attr(prot, "sb_var"))
  design <- cbind(batchmod, prot)
  keep <- !apply(design, 2, function(x) all(x == 1))
  design <- design[, keep, drop = FALSE]; var_of <- var_of[keep]
  rank <- qr(design)$rank
  est <- sb_estimable_cols(design)
  is_study <- var_of == "--study-var"
  if (!any(est[is_study])) {
    stop(paste0("OS_INVALID_DESIGN: --batch is completely confounded with --study-var (no study-variable coefficient is ",
               "estimable once the batch is in the design); the contrast of interest is not estimable. Redesign the ",
               "study (a batch cannot equal, or perfectly predict, the study variable)."), call. = FALSE)
  }
  if (!all(est[is_study])) {
    bad <- sub("^[.]study_var", "", colnames(design)[is_study & !est])
    stop(sprintf(paste0("OS_INVALID_DESIGN: --batch and --study-var are partially confounded so that the study-variable ",
                        "coefficient(s) %s (against the reference level) are NOT estimable jointly with the batch%s: those levels ",
                        "occur only inside batches that no other level shares. ComBat/ComBat_seq cannot protect them. Redesign, merge ",
                        "levels, or drop the samples of the non-estimable level(s)."),
                 paste(bad, collapse = ", "), if (any(var_of == "--covariates")) " (given --covariates)" else ""), call. = FALSE)
  }
  if (rank < ncol(design)) {
    bad <- unique(attr(prot, "sb_term")[match(colnames(design)[!est & var_of == "--covariates"], colnames(prot))])
    stop(sprintf(paste0("OS_INVALID_DESIGN: --covariates %s confounded with --batch (the joint protected design batch + ",
                        "covariates + study variable has rank %d of %d columns, so ComBat/ComBat_seq would stop). Every ",
                        "--study-var coefficient is estimable; drop the confounded covariate(s) -- the batch already absorbs them."),
                 paste(bad, collapse = ", "), rank, ncol(design)), call. = FALSE)
  }
  cross <- NULL; empty <- 0L
  if (is.factor(study_component)) {
    cross <- table(batch = as.character(batch_factor), study_var = as.character(study_component))
    empty <- sum(cross == 0)
  }
  list(status = if (empty > 0) "partial" else "ok", rank = rank, n_cols = ncol(design), empty_cells = as.integer(empty),
       study_estimable = TRUE, n_study_cols = sum(is_study),
       estimability_check = sprintf("joint design batch + covariates + study variable: rank %d of %d columns; all %d study-variable coefficient(s) estimable",
                                    rank, ncol(design), sum(is_study)))
}

# p-1 indicator columns per covariate level (Rd note under ComBat_seq's
# covar_mod / the sva vignette's "give ComBat p-1 indicator variables for
# this covariate"); NULL when there are no --covariates.
sb_covar_mod <- function(cd_cov, sample_ids) {
  if (!ncol(cd_cov)) return(NULL)
  rownames(cd_cov) <- sample_ids
  f <- stats::as.formula(paste("~", paste(names(cd_cov), collapse = " + ")))
  mm <- stats::model.matrix(f, data = cd_cov)
  mm[, setdiff(colnames(mm), "(Intercept)"), drop = FALSE]
}

# ---------------------------------------------------------------------------
# ComBat empirical-Bayes prior diagnostic (PACK F "ComBat prior plots"; S4 F4)
# ---------------------------------------------------------------------------
# ComBat(prior.plots = TRUE) draws this with base graphics, which the suite's
# figure layer does not allow, so prior.plots stays FALSE and the module
# recomputes the SAME quantities in base R, line for line after the sva
# 3.60.0 source (printed by deparse(sva::ComBat) in the locked container,
# acceptance/exemplars/sva-batch/_s4/probe1.log), for the path this module
# runs (par.prior = TRUE, mean.only = FALSE, ref.batch = NULL, no missing
# values -- os_read_matrix() refuses NA, so ComBat's Beta.NA branch is
# unreachable):
#   rows with zero variance inside a batch are set aside (not adjusted);
#   design <- cbind(model.matrix(~ -1 + batch), mod) without all-one columns;
#   B.hat <- solve(crossprod(design), tcrossprod(t(design), dat));
#   grand.mean <- crossprod(n.batches / n.array, B.hat[1:n.batch, ]);
#   var.pooled <- ((dat - t(design %*% B.hat))^2) %*% rep(1 / n.array, n.array);
#   stand.mean <- grand.mean + non-batch part of design %*% B.hat;
#   s.data <- (dat - stand.mean) / sqrt(var.pooled);
#   gamma.hat <- solve(crossprod(batch.design), tcrossprod(t(batch.design), s.data));
#   delta.hat[i, ] <- rowVars(s.data[, batch i])   (genefilter rowVars, n - 1);
#   gamma.bar <- rowMeans(gamma.hat); t2 <- rowVars(gamma.hat);
#   a.prior <- apply(delta.hat, 1, aprior); b.prior <- apply(delta.hat, 1, bprior)
#     with aprior(d) = (2 s2 + m^2) / s2, bprior(d) = (m s2 + m^3) / s2, m = mean(d), s2 = var(d).
# Prior curves on ComBat's own grid: 100 points spanning density(<estimates>)$x;
# gamma: dnorm(x, gamma.bar, sqrt(t2)); delta: inverse gamma density
# b^a / Gamma(a) x^(-a-1) exp(-b / x) (sva:::dinvgamma), evaluated on the log
# scale so a large shape a cannot overflow gamma(a). Every batch is shown
# (ComBat's own plot shows only the first). The smoke test checks these
# values against ComBat's internals captured with trace() and reproduces
# ComBat's adjusted matrix from them.
.sb_rowvars <- function(x) rowSums((x - rowMeans(x))^2) / (ncol(x) - 1)

sb_combat_prior <- function(dat, batch, mod) {
  dat <- as.matrix(dat); batch <- as.factor(batch)
  zero <- Reduce(union, lapply(levels(batch), function(b) {
    if (sum(batch == b) > 1) which(apply(dat[, batch == b, drop = FALSE], 1, function(x) stats::var(x) == 0)) else integer(0)
  }))
  keep <- setdiff(seq_len(nrow(dat)), zero)
  dat <- dat[keep, , drop = FALSE]
  batchmod <- stats::model.matrix(~ -1 + batch)
  n.batch <- nlevels(batch)
  batches <- lapply(levels(batch), function(l) which(batch == l))
  n.batches <- vapply(batches, length, integer(1)); n.array <- sum(n.batches)
  design <- cbind(batchmod, mod)
  design <- as.matrix(design[, !apply(design, 2, function(x) all(x == 1)), drop = FALSE])
  B.hat <- solve(crossprod(design), tcrossprod(t(design), as.matrix(dat)))
  grand.mean <- crossprod(n.batches / n.array, B.hat[1:n.batch, , drop = FALSE])
  var.pooled <- ((dat - t(design %*% B.hat))^2) %*% rep(1 / n.array, n.array)
  stand.mean <- t(grand.mean) %*% t(rep(1, n.array))
  tmp <- design; tmp[, 1:n.batch] <- 0
  stand.mean <- stand.mean + t(tmp %*% B.hat)
  s.data <- (dat - stand.mean) / (sqrt(var.pooled) %*% t(rep(1, n.array)))
  batch.design <- design[, 1:n.batch, drop = FALSE]
  gamma.hat <- solve(crossprod(batch.design), tcrossprod(t(batch.design), as.matrix(s.data)))
  delta.hat <- do.call(rbind, lapply(batches, function(i) .sb_rowvars(s.data[, i, drop = FALSE])))
  gamma.bar <- rowMeans(gamma.hat)
  t2 <- .sb_rowvars(gamma.hat)
  a.prior <- apply(delta.hat, 1, function(d) { m <- mean(d); s2 <- stats::var(d); (2 * s2 + m^2) / s2 })
  b.prior <- apply(delta.hat, 1, function(d) { m <- mean(d); s2 <- stats::var(d); (m * s2 + m^3) / s2 })
  lv <- levels(batch)
  emp <- do.call(rbind, lapply(seq_len(n.batch), function(i) rbind(
    data.frame(batch = lv[i], parameter = "gamma", value = gamma.hat[i, ], stringsAsFactors = FALSE),
    data.frame(batch = lv[i], parameter = "delta", value = delta.hat[i, ], stringsAsFactors = FALSE))))
  grid <- function(v) { d <- stats::density(v); seq(min(d$x), max(d$x), length = 100) }
  dinvgamma_log <- function(x, shape, rate) {
    out <- numeric(length(x)); pos <- x > 0   # sva:::dinvgamma: 0 for x <= 0 (no log of a non-positive grid point)
    out[pos] <- exp(shape * log(rate) - lgamma(shape) - (shape + 1) * log(x[pos]) - rate / x[pos])
    out
  }
  prior <- do.call(rbind, lapply(seq_len(n.batch), function(i) {
    xg <- grid(gamma.hat[i, ]); xd <- grid(delta.hat[i, ])
    rbind(data.frame(batch = lv[i], parameter = "gamma", x = xg, density = stats::dnorm(xg, gamma.bar[i], sqrt(t2[i])), stringsAsFactors = FALSE),
          data.frame(batch = lv[i], parameter = "delta", x = xd, density = dinvgamma_log(xd, a.prior[i], b.prior[i]), stringsAsFactors = FALSE))
  }))
  hyper <- data.frame(batch = lv, n_samples = n.batches, gamma_bar = gamma.bar, tau2 = t2, a_prior = a.prior, b_prior = b.prior,
                      n_features = nrow(dat), n_features_set_aside = length(zero), stringsAsFactors = FALSE)
  list(gamma.hat = gamma.hat, delta.hat = delta.hat, gamma.bar = gamma.bar, t2 = t2, a.prior = a.prior, b.prior = b.prior,
       s.data = s.data, var.pooled = var.pooled, stand.mean = stand.mean, batch.design = batch.design, batches = batches,
       keep = keep, emp = emp, prior = prior, hyper = hyper)
}

# Human-readable model formulas with the user's own column names (F3). The
# engine builds them with the internal name ".study_var"; the columns and
# their order are the same (covariates first, then the study variable).
sb_model_formulas <- function(method, a) {
  sv <- a[["study-var"]]; cv <- a$covariates
  rhs_full <- paste(c(cv, sv), collapse = " + ")
  rhs_null <- if (length(cv)) paste(cv, collapse = " + ") else "1"
  if (method == "combat") {
    list(protected_design = sprintf("mod = model.matrix(~ %s)", rhs_full),
         fitted_model = sprintf("~ -1 + %s + %s (ComBat binds the batch indicators model.matrix(~ -1 + %s) to mod and drops mod's intercept)", a$batch, rhs_full, a$batch),
         null_model = NA_character_)
  } else if (method == "combat_seq") {
    list(protected_design = sprintf("group = %s; covar_mod = %s", sv, if (length(cv)) sprintf("p-1 indicator columns of model.matrix(~ %s)", paste(cv, collapse = " + ")) else "NULL"),
         fitted_model = sprintf("~ -1 + %s + %s (ComBat_seq full model, full_mod = TRUE: batch indicators + model.matrix(~ group) + covar_mod, intercept dropped)", a$batch, rhs_full),
         null_model = NA_character_)
  } else {
    list(protected_design = sprintf("mod = model.matrix(~ %s)", rhs_full),
         fitted_model = sprintf("full model ~ %s", rhs_full),
         null_model = sprintf("null model ~ %s", rhs_null))
  }
}

# ---------------------------------------------------------------------------
# Compute
# ---------------------------------------------------------------------------
# a: parsed args. mat: feature x sample numeric matrix (raw counts for
# combat_seq/svaseq, log-scale/normalized for combat/sva). st: aligned
# sample table (rownames = sample ids, matrix column order).
sva_batch_compute <- function(mat, st, a, seed) {
  method <- a$method
  sample_ids <- colnames(mat)
  batch_factor <- sb_batch_factor(st, a$batch)
  study_component <- sb_study_component(st, a[["study-var"]], a[["study-var-type"]])
  cd_cov <- sb_covariate_frame(st, a$covariates)
  # Joint design with ALL protected variables, validated before any sva call
  # (F2): known batch -> sb_joint_check on batch + covariates + study
  # variable; sva/svaseq (no batch) -> sb_mod_mod0's full-rank checks of
  # mod/mod0 below (the full model carries every protected variable).
  confound <- list(status = "not_applicable", rank = NA_integer_, n_cols = NA_integer_, empty_cells = NA_integer_,
                   study_estimable = NA, n_study_cols = NA_integer_, estimability_check = NA_character_)
  prot <- NULL
  if (method %in% SB_KNOWN_BATCH_METHODS) {
    prot <- sb_mod_combat(cd_cov, study_component, sample_ids)
    confound <- sb_joint_check(batch_factor, prot, study_component)
    attr(prot, "sb_term") <- NULL; attr(prot, "sb_var") <- NULL
  }

  n.sv <- NA_integer_; sv <- NULL; mod <- NULL; mod0 <- NULL; prior_diag <- NULL
  # F3: every result-affecting argument is taken from ONE list per call, so
  # the batch report, the results JSON and the Methods draft print exactly
  # the values the call received (sb_models_params()).
  calls <- list()

  if (method == "combat") {
    mod <- prot
    ca <- list(par.prior = TRUE, prior.plots = FALSE, mean.only = FALSE, ref.batch = NULL)
    corrected <- sva::ComBat(dat = mat, batch = batch_factor, mod = mod, par.prior = ca$par.prior, prior.plots = ca$prior.plots,
                             mean.only = ca$mean.only, ref.batch = ca$ref.batch, BPPARAM = BiocParallel::SerialParam())
    calls$ComBat <- ca
    # PACK F prior diagnostic (F4): only on this parametric ComBat path
    # (par.prior = TRUE, mean.only = FALSE); ComBat_seq here fits no prior
    # (shrink = FALSE) and sva/svaseq estimate no batch-effect prior.
    prior_diag <- sb_combat_prior(mat, batch_factor, mod)
  } else if (method == "combat_seq") {
    group <- study_component   # already a factor: continuous is refused for combat_seq (sb_check_method_args)
    covar_mod <- sb_covar_mod(cd_cov, sample_ids)
    ca <- list(full_mod = TRUE, shrink = FALSE, shrink.disp = FALSE, gene.subset.n = NULL)
    corrected <- sva::ComBat_seq(counts = mat, batch = batch_factor, group = group, covar_mod = covar_mod,
                                 full_mod = ca$full_mod, shrink = ca$shrink, shrink.disp = ca$shrink.disp, gene.subset.n = ca$gene.subset.n)
    storage.mode(corrected) <- "integer"
    calls$ComBat_seq <- c(ca, list(covar_mod_columns = if (is.null(covar_mod)) character(0) else colnames(covar_mod)))
  } else {
    mm <- sb_mod_mod0(cd_cov, study_component, sample_ids)
    mod <- mm$mod; mod0 <- mm$mod0
    confound$study_estimable <- TRUE
    confound$estimability_check <- sprintf(paste0("full model (covariates + study variable) rank %d of %d columns, null model rank %d of %d; ",
                                                  "all study-variable coefficients estimable (no known batch in this path)"),
                                           qr(mod)$rank, ncol(mod), qr(mod0)$rank, ncol(mod0))
    na <- list(method = a[["num-sv-method"]], vfilter = NULL, B = 20L, seed = seed)
    n.sv <- sva::num.sv(dat = mat, mod = mod, method = na$method, vfilter = na$vfilter, B = na$B, seed = na$seed)
    calls$num.sv <- na
    sa <- list(controls = NULL, method = "irw", vfilter = NULL, B = 5L, numSVmethod = "be")
    if (method == "sva") {
      svobj <- sva::sva(dat = mat, mod = mod, mod0 = mod0, n.sv = n.sv, controls = sa$controls, method = sa$method,
                        vfilter = sa$vfilter, B = sa$B, numSVmethod = sa$numSVmethod)
      calls$sva <- c(sa, list(n.sv = n.sv))
    } else {
      sa$constant <- 1
      svobj <- sva::svaseq(dat = mat, mod = mod, mod0 = mod0, n.sv = n.sv, controls = sa$controls, method = sa$method,
                           vfilter = sa$vfilter, B = sa$B, numSVmethod = sa$numSVmethod, constant = sa$constant)
      calls$svaseq <- c(sa, list(n.sv = n.sv))
    }
    sv <- svobj$sv
    if (is.null(sv)) sv <- matrix(numeric(0), nrow = ncol(mat), ncol = 0)
    rownames(sv) <- sample_ids
    colnames(sv) <- if (ncol(sv)) sprintf("SV%d", seq_len(ncol(sv))) else character(0)
    # Display-only correction (deseq2-qc P-3 cross-reference): protect the
    # full biological design, regress out the estimated surrogate variables
    # as covariates. batch/batch2/group are explicitly NULL: there is no
    # known batch in this path, and design (never NULL) carries the
    # protected model instead of group.
    corrected <- if (ncol(sv) > 0) {
      ra <- list(batch = NULL, batch2 = NULL, group = NULL)
      calls$removeBatchEffect <- c(ra, list(covariates = colnames(sv), design = "full model (mod)"))
      limma::removeBatchEffect(x = mat, batch = ra$batch, batch2 = ra$batch2, covariates = sv, design = mod, group = ra$group)
    } else {
      mat   # nothing estimated to remove; the display matrix is the input unchanged (SB-06 warns)
    }
  }

  list(method = method, mat_before = mat, corrected = corrected, mod = mod, mod0 = mod0, n.sv = n.sv, sv = sv,
       batch_factor = batch_factor, study_component = study_component, confound = confound, calls = calls, prior_diag = prior_diag,
       models = sb_model_formulas(method, a),
       n_samples = ncol(mat), n_features = nrow(mat), sample_ids = sample_ids)
}
