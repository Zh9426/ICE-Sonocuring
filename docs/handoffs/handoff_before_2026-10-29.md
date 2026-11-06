# ICE体外聚焦与候选固化：交接文档

更新日期：2026-10-24。工作目录：`H:/print_transducer`。

> 2026-10-24最新：宽域52 μm的fine_even32和fine_full64_matched均已完成及独立回读，分别1737.9／1738.4 s，勿重复启动。原离轴/主焦区测点Qp比为32元0.9390、全64元0.000623，两组主焦点均18.460 mm。32元近源/浅层L2约11.68%/6.89%，浅层峰压约+11.43%，未过5%判据；全64各分区场差较小，但不代表所有argmax位置判据均通过或完整收敛。见[最新解读](independent_simulation/docs/findings_2026-10-24.md)及[完整报告](independent_simulation/docs/widegrid_2026-10-24.md)，结果目录`independent_simulation/results/kwave_widegrid_2026-10-24`。36项MATLAB/25项Python通过，173份历史文件哈希一致。源空间谱审计显示0.11 mm单元仅1.69/2.12格，代表单元6 MHz/75°谱偏差约18.4%/7.4%，尚未隔离传播误差因果。下一优先为kWaveArray带限源表示与尺度/支撑/容差及网格验证，再处理20 mm焦深和俯仰模型；本轮尚未替换源、执行BLI传播或模拟SonoInk材料。

> 2026-10-23最新：边界两组与synthetic full64_matched均已完成并回读。PML/X域控制L2差0.077%/0.022%，原离轴峰位不变；全64等源端代理预算下原固定离轴/主焦点Qp比0.7669→0.000373，主峰仍约18.4 mm。见[结果解读与下一步](independent_simulation/docs/findings_2026-10-23.md)、[边界报告](independent_simulation/docs/offaxis_diagnostic_2026-10-22.md)及[阵元对照](independent_simulation/docs/aperture_control_2026-10-23.md)。全64输出在`independent_simulation/results/kwave_aperture_control_2026-10-23`，勿重复启动完成工况。32项MATLAB/17项Python测试通过，全64审计98份历史输入/结果哈希一致；保存SetUp和硬件角色均未改变。下一步优先宽域细网格、真实俯仰模型及固定20 mm目标的设计焦深补偿；仍无固化/硬件结论。

> 当前状态：64阵元线阵奇偶交替驱动已完成离线构造与相关软件测试；偶数32元单次照射的k-Wave三维声场已实际运行。尚未验证实物精确聚焦或材料固化。近期目标是ICE体外单点聚焦、局部固化及扫描成线。

> 2026-10-22单点验证增量：65 μm基线、加厚PML、扩大横向域、延长轴向域和52 μm累计暴露五个工况均已完成并回读。扩大域发现比目标附近局部峰更强的离轴声压峰，全前向域峰值稳定性检查未通过；不能把公共ROI小差异写成全域聚焦已通过。最新状态及独立结果目录见[本轮报告](independent_simulation/docs/singlepoint_validation_2026-10-22.md)。

本文替代此前以左右分区为主体的根目录交接快照。旧配置与结果保留在原目录，不能混用为当前奇偶方案的证据。本文是状态和技术资料，不构成硬件操作授权。

## 1. 用户最新方向与未决事项

