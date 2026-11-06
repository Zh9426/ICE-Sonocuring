# Verasonics ICE 资料入口

本目录整理 `VantageNXT-2.3.2-p2` 软件包中的可读资料，服务于心内 ICE 序列阅读和后续迭代。原软件包保持不变。

- **当前驱动：[64元线阵左右32/32分区](../../verasonics/dual_mode/README.md)**。用户2026-10-12确认原始64元驱动可用，撤回12×8硬件判断。[实物型号与性能研究](sonic_eyes_hardware_2026-10-12.md)区分商品系列、软件别名、源码参数和unknown额定值。
- [2026-10-08 提取报告](package_review_2026-10-08.md)：主要发现、探头身份冲突、工具使用边界、手册版本和推荐阅读顺序。
- [双模式算法升级报告](dual_mode_upgrade_2026-10-08.md)、[运行说明](../../verasonics/dual_mode/README.md)：基于现有ICE配置生成成像/候选照射/交替运行序列，含离线验证记录。
- [文件清单](reference_2026-10-08/file_inventory.csv)：4,046 个文件的相对路径、类型和大小。
- [PDF 目录](reference_2026-10-08/pdf_catalog.csv)：347 份 PDF 的页数、文档版本和 SHA-256。
- [PDF 主题页索引](reference_2026-10-08/pdf_topic_index.csv)：按探头映射、波形、接收、时序、重建、RF 导出、环境、功率等主题定位 PDF 页。
- [探头定义表](reference_2026-10-08/probe_definitions.csv)：`computeTrans.m` 中 75 条可直接提取阵元数常量的单名称分支；表达式保留为源码文本，不是完整的执行后探头数据库。
- [ICE 保存配置快照](reference_2026-10-08/ice_saved_mat_snapshot.json)：通过 SciPy 读取已有 MAT，未执行 MATLAB 序列。
- [两套手册对照](reference_2026-10-08/manual_version_comparison.json)、[重复工具比对](reference_2026-10-08/duplicate_utilities.csv)、[提取状态](reference_2026-10-08/extraction_status.json)。

物理拓扑：用户2026-10-12纠正为与原始源码一致的64阵元线性相控阵，采用左32成像、右32候选固化。12×8及96+96模型均不能代表当前实物，只保留为synthetic案例。具体Sonic Eyes型号后缀、额定长脉冲/占空比/热负荷仍unknown。
