# clusterprofiler-gsea S5 前返修（R2，来自 S3 最终核验 FAIL）

返修对象：`S3_FINAL_astra.md` 封闭清单第 1 项（原 F2 / PACK W）。原文案称全同号输入“只有一端、另一端富集不可观察”，`tests:90` 还强制这句话；实际全正 12495 分数、CC 10–30 跑出 320 项、27 个负 NES（GO:0031082 NES=-2.057091，BH=.03071103）。signed 图注把负 NES 读成相反的基因效应；curve 图注不管有没有零交点，都写有零交点虚线。估计器未改。

## 改动

| 项 | 文件:行 | 改动 |
|---|---|---|
| Methods 的 NES 解读 | `skills/clusterprofiler-gsea/scripts/clusterprofiler_gsea_report.R:38-60,65` | 删掉错误句；新增 `cg_score_signs()` / `cg_nes_reading()`。每次都写：NES 是集合在该排名顶端（NES>0）或底端（NES<0）的相对富集。全正时补一句：排名仍有底端，由最小的分数组成，负 NES 表示那里的相对富集，本身不表明相反效应（`negative_end`）；全负时对称处理。 |
| signed 点图图注 | `skills/_shared/scripts/fig_mod_enrich.R:26-28,54-70`；调用处 `clusterprofiler_gsea_report.R:10-11` | 新增参数 `score_signs`，默认 `"both"`。三种情况都用“toward the top / bottom of the ranking”（相对富集）的措辞；同号时写明负 NES（或全负时的正 NES）本身不表明相反效应，不再出现“negative end / negative scores:”。 |
| curve 图注的零交点 | `skills/_shared/scripts/fig_enrich.R:194-199,249`；同类 `fig_enrich_network.R:442`（gsea_multi） | 新增 `.os_gsea_bottom_caption(zero_cross)`：只有真的画了零交点虚线时才写 “dashed line, where it crosses zero.”；否则写 “all scores have the same sign, so the metric has no zero crossing and no crossing line is drawn.”。有交点时文字与原来逐字相同，所以 fgsea-prerank 和图库的 curve 图注不变。 |
| 回归测试 | `skills/clusterprofiler-gsea/tests/run_smoke_test.R:44-50,82-122` | 删除强制错误句的断言。同号用例改用核验反例 fixture（abs(geneList)+1e-6·i，CC，10–30），检查：仍被接受；JSON 中 n_negative_scores=0、n_positive_scores=12495；表中有负 NES 且至少一个 BH 显著（GO:0031082 NES −2.057091，BH 0.03071103）；Methods 用新解读、不含 “only one end / cannot be observed”；signed 图注计数与措辞正确；curve 图注不提零交点；草稿图例与 figure_spec 图注逐字一致；Results 的计数与表一致。anchor（有正有负）新增断言：curve 图注写零交点线。保留：有方向同号输入被接受，以及 LRT/无方向 metadata 拒绝（OS_RANKING_UNDIRECTIONAL）、F/LRT 名称拒绝两项测试。 |
| golden | `skills/clusterprofiler-gsea/tests/golden_manifest.csv` | 只有 `figures/gsea_dotplot_signed.figure_spec.json` 这一行变化（6f71280b… → d02a5a1a…）。原因：anchor signed 图注换成顶端/底端相对富集的措辞。旧版与新版 spec 的 JSON 差异只在 caption 字段；该图 PNG 字节不变（两边都是 a6f11030…）。其余 5 个 golden 不变。 |
| module lock | `skills/clusterprofiler-gsea/module_lock.json` | 因 report 脚本、测试和 golden_manifest 的哈希变化而重写。 |

## 证据（GT103，容器 `omicstat-r:2026.09.1`）

- 改动后第一轮 `~/omic-fix-runs/logs/gsea-smoke-1.log`：全部 S5-R2 断言 PASS，唯一 FAIL 是 golden 的 `figures/gsea_dotplot_signed.figure_spec.json`（预期中的图注变化，已经 diff 核实）。
- golden 写入 `~/omic-fix-runs/logs/gsea-golden-write.log`（EXIT 0）；重跑 `~/omic-fix-runs/logs/gsea-smoke-2.log`：`PASS: golden PASS`、`SMOKE PASSED`、EXIT 0；`make_module_lock.R clusterprofiler-gsea --check`：`module_lock clusterprofiler-gsea 1.1.0: OK (14 files)`。
- 反例用例实测输出：320 项、27 个负 NES，BH 显著的负 NES 为 GO:0031082（NES −2.057091，BH 0.03071103）；signed 图显示 9 正 / 1 负（BLOC complex）。已人眼看过 `oneside/figures/gsea_curve.png`（底部轨道没有零交点虚线，与新图注一致）和 `gsea_dotplot_signed.png`。

## 复核命令

```
cd ~/omic-fix-runs/gsea && OMICSTAT_TEST_TMP=/ws/smoke-verify bash ~/omic-integrate/bin/omicstat-r-route.sh Rscript ~/omic-integrate/skills/clusterprofiler-gsea/tests/run_smoke_test.R
cd ~/omic-integrate && bash bin/omicstat-r-route.sh Rscript tools/make_module_lock.R clusterprofiler-gsea --check
```

注：共享图形文件改动后，fgsea-prerank 冒烟测试（有零交点）的 golden 预期不变，但这一点要等到尚未运行的完整 env/test.sh 才能确认。
