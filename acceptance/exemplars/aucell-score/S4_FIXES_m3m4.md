# aucell-score S4 闭合修复

离线 GMT → scripts/run_aucell_score.R:14 必填 sets-file、sets-source、sets-licence、accept-licence；scripts/aucell_score_core.R:4 去掉单文件 SHA 限制，保留禁止集合/声明 gate，state/provenance 记录文件/source/licence/hash；Methods 记录实际声明。registry/options/SKILL 同步；SKILL:3 description block 修正 YAML，路线明确 single-cell per-cell activity / bulk,pseudobulk 使用 gsva-score，均非唯一 standard。

静态检查发现已有 os_bioc_call 间接调用不被 check_calls 识别；core:11/:13 改为显式 native anonymous wrapper，保留原来的 supplementary arguments 和优先级；getGmt 命名 con，geneIds 登记 accessor。

证据（run.sh locked non-root/offline）：
- Rscript skills/aucell-score/tests/run_smoke_test.R → exit 0；bundled example native replay、golden PASS；两自定义 user-derived sets native parity PASS；prohibited/reference licence gate、missing acknowledgement、source Methods PASS。aucell_smoke.log；golden 未修改。
- bash /scratch/check.sh aucell-score → 0 registry/default drift/defaults/lint problems，21/21 flags documented，lock/check OK (9 files)，aucell_checks.log。
- 本 checkout 起初缺少 tools/check_skill_frontmatter.py；先用 scratch YAML checker 验证，再新增最小 YAML frontmatter checker tools/check_skill_frontmatter.py。要求的命令 `python3 tools/check_skill_frontmatter.py skills/aucell-score` → skills/aucell-score/SKILL.md: 0 problems；1 skills checked; 0 problems，frontmatter.log。此工具仅校验 YAML/name/description，不修改其他 SKILL。
- 全部 4 PNG 在 aucell_figures_0.jpg 打开，非空、文字可读、无明显裁切；aucell_figures.json。
- 未闭合项：无；缺失 checker 已补齐并按要求运行。
