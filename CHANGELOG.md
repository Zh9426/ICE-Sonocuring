# 更新与升级公告

## 2026-11-14 — 双焦与四焦离线声场对照

**已实现并验证。** 保持 All64 假设源和单发设置，新增连续分组双焦与四焦模拟输入及 GPU 对照，补算 All64 基准，完成六组 65/52 μm 声场、到时验证和 HDF5 全量回读。目标平面图、剖面及结果见 [对照报告](independent_simulation/docs/curing_multifocus_comparison_2026-11-14.md)。

**限制。** 焦点坐标为 assumed 的 20 mm 深处局部线段，非患者图像；压力未标定，计算介质均匀无损，近源和全场收敛未验证。没有温升或固化验证，模拟输入不是硬件序列。原始大场及 HDF5 只在本机，图表和代码随仓库同步。

## 2026-11-13 — 文献图表对照及源谱指标口径更正

- 新增 `independent_simulation/docs/curing_literature_comparison_2026-11-13.md`，按焦点、孔径、近场和源表示逐项对照已有项目结果与文献图表，保留模型和数据适用边界。本次没有重新运行仿真。
- 更正 `independent_simulation/docs/curing_field_2026-11-10/README.md`：单阵元75° BLI诊断为谱幅值相对差而非复谱误差；原始数值不变，不改变声场结果。

## 2026-11-13 — 更正目标距离并整理一维线阵文献

**更正及文献。** 用户澄清此前“2 mm”为口误，关注设定20 mm与实际焦点距离的关系；整理结构相近的一维线阵水听器和声全息研究，见 [线阵文献对照](independent_simulation/docs/linear_array_nearfield_literature_2026-11-13.md)。区分目标盒内峰与全前向峰、近场测量与源面重建、半功率与压力−6 dB宽度。仿真继续暂停；未运行硬件或新增传播。

## 2026-11-13 — 整理焦点偏移及稀疏阵列文献

**文献对照。** 按用户要求停止仿真，核对有限孔径焦点偏移、稀疏阵列目标外声场和近场声热风险的公开研究，见 [文献记录](independent_simulation/docs/curing_acoustic_literature_2026-11-13.md)。区分论文实验与仿真、目标盒峰和全前向峰；文献仅定性支持有关机制，不确认本设备的实际声场或安全。本次未运行传播或硬件。

## 2026-11-13 — 奇偶32元与连续阵列的离线对照

**已执行并验证。** 用纯照射构建器分别导出物理+x奇数/偶数32元候选，补算各65/52 μm三维单发声场；复用此前全64和中央连续32作为对照。相关MATLAB测试8/8通过；Sol独立核验新增四个HDF5到MAT全量场、选元及延时。统一图、表和运行记录见 [对照报告](independent_simulation/docs/curing_sparse_comparison_2026-11-13.md)。

**限制。** 奇偶组目标盒主瓣较窄，但同域出现明显近源离轴高值；源面Qp原生峰随网格变化+8.59%，域外可能存在宽角声束，均不能作为实测声场或安全结论。没有真实俯仰透镜、组织热模型和声输出标定。

**数据同步。** 本轮奇偶四个三维场MAT及CUDA输入输出HDF5按用户要求仅保存在本机，不随Git同步；代码、图表、驱动导出与核验表随仓库同步，另一台电脑重跑独立回读须先复制或重新计算原始文件。

## 2026-11-12 — 四版离线三维声场补算与统一比较

**已执行并验证。** 在既有64/16元结果上补算中央连续48/32元、65/52 μm四个假设单发传播；四版同色标声场、目标平面和指标见 [比较报告](independent_simulation/docs/curing_four_variant_comparison_2026-11-12.md)。相关MATLAB测试16/16通过；Sol独立核对八个算例HDF5到MAT全量场、实际驱动和指标。无VSX或硬件操作。

**适用范围。** 每活动阵元假设源相同，阵元数与孔径同步变化；64/16源面原生峰网格敏感性未消除。32/16目标盒峰在边界、轴向−6 dB宽度未完整测得；俯仰透镜、实际声压和材料阈值均未标定，未作实物性能或固化结论。

