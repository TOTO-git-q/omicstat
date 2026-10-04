# build_m2b S2 构建报告

工作树 `/home/<user>/omic-build-m2b`，分支 `build/m2-rank`；锁定镜像 `omicstat-r:2026.09.1`；运行日志在 `/home/<user>/omic-build-logs/build_m2b/`。三个模块均已完成 S2 并各自提交，等待独立 S3 验收。

## 需所有者或协调员处理

1. **limma-camera 印刷锚点不一致。** 锁定版 limma User's Guide §18.1.10 印刷的 camera 值为 Y（13，Up）P=2.40e-262、FDR=4.80e-262；X（54，Down）P=5.58e-26。按指南重建 Yoruba 数据及设计后，锁定容器中直接调用和模块均得到 Y P=1.79122449658387e-262、FDR=3.58244899316775e-262，X P=6.02018304198957e-26。集合大小和方向相同，但**印刷数值锚点未通过**。需独立核查预处理、指南印刷结果来源及版本行为；S2 没有为匹配印刷值改动估计器。
2. **Hallmark 离线集合尚未落实。** `msigdb_collections` 在锁定注册表中仍无已核验版本和 SHA-256，三个模块均对该默认集合报 `OS_REFDATA_MISSING`。本次使用已登记的离线示例集合；发表用途的 Hallmark 资源须由 M1-3 所有者落实。
3. **GSVA 分数的后续 limma 接口与 eBayes 设定待裁决。** 当前使用连续分数的 `lmFit` + `eBayes(trend=FALSE, robust=FALSE)`，保留样本设计，不做 voom 或探针过滤；具体接收模块和设置见 `gsva-score/S3_REQUEST.md`。
4. **上游排序交接尚未贯通。** 本分支的 `deseq2-wald` 尚未输出约定的 `ranked_list`，与 lane 任务文字有出入。两个排序模块的读取器、类型校验和模拟 `--from-run` 均通过；协调员须合并实际生产者。
5. **S3 路由与参考数据审查。** `limma-camera/S3_REQUEST.md` 提出独立的显微镜 camera、FRY 基因负例及 cameraPR 正例。GenderGenes 仅为私有离线验收素材，注册表标明再分发条款需审查。请按三份 S3_REQUEST 进行独立验收；本 lane 未自行做 S3。

## 各模块 S2 结果

| 模块与提交 | 锚点、来源和结论 | 测试与图形 | 待处理 |
|---|---|---|---|
| `fgsea-prerank` `60a86c5` | fgsea 1.38.0 官方 `exampleRanks`/`examplePathways`，锁定容器重放锚点：12,000 个排序基因、1,457 集合输入、586 保留、124 个 BH 显著；Cell Cycle Mitotic NES=2.75941576990235。直接 `fgseaMultilevel` 重放通过；这是重放锚点，非教程印刷数值。 | `fgsea_final_smoke.log`：22 PASS、0 FAIL；golden 与 module lock 通过；NES 条形图和 GSEA 曲线两张 PNG 已目视检查，无裁切或重叠。 | Hallmark 集合缺失；上游 `ranked_list` 生产者待合并。 |
| `gsva-score` `34be5d0` | GSVAdata 1.48.1 `gbm_VerhaakEtAl` + `brainTxDbSets`，锁定容器重放：11,861 特征、173 样本、4 集合，auto 进入 Gaussian；Proneural 53 对 Classical 38，4 集合 BH 显著；`oligodendrocytic_up` logFC=-0.522609890627989。直接 GSVA 参数对象及 limma 重放通过。 | `gsva_final_smoke.log`：27 PASS、0 FAIL；golden 与 module lock 通过；四张不同 PNG 已目视检查，无裁切或重叠。 | 连续分数 limma 接口与 eBayes 设定待裁决；Hallmark 集合缺失。 |
| `limma-camera` `79c1f70` | limma 3.68.5 Yoruba F10/F11，16,918 特征、86 样本。camera：Y 13 Up、X 54 Down，容器直接重放与模块一致；与指南印刷 P 值不一致，故印刷 camera 数值锚点**未通过**。mroast `nrot=9999`：Y/X 均 P=1e-04，方向 Up/Down，与指南印刷锚点一致。 | `limma_final_smoke.log`：26 PASS、0 FAIL；golden 与 14 文件 module lock 通过；camera、cameraPR、fry、roast、mroast 五张不同 PNG 已目视检查，无裁切或重叠。 | 印刷 camera 锚点需独立调查；Hallmark 集合缺失。 |

各模块的完整来源哈希、参数、输出位置、QC、提出的路由行及规则记录见 `acceptance/exemplars/<module>/S3_REQUEST.md`。三个模块均已核验显式函数参数、锁定默认值、文档默认值、类型错误、可重放结果和图形规范；图形规范中的 FIG-03 灰度色彩接近仅为信息级提示。

## 共享代码变更

- 新建 `skills/_shared/scripts/enrich_rank_io.R`，实现排序交接的精确 CSV 合约及离线集合 SHA-256 校验；FGSEA 示例、GSVAdata brain 集合与 limma GenderGenes 均经注册表读取。未使用 KEGG 内容。
- 新建 `skills/_shared/scripts/fig_mod_enrich_rank.R`，集中提供 FGSEA、GSVA 与 camera 图形构造器；已在 `fig_all.R` 列表末尾登记。未改动 M2 lane 拥有的 `fig_mod_enrich.R` 或 `enrich_io.R`。
- `env/refdata_registry.json` 增加三个仅供离线 S2 重放的集合条目；Hallmark 默认条目仍未解析。未改动其他 lane 的模块、路由器、SUITE 或发表规则文件。

## 偏离与未完成事项

- 指南印刷 camera 数值与锁定容器直接计算不一致；如上逐值报告，未宣称该锚点通过。
- 任务文件声称上游 `deseq2-wald` 已产出 `ranked_list`，本工作树实际没有；通过契约和模拟上游交接验证了读取端，跨模块真实链接仍待协调。
- GSVA 的 limma 推断采用明确标注的暂定设置；待所有者裁决。Hallmark 默认离线资料未就绪，运行时明确拒绝。
- 独立 S3 验收、S5 安装与路由/发表规则落地不属本 lane 授权范围，未执行。未推送分支。
