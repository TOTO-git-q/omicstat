# fix_r 最终修复报告

工作树 `/home/<user>/omic-fix-r`，分支 `fix/m3m4-r`。遵循 `fin_common.md` 和闭合修复顺序；启动时发现 lane worklog，承接已完成 seurat-cluster / seurat-integrate，从 seurat-markers 继续。没有执行 git commit/push；外部 helper 使用 worklog 最后一行提交。

全部运行使用 `omicstat-r:2026.10.1`、non-root、`docker run --rm --network none`，没有安装包、下载参考数据、改镜像或 vendor。日志和原生探针在 `/home/<user>/omic-sol61/fix_r/`，统一运行器 `run.sh`，静态检查/lock 运行器 `check.sh`。每个模块的详细 item → file:line → command/output 见 `acceptance/exemplars/<module>/S4_FIXES_m3m4.md`。

| 模块 | 闭合项与原生证据 | golden | 静态与 lock | 打开 PNG |
|---|---|---|---|---|
| seurat-cluster | initial.membership/node.sizes、HVG mean.function/dispersion.function、SCT reference.SCT.model/residual.features；有效 Leiden、HVG、SCT native replay PASS；2638 cells/nine communities/95927 edges | PASS，未改 | 四项 PASS；OK 16 files | 6，cluster_figures.jpg |
| seurat-integrate | project.dim TRUE/FALSE native loadings 和实际 Methods PASS；两路线 smoke PASS | PASS，未改 | 四项 PASS；OK 15 files | 18，integrate_figures_0..2.jpg |
| seurat-markers | 两路线 base/mean.fxn；精确 exp(1)、Matrix::rowMeans native replay PASS；实际 test/prefilter/base、Wilcoxon/presto、Bonferroni 定义与显著计数 Methods/Results/caption 检查 PASS | PASS，未改，11648 rows/7023 above log2FC1 不变 | 四项 PASS；OK 15 files | 10，markers_figures_0..1.jpg |
| aucell-score | 必填用户 offline GMT/source/licence/acknowledgement，保留禁止集合 gate；bundled native replay、两 custom sets parity/refusal PASS；SKILL input-specific route wording、YAML 修复 | PASS，未改 | 四项 PASS；OK 9 files | 4，aucell_figures_0.jpg |
| singler-annotate | 从实际 opts_singler/opts_prune 填 Methods/results/provenance/caption；quantile=.5、de.method=wilcox、nmads=2、min.diff.med=.01/min.diff.next=.05 native override parity PASS；pancreas 1718/59 pruned | PASS，未改 | 四项 PASS；OK 16 files | 12，singler_figures_0..1.jpg |
| wgcna-network | review 列出的 5 函数原生 controls 独立 CLI；Pearson/bicor + TOMDenom mean native replay PASS；cor Pearson/Spearman PASS；BH/none stats::p.adjust saved native P PASS；实际 Methods/caption PASS | PASS，未改；18 assigned modules/grey99，全部 printed sizes 不变 | 四项 PASS；OK 16 files | 24，wgcna_figures_0..3.jpg |
| maftools-landscape | captureRegions 与 captureSize 二选一必填；native region TMB CSV identical、全 variants 保留、source/hash Methods/provenance PASS；218 variants within ranges/103 TMB rows | PASS，未改 | 四项 PASS；OK 9 files | 16，maf_figures_0..2.jpg |
| immunedeconv-infiltration | method-args JSON / abs_method sig.score,no.sumto1 native synthetic interface parity、实际 Methods/provenance PASS；八 offline native 方法 full-table parity、42 原 checks PASS；licence/user-file refusals 保留 | 八方法 golden PASS，未改 | 四项 PASS；OK 9 files | 13，id_figures_0..2.jpg |

所有图形查看均通过逐 PNG 的 contact sheets；清单保存在对应 `<prefix>_figures.json`，图非空、文字可读，未见明显裁切。密集 WGCNA gene dendrogram 与 native anchor 展示范围一致。

Golden 没有任何改动，也没有放宽断言/容差。WGCNA 原 manifest 包含 main Methods 和 figure specs，因此完整 resolved controls 写入 `draft/native_parameters.md` 补充 Methods 和 provenance；main Methods/caption 用实际 correlation/adjustment，默认文字不变。

唯一共享改动是 `skills/_shared/scripts/fig_mod_sc_backend.R` 两个 SingleR builder 的兼容 optional min.diff.med/min.diff.next 参数和 caption/spec 绑定；没有改其他 30 模块、router、method_map 或公共 registries。

工具补齐：本 checkout 起初缺少任务明确要求的 `tools/check_skill_frontmatter.py`，最终新增最小 YAML/name/description checker，支持限制校验路径。要求的命令 `python3 tools/check_skill_frontmatter.py skills/aucell-score` 报告 `skills/aucell-score/SKILL.md: 0 problems; 1 skills checked; 0 problems`；先前 scratch checker 的替代验证已经由此正式命令取代。该工具不修改其他模块，未执行其他模块修复。

原生诊断说明：seurat-cluster 早期无效 0 起始 Leiden membership 探针失败，改为原生有效 1 起始后通过；marker exp(1) 探针精度和 maftools factor→CSV representation 比较已修正，没有改变生物结果；WGCNA 200-probe alternative 全 grey 与直接 native 一致，原生 merge 警告保留。

最后检查：sample-varying synthetic interface 全部 native/Methods/provenance/default checks PASS；三张 interface PNG 已再次打开且有 sample 变化。八模块最终 `make_module_lock.R <module> --check` 全部 OK，见 final_locks.log；git diff --check 无问题；八模块 golden_manifest.csv 与基线完全相同。

未闭合修复项：无。Licensed CIBERSORT 算法本身仍须真实用户合法文件；本次按 review 仅验证 synthetic interface，不声称执行 licensed 算法。

DONE