## 2026-11-11 — 部署独立 CUDA 求解器与首批三维声场

**已执行。** 本机恢复 k-Wave GPU 路径，R2024a 通过独立 CUDA 程序在 RTX 5060 Ti 上运行；点源、带限矩形源及全域 RMS 的 CPU/GPU 对照和正式域资源探针见 [GPU 验证](independent_simulation/docs/gpu_deployment_2026-11-11.md)。不需声称 PCT 已安装。

**已实现并验证。** 实际 All64/Center16 两档网格各完成一次假设脉冲传播，原始 MAT、HDF5、图和表在 `independent_simulation/results/curing_field_2026-11-10/bli_gpu_full/`；完整场大文件以 Git LFS 管理。源面 z=0 原生 Qp 峰在65→52 μm 分别变化8.97%和−6.10%，尚未达到5%内部诊断标准；目标区和共同格点差异较小不能替代这一事实。

**尚未完成。** 源面敏感性原因与更细网格结果仍在研究；48/32 元正式传播尚未展开。模型未标定，Qp仅为单发假设压力平方积分；不能据此推断实测声功率、热量、固化或安全。

**浅层诊断进展。** 两版 52 μm 短域与全域浅层一致；43.333→32.5 μm 时，All64 源面 Qp 峰仍变化 +5.49%，Center16 变化 +1.53%。All64 在同一 32.5 μm 网格下缩小横向域后，浅层 Qp 分区相对 L2 均低于 0.001%；32.5→26 μm 原生源面峰变化 +5.38%、紧邻源面的峰变化 +7.37%，未通过5%内部标准。共同点峰变化 +0.62%，共同插值网格峰变化 +3.31%，后者是诊断而非收敛证明。详见 GPU 验证报告及 `bli_gpu_shallow/`，不能把短域数据当作完整目标深度场。

## 2026-11-10 — 纯照射四版 MAT 回读及三维声源方法诊断

**已实现并验证。** 修复 R2024a 下活动孔径计算对不可用 `range` 的依赖；四版实际导出和两套回读分别 461/461、204/204，通过 7/7 纯照射测试和 40/40 相关回归。输出、实际运行命令、环境与假设见[核验报告](independent_simulation/docs/curing_field_2026-11-10/README.md)。

**已执行的声场前置诊断。** 完成 65/52 μm 面积重叠源频谱检查及单阵元 BLI 源谱、域边界检查；均不是完整三维传播收敛结论。采用声压幅值 −6 dB 的草稿指标和全阵列执行入口仍待验证，后者目前被阻断。

补充：单阵元 BLI 两档传播已完成，五个共同点的峰值与 Qp 最大变化分别为 4.716% 和 2.143%；小域内 `p_rms` 与时序 Qp 积分及索引核对通过，辅助函数最新测试 21/21 通过。见同一报告与原始输出；尚不能推广为全阵列收敛。

补充：带限阵列源首轮测试因滤波前沿与 TX.Delay 混淆失败，修订后 7/7 小测试和四份实际 MAT 的 1/1 测试通过；All64/Center16 两档正式域均完成 16 步资源探针。共同格点与分区 L2 比较程序通过合成场测试。完整阵列声场仍未产生，带限源的两档传播敏感性及焦斑边界尚未知。

**尚未实现或验证。** 四版统一假设传播、Qp 全场、三方向焦斑宽度和目标外/浅层比较尚未交付；不存在声功率、温升、固化或安全结论。求解器版本、源表示和未标定限制见报告。

## 2026-11-07 — 记录用户确认的探头型号

用户确认当前探头按 TINGSN Sonic Eyes 10 标准版开展研究，照片可见品牌、系列与10F，完整型号的确认来源为用户而非照片上的完整标签。详见[原版与纯照射驱动对照](docs/verasonics/curing_original_comparison_2026-11-07.md)。本次仅更新文档；驱动配置中的型号状态未修改，源码几何未经标定，器件额定和实际输出仍 unknown，未运行 MATLAB、VSX 或硬件。

## 2026-11-03 — 新增纯照射最小驱动及64/48/32/16元四版