- 用户确认采用**64阵元、单行线性排布、奇偶交替**。默认沿物理+x排序，奇数1,3,…,63用于成像TX/RX，偶数2,4,…,64用于候选照射TX；奇数负责成像是assumed软件角色约定，支持互换。
- 成像与照射按时间交替，不是在照射时同时接收成像。用户要求先保留现有SetUp；官方simulator尚未取得，本阶段先使用独立k-Wave求解。
- 2026-10-21用户将近期目标收缩为：先关注ICE探头本身，在体外验证焦点，或扫过固化缸形成一条线。左心耳、球囊、血流和临床封堵暂不作为近期验收对象。
- 用户特别关注非目标区域暴露偏高。后续必须同时评价目标覆盖和目标外暴露；不能仅凭焦点附近有高声压宣布方案有效。
- 2026-10-22用户补充：材料暂按SonoInk方向，具体配方、批次、触发/聚合参数、固化判据、样品形状与厚度、水听器和位移台仍unknown。文献SonoInk体系提供声热聚合机制线索，不能当作本样品标定；本轮仍是assumed均匀无损声场。用户此前只知道球囊辅助递送，不能自行补成左心耳模型。
- “固定焦点后机械移动探头/材料槽”与“固定探头后电子逐点扫描”是两个候选路径；机械方案优先是已有方案建议，尚非用户确认的最终实验方式。

## 2. 接手先读这些文件

|入口|作用|
|---|---|
|[根目录规则](AGENTS.md)、[独立目录规则](independent_simulation/AGENTS.md)|证据标记、硬件资料、文件范围和验证要求|
|[体外验证方案](independent_simulation/docs/ice_bench_poc_plan_2026-10-21.md)|近期阶段目标、机械/电子扫描区别和下一轮仿真范围|
|[单点边界与Qp验证](independent_simulation/docs/singlepoint_validation_2026-10-22.md)|本轮增量、扩大域离轴声压峰、累计暴露代理及SonoInk依赖|
|[实际k-Wave结果报告](independent_simulation/docs/kwave_oddeven_results_2026-10-19.md)|聚焦数值、记录语义、适用范围及未完成事项|
|[独立仿真入口说明](independent_simulation/README.md)|MATLAB R2024b运行入口及历史模型边界|
|[当前驱动说明](verasonics/dual_mode/README.md)、[奇偶升级报告](docs/verasonics/linear64_oddeven_2026-10-12.md)|当前分区、离线驱动与测试|
|[硬件研究](docs/verasonics/sonic_eyes_hardware_2026-10-12.md)|实物身份、来源和四手册章节；其中左右分区段落是历史快照|
|[更新公告](CHANGELOG.md)|各阶段实际状态；优先采用最新日期且配置相符的记录|

原始工作源码为`VantageNXT-2.3.2-p2/XJD/SetUpP9_4TSICE_FlashAngles.m`，末尾会调用VSX。读取源码或已有MAT即可，不能为了解配置直接运行该原始脚本。

P0后端开发仍参考[升级计划](docs/superpowers/plans/2026-09-24-ice-p0-upgrade.md)和[升级记录](docs/upgrade_2026-09-24.md)，但其中的合成阵列不可替代当前实物定义。

## 3. 当前驱动与参数边界

入口：[SetUpICE_ImagingCuring.m](verasonics/dual_mode/SetUpICE_ImagingCuring.m)；配置：[default_config.m](verasonics/dual_mode/+icevs/default_config.m)。

当前实现按阵元物理x排序划分用途，不依赖数组行号或ConnectorES盲切。保留完整64项Apod/Delay向量与接线映射；支持`odd_imaging_even_exposure`、反向角色和显式历史左右分区。线阵焦点限定XZ平面，y=0。

