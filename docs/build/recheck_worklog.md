# recheck — /home/<user>/omic-recheck — s3/recheck
# 审查基线 bb60144f325085c4b400e408887a1be7fe4eabd9；只改指定审查文件；提交由外部 helper 完成。
# NEXT：seurat-cluster，随后按 fin_recheck.md 的 13 模块顺序；最后三生态链、中文总报告。
seurat-cluster: 独立复验 PASS；smoke/golden、lock 16 files、两路线 CLI/native/Methods/provenance 及全部 12 PNG 已验证；NEXT seurat-integrate。
seurat-integrate: 独立复验 PASS；smoke/golden、lock、修复绑定/native/Methods/provenance、全部 18 PNG 已验证；NEXT seurat-markers。
seurat-markers: 独立复验 PASS WITH NOTES；smoke/golden、lock、修复绑定/native/Methods/provenance、全部 14 PNG 已验证；NEXT aucell-score。
aucell-score: 独立复验 PASS；smoke/golden、lock、修复绑定/native/Methods/provenance、全部 4 PNG 已验证；NEXT singler-annotate。
singler-annotate: 独立复验 PASS；smoke/golden、lock、修复绑定/native/Methods/provenance、全部 12 PNG 已验证；NEXT wgcna-network。
wgcna-network: 独立复验 PASS WITH NOTES；smoke/golden、lock、修复绑定/native/Methods/provenance、全部 24 PNG 已验证；NEXT maftools-landscape。
maftools-landscape: 独立复验 PASS；smoke/golden、lock、修复绑定/native/Methods/provenance、全部 16 PNG 已验证；NEXT immunedeconv-infiltration。
immunedeconv-infiltration: 独立复验 PASS WITH NOTES；smoke/golden、lock、修复绑定/native/Methods/provenance、全部 13 PNG 已验证；NEXT scanpy-qc。
scanpy-qc: 独立复验 FAIL；smoke/golden、lock 结果、修复绑定/native/Methods/provenance、全部 6 PNG 已验证；NEXT scanpy-cluster。
scanpy-cluster: 独立复验 FAIL；smoke/golden、lock 结果、修复绑定/native/Methods/provenance、全部 11 PNG 已验证；NEXT scanpy-markers。
scanpy-markers: 独立复验 FAIL；smoke/golden、lock 结果、修复绑定/native/Methods/provenance、全部 7 PNG 已验证；NEXT scvi-integrate。
scvi-integrate: 独立复验 FAIL；smoke/golden、lock 结果、修复绑定/native/Methods/provenance、全部 10 PNG 已验证；NEXT scanvi-annotate。
scanvi-annotate: 独立复验 FAIL；smoke/golden、lock 结果、修复绑定/native/Methods/provenance、全部 12 PNG 已验证；NEXT 三生态链证据汇总和中文总报告。
recheck: 十三卡及中文总报告完成；13 smoke/golden PASS、8 R locks OK、5 Python stale shared hash FAIL；三生态实际链和177 PNG已核验；S5资格19；最终文件范围及格式检查通过，NEXT 无。
DONE