**已实现。** 单独建立`verasonics/curing_mode`入口，共用`+icec`构建器，四版只改变物理+x排名的全64/中央48/中央32/中央16元。沿用原探头定义、聚焦延时和有限事件后端；序列不含成像/接收/重建/显示对象及缓冲区，仅一项照射TW、聚焦TX、TPC与有限事件。纯照射不再安排接收恢复或结束切回成像档位，充电等待保留；原两用模式默认不变。详见[四版入口及参数来源](verasonics/curing_mode/README.md)、[验证脚本](scripts/verify_curing_only.m)。

**已验证。** 本轮MATLAB相关66/66测试通过，33文件最终Code Analyzer 0消息；新增最小对象集、四版选元/回读、原照射延时对照、无DMA/成像事件、单波形编号统计、有限次数及两用恢复保护回归。四套MAT/JSON/事件和阵元CSV已生成，独立保存MAT复查4/4通过，四个厂商原文件SHA256未变。见[对照表](results/curing_only_2026-11-03/variant_summary.csv)、[测试表](results/curing_only_2026-11-03/test_results.csv)及同目录静态/运行记录。

**限制。** 这是MATLAB离线构建模块，未运行VSX或硬件/固化实验。6 MHz、20周期、PRI=1000 us、300脉冲及等待来自已有assumed配置；没有取得厂家burst/duty/温升额定或固化功率标定。减少阵元同时缩小孔径，相同电压不等于等功率。取消2 ms接收等待缩短组间周期，不能声称热冷却已充分。单位、手册版本/章节、许可与stop重跑限制见运行说明。

## 2026-11-01 — 全64元成像与所选阵元照射的时间复用

**已实现。** 默认成像TX/RX恢复全64元，照射从物理+x排名中选择非空子集（含全64），两种角色可重叠，事件仍时间互斥。偶数32元仅为沿用的assumed初始候选；历史奇偶/左右分区显式保留。新增逐阵元名义burst包络时间和全阵列element-us统计（不是能量）；报告schema=6，新默认输出目录保留旧结果。见[改动与优化准则](docs/verasonics/shared_aperture_2026-11-01.md)、[运行说明](verasonics/dual_mode/README.md)及[验证脚本](scripts/verify_shared_aperture.m)。

**已验证。** 本轮相关58/58 MATLAB测试通过，23文件Code Analyzer 0消息，四个厂商基线文件SHA256未变。覆盖原版成像对照、共享角色、任意子集/错误拒绝、重排接线、恢复事件、逐阵元计数、跨用途短间隔局部比较保护及导出隔离。64/16、64/32、64/64离线候选的成像TX、450条Receive和PData均通过原MAT对照，见[测试表](results/shared_aperture_2026-11-01/test_results.csv)、[候选表](results/shared_aperture_2026-11-01/candidate_summary.csv)及同目录静态检查/运行日志。

**限制。** 无声热/材料求解或硬件运行，不称候选已优化。未实测最低固化功率、声能、电能、温度或恢复时间；厂家额定范围和本机Simulator许可仍需核实。两个目标是在固化质量/时间、器件额定约束和成像恢复满足要求后降低实测功率及总消耗，并建立允许范围内的可用能力包络；低于击穿电压不等于符合工作额定值。手册版本、来源、单位和未验证项见报告。

## 2026-10-29 — 以原工作成像链路恢复两用驱动

**已实现。** 在现有自写构建器上恢复原发散波/虚拟顶点、实际-22.5..67.5度、SectorFT、原重建网格、432波长默认接收窗口、Media/显示和未指定TPC.hv的启动逻辑；保留奇偶分区与独立照射，新增仅imaging_only可用的全64元对照。有限停止、离线开关、等待和Range滑块限制的逐项理由见[修改报告](docs/verasonics/original_imaging_restoration_2026-10-29.md)；[入口](verasonics/dual_mode/SetUpICE_ImagingCuring.m)和[生成脚本](scripts/verify_verasonics_dual_mode.m)写入新目录，旧结果保留。

