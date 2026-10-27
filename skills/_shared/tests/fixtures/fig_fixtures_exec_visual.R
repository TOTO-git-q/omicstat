# Entirely project-created numeric examples. No patient, public biological, or
# published-figure data. Values are deliberately simple and independently
# checkable; this fixture is not a scientific validation dataset.
fx_exec_visual <- function() {
  time <- c(0, 3, 6, 9, 12, 18, 24)
  curves <- data.frame(time = rep(time, 2),
    survival = c(1, .94, .88, .82, .76, .68, .60, 1, .97, .94, .90, .86, .81, .76),
    group = rep(c("Synthetic A", "Synthetic B"), each = length(time)),
    n_censor = c(0, 0, 1, 0, 0, 1, 0, 0, 1, 0, 0, 1, 0, 0))
  risk <- data.frame(time = rep(c(0, 6, 12, 18, 24), 2),
    n_risk = c(30, 26, 21, 16, 11, 30, 27, 24, 20, 15),
    group = rep(c("Synthetic A", "Synthetic B"), each = 5))
  group <- data.frame(group = rep(c("Synthetic A", "Synthetic B"), each = 5),
    value = c(2, 3, 4, 5, 6, 4, 4.5, 5, 5.5, 6), unit = paste0("SYN_UNIT_", seq_len(10)))
  doses <- c(.25, 1.25, 6.25, 31.25, 156.25)
  obs <- data.frame(dose = rep(doses, each = 2))
  obs$response <- obs$dose / (obs$dose + 6.25) + rep(c(-.01, .01), length(doses))
  grid <- data.frame(dose = 10^seq(log10(min(doses)), log10(max(doses)), length.out = 151))
  grid$predicted <- grid$dose / (grid$dose + 6.25)
  list(curves = curves, risk = risk, group = group, obs = obs, grid = grid)
}

fx_exec_visual_builders <- function(journal = NULL, functions = parent.frame()) {
  x <- fx_exec_visual()
  list(km = function() get("os_km", envir = functions)(x$curves, x$risk, "months", journal = journal),
    group_bar = function() get("os_group_points", envir = functions)(x$group, "unit", "Synthetic response", "bar", journal = journal),
    standard_curve = function() get("os_standard_curve", envir = functions)(x$obs, x$grid, "synthetic units/mL", "4PL", .5, 100, journal = journal))
}
