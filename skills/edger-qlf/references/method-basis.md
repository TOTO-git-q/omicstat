# edger-qlf method basis

| Claim | Locked source |
|---|---|
| TMM normalization and design-aware expression filtering before fitting | edgeR User's Guide 4.4.4-4.4.6; filterByExpr.Rd; normLibSizes.Rd |
| New QL fit uses dispersion=NULL, legacy=FALSE, abundance.trend=TRUE; legacy=TRUE only to reproduce old analyses | glmQLFit.Rd Usage/Details; NEWS 4.0.0/4.2.0; PACK S1 P-1 |
| Robust QL prior uses robust=TRUE and winsor.tail.p=c(0.05,0.1) | edgeR User's Guide 4.4.7; PACK S1 P-2 |
| Default QL F-test and optional prespecified minimum-effect glmTreat are distinct hypotheses | glmQLFTest.Rd, glmTreat.Rd; PACK S1 P-3 |
| GSE60450 anchor: 15,969/27,179 genes after filtering; Mrgprf is the top row | edgeR User's Guide 4.4.4-4.4.8; PACK C |

## GSE60450 anchors: guide route and suite route (S4 correction of the earlier version attribution)

The earlier text attributed the difference between the guide printout and this module to edgeR 4.9.9 versus 4.10.5. That attribution was wrong. In the locked image (edgeR 4.10.5), the guide's own code (User's Guide 4.4: `y <- estimateDisp(y, design, robust=TRUE); fit <- glmQLFit(y, design, robust=TRUE)`) reproduces every printed value of the case study: `filterByExpr` 15,969/27,179, TMM factors, MDS dims 65 %/17 %, `y$common.dispersion` 0.0134 (0.0134413085635106), `fit$dispersion` 0.013 (0.0129556217857436), `head(fit$coefficients)`, both `topTags` tables, QLF Down/NotSig/Up 2607/10546/2816 and `glmTreat(lfc=log2(1.2))` 1533/12573/1863. The smoke test asserts these as printed anchors (C-guide).

`fit$dispersion` is a length-1 value: under the new QL method (`legacy = FALSE`, `dispersion = NULL`) `glmQLFit.default` estimates one NB dispersion with `estimateGLMCommonDisp` on the top `top.proportion` genes by AveLogCPM. It is not a QL dispersion; the QL dispersions are `s2.post` (squeezed) and `s2.prior` (trend).

The module follows the frozen S1 P-1 call set: `glmQLFit` receives the TMM DGEList without a previous `estimateDisp` (which runs only for the BCV display). `glmQLFit.DGEList` passes `y$AveLogCPM` to `glmQLFit.default`; `estimateDisp` caches AveLogCPM computed with its common dispersion (0.0134), while without it `glmQLFit.DGEList` computes `aveLogCPM(y)` with the aveLogCPM default dispersion 0.05. The two AveLogCPM vectors differ by up to 0.2674049. AveLogCPM chooses the genes for the scalar NB dispersion (suite 0.0129516892728812), enters the average QL dispersion and is the covariate of the QL prior trend. Result: the suite route gives QLF 2608/10546/2815 (max P difference to the guide route 0.002497297) and glmTreat 1535/12570/1864 (max P difference 0.002447250). Copying only the guide's AveLogCPM into the suite input reproduces the guide P values exactly (difference 0); giving only the guide's scalar dispersion does not. The estimator was not changed to chase the printout; whether PACK C (printed anchors "for S2") and S1 P-1 should be reconciled is an owner item (S4_FIXES.md).
