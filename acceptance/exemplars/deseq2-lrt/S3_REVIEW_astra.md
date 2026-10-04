# deseq2-lrt 独立 S3 验收

Pinned: `build/m1m2@2ddf174fb36cbaa3c280af00b52b92fe7f039d04`。

- [x] PACK C/L1：核读 DESeq2.rendered.txt:1085 起 LRT 说明、Rmd:1668/1677 的 eval=FALSE，无此 LRT 的 usable printed 数值。fission 交互设计为冻结 P-4 指定；独立包调用而非引擎回调。当前 smoke fission 验 P、仅验 padj NA；pasilla 只验结构，见 F1。
- [x] PACK T：实际 feature_table/full 表含 baseMean、单一 LFC/SE、非负 stat、P/BH；canonical 排序与字段齐全。公式在 contrast、JSON/Methods 完整，report_coefficient 明确，无 up/down 或 ranked_list 的错误推断。
- [x] PACK W：实际 a1 草稿 DESeq2 1.52.0、full/reduced、交互项、df=5、filter、fit/sf、BH 0.05 与单系数限制正确；JSON 与 7039 输入、6205 检验、8 命中一致。a2 为 8148 检验。展示变换/图注仍有 F2。
- [x] Mechanical/S1：逐行核 core:176–203 与 registry；嵌套/满秩/df、显式过滤、无 FC 门槛、corrected input refusal 均实现。静态登记/default drift/defaults/flag docs/lint、spec 字节回放、真实 QC→LRT handoff/篡改、golden PASS、无 Rplots.pdf，SMOKE PASSED / EXIT 0。name 参数登记缺口见 F3。
- [x] Figures：逐张打开 a1 top_heatmap/trajectory 和 a2 top_heatmap，标签/分面无遮挡裁切；图注有基因数，未完整声明 BH 选择阈值与变换，见 F2。

证据目录 `/home/<user>/omic-s3-runs/deseq2-lrt/`。`run_locked.sh deseq2-lrt review-final Rscript skills/deseq2-lrt/tests/run_smoke_test.R` 的日志 `_s3/review-final.log`；额外 `_s3/lrt_probe.R` 在锁定容器独立 DESeq/结果回放，`numerical-probe.log`：fission P 最大误差 4.998901e-11、padj 4.967271e-11；pasilla P 4.998835e-11、padj 4.999279e-11，NA 均一致，符合 CSV 有限精度。故未发现这两个运行的统计数值错误，但提交的验收覆盖不足。

## 闭口返修清单

1. **F1 — PACK C / S1 P-4**：`skills/deseq2-lrt/tests/run_smoke_test.R:61–67,76–84`，补全部 P/调整 P 数值与 NA 对齐断言；pasilla 不能仅以 df/行数/term 名称当 numerical replay。保存并引用 fission 原工作流的完整代码/预过滤来源，与套件过滤的差别明确标注。独立审查探针不能代替已提交的回归门禁。
2. **F2 — PACK W/F**：`scripts/deseq2_lrt_report.R:33–38,64–73`，Methods/图注只称 transformed expression，未写实际 vst/直接 VST、blind=FALSE、fitType、nsub；图注亦未写 LRT padj < alpha 的源集合选择和样本数。按实际运行补齐，保持变换与 inferential LRT 分开；图片本身可读。
3. **F3 — PACK T / S1 P-3（锁3）**：`scripts/deseq2_lrt_core.R:189` 使用 results(name=report_coef)，但 calls_registry 的 results 项不登记 name。补可选单系数选择的来源和值；不能只靠静态“已登记参数均存在”检查证明结果相关参数完备。验证改变 report-coef 只改变展示系数、不改变联合 P/BH。

所有者项：模式聚类 OS_UNAVAILABLE_DEPENDENCY 明确拒绝，未擅定 DEGreport 输入规则，不因此判失败。--adjust 只验证用户明确声明的调整项，已记录其边界；未替用户推断研究意图。

NEXT STEP: S4 修复闭口清单。
VERDICT: FAIL
