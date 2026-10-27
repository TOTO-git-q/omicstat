here <- dirname(normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1])))
mod <- dirname(here); shared <- file.path(mod, "..", "_shared", "scripts")
for (f in c("module_kit.R", "basic_stats_io.R", "calls_check.R")) source(file.path(shared, f))
source(file.path(mod, "scripts/omicstat_groupcompare_core.R"))
check <- function(ok, msg) { if (!isTRUE(ok)) stop(paste("FAIL:", msg)); cat("PASS:", msg, "\n") }
refuse <- function(expr, code) { got <- tryCatch({force(expr); "NO_ERROR"}, error = conditionMessage); check(grepl(code, got, fixed = TRUE), paste("refusal", code, got)) }
tmp <- tempfile(); dir.create(tmp)
write <- function(d, name) {p <- file.path(tmp, name); write.csv(d, p, row.names = FALSE); p}
d <- datasets::sleep; input <- write(d, "sleep.csv"); cp <- write(data.frame(contrast = "1-2", group1 = "1", group2 = "2"), "cp.csv")
a <- list(input = input, `response-col` = "extra", `group-col` = "group", `unit-col` = "ID", `group-order` = "1,2", design = "paired",
 `technical-policy` = "reject", comparisons = cp, `pairwise-test` = "paired-t", omnibus = "none", `rank-method` = "not-applicable",
 adjust = "none", `family-size` = 1L, `ci-level` = .9, display = "box", journal = "nature")
x <- omicstat_groupcompare_compute(a); check(abs(x$tables$effect_table$estimate + 1.58) < 1e-12, "paired mean difference and declared sign")
b <- a; b$input <- write(d[rev(seq_len(nrow(d))), ], "reverse.csv"); y <- omicstat_groupcompare_compute(b)
check(identical(x$tables, y$tables), "row-order independent paired matching")
tech <- rbind(transform(d, well = "w1", extra = extra - 1), transform(d, well = "w2", extra = extra + 1))
b <- a; b$input <- write(tech, "tech.csv"); b[["technical-policy"]] <- "mean"; b[["technical-col"]] <- "well"
y <- omicstat_groupcompare_compute(b); check(all(y$tables$biological_units$n_technical == 2) && identical(x$tables$tests, y$tables$tests), "technical means preserve biological n and inference")
b[["technical-col"]] <- NULL; refuse(omicstat_groupcompare_compute(b), "OS_MISSING_PARAMETER")
b <- a; b$design <- "independent"; refuse(omicstat_groupcompare_compute(b), "OS_INVALID_DESIGN")
b <- a; b$input <- write(d[-1, ], "missing.csv"); refuse(omicstat_groupcompare_compute(b), "OS_INVALID_DESIGN")
b <- a; b$input <- write(rbind(d,d[1, ]), "dupe.csv"); refuse(omicstat_groupcompare_compute(b), "OS_INVALID_DESIGN")
b <- a; b[["pairwise-test"]] <- "paired-wilcoxon"; b[["rank-method"]] <- "exact"; refuse(omicstat_groupcompare_compute(b), "OS_INVALID_DESIGN")
b[["rank-method"]] <- "asymptotic"; y <- omicstat_groupcompare_compute(b)
check(is.finite(y$tables$tests$p_value) && is.null(y$tables$effect_table), "rank test does not fabricate mean-effect interval")
b <- a; b$comparisons <- NULL; b[["pairwise-test"]] <- "none"; b$omnibus <- "friedman"
y <- omicstat_groupcompare_compute(b); check(is.finite(y$tables$tests$p_value), "complete-block Friedman executes")
# Independent three-group data, unequal variances and biological identifiers.
z <- data.frame(ID = paste0("s",1:18), group = rep(c("a","b","c"),each=6), extra = c(1,2,3,4,5,6,2,4,6,8,10,12,1,3,4,7,9,15))
b <- a; b$input <- write(z,"ind.csv"); b$design <- "independent"; b[["group-order"]] <- "a,b,c"
b$comparisons <- write(data.frame(contrast=c("a-b","a-c"),group1=c("a","a"),group2=c("b","c")),"multi.csv")
b[["family-size"]] <- 4L; b$adjust <- "holm"
for (test in c("welch","student")) {
 b[["pairwise-test"]] <- test
 for (omni in c("anova","welch-anova","kruskal")) {
  b$omnibus <- omni; y <- omicstat_groupcompare_compute(b)
  check(nrow(y$tables$tests)==3 && isTRUE(all.equal(y$tables$tests$p_adjusted,p.adjust(y$tables$tests$p_value,method="holm",n=4))), paste(test,omni,"complete declared family"))
 }
}
b[["pairwise-test"]] <- "wilcoxon"; b[["rank-method"]] <- "asymptotic"; y <- omicstat_groupcompare_compute(b)
check(all(is.finite(y$tables$tests$p_value)), "independent asymptotic Wilcoxon executes")
b[["rank-method"]] <- "exact"; refuse(omicstat_groupcompare_compute(b), "OS_INVALID_DESIGN")
b <- a; b$input <- write(transform(d,extra=0),"constant.csv"); refuse(omicstat_groupcompare_compute(b),"OS_INVALID_DESIGN")
b <- a; b[["family-size"]] <- 1; b$omnibus <- "friedman"; refuse(omicstat_groupcompare_compute(b),"OS_INVALID_DESIGN")
# Exact modes with no ties, including a deliberately reversed input order.
e <- data.frame(ID=rep(paste0("u",1:6),2),group=rep(c("1","2"),each=6),extra=c(0,2,5,9,14,20,1,5,11,19,29,41))
b <- a; b$input <- write(e,"exact-paired.csv"); b[["pairwise-test"]] <- "paired-wilcoxon"; b[["rank-method"]] <- "exact"
check(is.finite(omicstat_groupcompare_compute(b)$tables$tests$p_value),"paired exact Wilcoxon executes")
e$ID <- paste0("u",seq_len(nrow(e))); e$extra <- seq_len(nrow(e)); b$input <- write(e,"exact-independent.csv"); b$design <- "independent"; b[["pairwise-test"]] <- "wilcoxon"
check(is.finite(omicstat_groupcompare_compute(b)$tables$tests$p_value),"independent exact Wilcoxon executes")
collision <- data.frame(id=c("a.b","a"),g=c("c","b.c"),v=c(1,9),w="w")
check(nrow(os_basic_units(collision,"v","g","id","mean","w"))==2,"punctuation cannot collide in technical grouping keys")
cc <- check_calls(list.files(file.path(mod,"scripts"),pattern="\\.R$",full.names=TRUE),file.path(mod,"scripts/calls_registry.json"))
check(cc$ok,paste("call registry",paste(cc$problems,collapse=";")))
check(check_default_drift(file.path(mod,"scripts/calls_registry.json"))$ok,"actual native formal defaults")
check(!file.exists("Rplots.pdf"),"no device leak")
cat("SMOKE PASSED: biological-unit group comparisons\n")
unlink(tmp,recursive=TRUE)
