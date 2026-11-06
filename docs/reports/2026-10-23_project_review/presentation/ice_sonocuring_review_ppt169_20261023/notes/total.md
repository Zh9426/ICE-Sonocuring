# 01_目标聚焦

这一阶段，我们已经把ICE双用途的架构设想，推进到可以逐项验证的体外单点目标。最初的问题是：同一支ICE探头，能否既提供成像定位，又对指定区域实施局部超声作用？长期方向仍然是成像与材料作用协同，但近期先聚焦固定单点，再讨论连续短线。

九月主要建立参数化声场、架构比较和暴露指标，使不同配置能够在明确条件下比较。十月上旬接入原有软件配置，形成成像、候选照射与交替三种离线模式，同时建立独立传播计算。十月中旬将当前方案明确为六十四阵元线阵的奇偶分区，并完成对应三维k-Wave计算。十月下旬则转向扩大计算域、累计暴露代理和体外单点方案，查找现有证据的缺口。图中时间轴只表达阶段顺序，不按持续时间比例绘制。

目前交付的核心是可追溯的仿真与离线序列证据。它们让我们知道配置、算法和数值结果如何连接，但还没有证明材料可以固化，也没有完成真实声压和完整双功能流程验证。下面先说明，这段时间具体建成了哪些可复用工具。

本页主要依据H:/print_transducer/docs/reports/2026-10-23_project_review/项目工作梳理报告.md和PPT详细大纲_5页.md，原始依据包括H:/print_transducer/docs/project_implementation_report.md、H:/print_transducer/docs/upgrade_2026-09-24.md、H:/print_transducer/docs/superpowers/plans/2026-09-26-ice-research-roadmap.md、H:/print_transducer/docs/verasonics/linear64_oddeven_2026-10-12.md、H:/print_transducer/independent_simulation/docs/ice_bench_poc_plan_2026-10-21.md及H:/print_transducer/independent_simulation/docs/singlepoint_validation_2026-10-22.md。资料范围截至2026年10月22日。本次PPT制作只读取保存证据，没有重新运行MATLAB、k-Wave、VSX或硬件实验。九月二十二日是最早现存基线记录，九月二十三日为首个Git提交，后续工作包含未提交增量，不能说全部进展已经提交。

---

# 02_验证工具

现有工作已经形成三条可以追溯和复核的工具线，但还没有形成完整物理闭环。

第一条是Rayleigh快速筛选。它负责阵列几何、孔径分配和逐点扫描，输出覆盖、目标外暴露和均匀性等声学筛选量。这里的覆盖不是固化率，模型也没有真实材料吸收、温升或反应动力学。第二条是Verasonics对象的离线编排，负责把成像、候选照射和交替模式的阵元、波形及事件组织起来，并保存MAT文件、事件表与参数来源。第三条是独立k-Wave传播复核，已经能够读取保存序列中选定的一次发射，计算三维声场，并检查网格、计算域和PML的敏感性，补充Qp代理统计。

连接方式需要分清。Rayleigh筛选与离线序列之间尚未自动贯通，所以用虚线表示。离线序列到k-Wave使用实线，表示读取保存MAT中的选定TX；这仍然是单次发射计算，不是整个成像与照射交替流程。配置与单位、软件检查、数值结果及解释范围都应保留，任何一层通过都不能代替其他层的验证。

下方是仍待补齐的物理链：电气请求如何对应真实声压，声场如何通过吸收形成热源，材料如何发生可测转化，以及实际双功能流程如何运行。接下来所有性能讨论，都要回到当前究竟采用哪支探头、哪一种阵元分配。

本页依据H:/print_transducer/docs/system_architecture.md、H:/print_transducer/docs/upgrade_2026-09-24.md、H:/print_transducer/docs/verasonics/simulation_verification_2026-10-09.md、H:/print_transducer/docs/verasonics/linear64_oddeven_2026-10-12.md、H:/print_transducer/independent_simulation/docs/model_and_validation.md、H:/print_transducer/independent_simulation/docs/kwave_oddeven_results_2026-10-19.md及H:/print_transducer/independent_simulation/docs/singlepoint_validation_2026-10-22.md。历史测试范围不同且存在重叠，不能相加成一个项目总数；相关记录分别保存在H:/print_transducer/results/verasonics_linear64_oddeven/validation.json、H:/print_transducer/independent_simulation/results/kwave_oddeven/validation.json及H:/print_transducer/independent_simulation/results/kwave_singlepoint_validation_2026-10-22/validation.json。本轮没有重跑这些测试。

