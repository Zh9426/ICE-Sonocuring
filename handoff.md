# ICE 双功能探头：驱动核验与实验准备交接

## 2026-11-07 标准版公开参数与高输出研究

按用户确认的 TINGSN Sonic Eyes 10 标准版检索公开资料。监管审评概述确认相控阵压电陶瓷及头端温度传感器；标准版产品推介报告64阵元和4.5–9.5 MHz成像多频切换，见[公开参数与证据](docs/verasonics/sonic_eyes_10_public_parameters_2026-11-07.md)。0.13 mm中心距、0.11 mm宽度、50 Ω及35 V仍仅为原软件定义或限制，非实物标定或长脉冲厂家额定；4.5–9.5 MHz多频切换不等于探头−6 dB带宽。本次未找到本型号公开的允许电压、burst/duty或热额定，无法据此确定更强照射的可用范围。后续优先获取对应厂家资料、确认温度接口和系统选件，并对实际输出/温度/固化结果分别验证；本次未修改驱动或运行硬件。

## 2026-11-07 用户确认探头型号

用户结合实物手柄及已查产品外形，确认本项目探头按 **TINGSN Sonic Eyes 10 标准版**开展研究。用户提供照片可见 TINGSN、Sonic Eyes 和 10F；照片该面未显示完整商品型号，型号依据为用户确认而非读取完整标签。此前 Eco 候选图片的型号未能独立核实，不能作为 Eco 与标准版外观差异已证实的依据。型号确认不代表阵元几何、电气参数或额定条件已由厂家标定；这些仍沿用源码或 unknown。纯照射代码的 `cfg.identity.exact_model` 当前仍为 `unknown`，本轮仅记录用户确认，未修改驱动、生成结果或实际硬件配置。

## 2026-11-07 纯照射线程：原版对照与探头定义

本线程范围限定为纯照射探头驱动开发与研究。已找到本机 `VantageNXT-2.3.2-p2/` 的原成像 SetUp、原 MAT、`computeTrans.m` 和 `computeTXDelays.m`，四项 SHA-256 与 2026-11-03 记录一致；该软件包不随 Git 同步，跨电脑可能不可用。原版与四个纯照射候选的发射、事件、孔径及源码参数见[对照记录](docs/verasonics/curing_original_comparison_2026-11-07.md)。原代码的连接映射注释与执行语句不同，应以 `ConnectorES=1:64` 执行值描述，实物接线仍 unknown。

指定手册目录在当前电脑不可访问；随包产品规格书 D00108 Rev.L 与指定版历史哈希一致，随包序列手册为 D00163 Rev.L，而指定版为 Rev.K。本次为只读核验与文档整理，未运行 VSX、MATLAB 回归或硬件；纯照射参数仍 assumed，实物额定与输出 unknown。

## 2026-11-03 当前优先：单独验证探头固化能力的纯照射最小驱动

用户要求先单独验证探头固化能力，建立只有固化/照射功能的最小驱动，按全用到部分调用导出几版。现新增 `verasonics/curing_mode/+icec` 和四入口 `SetUpICE_Curing_All64 / Center48 / Center32 / Center16`，物理+x排名分别1:64、9:56、17:48、25:40。核心逻辑共用，其他照射参数一致；子集是居中连续选元，数量和孔径同时改变。

MAT序列不含Receive/PData/Recon/Process/UI或接收/显示缓冲区，只有一项照射TW及必要发射/TPC/有限事件；没有DMA，不安排成像恢复或结束切回成像档位，仍保留assumed充电等待和stop。复用原探头定义、既有聚焦延时、事件及限值后端；两用模块默认恢复行为不变。

本轮66/66相关MATLAB测试通过，四版已在 `results/curing_only_2026-11-03/drivers` 导出。入口不调用VSX/硬件；6 MHz、20周期、300脉冲等仍是沿用的assumed离线配置，不是已验证固化或上机推荐。见[运行说明及手册边界](verasonics/curing_mode/README.md)、[四版参数表](results/curing_only_2026-11-03/variant_summary.csv)、`results/curing_only_2026-11-03`下实际验证记录。以下为较早工作快照，两用方案保留，当前实验优先纯照射。

## 2026-11-01 当前方案：全64成像、照射阵元可选、时间复用