|参数|当前配置|来源与限制|
|---|---|---|
|探头身份|TINGSN / Sonic Eyes / 10F；64元线阵|用户照片及原代码可用的用户报告；完整型号后缀unknown，未在本线程实测|
|软件别名|P9-4ULts|软件命名，不等于已核实商品型号|
|阵元pitch/宽度|0.13/0.11 mm|existing_code_unverified，不是厂家标定|
|俯仰孔径/焦距|2.02/30 mm|assumed估计；当前传播模型未实现该俯仰透镜|
|Trans参考频率/源码带宽|6.5 MHz/[4,9] MHz|existing_code_unverified，不是实测频响|
|ConnectorES/connType|1:64/4|existing_code_unverified；实物朝向及接线仍需核对|
|声速/阻抗|1540 m/s / 50 ohm|assumed，阻抗不是实测复阻抗谱|
|系统通道声明|128 TX/128 RX|existing_code_unverified；本机配置及许可unknown|
|成像|6 MHz、2半周期、15角度[-15°,15°]|离线序列配置，实际波形与图像未验证|
|候选照射|6 MHz、20周期、每焦点10脉冲、PRI 1000 μs|assumed离线示例，不代表足以固化或已核实实验工作点|
|默认焦点|[0,0,20] mm|探头坐标系中的synthetic测试目标|
|供电请求|成像/照射均5 V、Profile 1|assumed，未进行电压到声压标定|
|软件最高高压请求|35 V|源码值，不是探头长脉冲额定值|
|会话|默认30轮，有限事件后stop|软件策略，非硬件额定值|
|burst/duty/on-time/电压额定限制|NaN，导出JSON为null|unknown，不代表无限制|

按源码几何，奇数/偶数活动间距均为0.26 mm，单组孔径跨度8.17 mm，中心分别约−0.065/+0.065 mm；这是离散几何值，不是连续填充孔径或声场性能指标。历史左右分区的4.14 mm宽度不能套用。

`compile_events.m`提供成像、照射和交替三模式；照射事件rcv=0。`operating_envelope.m`记录名义burst、局部/会话duty及累计on-time，未知额定值不报告为通过。simulate_mode=0仍被拒绝，默认simulateMode=1、freezeOnStart=true。该离线入口不调用VSX；接收钳位、再充电、功率档位切换及恢复等待仍待实际验证。

**已保存的软件验证记录（2026-10-12，本次交接未重跑）：**相关43/43测试通过，19份MATLAB文件Code Analyzer 0消息，三模式产物回读完成；未运行全仓库测试或VSX。见[validation.json](results/verasonics_linear64_oddeven/validation.json)、[测试表](results/verasonics_linear64_oddeven/test_results.csv)和[模式表](results/verasonics_linear64_oddeven/mode_summary.csv)。

当前序列MAT为[ICE_Linear64OddEven_interleaved.mat](results/verasonics_linear64_oddeven/ICE_Linear64OddEven_interleaved.mat)。TX1–15为成像，TX16为第一候选照射焦点。MAT存在不等于厂商运行时验证通过。

## 4. 已实际运行的k-Wave仿真

### 2026-10-22单点边界与累计暴露增量

独立入口为`independent_simulation/run_kwave_singlepoint_validation_R2024b.ps1`，新产物在`independent_simulation/results/kwave_singlepoint_validation_2026-10-22/`。保持原MAT/TX16和源模型，分别比较65 μm基线、PML厚度、横向域、轴向域及52 μm网格，使用至少40 μs共同记录时窗。记录全域RMS/正负极值，以`Qp=Nt*dt*p_rms^2`得到离散压力平方时间积分代理，无完整四维p(t)，不把Qp称为能量或沉积热量。

已完成的扩大横向域工况在(6.370,0,2.015) mm出现约1.501624 Pa峰值（仅assumed源下），目标附近局部峰仍在(0,0,18.395) mm、约1.406597 Pa。前者处于z≥2 mm分析域浅端，x/z半幅宽截断；不把约19 mm的全局峰到目标距离当作主焦区定位误差。公共ROI场接近不能排除原域外的更强峰，进一步大域/PML与近源区验证仍待执行。当前不直接将其定性为物理栅瓣或边界伪影。

假设目标/材料盒的Qp比例高度依赖所选体积。补充厚度比较只是同一无损场上的积分域变化，没有重算SonoInk材料吸收、容器反射或温升。最终表格、测试、受保护文件哈希及适用范围以[本轮报告](independent_simulation/docs/singlepoint_validation_2026-10-22.md)和其链接JSON为准。

### 2026-10-19历史基线：输入与模型

