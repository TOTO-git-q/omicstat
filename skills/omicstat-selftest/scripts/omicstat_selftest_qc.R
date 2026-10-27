# omicstat_selftest_qc.R -- qc layer of module omicstat-selftest. ASCII only on purpose.
#
# One row per rule ST-01..ST-08 (references/qc-rules.md), triggered or not,
# written to qc/qc_results.csv in the "id / severity / triggered / blocking /
# message / action / evidence" dialect that mcp/publication.py scan_qc()
# normalises. Severities: blocker (blocking = TRUE), error, warning, info.
# A check FAILS (and --strict exits non-zero) when a blocker or error rule
# is triggered; warnings never fail --strict.

ST_FAIL_SEVERITIES <- c("blocker", "error")

.st_rule <- function(id, check, triggered, severity, message, action, evidence = "environment_report.md") {
  data.frame(id = id, check = check, severity = severity,
             triggered = isTRUE(triggered), blocking = isTRUE(triggered) && identical(severity, "blocker"),
             message = message, action = if (triggered) action else "", evidence = evidence,
             stringsAsFactors = FALSE)
}

.st_mm <- function(v) { p <- tryCatch(package_version(v), error = function(e) NULL); if (is.null(p)) NA_character_ else paste(p$major, p$minor, sep = ".") }