用户明确将“奇偶互斥分区”调整为“原全64元成像TX/RX，照射从同一阵列中选取部分或全部阵元”。驱动已支持新默认layout `full64_imaging_selected_exposure` 和 `cfg.partition.exposure_ranks`（物理+x排名）；旧奇偶/左右分区仅为显式对照。默认偶数32元照射是沿用候选，不是已优化或可上机的额定设置。新默认产物在 `results/verasonics_full64_selected_exposure`，旧结果保留。

研究准则：在达到预定义固化质量和处理时间要求后，寻找最低实测有效功率并记录总声能/电能；在厂家允许工作范围内建立可复现的器件能力包络，计入电压、burst、PRF/duty、累计负荷、温升和成像恢复。不是击穿阈值以下任意提升，也不是破坏性极限试验。

本轮58/58 MATLAB回归通过，23文件Code Analyzer 0消息，四个厂商基线文件SHA256未变；64/16、64/32、64/64候选均保留原成像TX、450条Receive及PData。名义负荷按共享阵元累计两类脉冲时间，并计入跨用途相邻发射间隔的局部比例检查。报告/运行记录见 [本轮方案](docs/verasonics/shared_aperture_2026-11-01.md)、`results/shared_aperture_2026-11-01`。未运行VSX/硬件；恢复时间仍assumed，真实固化功率与器件额定值unknown。以下2026-10-29及更早段落为历史快照，不代表新默认分配。

## 2026-10-29 本线程后续更新：已恢复原成像定义

用户已明确授权以原工作驱动为母版改写现有自写版。现已恢复原虚拟顶点发散波、实际角度、SectorFT/网格/接收窗口、Media/显示和缺省电压语义，保留奇偶分区与独立照射，新增仅imaging_only的全64对照。入口不变；新产物在 `results/verasonics_original_sector`，旧导出保留。

实际验证：MATLAB 48/48测试通过，21文件Code Analyzer 0消息；全64对照450条Receive和PData与原MAT一致，四个厂商基线文件SHA256未变。未运行VSX或硬件。各保留差异的理由、参数来源、手册页码和限制见 [本次修改报告](docs/verasonics/original_imaging_restoration_2026-10-29.md)，测试证据见 `results/original_imaging_restoration_2026-10-29`。

**下文第1–10节保留修改前的核验交接快照，其中“尚未恢复/尚未修改”和旧自写参数描述不再代表当前代码；研究边界、未知额定数据及硬件未验证状态继续适用。**

更新日期：2026-10-29（Asia/Shanghai）。工作目录：H:/print_transducer。

**当前重点已转为原驱动核验与器件实验准备。用户明确认为成像模块不应有大的改动。原驱动已能正常驱动探头成像，应作为后续修改基准；自写版改变了多项成像设置，尚未恢复。本轮只更新交接文档，不修改驱动。**

## 1. 用户最新确认与研究边界

- 合作方体外 FUS 打印是用户确认已经实施并成功的实验。不要再写成尚未开始的设想。
- 用户研究的是 ICE 器件在该应用中能否成功使用，是另一个实验角度/升级途径；ICE 双功能路线继续研究。
- 材料配方、材料递送、球囊和具体手术操作不属于用户研究范围，不重新安排为用户的工作包。合作方体外 FUS 不等于用户已决定采用的固化声源。
- 工作重心可以从仿真转移到器件实验准备，首先核验驱动。既往仿真用于解释和辅助设计，不要求先解决全部数值问题才开展所有器件验证。
- 驱动核验/修改的两个依据：①现有 H:/print_transducer/VantageNXT-2.3.2-p2 及已工作的原成像程序；②本支探头型号及规定的硬件限制。指定四份手册仍是系统侧基础。
- 探头目前仅猜测为 TINGSN Sonic Eyes 10 标准版，尚未确认，不能借用 10 Eco/10 Pro 的额定值。
- 用户本轮明确先核验、暂不修改驱动，随后确认成像模块应尽量保持原样。目前尚未实施恢复或功能修改。接手按用户后续任务执行，本交接不构成硬件操作授权。

## 2. 已确定的后续修改原则

**保留原驱动已经验证能工作的成像链路，在其基础上增加照射功能。**

