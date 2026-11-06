# 原成像链路恢复及两用驱动增量（2026-10-29）

用户要求以已工作的原驱动为母版，每项偏离必须有充分理由。本次修改现有 `+icevs` 构建器，原始 SetUp、原 MAT 和厂商工具保持原文件。入口仍为 `verasonics/dual_mode/SetUpICE_ImagingCuring.m`，不执行 VSX。

## 已实现：恢复项及原版对照

| 项目 | 恢复后的定义 | 来源及理由 |
|---|---|---|
| 成像发射 | 虚拟顶点发散波、focus=-P.radius、Origin=[0,0,0] | 原 SetUp 的 P/TX；分区只改变 Apod 和活动阵元延时零点，不重新放置原点 |
| 角度 | 15 次，实际 -22.5..+67.5 度 | 采用原代码执行值和原 MAT，不按不一致的注释修正 |
| 重建 | SectorFT，原 P.theta/rayDelta/aperture/radius 公式 | 撤回增加照射所不需要的矩形视野 |
| 网格 | PDelta=[Trans.spacing,0,0.5] 波长，默认 Size=[810,1087,1] | 原脚本；默认参考频率6.5 MHz、c=1540 m/s 时 dx=0.13 mm、dz约0.11846 mm；这是重建网格 |
| 接收 | 恢复原 maxAcqLength 和16波长取整公式；默认 endDepth=432 波长 | 不再使用矩形包围盒推导的416波长窗口 |
| 启动电压 | 两类 voltage_v 默认均为 []；导出 TPC 不含 hv | 原版未指定 hv；移除自写5 V。D00163 Rev.K §12 p96规定软件缺省1.6 V，不代表原实验实际电压 |
| Media/显示 | 原 MAT 的 synthetic Media、movePoints、逐帧callMediaFunc；恢复整个原 DisplayWindow | 撤回三点静态目标和显示窗口变化；Media不是实测对象 |
| 已沿用项 | 成像 TW=[6,.67,2,1]、NS200BW、12 MHz解调、TGC、Recon/IQ和Process | 原工作配置；TW的C=2为两个半周期 |

默认 `cfg.imaging.geometry='original_sector'`。`x_limits_mm/y_limits_mm/voxel_size_mm/slice_y_mm` 只供显式 `plane_wave_rectangle` 历史矩形/矩阵回归使用，不控制原扇形网格。原扇形深度由 start_depth_wls/end_depth_wls 控制；修改深度后重新构建并验证。原公式继承不表示任意新深度都已验证。

## 保留差异：目的、必要性及边界

| 与原版不同的地方 | 保留理由 | 验证/尚欠依据 |
|---|---|---|
| 奇数32元成像、偶数32元照射 | 用户已确定的两用分区方案；作为独立实验变量 | 掩码、禁用元延时和事件隔离已测试；成像质量与定位影响未测 |
| 独立TW(2)、聚焦TX及照射事件 | 新增照射功能所需 | 有限次数与rcv=0测试；声输出、热负荷、固化能力未测 |
| 有限事件后stop | 新增照射不继承原无限jump，限制一次运行的名义发射次数 | stop仅冻结，人工unfreeze可能重跑；未建立跨运行累计保护 |
| simulateMode=1、freezeOnStart=1及拒绝硬件模式 | 当前仅交付可审查的离线产物；未确认本支探头长脉冲额定值和本机配置 | 不代表已完成硬件版，也未运行VSX loader |
| 初始化、完成、换档、充电与接收恢复等待 | 将新增照射与成像事件边界明确表示 | 数值均assumed；不宣称原20 ms整体成像周期或等待已满足实物。成像组内PRI仍400 us，名义成像部分仍20 ms；整个交替周期另加照射/等待/处理 |
| TPC.xmitDuration | 让档位切换计入TX最大延时和burst时长 | D00163 Rev.K §12 p96；软件请求须由VSX量化后复核 |
| 缓冲按实际采样估计扩大、帧数向偶数取整 | 防止新增配置超出原固定空间，同时不增加照射次数 | 默认每采集仍8192行；采样量化/实际空间尚待VSX验证 |
| UI保留灵敏度滑块，暂不恢复Range滑块 | 原Range回调不重编本构建器的完成时间、等待和缓冲界限，可能使离线检查失效 | 深度通过配置重建；尚未实现两用序列的动态深度同步回调 |
| 配置及报告/CSV | 记录新增照射、参数来源、有限事件和原版恢复状态 | schema=5；不是原始硬件采集格式 |