- MATLAB R2024b Update 2（24.2.0.2773142），k-Wave 1.4.1，`kspaceFirstOrder3D`，RTX 4070 Laptop GPU，gpuArray-single。
- 输入为上述奇偶MAT的TX16，偶数32元单次发射。读取阵元坐标、掩码和延时；不执行SetUp。TX.Delay按Trans.frequency=6.5 MHz周期换算为秒。
- 几何为existing_code_unverified；矩形有限面源、PWM经assumed带通响应后归一为1 Pa参考源。没有从5 V推导实物声压。
- assumed均匀、线性、无损流体，c=1540 m/s、ρ=1000 kg/m³。没有俯仰透镜、匹配层、背衬、阵元耦合、容器壁、吸收、热、流动或材料固化模型。
- 物理计算域10.4×5.2×31.2 mm，域外PML厚1.04 mm，CFL=0.2。有限域不能排除域外宽角旁瓣/栅瓣。
- 只算单次候选照射，不是完整成像/照射交替流程，也不是厂商simulator或实物验证。

### 结果与解释

65 μm结果于2026-10-12完成，52 μm结果于2026-10-19完成；细网格求解约506秒。

|量|52 μm结果|解释|
|---|---|---|
|物理网格|200×100×600|保存完整三维极值体|
|设定目标|[0,0,20] mm|synthetic目标|
|前向域峰值|[0,0,18.460] mm|搜索排除z<2 mm近源区|
|位置误差|1.540 mm|未通过proposed 0.5 mm内部数值诊断；非厂家精度标准|
|目标点/前向峰值声压|95.89%|压力幅度比，不是目标内能量占比|
|峰值处x/y/z连续半幅宽|0.717/2.894/13.477 mm|声压约−6.02 dB宽度，不是强度FWHM；这些剖线交点未截断|
|峰压|约1.40888 Pa|仅适用于assumed 1 Pa源，不是实物输出|

两网格共同ROI为x=[−4,4]、y=[−2,2]、z=[2,29] mm：场相对L2差0.749%，峰压变化0.142%，峰值位置变化0.065 mm，见[grid_comparison.json](independent_simulation/results/kwave_oddeven/grid_comparison.json)。通过预设两网格检查，但**完整数值收敛未建立**；PML、计算域和进一步源离散化敏感性尚未验证。

可支持的结论：该假设模型在目标附近形成声压集中，两网格结果较接近；横向比轴向更集中。不能支持：三维精确聚焦、目标外能量已受控、探头能使材料固化或临床安全。

### 数据入口与记录语义

结果目录：`independent_simulation/results/kwave_oddeven/`。

- [细网格MAT](independent_simulation/results/kwave_oddeven/even32_focus20mm_dx52um.mat)、[JSON](independent_simulation/results/kwave_oddeven/even32_focus20mm_dx52um.json)、[PNG](independent_simulation/results/kwave_oddeven/even32_focus20mm_dx52um.png)。
- [可旋转三维HTML](independent_simulation/results/kwave_oddeven/pressure_3d_interactive.html)：离线可视化；显示降采样，数值指标来自全网格。此前已在内置浏览器验证旋转。
- MAT中`data.p_max_all`、`data.p_min_all`、`p_peak_pa`对应XYZ体积，坐标`x_m/y_m/z_m`单位m；`p_peak_pa=max(abs(p_max_all),abs(p_min_all))`。
- **该体积是各点在时间窗内的最大绝对声压，不是同一时刻的三维快照。** `data.p`仅含4个传感器的p(t)，时间轴为`t_s`；没有完整四维p(x,y,z,t)或全域累计能量数据。
- Python直接读MAT v7.3时需核对HDF5维序；现有后处理对`p_peak_pa`使用`transpose(2,1,0)`恢复XYZ，不要再次转置已载入MATLAB的数据。

**已保存的独立验证记录（2026-10-19，本次交接未重跑）：**20/20测试通过，7份文件Code Analyzer 0消息，两份MAT回读审计完成，SetUp哈希与保存基线相符。见[validation.json](independent_simulation/results/kwave_oddeven/validation.json)、[artifact_validation.json](independent_simulation/results/kwave_oddeven/artifact_validation.json)及[测试表](independent_simulation/results/kwave_oddeven/test_results.csv)。