1. 沿用原发散波方式、实际发射角度、扇形重建区域、网格、接收窗口、TGC、显示处理和启动电压逻辑。当前平面波、窄矩形视野、粗网格和显式 5 V 等变化，应逐项撤回或说明保留依据；它们不是增加照射所必需的。
2. 当前方案仍是 64 阵元线阵、奇偶交替分工：软件约定按物理 x 排序，奇数 32 元成像 TX/RX，偶数 32 元照射 TX。阵元分区单独作为设计变量，保留原全 64 成像为对照，不将分区与成像方式、角度及重建参数变化混在一起验证。
3. 照射独立增加 TW/TX、聚焦延时、有限事件和照射后的恢复时序。成像与照射时间交替，不是在照射期间同时成像接收。
4. 重点验证分区对成像/定位的影响，以及照射对后续接收和成像的影响、恢复需要多久。估计等待时间由实测逐项替换，不能写成已经测得。

以上是已讨论的方向，不是已完成的代码变更。

## 3. 接手先读

| 文件 | 用途 |
|---|---|
| [AGENTS.md](H:/print_transducer/AGENTS.md) | 仓库规则、四手册、验证和变更记录要求 |
| [本轮驱动核验](H:/print_transducer/docs/verasonics/driver_audit_2026-10-29.md) | 11 项发现、依据、检查范围及缺失资料 |
| [本轮验证状态](H:/print_transducer/results/driver_audit_2026-10-29/verification_status.json) | 实际完成项与未完成项 |
| [原工作程序](H:/print_transducer/VantageNXT-2.3.2-p2/XJD/SetUpP9_4TSICE_FlashAngles.m) | 成像工作基准；末尾调用 VSX，不为查看配置直接运行 |
| [原保存 MAT](H:/print_transducer/VantageNXT-2.3.2-p2/MatFiles/SetUpP9_4TSICE_FlashAngles.mat) | 实际对象值的只读对照 |
| [computeTrans.m](H:/print_transducer/VantageNXT-2.3.2-p2/Utilities/computeTrans.m) | P9-4ULts 分支约 1854 行起的几何和连接器执行定义 |
| [自写入口](H:/print_transducer/verasonics/dual_mode/SetUpICE_ImagingCuring.m) | 当前离线构建/导出，不调用 VSX |
| [default_config.m](H:/print_transducer/verasonics/dual_mode/+icevs/default_config.m) / [build.m](H:/print_transducer/verasonics/dual_mode/+icevs/build.m) / [compile_events.m](H:/print_transducer/verasonics/dual_mode/+icevs/compile_events.m) | 自写配置、成像构建和事件时序 |
| [旧交接完整快照](H:/print_transducer/docs/handoffs/handoff_before_2026-10-29.md) | 2026-10-24 以前的仿真、结果及入口；旧优先级已被本文件替代 |

P0 后端开发另参照 [P0 计划](H:/print_transducer/docs/superpowers/plans/2026-09-24-ice-p0-upgrade.md) 和 [升级记录](H:/print_transducer/docs/upgrade_2026-09-24.md)，其中 synthetic 阵列不能替代本支实物。

## 4. 原驱动与自写版的确定差异

已对照源码及保存 MAT。以下是当前状态，不是计划修改后的结果。

| 项目 | 原工作成像程序 | 当前自写版 | 接手注意 |
|---|---|---|---|
| 成像 TX/RX | 全 64 元 | 奇数 32 元 | 分区是独立变量，保留全 64 对照 |
| 发射方式 | 虚拟顶点发散波，负焦距 | 平面波，focus=0 | 不是原样继承 |
| 15 个发射角度 | 实际 −22.5°～+67.5° | −15°～+15° | 原注释与执行值不一致，MAT 支持执行值；不要写成 ±30°/±45° 或自动纠正 |
| 重建区域 | SectorFT 扇形 | x=[−6,6] mm 矩形 | 视野改变 |
| 网格 Δx/Δz | 0.13 / 约 0.11846 mm | 0.25 / 0.5 mm | 按 c=1540 m/s、Trans.frequency=6.5 MHz 换算；现网格较粗 |
| PData.Size | [810,1087,1] | [191,49,1] | 是重建网格，不是 k-Wave 传播网格 |
| Receive.endDepth | 432 波长 | 416 波长 | 随新视野重新计算，未保留原接收窗口 |
| 启动电压 | 原脚本未设 TPC.hv，原 MAT 无 TPC | 显式 5 V | 缺省启动 1.6 V；原实验是否手动调压未知 |
| 模式/循环 | simulateMode=0；30 帧缓存后 jump 持续循环 | simulateMode=1；有限 30 组后 stop | 构建器目前拒绝 simulate_mode=0 |
| 成像时序 | 400 μs 组内间隔，20 ms 帧时序 | 保留名义值，插入照射/等待 | 整体不再是原持续成像周期；计划时长是下界 |
| 照射 | 无独立照射模块 | 偶数 32 元、6 MHz、20 周期 | 新功能，原成像成功不能验证其输出/热负荷 |

