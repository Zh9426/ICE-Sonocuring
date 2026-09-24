# 可复现输出

运行脚本会生成 PNG、CSV、MAT 和 JSON。MAT 保存完整配置、公共阈值参考及必要结果；CSV 的 NaN 表示指标不可定义或切线边界截断，不能当作零旁瓣。默认全部是 synthetic 示例。

- `demo/`: 六种几何/声束示例及完整场数据。
- `architectures_linear/`, `architectures_matrix/`: 分区与模式对比。
- `sweep/`: 单因素扫描。
- `validation/`: 实际运行的单元测试与收敛记录。

同名脚本重复运行会更新对应输出。先复制目录再改变配置可保留多轮实验。CSV、PNG、JSON 快照进入 Git，较大的 MAT 和运行日志留在本地，可用脚本重建。

## P0 双阵列示例

`p0_probe_compare/` 保存 2026-09-24 合成 96+96 双阵列与 24×8 连续分区的 PNG、CSV。`comparison.csv` 是 25% 公共相对阈值的标量结果，`threshold_sensitivity.csv` 另外提供 25/35/50% 三档筛选；`voxel_check.csv`、`surface_quadrature_check.csv` 是局部数值诊断。图和表并非实测材料固化或安全结果；完整配置及压力场在同目录 MAT 文件，仓库默认忽略 MAT。运行入口为 `run_p0_probe_compare`、`run_p0_convergence`，解读见 `docs/upgrade_2026-09-24.md`。
