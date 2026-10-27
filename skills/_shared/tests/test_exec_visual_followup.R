args <- commandArgs(FALSE)
here <- dirname(normalizePath(sub("^--file=", "", args[grepl("^--file=", args)][1])))
source(file.path(here, "../scripts/fig_all.R"))
source(file.path(here, "fixtures/fig_fixtures_exec_visual.R"))
out <- Sys.getenv("OMICSTAT_EXEC_VISUAL_OUT", file.path(tempdir(), "exec-visual-followup"))
dir.create(out, recursive = TRUE, showWarnings = FALSE)
n_checks <- 0L
check <- function(value, label) {
  if (!isTRUE(value)) stop(paste("FAIL", label), call. = FALSE)
  n_checks <<- n_checks + 1L; cat("PASS", label, "\n")
}
near <- function(a, b) isTRUE(all.equal(a, b, tolerance = 1e-13, check.attributes = FALSE))
sha <- function(p) digest::digest(file = p, algo = "sha256")
x <- fx_exec_visual()
p <- os_group_points(x$group, "unit", "Synthetic response", "bar")
m <- attr(p, "os_meta"); s <- m$data$summary_table
check(near(s$mean, c(4, 5)), "bar heights are original arithmetic means")
check(near(s$sd, c(sqrt(2.5), sqrt(.625))), "error bars use sample SD with n-1 denominator")
check(near(s$lower, s$mean - s$sd) && near(s$upper, s$mean + s$sd), "interval endpoints are mean +/- SD")
check(identical(s$n_units, c(5L, 5L)), "denominators count biological units, not technical wells")
check(identical(m$notes$summary_statistic, "arithmetic_mean") && identical(m$notes$error_type, "sample_standard_deviation"), "summary and interval semantics are explicit")
check(grepl("not confidence intervals or standard errors", m$caption, fixed = TRUE), "caption does not claim inferential uncertainty")
check(grepl("mean +/- SD", p$labels$subtitle, fixed = TRUE), "mean and SD are stated on the figure")
b <- ggplot2::ggplot_build(p)
check(nrow(b$data[[3]]) == nrow(x$group) && near(b$data[[3]]$y, x$group$value), "all biological-unit points retain actual values")
special <- data.frame(group = c("Singleton", "Pair", "Pair", "Constant", "Constant", "Below zero", "Below zero"),
  value = c(3, 1, 3, 2, 2, 0, 2), unit = paste0("SYN_EDGE_", 1:7))