**已验证。** 本轮MATLAB相关48/48测试通过，21个文件Code Analyzer 0消息；全64元450条Receive和PData与原保存MAT一致，原TX延时及关键成像对象通过字段对照。三种模式和全64对照已离线导出，见[模式表](results/verasonics_original_sector/mode_summary.csv)、[测试表](results/original_imaging_restoration_2026-10-29/test_results.csv)。四个厂商原文件SHA256未变，实际日志见修改报告和结果目录。

**限制。** 这是离线构建器的原成像恢复，未运行VSX或硬件。照射及恢复等待仍assumed，厂家额定值、选件和实测输出unknown。TPC未指定hv的软件缺省1.6 V依据D00163 Rev.K §12 p96，不能反推原实验电压或称为照射安全设置。重建网格不是声场传播求解网格；未作声热求解或固化结论。

## 2026-10-29 — 新增合作沟通信息与ICE双功能进度整合

归档六张用户提供截图及用户确认：体外聚焦声源属于合作方既有路线，当前主线仍研究ICE双功能。整理临时挡口球囊、材料注射/脱离/保持和定位恢复的需求，区分沟通述称、现有数值证据及待验证事项，见[整合说明](independent_simulation/docs/updates/2026-10-29_new_inputs/ICE双功能课题新信息与工作进度整合_20261029.md)。本轮未修改物理模型或驱动限值，未新增传播、硬件或材料实验；既有未收敛及unknown状态保留。

## 2026-10-24 — 新增包含浅层离轴结构的宽域三维声压浏览器

只读导出已有52 μm偶数32元与synthetic全64等源端代理预算结果，新增全前向域等值面、XY深度平面、XZ/YZ切片与原生分区峰值表。共同压力标尺、显示抽样、assumed/unknown来源及未收敛限制见[实现与验证说明](independent_simulation/docs/widefield_viewer_2026-10-24.md)。未重跑传播；浏览器file协议受策略限制，实际WebGL交互目视验收尚未完成。

## 2026-10-24 — 宽域细网格与源表示审计完成，浅层网格敏感性未通过

两组52 μm实际传播、源预算跨网格匹配、分区判据及源空间谱诊断已完成。已实现、已验证、未通过项和未实施的带限源改进见[结果解读与下一步](independent_simulation/docs/findings_2026-10-24.md)及[完整验证报告](independent_simulation/docs/widegrid_2026-10-24.md)。

## 2026-10-23 — 离轴峰边界诊断与活动阵元配置对照完成

已实现、实际验证、尚未验证、参数/单位和下一步见[结果解读](independent_simulation/docs/findings_2026-10-23.md)、[离轴峰诊断报告](independent_simulation/docs/offaxis_diagnostic_2026-10-22.md)及[全64元等源端代理预算对照](independent_simulation/docs/aperture_control_2026-10-23.md)。

## 2026-10-22 — 单点声场边界敏感性与累计暴露代理

实现、实际验证状态、参数与单位、结果表及适用范围见[独立单点验证报告](independent_simulation/docs/singlepoint_validation_2026-10-22.md)。

## 2026-10-21 — ICE体外单点与线条固化验证范围

阶段目标、既有证据、待执行工作及硬件资料依据见[体外验证方案](independent_simulation/docs/ice_bench_poc_plan_2026-10-21.md)。

## 2026-10-19 — 64阵元奇偶版k-Wave三维声压与聚焦验证

实现、实际运行结果、两网格对照、三维数据入口、测试记录及模型限制见[独立仿真结果报告](independent_simulation/docs/kwave_oddeven_results_2026-10-19.md)。

## 2026-10-12 — 64阵元奇偶交替成像/候选固化驱动

**已实现。** 按用户最新确认，将默认改为物理+x顺序的奇数32元成像TX/RX、偶数32元候选照射TX；支持反向角色。完整64项向量和ConnectorES映射保留，继续有限时间交替。新结果独立写入`results/verasonics_linear64_oddeven`，schema 4明确编号依据和无分界线语义。历史左右配置作为显式回归保留。见[升级报告](docs/verasonics/linear64_oddeven_2026-10-12.md)、[运行说明](verasonics/dual_mode/README.md)、[生成脚本](scripts/verify_verasonics_dual_mode.m)与[模式表](results/verasonics_linear64_oddeven/mode_summary.csv)。