---

# 03_奇偶与时序

当前方案已经完成六十四元奇偶分区和事件的离线编排，物理性能仍需分别验证。这里特别画成一条连续线阵，是为了避免与历史十二乘八矩阵分支混淆。

按物理位置的正x顺序，奇数三十二元约定用于成像发射和接收，偶数三十二元用于候选照射发射。用途角色是assumed设计约定，可以交换；源码保留完整六十四项孔径、延时和接线映射。源码pitch为零点一三毫米，因此每组活动间距为零点二六毫米；这些属于existing_code_unverified数据，还没有得到厂家或水听器标定。历史矩阵结果只保留synthetic分支价值，不再解释当前探头。

十月十二日保存记录中，相关离线测试四十三项全部通过，覆盖重排、映射、用途交换、孔径、延时和事件互斥。这个计数说明软件对象和策略的一致性，不能证明VSX实际加载、成像质量、真实发射或材料作用。本机模块与许可、探头额定长脉冲和占空比范围仍为unknown。

下方时序表示成像、切换等待、候选照射、接收恢复，再回到成像，是有限时间交替的概念示意，不按真实时长比例绘制。等待值需要实际验证，不能把这张图解释为同时成像固化。声场、图像恢复和材料结果要分别验收。下一页再看当前方案的独立传播结果。

本页证据为H:/print_transducer/docs/verasonics/linear64_oddeven_2026-10-12.md、H:/print_transducer/verasonics/dual_mode/+icevs/default_config.m及H:/print_transducer/results/verasonics_linear64_oddeven/validation.json。探头照片与原代码支持当前六十四元线阵软件基础，但完整商品后缀unknown。六兆赫、二十周期和五伏是assumed离线示例，不是已验证的固化工作点，也不存在五伏到真实声压的映射。

硬件解释直接核对了F:/xwechat_files/wxid_quwpem6vchzg22_3c29/msg/file/2026-10/目录中的四份原始PDF。Vantage NXT Sequence Programming Manual，D00163 Rev.K，第四点三点二节、第二十四至二十五页说明TW与TX、孔径和延时；TX.Delay附录A171页，即PDF第三百一十页，明确延时以Trans.frequency的周期解释，因此当前六点五兆赫延时参考与六兆赫波形频率的用途不同。System User Manual，D00107 Rev.K，第四点四点一至第四点四点二节、第三十页区分成像供电与可选Profile 5扩展发射。System Product Specification，D00108 Rev.L，第一点四节、印刷第八至九页，即PDF第九至十页，说明相关高功率选件和系统保护边界，不能据此认定本机具备选件或探头不过热。Initial Setup Instructions，D00109 Rev.D，第四点五节、第九至十页说明自检及HardwareTest/TestResultLogs记录，当前没有实际自检证据。这些手册仅用于技术核对，本次没有执行硬件操作。

---

# 04_数值证据

核心判断是：目标附近的声压集中已有模型证据，但空间选择性和局部固化能力还没有得到证明。

先看左侧。模型采用assumed的一帕参考源、均匀线性无损流体，没有实现真实俯仰透镜，也没有材料吸收、热学、容器或固化模型。求解器为k-Wave一点四点一的kspaceFirstOrder3D，MATLAB R2024b Update 2，gpuArray-single，CFL零点二。十月十九日五十二微米网格结果中，目标深度为二十毫米，搜索域内峰值在十八点四六毫米，向前偏移一点五四毫米，未通过proposed零点五毫米内部定位诊断；这个诊断阈值并非厂家精度标准。

连续声压半幅宽在x、y和z方向分别约为零点七一七、二点八九四和十三点四七七毫米，条形图使用同一零到十四毫米坐标轴。这是约负六点零二分贝的压力幅度宽度，不是强度FWHM。较长的轴向焦区是需要解释的问题。六十五与五十二微米两网格在公共ROI的声压场相对L2差为百分之零点七四九，只支持这一范围内两网格接近，完整收敛尚未建立。

再看右侧。十月二十二日扩大横向计算域后，wide65在坐标六点三七、零、二点零一五毫米发现更强的浅层离轴声压峰，比同工况目标附近的峰高约百分之六点七六，而且半幅交点触边。公共ROI很接近仍可能遗漏旧域外更强的峰，因此全前向域峰值稳定性未通过。该热点成因尚待诊断，不能直接命名为栅瓣；它到目标约十九毫米的距离，也不能与左侧一点五四毫米主焦区偏移混写。