同Profile的有效电压必须一致。[]按手册缺省1.6 V参与限值计算；若任一用途显式指定电压，统一TPC数组为其余缺省档位显式写入1.6 V，并在报告 `startup_hv_omitted=false` 表明该行为。默认两者均[]则不写hv。该数值不是探头端实测电压，也不是已核准照射设置。

## 全64元成像对照及运行

```matlab
addpath(fullfile(pwd,'verasonics','dual_mode'));
cfg=icevs.default_config();
[seq,report]=SetUpICE_ImagingCuring(cfg); % 默认奇偶交替，离线导出

cfg.mode='imaging_only';
cfg.partition.layout='full64_imaging_control';
[control,controlReport]=SetUpICE_ImagingCuring(cfg);
```

全64对照仅允许 imaging_only；构建器保留未使用的偶数照射TX定义用于统一数据结构，不能切到照射或交替模式。该模式的成像/照射定义掩码有重叠，但 `exposure_events_enabled=false` 且没有照射事件；不能把它解读为同时两用。

新产物在 [results/verasonics_original_sector](../../results/verasonics_original_sector)，前缀 `OriginalSector_`；不会覆盖旧奇偶结果。同一新目录重复运行会覆盖同名新产物。`scripts/verify_verasonics_dual_mode.m` 的导出目录已同步更新。

## 已验证与尚未验证

本轮 MATLAB R2024b 相关 **48/48** 测试通过，包含5项新增原版对照测试。首次运行已检出旧自写版的角度、P/PData、显示、窗口、原点/焦距及hv偏差，再完成恢复。测试及完整日志在 [验证目录](../../results/original_imaging_restoration_2026-10-29)。

全64对照比较原 MAT 的成像TX.Delay/Apod、完整Receive、Media、P/PData、TGC、Process及DisplayWindow；分区版额外检查原角度和虚拟顶点，并对照原全孔径延时取奇数组后减去其最小值。完整30帧对照另确认450条Receive和PData与原MAT逐值一致。最终Code Analyzer检查21个文件、0消息，见新产物目录 `code_analysis.json`；首次导出的 `generation.log` 保留修正前2条测试代码提示的记录，不是最终静态状态。四个厂商原文件SHA256复核全部未变，见验证目录 `vendor_integrity.json`。

未运行VSX、硬件发射、系统自检、波形/声压/温度、接收恢复或材料固化验证。20周期/6 MHz、PRI=1000 us、每焦点10脉冲、30组及等待仍为assumed；35 V仅原源码配置值，本支探头额定值和Profile5安装许可unknown。本次不改变独立仿真或材料研究范围。

## 手册依据

指定F盘四PDF当前SHA256均与核验提取文本对应；版本不可与随包新版本混用：

- D00108 Rev.L §1.4，印刷p8-9（PDF p9-10）：选配发射能力及保护范围，系统保护不保证探头温度/声输出。
- D00109 Rev.D §4.5 p9-10：系统自检和日志流程，本次未执行。
- D00107 Rev.K §4.4.1-4.4.2 p30：成像供电与Extended Transmit选件。
- D00163 Rev.K §4.3.1-4.3.2 p23-25、§12 p95-98、§13.1 p107/110-111、§16 p121、附录A107：波形/延时、TPC、映射、采样和stop恢复。

这些技术资料不构成硬件操作授权。未标定输入继续标assumed/unknown，软件通过不等于成功固化或临床安全。