**已验证。** MATLAB R2024b Update 2相关43/43测试通过，19份文件Code Analyzer 0消息；新增奇偶测试先失败后通过。覆盖重排/接线独立性、用途互换、孔径/延时、事件互斥和保存后的MAT/JSON/CSV一致性。三模式文件已生成。原始4项vendor基线SHA-256复核一致。

**假设及尚未验证。** 奇数成像为assumed角色约定，几何及电气参数仍沿用未标定源码。每组0.26 mm活动间距、8.17 mm孔径跨度和±0.065 mm中心是解析几何值，不是声场性能结论。波形/时序/限值策略未放宽；没有执行VSX、实物、声热或材料固化验证，栅瓣/旁瓣和成像质量仍待验证，hardware_qualified保持false。手册版本/章节与求解范围见升级报告。

## 2026-10-12 — 恢复实物64线阵基础及左右32/32驱动（历史默认）

**已实现。** 用户确认原始64阵元驱动可用于照片中的TINGSN Sonic Eyes 10F实物，撤回96元12×8硬件判断。当前Verasonics默认恢复type0、源码几何/1:64映射、左32成像/右32候选固化、二维XZ重建与有限时间交替；保留矩阵数学分支作显式synthetic回归。新增burst时长、局部/会话占空比、累计on-time和有来源限值的比较检查，unknown不报告为硬件通过。配置入口见[运行说明](verasonics/dual_mode/README.md)，型号证据与四手册依据见[硬件研究](docs/verasonics/sonic_eyes_hardware_2026-10-12.md)，输出见[模式表](results/verasonics_linear64_partition/mode_summary.csv)。

**已验证。** MATLAB R2024b Update 2，相关38/38测试通过；18份文件Code Analyzer 0消息，三模式MAT/JSON/事件与阵元CSV已离线生成。测试覆盖物理顺序重排、线阵聚焦延时对照厂商数学工具、二维接收界限、互斥/有限停止及显式限值拒绝；见[测试表](results/verasonics_linear64_partition/test_results.csv)和[静态检查](results/verasonics_linear64_partition/code_analysis.json)。本轮未运行VSX或硬件。

**限制与解释更正。** 照片未确定10/Eco/Pro后缀，软件别名P9-4ULts不等于商品型号；间距、宽度、阻抗和35V限值仅来自工作源码，非厂家长脉冲/占空比/热负荷标定。采样与波形量化、恢复等待、Profile5、本机许可和温度读取通路仍待验证，simulate_mode=0仍被拒绝。此前12×8及96+96计算仅能作synthetic案例，不能继续解释为本实物性能；独立仿真模块本轮未更改。尚无成功固化或临床安全结论。

## 2026-10-09 — 96元12×8矩阵固定分区与三维声场

**已实现。** 新增独立96元矩阵几何、左右48+48固定物理分区、逐阵元聚焦延时及三维k-Wave入口；与旧64元线阵结果隔离。完整声压极值体、传感器时序、可旋转FIG、PNG、含全前向场/ROI切换及XY深度滑块的离线HTML均已导出。入口、文件与参数来源见[矩阵模型报告](independent_simulation/docs/matrix96_model.md)。

**已验证。** R2024b/k-Wave1.4.1，64μm、CFL0.2，左右求解约307/305秒；15/15独立MATLAB测试及1项Python轴顺序测试通过，新增6份MATLAB文件静态检查0消息。左右镜像L2相对差约0.000916%，见[结果表](independent_simulation/results/matrix96/comparison.json)及[三维视图](independent_simulation/results/matrix96/matrix96_3d.html)。git diff --check无空白错误。PNG已目视检查；浏览器file协议限制使HTML交互未实测。