## 5. 下一步怎么推进

已写入[体外验证方案](independent_simulation/docs/ice_bench_poc_plan_2026-10-21.md)。2026-10-22已推进中心点边界与Qp增量，见上节；**尚未执行新增偏转/短线仿真或材料实验**。以下累计暴露待办已有单次中心发射实现，逐点扫描累计仍待开发。

1. **先把单点焦区验证清楚。** 保留当前基线，核对介质、透镜和真实几何；分别报告设定位置与实际峰值。具备合适标定设备时，用水听器等测得焦区及p(t)。不能简单挪动目标坐标后掩盖1.54 mm偏移。
2. **离线比较中心与左右偏转。** 初始synthetic例子为x=−1/0/+1 mm、y=0、z=20 mm；范围未获实物验证，不是上机处方。新结果另建目录，检查旁瓣、边界和目标外暴露。
3. **补齐累计暴露记录。** 在所需空间区域记录p(t)，可计算Qp=∫p²dt（Pa²·s）作为压力平方时间积分代理。对不重叠发射按实际次数累计；Qp不是声能或沉积热量，不能把各焦点的峰压体相加称为能量。
4. **明确目标线带与材料体积。** 宽度、厚度和容器形状未知时用assumed并做尺寸敏感性；同时评价覆盖、均匀性、传播路径和线外暴露。当前尚无有效的“左心耳目标外能量比例”。
5. **材料先单点，再成线。** 确认配方、机制、固化判据和后处理，设置无超声对照；单点成立后，再做受控机械移动或独立电子扫描，记录线长、连续性、宽厚及线外额外固化。声学阈值、温升或颜色变化不自动等于成功固化。
6. **最后再接双功能流程。** 成像定位、照射、恢复成像及监测要另外验证，单点/机械成线结果不代表闭环或电子扫描能力。

可先继续离线工作；上机参数需另核对探头额定约束、本机配置及实验条件。当前没有水听器测量、实物温升或固化成功结果。

## 6. 运行与后处理入口

独立模块限定MATLAB R2024b，不要对整个仓库执行addpath(genpath(...))。以下代码为历史基线复现资料，本轮未执行这些旧入口；2026-10-22五个新工况使用第4节的独立入口。旧命令会覆盖历史产物，不要为了查看结果重新运行。

```matlab
cd('H:/print_transducer/independent_simulation')
results = run_independent_tests;          % 写入本目录results/test_results.csv
reports = run_kwave_oddeven;              % 默认65/52 μm两档，需足够GPU显存
% 仅重算细网格：run_kwave_oddeven(52e-6);
% 对照两网格：compare_kwave_oddeven;       % 需两份场已存在
```

`run_kwave_oddeven`会覆盖当前结果目录相应同名文件，包含进度、MAT/JSON和图片；未来修改配置应另设输出位置，并核对文件名/报告里的焦点信息。`run_kwave_oddeven_R2024b.ps1`是该任务的Windows入口；`run_R2024b.ps1`用于独立解析基准测试/演示，不要混淆。

主要实现：`+iceind/kwave_focus_config.m`、`prepare_kwave_focus.m`、`pressure_focus_metrics.m`；展示为`render_kwave_oddeven.m`、`export_kwave_oddeven.py`；审计为`audit_kwave_oddeven.py`；结果报告生成器为`write_kwave_oddeven_report.py`。

Python后处理此前使用`C:/Users/Zh89/anaconda3/python.exe`（numpy、h5py、plotly、scikit-image），运行前应核实依赖仍可用。k-Wave依赖目录为`independent_simulation/dependencies/k-wave-1.4.1/k-wave-toolbox-version-1.4.1`。