omicstat_selftest_qc <- function(res) {
  pr <- res$probe
  rows <- list()

  # ST-01 R version vs the pin (major.minor must match; patch = warning)
  if (is.na(pr$r_pin)) {
    rows[[1]] <- .st_rule("ST-01", "r_version", TRUE, "error",
                          "env/r-env.json could not be read, so the R version pin is unknown.",
                          "Run the self-test from an omicstat checkout (the module must sit in <suite>/skills/).")
  } else if (!identical(.st_mm(pr$r_version), .st_mm(pr$r_pin))) {
    rows[[1]] <- .st_rule("ST-01", "r_version", TRUE, "error",
                          sprintf("R %s does not match the pinned R %s (major.minor must match).", pr$r_version, pr$r_pin),
                          "Use the omicstat-r container, or build the native environment with R of the pinned major.minor (env/native/setup_native.R).")
  } else if (!identical(pr$r_version, pr$r_pin)) {
    rows[[1]] <- .st_rule("ST-01", "r_version", TRUE, "warning",
                          sprintf("R %s differs from the pinned R %s at patch level only.", pr$r_version, pr$r_pin),
                          "Acceptable for the native tier; byte-level golden checks apply to the container only.")
  } else {
    rows[[1]] <- .st_rule("ST-01", "r_version", FALSE, "error", sprintf("R %s matches the pin.", pr$r_version), "")
  }

  # ST-02 Bioconductor release
  if (!pr$bioc_installed || is.na(pr$bioc_version)) {
    sev <- if (identical(pr$mode, "container")) "error" else "warning"
    rows[[2]] <- .st_rule("ST-02", "bioconductor", TRUE, sev,
                          sprintf("BiocManager is not installed (or its version is unreadable); Bioconductor %s cannot be confirmed.", pr$bioc_pin),
                          "Expected outside the container before env/native/setup_native.R has run; inside the container, rebuild the image.")
  } else if (!is.na(pr$bioc_pin) && !identical(pr$bioc_version, as.character(pr$bioc_pin))) {
    rows[[2]] <- .st_rule("ST-02", "bioconductor", TRUE, "error",
                          sprintf("Bioconductor %s does not match the pinned release %s.", pr$bioc_version, pr$bioc_pin),
                          "Use the omicstat-r container or rebuild the native library with env/native/setup_native.R.")
  } else {
    rows[[2]] <- .st_rule("ST-02", "bioconductor", FALSE, "error", sprintf("Bioconductor %s matches the pin.", pr$bioc_version), "")
  }

  # ST-03 UTF-8 character locale
  if (pr$utf8_start) {
    rows[[3]] <- .st_rule("ST-03", "utf8_locale", FALSE, "warning", sprintf("LC_CTYPE %s is UTF-8.", pr$lc_ctype_start), "")
  } else if (pr$utf8_now) {
    rows[[3]] <- .st_rule("ST-03", "utf8_locale", TRUE, "warning",
                          sprintf("LC_CTYPE was %s (not UTF-8); the figure layer switched it to %s.", pr$lc_ctype_start, pr$lc_ctype_now),
                          "Set LANG/LC_ALL to C.UTF-8 (the container does) so every R session starts in UTF-8.")
  } else {
    rows[[3]] <- .st_rule("ST-03", "utf8_locale", TRUE, "error",
                          sprintf("LC_CTYPE %s is not UTF-8 and no UTF-8 locale could be selected.", pr$lc_ctype_start),
                          "Install a UTF-8 locale (C.UTF-8 or en_US.UTF-8); figure text needs one for the true minus sign.")
  }

  # ST-04 single-threaded numerics
  bad <- names(pr$threads)[pr$threads != "1"]
  rows[[4]] <- .st_rule("ST-04", "single_thread", length(bad) > 0, "warning",
                        if (length(bad)) sprintf("Not set to 1: %s.", paste(sprintf("%s='%s'", bad, pr$threads[bad]), collapse = ", "))
                        else "OMP_NUM_THREADS, OPENBLAS_NUM_THREADS and MKL_NUM_THREADS are 1.",
                        "Run through bin/omicstat-r-route.sh (it sets them) or export them as 1 before starting R.")

  # ST-05 figure font
  rows[[5]] <- .st_rule("ST-05", "font", !pr$font_resolvable, "error",
                        if (pr$font_resolvable) sprintf("Font '%s' is resolvable by systemfonts.", ST_FONT)
                        else sprintf("Font '%s' is not resolvable by systemfonts; figures fall back to another family.", ST_FONT),
                        "Install the Liberation fonts (fonts-liberation) and rebuild the font cache (fc-cache -f).")

  # ST-06 figure packages
  miss <- pr$packages$package[pr$packages$required & !pr$packages$loadable]
  rows[[6]] <- .st_rule("ST-06", "figure_packages", length(miss) > 0, "blocker",
                        if (length(miss)) sprintf("Required figure-layer package(s) not loadable: %s.", paste(miss, collapse = ", "))
                        else sprintf("All %d required figure-layer packages load.", sum(pr$packages$required)),
                        "Install the L7_figures layer (container) or re-run env/native/setup_native.R.")

  # ST-07 execution environment
  rows[[7]] <- .st_rule("ST-07", "execution_environment", identical(pr$mode, "unmanaged"), "error",
                        switch(pr$mode,
                               container = "Running inside the omicstat-r container (OMICSTAT_CONTAINER=1).",
                               native = sprintf("Running in the isolated native environment (OMICSTAT_R_LIBS=%s).", pr$native_library),
                               unmanaged = "Running in an unmanaged R session: neither the container (OMICSTAT_CONTAINER=1) nor the isolated native environment (OMICSTAT_R_LIBS)."),
                        "Start R through bin/omicstat-r-route.sh (docker) or with OMICSTAT_R_NATIVE=1 after env/native/setup_native.R.")

  # ST-08 library isolation (native mode only)
  if (identical(pr$mode, "native")) {
    leak <- pr$leaked_lib_paths
    rows[[8]] <- .st_rule("ST-08", "library_isolation", length(leak) > 0, "blocker",
                          if (length(leak)) sprintf("Library search path leaks outside the omicstat library: %s.", paste(leak, collapse = "; "))
                          else "Library search path is exactly the omicstat library plus the base library.",
                          "Start R with R_PROFILE_USER=env/native/Rprofile.omicstat (the router does this); remove R_LIBS/R_LIBS_USER overrides.")
  } else {
    rows[[8]] <- .st_rule("ST-08", "library_isolation", FALSE, "blocker",
                          if (identical(pr$mode, "container")) "Container mode: the image is the isolation boundary."
                          else "Not applicable outside the native environment; the library paths are listed in environment_report.md.", "")
  }

  qc <- do.call(rbind, rows)
  trig <- qc[qc$triggered, , drop = FALSE]
  sev_rank <- match(trig$severity, c("blocker", "error", "warning", "info"))
  list(table = qc, n_rules = nrow(qc), n_triggered = nrow(trig),
       failed = any(trig$severity %in% ST_FAIL_SEVERITIES),
       failed_ids = trig$id[trig$severity %in% ST_FAIL_SEVERITIES],
       worst = if (nrow(trig)) trig$id[order(sev_rank, trig$id)][1] else NA_character_,
       read_first = "environment_report.md")
}

write_qc_results <- function(qc, outdir) {
  dir.create(file.path(outdir, "qc"), recursive = TRUE, showWarnings = FALSE)
  path <- file.path(outdir, "qc", "qc_results.csv")
  out <- qc$table
  out$triggered <- ifelse(out$triggered, "TRUE", "FALSE")
  out$blocking <- ifelse(out$blocking, "TRUE", "FALSE")
  con <- file(path, open = "wb"); on.exit(close(con))
  utils::write.csv(out, con, row.names = FALSE, fileEncoding = "UTF-8", eol = "\n", quote = TRUE)
  invisible(path)
}