**假设与限制。** 12×8来自用户确认；160μm间距、6MHz参考不同排布的ICE研究后作为assumed值，140μm有效宽度及1Pa声源等为assumed，实物校准unknown。均匀无损线性介质、矩形压力源，无透镜/挡板/耦合。两区20mm附近声压约0.1833Pa（假设源下），剖线-6dB宽约6.47×4.84mm；ROI峰值与等值面触边，不能解释为完整焦区。单网格未收敛验证，未完成分区优化、成像重建或实物验证，不作固化/安全结论。

## 2026-10-09 — 更正探头拓扑：12×8矩形阵列、左成像右固化

**更正原因。** 前版错误地采用P9的64元线阵共享孔径假设；用户现明确单个12×8、共96元矩形阵列，左6×8成像、右6×8固化。此前85项测试只证明旧假设下的软件一致性，不证明适配本探头。旧结果已标记superseded，不能继续用于本探头的物理解释。

**已实现。** 默认Trans.type=2，按坐标固定划分48/48互斥子孔径；成像TX/RX限定左半阵，照射TX限定右半阵；三维目标聚焦与接收范围，矩阵PData上的XZ切片重建，新增逐阵元/接线假设CSV及分区图。入口仍为[SetUpICE_ImagingCuring](verasonics/dual_mode/SetUpICE_ImagingCuring.m)，参数集中修改；[修正报告](docs/verasonics/matrix_partition_correction_2026-10-09.md)记录来源、单位与适用范围。

**已验证。** MATLAB R2024b Update2全项目91/91项测试通过；16个MATLAB文件Code Analyzer为0条消息。包括分区无交集、TX/RX不跨区、接线及列表重排、非零y聚焦与厂商二维延时函数对照。见[测试快照](results/verasonics_matrix_partition/test_results.csv)、[模式汇总](results/verasonics_matrix_partition/mode_summary.csv)、[阵元分区表](results/verasonics_matrix_partition/ICE_MatrixPartition_interleaved_elements.csv)。

**尚未验证。** 拓扑及用途由用户确认；pitch/宽高为synthetic，电气数值和波形仍assumed，接线、电声及材料标定unknown。仅几何延时与序列编排，没有VSX、硬件、声场/热/固化实验，也未验证同时收发。轴对称ElementSens仅作近似，不能当作矩形单元实测指向性。旧P0和其他线程历史仿真不随本次修正自动成为适配结果。

## 2026-10-09 — 独立 k-Wave 声场及恢复计算

**已实现。** 新增独立 k-Wave 1.4.1 三维求解、保存的 SetUp 结构导入、TW/TX/Event 映射及单发调度。有限矩形阵元面积映射、分数延时压力源、SI单位、CFL=0.2；配置与依据见[声场记录](independent_simulation/docs/kwave_bridge.md)。修正焦距元数据单位和调度器首个报告的结构体赋值。

**已验证。** R2024b 下独立测试11/11通过。用户确认GPU空闲后，64 μm照射TX16与原始成像TX5完成，耗时约101/87秒。照射80/64 μm固定XZ ROI场相对L2差0.86517%，局部峰压变化0.072669%，见[网格比较](independent_simulation/results/kwave/grid_comparison.json)与[测试表](independent_simulation/results/test_results.csv)。调度器修复后的成像运行生成事件结果映射；先前照射运行保存声场后在汇总层报错，其事件映射未更新。

**尚未验证与限制。** 两网格接近不等于完整收敛。未验证PML/计算域敏感性、全角度序列或实测探头。几何为existing_code_unverified，均匀无损介质及1 Pa声源、电声响应为assumed，标定unknown；未建模俯仰透镜。有限ROI不支持完整焦域/总能量判断，不作温升、固化或临床安全结论。

## 2026-10-09 — 独立 R2024b 单点成像基准

**已实现。** 按用户要求新建 [independent_simulation](independent_simulation/README.md)，独立入口、+iceind命名空间、参数、测试及结果；不加载厂商运行时或修改许可。首版为理想法向平面波的单点解析RF与相干DAS重建，原ICE虚拟焦点序列尚未移植。内部SI单位，幅度arbitrary units；配置来源和方程见[模型记录](independent_simulation/docs/model_and_validation.md)。

