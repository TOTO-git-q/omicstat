# fgsea-prerank S5 前返修（R1，来自 S3 最终核验 FAIL）

返修对象：`S3_FINAL_astra.md` 封闭清单第 1 项（原 F1 / PACK C）——`tests/run_smoke_test.R:60` 的行内注释吞掉了 ES/NES 两个 `at_print` 调用，P3 实际只查 log2err 和 size。

## 改动（仅测试文件；引擎、算法、golden 均未动）

| 项 | 文件:行 | 改动 |
|---|---|---|
| P3 逐字段执行 | `skills/fgsea-prerank/tests/run_smoke_test.R:62-72` | 新增 `p3_fields()`，对 log2err（7 位小数）、ES、NES（`at_print` 7 位有效数字）、size（整数全等）各返回一个实际执行的逻辑值；check 要求四项全 TRUE，并在消息里逐字段打印 ok/FAIL。原注释吞断言的写法已删除。 |
| P3 阴性对照（留在测试里） | `run_smoke_test.R:73-92` | 对四个字段分别在第 1 行和第 6 行把值朝远离打印值方向移动“最后一位打印数字的一个单位”（size 移 1），要求该字段失败且其他字段仍通过；再把全部 ES 改 999、NES 改 -999，要求 ES 和 NES 同时失败。任一扰动未被抓住即该 check FAIL。 |
| 保留不变 | `run_smoke_test.R:33-56` | 教程原调用 `data(examplePathways); data(exampleRanks); set.seed(42); fgsea(..., minSize = 15, maxSize = 500)`、六行打印值及 source 锚点（fgsea-tutorial.rendered.txt:17-56）原样保留。 |
| module lock | `skills/fgsea-prerank/module_lock.json` | 只因 `tests/run_smoke_test.R` 的 sha256 变化而重写；其余 13 个文件哈希不变。 |

Golden 未重生成：本次只改测试断言，引擎输出字节不变，golden 实测 PASS。

## 证据（GT103，容器 `omicstat-r:2026.09.1`）

1. 冒烟测试 `~/omic-fix-runs/logs/fgsea-smoke-1.log`（EXIT 0）：
   - `PASS: P3 printed log2err/ES/NES/size (tutorial:44-49) [log2err=ok, ES=ok, NES=ok, size=ok]; ... ES 0.5388497, 0.5594755, 0.725327, 0.7347987, 0.5576247, 0.6052906; NES 2.705894, 2.76907, 2.97269, 2.957518, 2.554076, 2.648685 ...`
   - `PASS: P3 negative control: ... (log2err[1]:caught, log2err[6]:caught, ES[1]:caught, ES[6]:caught, NES[1]:caught, NES[6]:caught, size[1]:caught, size[6]:caught, ES=999,NES=-999:caught)`
   - `PASS: golden PASS`、`PASS: same-signature golden hashes match`、`SMOKE PASSED`。
2. 打印锚点变异探针（临时副本，跑完即删，不入库）：把测试里打印锚点改一位数字，P3 必须失败。
   - ES 第 4 行 0.7347987→0.7347988：`~/omic-fix-runs/logs/fgsea-printed-mutation-ES.log`，EXIT 1，`FAIL: P3 ... [log2err=ok, ES=FAIL, NES=ok, size=ok]`。
   - NES 第 4 行 2.957518→2.957519：`~/omic-fix-runs/logs/fgsea-printed-mutation-NES.log`，EXIT 1，`FAIL: P3 ... [log2err=ok, ES=ok, NES=FAIL, size=ok]`。
   （这两份日志里阴性对照显示 MISSED 是预期的：被改字段在基线上已失败，所以“只让该字段失败”的条件不成立。）
3. `Rscript tools/make_module_lock.R fgsea-prerank --check`：改前 `FAIL: module_lock.json is stale for: skills/fgsea-prerank/tests/run_smoke_test.R`；重写后 `module_lock fgsea-prerank 1.1.0: OK (14 files)`。

## 复核命令

```
cd ~/omic-fix-runs/fgsea && OMICSTAT_TEST_TMP=/ws/smoke bash ~/omic-integrate/bin/omicstat-r-route.sh Rscript ~/omic-integrate/skills/fgsea-prerank/tests/run_smoke_test.R
cd ~/omic-integrate && bash bin/omicstat-r-route.sh Rscript tools/make_module_lock.R fgsea-prerank --check
```
