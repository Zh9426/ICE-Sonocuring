# ICE 纯照射最小驱动：64 / 48 / 32 / 16 元

本模块用于单独验证当前ICE探头的固化能力，不包含成像、回波采集、重建或图像显示。沿用原探头定义、现有聚焦延时、有限事件及限值比较，生成独立Verasonics序列MAT和检查文件。

**目前交付为MATLAB离线构建代码，不调用VSX或发射硬件。** simulate_mode=1，硬件模式仍拒绝；VSX加载、Simulator许可及实际输出未验证。Curing是实验目的，不表示已实现固化。

## 四个独立入口

| 入口 | 阵元数 | 物理+x排名 |
|---|---:|---|
| `SetUpICE_Curing_All64` | 64 | 1:64 |
| `SetUpICE_Curing_Center48` | 48 | 9:56 |
| `SetUpICE_Curing_Center32` | 32 | 17:48 |
| `SetUpICE_Curing_Center16` | 16 | 25:40 |

按ElementPos的x坐标升序排名，不是连接器号。子集均居中连续，源码pitch为0.13 mm；四组孔径跨度8.30、6.22、4.14、2.06 mm（最外中心距加0.11 mm宽度，非厂家标定）。减少阵元同时缩小孔径，不能仅归因于数量，也不是等功率比较。

```matlab
% 在仓库根目录
addpath(fullfile(pwd,'verasonics','curing_mode'));
[seq,report,cfg]=SetUpICE_Curing_All64();
[seq48,report48]=SetUpICE_Curing_Center48();
[seq32,report32]=SetUpICE_Curing_Center32();
[seq16,report16]=SetUpICE_Curing_Center16();
```

四个入口只指定选元，共用`+icec/build.m`，避免核心代码分叉。输出在`results/curing_only_2026-11-03/drivers`。文件名编码完整选元掩码，同数量不同子集不会重名；同一子集/模式重复导出仍覆盖。比较不同波形或时序时使用独立outdir。

自定义候选：

```matlab
cfg=icec.default_config();
cfg.partition.exposure_ranks=[1 2 31 32 33 34 63 64]; % 非推荐上机参数
cfg.sequence.num_groups=1; % 照射组，不是成像帧
[seq,report]=SetUpICE_CuringOnly(cfg,fullfile(pwd,'results','my_curing_candidate'));
```

`cfg.exposure`管理焦点mm、频率MHz、完整周期数、PRI us、每焦点脉冲数、Profile和电压请求；`cfg.sequence.num_groups`控制有限组数。默认保留已有6 MHz、20周期、[0,0,20] mm焦点、PRI=1000 us、每焦点10脉冲、30组，均为assumed离线初值，**不是厂家额定或已实现固化的条件**。电压默认[]，不写TPC.hv；限值计算用手册缺省1.6 V，不是测得输出。

## 最小对象与时序

MAT序列仅有`Trans / Resource.Parameters / TW / TX / TPC / Event / SeqControl`及配置/报告。一项照射TW，TX从1编号；没有占位成像波形、Receive、PData、TGC、Recon、Process、Media、UI或接收/显示缓冲区。

事件为：初始化档位/assumed稳定等待 → 每焦点有限脉冲列 → 完成等待 → assumed充电等待 → 下一组 → stop。没有DMA、重建或无限jump。不再安排成像，因此移除遗留接收恢复等待和结束时切回成像档位；充电等待保留。取消原2 ms接收等待会缩短组间周期，不能解读为热冷却已充分；以后加入成像须重新验证恢复。

复用`icevs.make_trans`、`focus_delays`、`compile_events`和既有限值校验。内部验证适配用到的成像兼容输入不构建或导出为成像对象。原两用驱动的默认时序不变；新增关闭标志用于纯照射，包含成像时拒绝关闭。

`report.operating_envelope`统计名义burst、局部比例、累计包络时间及逐阵元计数，不是声功率、能量或温升。纯照射的TW从原第二项重编号为第一项，按exposure_only角色统计，不能误计为成像短脉冲。默认器件上限unknown不报告硬件合格，显式声明上限超出即拒绝。

## 验证与使用边界

```matlab
addpath('scripts'); summary=verify_curing_only();
```

本轮测试、静态检查、四版对照表及实际日志位于`results/curing_only_2026-11-03`，离线与实物验证分开记录。

2026-11-03实际结果：相关66/66测试通过，33个MATLAB文件最终Code Analyzer 0消息；独立读取四套保存MAT检查全部通过，确认对象精简、索引范围、无接收/DMA、300次有限发射及末尾stop。四个厂商原文件SHA256未变。首次`verification_batch.log`保留修正前1条验证脚本写法提示，最终静态状态见`static_batch.log`和`code_analysis.json`。

实物比较时记录焦点、介质/材料批次、相对位置、实际电压定义、声输出、时间/能量、探头温度和是否达到预定义固化质量。相同电压不是相同总声功率；先验证全孔径能否固化，再比较减少阵元后的范围，不预先断言电压或阵元数增加就必然有效。

2026-11-07用户确认按TINGSN Sonic Eyes 10标准版开展研究，依据见[对照记录](../../docs/verasonics/curing_original_comparison_2026-11-07.md)；代码中的`cfg.identity.exact_model`尚为unknown。厂家burst/duty/温升额定及本机选件仍unknown。35 V仅原源码软件上限。stop为冻结，unfreeze可重复，未建立跨运行累计保护或温度闭环。

指定手册依据：D00108 Rev.L §1.4印刷p8-9；D00109 Rev.D §4.5 p9-10（本轮不执行自检）；D00107 Rev.K §4.4 p30；D00163 Rev.K §4.3 p23-25、§12 p95-98、§13.1 p110-111及Event/stop附录。系统保护不等于探头或声输出保护；许可、器件条件及上机参数仍需核实。

原有`iceio.export_handoff`仍保留：它保存几何、表面速度假设、物理延时秒等仿真数据，本身不是本模块SetUp，也不能替代实物标定。
