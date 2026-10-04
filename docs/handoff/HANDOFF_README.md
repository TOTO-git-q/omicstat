# omicstat 交接包（2026-09-25）

## 阅读顺序
1. `omicstat/ENGINEERING_PLAN.md`：**权威落地文档**（模块划分、参考文档采集、Rscript 冻结、skill 与路由构建、里程碑、门禁）
2. `omicstat/IMPLEMENTATION_SPEC.md`：基础设施分叉规格（只有 §0、§3、§4、§5、§7 有效；它 §2 的旧模块表已被 ENGINEERING_PLAN 取代）
3. `reference/` 下是上面两份文档引用的架构参照源，**只读，照抄结构，不要修改**

## 路径对照（文档中写的原 Windows 路径 → 本包中的位置）
| 文档里的原路径 | 本包中的位置 |
|---|---|
| `E:\claude workspace\skills-dev\omicstat\` | `omicstat-handoff/omicstat` |
| `E:\claude workspace\skills-dev\medstat-55692f7\` | `omicstat-handoff/reference/medstat-55692f7` |
| `E:\claude workspace\skills-dev\medstat\acceptance\replication-sop.md` | `omicstat-handoff/reference/medstat-acceptance/replication-sop.md` |
| `E:\claude workspace\skills-dev\medstat\research\skillmd-craft\` | `omicstat-handoff/reference/medstat-research/skillmd-craft` |
| `E:\claude workspace\skills-dev\medstat\docker\（不含 rlib-phase5-linux 编译库）` | `omicstat-handoff/reference/medstat-docker` |
| `E:\claude workspace\skills-dev\medstat-reference\（不含 .git）` | `omicstat-handoff/reference/medstat-reference` |

在新电脑上，建议把整个包解压到一个固定目录，然后告诉实现 agent："文档中出现的 `E:\claude workspace\skills-dev\...` 路径，一律按本 README 的对照表换成解压后的对应位置。"

## 不在包里、需要在新电脑上自备的
- R 4.6.0（或按文档构建 Docker 容器 `omicstat-r`；Windows 上需要 WSL + Docker）
- Python 3.12 + `mcp==1.28.0`（MCP 服务用）
- `medstat-r` 的编译库 `rlib-phase5-linux` 没有打包（它是可以重建的二进制文件，不是文档）
- 小主机 GT103 的 SSH 访问：只有部署参考伴随服务时才需要