驱动三模式生成入口为根目录`scripts/verify_verasonics_dual_mode.m`，会覆盖`results/verasonics_linear64_oddeven`内对应产物；仅为了阅读已有状态无需重新生成，也不应为本轮体外方案改动原SetUp。

### MATLAB启动问题的既往处理

2026-10-19曾出现启动/服务失败；当时日志提示MathWorks邮箱需重新验证。用户完成验证并重启相关MathWorks服务后，MATLAB最小计算和细网格仿真成功。诊断结论仅适用于当次，不能将今后所有网络问题归为同一原因。若再失败，先查日志和最小计算，勿盲目并发启动多个MATLAB；不修改Verasonics的license.enc。

## 7. 四份硬件手册与关键约束

目录：`F:/xwechat_files/wxid_quwpem6vchzg22_3c29/msg/file/2026-10/`。相关原始章节已在本线程查阅；后续改动驱动、时序或硬件操作前仍应核对适用章节和实际设备。资料不可访问时应报告缺失。

|手册/版本|相关章节及关键边界|
|---|---|
|Vantage NXT System Product Specification，D00108 Rev. L|§1.4，印刷第8–9页（PDF第9–10页）：高功率选件、Profile 5及系统保护；系统检查不能替代探头过热保护或声输出标定|
|Vantage NXT System Initial Setup Instructions，D00109 Rev. D|§4.5，第9–10页：系统自检及HardwareTest/TestResultLogs；本线程未执行自检|
|Vantage NXT System User Manual，D00107 Rev. K|§4.4.1–4.4.2，第30页：Profiles 1–4面向短脉冲、低占空比成像；扩展发射是可选能力，本机是否具备unknown|
|Vantage NXT Sequence Programming Manual，D00163 Rev. K|§4.3.2，第24–25页：TW/TX、Apod与延时；§13.1，第107、110–111页：自定义探头几何和映射。离线对象成立不代表VSX或实物通过|

手册可选配置不等于实验室已购买或启用；实际型号、模块、软件、许可、探头接线及允许驱动范围继续为unknown，直至另有核实。电气电压/功率不直接等于声压、温升或固化能力。固定5 ms切换等待也不能被当成普遍保证。

## 8. 历史结果与易混淆事项

- `results/verasonics_linear64_partition/`：左右32/32历史配置，38/38测试不替代当前奇偶43/43记录。
- `results/verasonics_matrix_partition/`及`independent_simulation/results/matrix96/`：96元12×8模型已撤回对本实物的适用性，仅synthetic历史记录。
- `results/verasonics_dual_mode/`和`independent_simulation/results/kwave/`：旧共享孔径或早期配置，不能与当前`kwave_oddeven`混称同一模型。
- `docs/experiment_plan.md`等较早文件可能仍写“k-Wave未运行”；当前状态以2026-10-19奇偶结果报告为准。
- 现有声场未完成全空间能量核算，不能把目标点95.89%的峰压比解释为95.89%能量在目标内；也不能把synthetic球形ROI敏感性当作左心耳实测结论。
- 当前仅有部分测点p(t)；没有完整四维声压。三维极值场不能视为一帧同时声压。

## 9. 工作区与本次交接验证

工作区已有大量修改和未跟踪文件，包括vendor包、驱动、独立仿真及结果。不要清理、重置、批量覆盖或把全部dirty文件归为本次改动。早前仅更新交接文档的记录已由本轮增量补充：当前已新增独立单点验证代码、测试、声场/Qp产物与报告，更新入口文档和公告；未修改SetUp、启动硬件、提交或推送。

历史交接检查包括配置、旧validation.json和链接回读；2026-10-22本轮实际软件测试与声场回读范围另见新结果目录。上文2026-10-12/19的历史测试数字仍不表示本轮重跑厂商驱动或全仓库测试；新独立模块验证记录与其分别保存。

接手时先对照本文件第1、4、5节，继续推进ICE体外概念验证；未知参数继续标为synthetic、assumed或unknown，不补写成功固化或安全结论。
