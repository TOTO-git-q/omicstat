# S4 probe 3: vignette sec 4-6 chain with the vignette's own printed n.sv = 2; leek zero-threshold ties. ASCII only.
suite <- normalizePath(".")
source(file.path(suite, "skills", "_shared", "scripts", "module_kit.R"))
bladderEset <- os_acceptance_data(suite, "bladderbatch", "bladderdata")
suppressMessages({ library(sva); library(limma); library(Biobase) })
pheno = pData(bladderEset); edata = exprs(bladderEset)
mod = model.matrix(~as.factor(cancer), data=pheno)
mod0 = model.matrix(~1,data=pheno)
n.sv = 2
svobj = sva(edata,mod,mod0,n.sv=n.sv)
modSv = cbind(mod,svobj$sv)
mod0Sv = cbind(mod0,svobj$sv)
pValuesSv = f.pvalue(edata,modSv,mod0Sv)
qValuesSv = p.adjust(pValuesSv,method="BH")
fit = lmFit(edata,modSv)
contrast.matrix <- cbind("C1"=c(-1,1,0,rep(0,svobj$n.sv)),"C2"=c(0,-1,1,rep(0,svobj$n.sv)),"C3"=c(-1,0,1,rep(0,svobj$n.sv)))
fitContrasts = contrasts.fit(fit,contrast.matrix)
eb = eBayes(fitContrasts)
tt <- topTableF(eb, adjust="BH")
print(tt)
print(tt, digits = 15)
cat("f.pvalue vs limma ordinary F? head pValuesSv:\n"); print(pValuesSv[rownames(tt)], digits = 15)
# leek internals: eigenvalues of wm near the a = 0 threshold
dat <- edata; dims <- dim(dat); n <- floor(dims[1]/10)
P <- (diag(dims[2]) - mod %*% solve(t(mod) %*% mod) %*% t(mod))
for (j in 1:10) {
  dats <- dat[1:(j * n), ]
  ee <- eigen(t(dats) %*% dats); sigbar <- ee$values[dims[2]]/(j * n)
  R <- dats %*% P; wm <- (1/(j * n)) * t(R) %*% R - P * sigbar
  ev <- eigen(wm)$values
  cat(sprintf("j=%d smallest 5 eigenvalues of wm: %s ; count > 0: %d\n", j, paste(signif(tail(ev, 5), 4), collapse = " "), sum(ev > 0)))
}
cat("PROBE3 DONE\n")