**已验证。** R2024b Update 2下5/5测试通过；synthetic目标(0.830,20.030) mm，峰值(0.825,20.025) mm，内部定位误差0.007071 mm，小于0.025 mm网格对角线。见[结果图](independent_simulation/results/point_target.png)、[配置和指标](independent_simulation/results/point_target_report.json)、[测试表](independent_simulation/results/test_results.csv)。

**尚未实现与限制。** 未接入MUST/k-Wave、有限孔径发射场、15角度复合、照射扫描、热/固化。原软件几何未核实，介质/波包assumed；正反演共享简化模型，仅为内部一致性检查，未做独立求解器、收敛或实测验证，不代表真实ICE精度或固化能力。

## 2026-10-09 — ICE 仿真入口检查与兼容性阻塞

**已实现。** 新增[诊断准备脚本](scripts/prepare_ice_simulation_checks.m)，生成原 ICE 静止单点仿真副本和三种双模式单帧诊断文件；明确 simulateMode=1、加载冻结及仅初始化。目标 synthetic，探头定义未核实，驱动/介质假设及单位见[验证记录](docs/verasonics/simulation_verification_2026-10-09.md)。

**已验证。** 本轮 MATLAB R2024b Update 2 离线测试85/85通过，诊断文件生成及保存重读检查通过；原脚本与原MAT未修改。证据见[本轮结果](results/verification_2026-10-09/test_results.csv)和[独立审计](results/verification_2026-10-09/audit.json)。

**同日复核。** 用户提供 R2024a Update 9 后，离线测试再次85/85通过，0失败、0未完成，见[结果CSV](results/verification_2026-10-09/test_results_r2024a.csv)。

**阻塞与未验证。** 初次因 R2024b 版本不兼容停止；随后使用用户提供的 `E:/MATLAB24a`（R2024a Update 9）成功生成本机 systemInfo，版本阻塞解除，但确认当前许可不授予本机任何功能（[日志](results/verification_2026-10-09/activation_r2024a.log)）。尚未进入VSX，没有仿真RF/图像、定位误差或交替运行通过结论；没有声场、热或固化求解。下一步为申请本机Simulator授权，详见验证记录。

## 2026-10-08 — ICE 成像与候选固化照射算法序列

**已实现。** 基于现有ICE软件配置新增[独立双模式入口](verasonics/dual_mode/SetUpICE_ImagingCuring.m)及[集中配置](verasonics/dual_mode/+icevs/default_config.m)，支持成像、仅照射和交替运行，多焦点聚焦、有限脉冲、TPC切换与恢复等待，导出MAT/JSON/事件CSV。原厂商脚本和基线MAT保留。阵元数、几何及接线可集中替换；96元必须显式提供匹配映射。具体来源、单位和数值适用范围见[升级报告](docs/verasonics/dual_mode_upgrade_2026-10-08.md)与[使用说明](verasonics/dual_mode/README.md)。

**已验证。** MATLAB R2024b Update 2全项目85/85项测试通过，其中新增25项；12个MATLAB文件Code Analyzer为0条消息。测试覆盖基线延时对照、聚焦到达时间、三模式事件索引、无接收无DMA、有限停止、96元适配及保存重读。审阅发现的显式几何、奇数缓冲帧数和NS200BW频率边界已修正。实际执行结果记录在[测试CSV](results/validation/test_results.csv)、[Code Analyzer记录](results/verasonics_dual_mode/code_analysis.json)、[三模式汇总](results/verasonics_dual_mode/mode_summary.csv)；[关键原文件哈希核对](results/verasonics_dual_mode/vendor_integrity.json)一致。

**尚未验证与限制。** 默认仅离线构建，未调用VSX、激活或硬件。当前64元为existing_code_unverified，与用户提供的实物96元信息仍需核对；新增照射与等待参数为assumed，电声/材料参数为unknown。求解仅涉及均匀介质几何延时及序列编排，未运行声场、热或固化求解。时间是调度下界，实际量化、缓冲容量、profile选配及恢复需后续验证，不能据此声称固化成功或临床安全。

## 2026-10-08 — Vantage 软件包资料提取与 ICE 配置核对