sp <- os_group_points(special, "unit", "Synthetic response", "bar")
ss <- attr(sp, "os_meta")$data$summary_table; sb <- ggplot2::ggplot_build(sp)
check(is.na(ss$sd[1]) && identical(ss$interval_state[1], "not_estimable_n_lt_2"), "n=1 SD remains non-estimable")
check(nrow(sb$data[[1]]) == 4L && nrow(sb$data[[2]]) == 3L && nrow(sb$data[[3]]) == 7L, "singleton bar and point remain while its undefined interval is omitted")
check(near(ss$sd[2], sqrt(2)) && identical(ss$sd[3], 0), "n=2 and genuine zero-SD groups are retained")
check(ss$lower[4] < 0 && near(sb$data[[2]]$ymin[3], 1-sqrt(2)), "SD endpoints are not silently clipped at zero")
paired <- x$group; paired$unit <- rep(paste0("SYN_PAIR_",1:5), 2)
pairp <- os_group_points(paired, "unit", "Response", "bar")
check(identical(attr(pairp, "os_meta")$counts$n_units, 5L) && near(attr(pairp, "os_meta")$data$summary_table$n_units, c(5,5)), "paired IDs may occur once in each group without multiplying n")
bad <- rbind(x$group, x$group[1,])
check(grepl("OS_INVALID_INPUT", tryCatch(os_group_points(bad, "unit", "Response", "bar"), error=conditionMessage)), "duplicate unit/group is refused")
bad <- x$group; bad$value[1] <- NA_real_
check(grepl("OS_INVALID_INPUT", tryCatch(os_group_points(bad, "unit", "Response", "bar"), error=conditionMessage)), "missing values are refused rather than silently changing n")
box <- os_group_points(x$group, "unit", "Response", "box")
check(inherits(box$layers[[1]]$geom, "GeomBoxplot") && !any(vapply(box$layers, function(z) inherits(z$geom,"GeomErrorbar"), logical(1))), "boxplot estimator and whiskers stay unchanged")
cmp <- data.frame(group1="Synthetic A",group2="Synthetic B",p=.03,y=8)
compared <- os_group_points(x$group,"unit","Response","bar",comparisons=cmp,test="supplied Welch t")
check(identical(attr(compared,"os_meta")$notes$comparisons$p,cmp$p),"SD rendering does not recompute or change supplied comparison P values")
dense <- data.frame(dose=seq(.23,5.75,length.out=25));dense$response<-dense$dose/(dense$dose+1)
dense_grid <- data.frame(dose=seq(.23,5.75,length.out=101));dense_grid$predicted<-dense_grid$dose/(dense_grid$dose+1)
dt <- attr(os_standard_curve(dense,dense_grid,"synthetic units/mL","4PL",.25,5.5,journal="cell"),"os_meta")$notes$x_ticks
check(all(dt$breaks %in% dense$dose) && identical(range(dt$breaks),range(dense$dose)),"dense calibration ticks retain measured endpoints without invented decades")
check(setequal(dt$omitted_doses,setdiff(dense$dose,dt$breaks)) && isTRUE(dt$thinned),"every thinned measured concentration remains explicitly recorded")
bad_dose <- x$obs;bad_dose$dose[1]<-0
check(grepl("OS_INVALID_INPUT",tryCatch(os_standard_curve(bad_dose,x$grid,"units/mL","4PL",.5,100),error=conditionMessage)),"zero standards are refused rather than floored onto a log axis")
bad_dose$dose[1]<- -1
check(grepl("OS_INVALID_INPUT",tryCatch(os_standard_curve(bad_dose,x$grid,"units/mL","4PL",.5,100),error=conditionMessage)),"negative standards are refused")
for (j in c("nature", "cell")) {
  km <- fx_exec_visual_builders(j)$km(); km_meta <- attr(km, "os_meta")
  check(identical(km_meta$notes$layout, "compact_shared_time_axis_v2") && km_meta$notes$text_size_pt >= 7.5 &&
    near(km_meta$notes$risk_label_margin_mm, 2) &&
    near(as.numeric(km$theme$axis.text.y$margin[2]), 2) &&
    identical(km_meta$notes$risk_text_clipping, "off") && identical(km$coordinates$clip, "off"),
    paste(j, "KM uses larger text, separated risk-row labels and uncut boundary counts"))
  check(near(km_meta$notes$risk_panel_height_mm, 10.4) && km_meta$default_height_mm == 100, paste(j, "two-row risk panel uses 10.4 mm without shrinking canvas"))
  curve <- km$patches$plots[[1]]
  check(near(curve$data$time, x$curves$time) && near(curve$data$survival, x$curves$survival), paste(j, "KM estimates and times remain exactly supplied"))
  check(identical(curve$theme$legend.position, "top") && inherits(curve$theme$axis.text.x, "element_blank"), paste(j, "legend no longer consumes curve width and time axis is shared"))
  standard <- fx_exec_visual_builders(j)$standard_curve()
  ticks <- attr(standard, "os_meta")$notes$x_ticks
  check(near(ticks$width_mm,os_width_mm("single",j)),paste(j,"calibration tick budget uses the explicit journal, independent of global defaults"))
  check(near(ticks$tested_doses, sort(unique(x$obs$dose))) && all(ticks$breaks %in% x$obs$dose), paste(j, "calibration ticks come only from actually measured concentrations"))
  check(identical(ticks$labels, os_experiment_dose_labels(ticks$breaks)) && any(!ticks$breaks %in% 10^(-3:3)), paste(j, "non-decade measured values remain literal labels"))
  for (nm in names(fx_exec_visual_builders(j))) {
    f <- fx_exec_visual_builders(j)[[nm]]
    lint <- os_fig_lint(f(), j)
    check(!any(lint$severity %in% c("warning", "blocker")), paste(j,nm,"shared visual lint"))
    saved <- lapply(c("a", "b"), function(k) os_save_figure(f(), file.path(out, j, k, nm), journal=j, root=file.path(out,j,k)))
    check(identical(sha(saved[[1]]$files$png),sha(saved[[2]]$files$png)) &&
      identical(os_pdf_content_sha256(saved[[1]]$files$pdf),os_pdf_content_sha256(saved[[2]]$files$pdf)) &&
      identical(sha(saved[[1]]$spec),sha(saved[[2]]$spec)), paste(j,nm,"exact PNG/PDF/spec replay"))
    check(identical(saved[[1]]$spec_obj$evidence_refs[[1]]$status,"pending"), paste(j,nm,"owner visual approval remains pending"))
  }
}
baseline <- Sys.getenv("OMICSTAT_EXEC_VISUAL_BASELINE_SOURCE", "")
if (nzchar(baseline)) {
  before <- new.env(parent=globalenv())
  for (f in c("fig_mod_survival.R", "fig_mod_groupcomp.R", "fig_mod_calibration.R")) sys.source(file.path(baseline,f), envir=before)
  panel_dimensions <- function(p, journal) {
    file <- tempfile(fileext=".pdf")
    grDevices::cairo_pdf(file,width=os_width_mm("single",journal)/25.4,height=100/25.4,family=os_font_family())
    on.exit({grDevices::dev.off();unlink(file)})
    print(p);grid::grid.force()
    v <- grid::grid.ls(viewports=TRUE,grobs=FALSE,print=FALSE)$name
    names <- unique(v[grepl("^panel-[12]\\.",v)])
    do.call(rbind,lapply(names,function(name) {
      grid::seekViewport(name)
      size <- data.frame(panel=if(grepl("^panel-1",name)) "curve" else "risk",
        width_mm=grid::convertWidth(grid::unit(1,"npc"),"mm",valueOnly=TRUE),
        height_mm=grid::convertHeight(grid::unit(1,"npc"),"mm",valueOnly=TRUE))
      grid::upViewport(0);size
    }))
  }
  measured <- list()
  for (j in c("nature","cell")) for (nm in names(fx_exec_visual_builders(j,before))) {
    old <- fx_exec_visual_builders(j,before)[[nm]](); new <- fx_exec_visual_builders(j)[[nm]]()
    os_save_figure(old,file.path(out,"comparison",j,"before",nm),journal=j,root=file.path(out,"comparison",j,"before"))
    os_save_figure(new,file.path(out,"comparison",j,"after",nm),journal=j,root=file.path(out,"comparison",j,"after"))
    if (nm == "km") {
      a <- panel_dimensions(old,j); b <- panel_dimensions(new,j)
      check(b$width_mm[b$panel=="curve"] > a$width_mm[a$panel=="curve"] &&
        b$height_mm[b$panel=="curve"] > a$height_mm[a$panel=="curve"],paste(j,"measured curve panel is wider and taller on the same physical canvas"))
      a$journal<-j;a$version<-"before";b$journal<-j;b$version<-"after"
      measured[[j]]<-rbind(a,b)
    }
  }
  utils::write.csv(do.call(rbind,measured),file.path(out,"KM_PANEL_DIMENSIONS.csv"),row.names=FALSE)
}
dir.create(file.path(out,"tables"),showWarnings=FALSE)
for(nm in names(x)) utils::write.csv(x[[nm]],file.path(out,"tables",paste0(nm,".csv")),row.names=FALSE)
utils::write.csv(s,file.path(out,"tables","bar_summary.csv"),row.names=FALSE)
utils::write.csv(ss,file.path(out,"tables","bar_edge_summary.csv"),row.names=FALSE)
cat("ALL PASSED:", n_checks, "executor visual checks; fully synthetic source; owner review pending\n")