仍沿用：64 线阵几何、1:64 通道映射、connType=4、Trans.id=−1、35 V 配置上限、成像波形 [6,.67,2,1]、NS200BW/12 MHz 解调、TGC 控制点、基本 IQ 叠加及 Image.imageDisplay 处理。波形 C=2 是两个半周期，即一个完整周期。

偏离原程序与已证明代码错误/超额定值要分开。用户确认原驱动能正常成像，接受其为工作基准；本线程没有重新进行实物验证。

## 5. 当前参数与硬件依据边界

- 源码几何：pitch 0.13 mm、宽度 0.11 mm、俯仰孔径 2.02 mm、固定俯仰焦距 30 mm、参考频率 6.5 MHz、配置带宽 [4,9] MHz；属于 source-derived/unverified，不是本支探头厂家标定。
- 奇/偶活动阵元中心距 0.26 mm，边缘空白 0.15 mm，每组孔径跨度 8.17 mm；不要混淆 pitch 与边缘缝隙。
- 35 V 来自原 SetUp 的 Trans.maxHighVoltage，不是已确认的长脉冲额定值。缺省 1.6 V 与自写 5 V 的比较依据为 D00163 Rev. K/L §12，p96；不证明 5 V 必然超限，也不反推原实验实际电压。
- 自写照射：6 MHz、20 周期、PRI 1000 μs、每焦点 10 脉冲、30 组。名义包络 3.333333 μs，组内包络占空比 0.333333%，300 次合计 1 ms；不是声能、温升或固化剂量。
- 初始化/换档各 5 ms、接收恢复 2 ms、充电等待 10 ms 均为 assumed。5 ms 不保证所有换档完成；默认成像/照射同为 Profile 1、5 V，两者之间不换档。
- Profile 5 安装/许可 unknown；离线可编译不代表本机具备。探头 burst/duty/累计通电时间/额定电压四项限制未核实，温度读取与保护闭环也未建立可验证证据。
- stop 是冻结，解除冻结可从 startEvent 再运行；一次序列有限不等于跨运行累计暴露受控。

待补：实物完整型号、厂家 IFU/额定表、转接板/UTA 接线和温度接口、本机型号/模块/频率配置/许可、原实验实际运行电压。缺少资料不妨碍只读核验或制定最小改动方案，但不能给出硬件额定合规结论。

## 6. 已完成与未完成

本轮已完成：

- 核对原脚本、原 MAT、computeTrans 分支、自写构建/校验/时序代码；读取指定四手册及随包手册，记录版本和哈希。
- 三个已保存 MAT 的事件引用、奇偶掩码、发射次数、照射 rcv=0、末尾 stop 检查通过：imaging_only 543 事件/450 采集；exposure_only 393 事件/300 照射；interleaved 933 事件/450 采集/300 照射。
- 核验阶段 12 个自写 MATLAB 文件和 4 个关键既有文件哈希一致，见 [source_integrity.json](H:/print_transducer/results/driver_audit_2026-10-29/source_integrity.json)。
- 用户确认保留原成像链路；进一步核对了原实际角度、网格和接收窗口。

未完成，不能宣称通过：

- MATLAB 离线回归及 Code Analyzer 请求约 7 分钟未返回后停止等待，未取得新输出。不是测试已失败，也不是已通过；不要盲目并发启动多个 MATLAB。
- 2026-10-12 的 43/43 测试、19 文件零静态消息是历史记录，非本轮运行。
- 未运行 VSX loader、系统自检、硬件、实际波形/声压/温度测量、接收恢复或固化实验。
- 未恢复原成像配置、未更改运行开关、源模型、额定值或 Verasonics 许可。

证据在 [results/driver_audit_2026-10-29](H:/print_transducer/results/driver_audit_2026-10-29)。[saved_mat_audit.json](H:/print_transducer/results/driver_audit_2026-10-29/saved_mat_audit.json) 是既有产物的本轮只读检查，不是新构建；[manual_manifest.json](H:/print_transducer/results/driver_audit_2026-10-29/manual_manifest.json) 记录手册路径、首页版本与哈希。

