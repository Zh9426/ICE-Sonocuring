# 可复现输出

运行脚本会生成 PNG、CSV、MAT 和 JSON。MAT 保存完整配置、公共阈值参考及必要结果；CSV 的 NaN 表示指标不可定义或切线边界截断，不能当作零旁瓣。默认全部是 synthetic 示例。

- `demo/`: 六种几何/声束示例及完整场数据。
- `architectures_linear/`, `architectures_matrix/`: 分区与模式对比。
- `sweep/`: 单因素扫描。
- `validation/`: 实际运行的单元测试与收敛记录。

同名脚本重复运行会更新对应输出。先复制目录再改变配置可保留多轮实验。CSV、PNG、JSON 快照进入 Git，较大的 MAT 和运行日志留在本地，可用脚本重建。