最后，峰压最大点并不是Qp最大点。Qp定义为dt乘以各采样时刻压力平方之和，单位帕平方秒，只是压力平方时间积分代理，缺少吸收和材料响应时不能称为沉积能量或热剂量。fine52中，在八乘四乘十八毫米的assumed评价盒内，中心位于零、零、二十毫米的synthetic一毫米立方目标，其Qp空间积分比例为百分之二点一六零。这个盒子不含浅层离轴峰，所以该比例不是全空间比例，更不是固化率或能量效率。当前应当以这些负结果决定后续诊断，而不是提前作出固化能力结论。

局部指标的依据为H:/print_transducer/independent_simulation/results/kwave_oddeven/focus_summary.csv、H:/print_transducer/independent_simulation/results/kwave_oddeven/grid_comparison.json及H:/print_transducer/independent_simulation/docs/kwave_oddeven_results_2026-10-19.md。扩大域与Qp依据为H:/print_transducer/independent_simulation/results/kwave_singlepoint_validation_2026-10-22/focus_summary.csv、sensitivity_summary.csv、exposure_summary.csv和interpretation_diagnostics.json，完整分析见H:/print_transducer/independent_simulation/docs/singlepoint_validation_2026-10-22.md及H:/print_transducer/independent_simulation/docs/singlepoint_interpretation_2026-10-22.md。十月二十二日延长记录时窗新基线的fine52差为百分之零点七五一四，与十月十九日百分之零点七四九属于不同对照，不混用。Qp峰仍在零、零、十八点三三零毫米，离轴峰压点的Qp约为该前向域Qp峰的百分之七十六点六八四。三维峰压体记录各点在时间窗内的最大绝对声压，不是同一时刻的三维快照，也没有完整四维声压历史。本轮只读取保存数据，没有重新求解。

---

# 05_验证路线

下一阶段以单点证据为门槛，再扩展到连续短线和双功能流程。图中全部是后续计划，首步只是已有工具基础上近期可继续的离线工作，并不表示已经完成。

第一步解释边界与孔径：继续检查宽域、PML和近源区，在明确资源口径下比较偶数三十二元与全六十四元，同时核实真实俯仰透镜。比较要分别报告同单元幅度和同源平方积分预算，避免把驱动差异误归因为孔径优势。第二步冻结参数并建立声压标定路径，明确探头允许范围、样品和容器、声压时间记录及空间坐标。

第三步才是固定单点材料试验。需要先明确SonoInk具体配方，设置无超声对照，并用可测的材料转化判据验收。单点成立后推进短线，机械移动与电子扫描代表不同能力，应分别验证，记录连续性、宽度和厚度、线外作用与重复性。最后再运行成像定位、候选照射、接收恢复和图像恢复的完整双功能流程。

当前最需要补齐的输入有两组。一组是探头与系统的完整型号、额定burst和duty范围、模块与许可；另一组是材料配方、样品厚度与容器，以及声压、位移和温度的记录条件。尚未确认的项目继续标为unknown，不承诺缺少条件时的完成日期。以有标定、有对照的单点结果，决定是否进入后续验证，阴性结果同样需要明确保留。

本页依据H:/print_transducer/independent_simulation/docs/ice_bench_poc_plan_2026-10-21.md、H:/print_transducer/independent_simulation/docs/singlepoint_validation_2026-10-22.md及H:/print_transducer/independent_simulation/docs/singlepoint_interpretation_2026-10-22.md。材料固化和短线尚无实际结果，SonoInk是研究方向而非已冻结配方；不能用任意温度阈值或Arrhenius参数替代真实配方的转化判据。硬件就绪依据为F:/xwechat_files/wxid_quwpem6vchzg22_3c29/msg/file/2026-10/Vantage NXT System Initial Setup Instructions.pdf，D00109 Rev.D第四点五节、第九至十页；驱动和选件解释同时依据同目录System Product Specification，D00108 Rev.L第一点四节、印刷第八至九页，System User Manual，D00107 Rev.K第四点四点一至第四点四点二节、第三十页，以及Sequence Programming Manual，D00163 Rev.K第四点三点二节、第二十四至二十五页和TX.Delay附录A171页。手册中存在的可选能力不代表本实验室设备已经具备，电气输出也不能直接换算成声压、温升、固化结果或临床安全结论。