## 7. 下一步建议顺序

1. 读本交接及核验记录，按用户后续任务继续核验、制定方案或修改；不直接启动原 SetUp/硬件。
2. 对照原脚本和 MAT，把原成像保留项、仅因奇偶分区必须改变的项、新增照射项分开。优先恢复非必要成像变化，避免同时改变多个变量。
3. 若用户后续要求修改，保留原全 64 成像对照，单独组织 32 元分区与照射。不能只取消 simulate_mode=0 的拒绝条件就称硬件版完成。
4. 完成实际离线对照与适用软件测试；MATLAB 不可用则记录未完成项，不用旧通过数替代。
5. 硬件依据落实后，按授权验证原成像、分区成像、有限照射输出和成像恢复，记录输出、热负荷及等待时间实测值，不先指定未经额定依据支持的上机参数。
6. 非琐碎代码修改依 AGENTS.md 更新 CHANGELOG、记录验证和限制。本轮只交接，不提交/推送。

## 8. 仿真与图片证据保留

此前完成过三维 k-Wave、扩大域/PML、32 对 64 元和 65 对 52 μm 网格比较。扩大域发现浅层离轴高压，64 元对照显著改变该分布，网格细化未消除相关现象；源表示是待排查方向，尚未确定全部因果、全域收敛或固化能力。继续源模型仿真不再是默认首要任务。

- [2026-10-24 结果解读](H:/print_transducer/independent_simulation/docs/findings_2026-10-24.md) / [宽域报告](H:/print_transducer/independent_simulation/docs/widegrid_2026-10-24.md)。完成工况不为查看结果重复启动。
- [含浅层区域的新版三维声压 HTML](H:/print_transducer/independent_simulation/results/kwave_widegrid_2026-10-24/interactive/widefield_pressure_3d.html)。显示含降采样，各位置时间窗最大绝对声压不是同一时刻快照；未标定幅度不等于实物声压。
- [旧交接快照](H:/print_transducer/docs/handoffs/handoff_before_2026-10-29.md) 保留详细仿真数据及入口。旧文档以仿真/材料/球囊为先的工作排序不再适用。

max_t|p| 是每一点随时间的最大绝对声压；Qp=∫p²dt 是压力平方时间积分代理，不自动等于声能或沉积热。固定主焦区作参考时，浅层可出现正 dB，不能误解为相对全域最大值仍为正。

## 9. 指定硬件手册

目录：F:/xwechat_files/wxid_quwpem6vchzg22_3c29/msg/file/2026-10/。涉及硬件能力、接口、驱动、采集和时序时，先查相关章节，注明版本和页码。资料不可访问时明确报告。

| 手册/版本 | 本次相关依据 |
|---|---|
| Product Specification，D00108 Rev. L | §1.4，印刷 p8–9/PDF p9–10：选件、Profile 5、系统检查不能替代探头过热及声输出约束 |
| Initial Setup Instructions，D00109 Rev. D | §4.5，p9–10：系统自检和日志；本轮未执行 |
| System User Manual，D00107 Rev. K | §4.4.1–4.4.2，p30：成像供电与扩展发射选件 |
| Sequence Programming Manual，D00163 Rev. K | §4.3.1–4.3.2，p23–25；§12，p95–98；§13.1，p107、110–111；§16，p121；附录 A107：stop/恢复 |

随包对应版本为 D00108 Rev. L、D00109 Rev. E、D00107 Rev. L、D00163 Rev. L，后面三份不同版，不混用页码。发布说明 D00297 Rev. C 还记录缓冲区对齐、无接收却有 DMA 等问题，详核验记录。选配能力不等于本机已安装/许可，电气输出不能直接当作声压、温升或固化。

## 10. 工作区与本次交接

工作区已有大量修改和未跟踪文件，包括 Vantage 包、自写驱动、独立仿真和结果。不要清理、重置、批量覆盖或把全部 dirty 内容归为本轮改动。原 SetUp 会运行 VSX；自写 SetUp 和 scripts/verify_verasonics_dual_mode.m 默认会覆盖已有导出，查看状态无需执行。

本次仅更新根目录 handoff.md、新增旧交接完整快照及快照说明；没有修改驱动、启动 MATLAB/VSX、操作硬件、修改许可证、提交或推送。未知数据继续标 synthetic/assumed/unknown，声学暴露不写成成功固化或临床安全。