**已完成。** 新增 [ICE 资料入口](docs/verasonics/README.md)及[提取报告](docs/verasonics/package_review_2026-10-08.md)，枚举 4,046 个文件，提取 347 份 PDF 共 918 页的文本，建立探头定义、文档主题页、工具和保存配置索引。40 对重复工具文件哈希一致。报告区分 AGENTS 指定手册与随包新版手册，记录单位、来源及适用范围。

**已核对。** 当前 ICE 源码、`computeTrans` 和已有 MAT 均使用 64 阵元软件定义；用户提供的实物信息为 96 阵元，两者对应关系仍为 unknown。保存 MAT 通过 SciPy 只读解析，不含实测 RF 数据，不能作为已上机运行的证据。文件与配置核验见[验证记录](docs/verasonics/reference_2026-10-08/validation.json)。

**尚未执行与限制。** 未修改厂商软件包、物理模型或驱动参数，未运行 VSX/采集/硬件测试；本轮没有声场、热或固化求解。MATLAB R2024b 的只读数据审计尝试在启动时失败，已用 Python 完成数据读取；未调用 activate，不能据此判断 Vantage 兼容性或启动失败原因。实物阵元几何、接线、实际 TPC 及电声标定仍待核实。

## 2026-09-26 — 课题推进与验证计划

**已完成。** 新增[课题总计划](docs/superpowers/plans/2026-09-26-ice-research-roadmap.md)、[实验合同](refine-logs/EXPERIMENT_PLAN.md)与[执行台账](refine-logs/EXPERIMENT_TRACKER.md)，覆盖 P0-B 数值可信度、受控比较、转向/扫描、稳健性，以及后续成像、材料、硬件与实测验证依赖。

**本次核对。** 静态审阅源码与已有结果发现：P0 粗细网格沿用首末体素中心，实际 ROI 边界随间距变化；两个演示固化孔径中心相差 0.2 mm；当前活动阵元积分模型不会因架构标签本身产生声场差异。计划据此增加固定物理边界、评价域/搜索域区分与同活动孔径负对照。原数值结果和物理求解器未修改。

**尚未执行与限制。** 本次只交付计划，未重跑 MATLAB 或新增材料/硬件实验。12 周、每周 20 小时为 assumed 排期；计划中的验收容差为 proposed 内部研究门槛，不是材料或安全标准。后续模型、脚本和真实参数仍需逐项实现与验证。

## 2026-09-24 — P0-A 双阵列声学筛选升级

**更新内容。** 增加共面独立 96+96 合成阵列、左右/上下连续分区、三维单焦点和逐点停留扫描、焦前/焦后暴露统计、显式驱动限值判断，并保留原 Rayleigh 快速求解器和旧配置入口。代码、脚本及单位说明见[升级记录](docs/upgrade_2026-09-24.md)；阶段安排见[升级计划](docs/superpowers/plans/2026-09-24-ice-p0-upgrade.md)。

**验证。** MATLAB 回归测试 60/60 通过；39 个 MATLAB 文件的 Code Analyzer 记录 0 条警告。合成比较及局部数值检查见[比较结果 CSV](results/p0_probe_compare/comparison.csv)及[升级记录](docs/upgrade_2026-09-24.md)。这些数字是配置定义的声学暴露筛选量，未经探头或材料标定。

**结论与下一步。** 当前需要继续做 P0-B 的轴向 ROI 扩展与网格/阈值联合收敛，然后才进行受控参数扫描。在相同的 35% 阈值下，两架构的目标外比例差约 0.00025；仅双阵列粗细网格的比例差约 0.00074，而且轴向 −6 dB 宽度因 ROI 截断为 `NaN`。因此当前结果不足以给两种架构排序。P1 的 k-Wave、热/血流、材料剂量和成像性能仍未实现。

## 2026-09-23 — 初始 MATLAB 声场基线

建立线阵/矩阵 Rayleigh 声场、三类发射模式、共享/分区基线、阈值与波束指标、测试和演示结果。初始物理假设与结果见[第一阶段报告](docs/project_implementation_report.md)；其中参数均为合成示例，不是实际 ICE 设备输出。
