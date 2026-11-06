# ICE 全64元成像与可选阵元照射驱动

2026-11-01：默认改为原版全64元成像TX/RX，照射从同一阵列选择部分或全部阵元，按时序复用。优化方向是达到验证固化要求的最低有效功率/能量，以及器件额定工作范围内的可用能力探索；当前尚无标定的最低固化功率或器件可用上限。见[架构与探索准则](../../docs/verasonics/shared_aperture_2026-11-01.md)。

2026-10-29：现有构建器已按原工作驱动恢复成像链路。默认虚拟顶点发散波、原实际角度-22.5..67.5度、SectorFT及原网格/接收窗口，启动电压不再显式指定5 V。每项恢复及保留差异的理由见[本次修改报告](../../docs/verasonics/original_imaging_restoration_2026-10-29.md)。

当前基础是用户确认可成像的原64阵元线性相控阵源码。默认成像全部64元、照射复用偶数32元；偶数32只是沿用的assumed初始候选，不是最优或已核准设置。可选其他非空子集，包括全64元。完整实物型号及厂家长脉冲额定值unknown，P9-4ULts是软件别名；矩阵函数仅保留synthetic回归。

## 运行与输出

在仓库根目录运行：

```matlab
addpath(fullfile(pwd,'verasonics','dual_mode'));
cfg=icevs.default_config();
cfg.partition.layout='full64_imaging_selected_exposure'; % 默认
cfg.partition.exposure_ranks=2:2:64; % 默认候选；物理+x排序，不是连接器号
% cfg.partition.exposure_ranks=1:64; % 全64元照射候选，仍非上机参数推荐
cfg.mode='interleaved'; % imaging_only / exposure_only / interleaved
cfg.exposure.foci_mm=[0 0 20; 1 0 20]; % assumed mm, y必须为0
cfg.sequence.num_frames=3;
[seq,report]=SetUpICE_ImagingCuring(cfg);
```

这里只构建和保存MAT，不调用VSX、激活、采集或设置实物电压。simulateMode=1及freezeOnStart=1；厂家长脉冲、占空比、热负荷和本机选件未确认，本版仍拒绝simulate_mode=0。未验证VSX加载或模拟成像。候选固化序列不代表已实现材料固化。

默认输出目录`results/verasonics_full64_selected_exposure`，前缀`OriginalSector_ICE_Linear64FullImage_Exposure<16位十六进制选元掩码>_`，相同数量的不同子集不会因同名被覆盖。重复导出相同子集/模式仍会覆盖同名文件。MAT含序列、ICEConfig、ICEReport；JSON含参数来源和限制；events.csv列出事件；elements.csv记录64元位置、接线与角色。`column`是物理+x排名，`logical_element`是ElementPos行号，`connector_signal_assumed`是接线号，三者不能混用。schema_version为6；`shared_count`是同时被分配两种角色的阵元数，不代表同时发射接收。

历史互斥分区可显式设置`odd_imaging_even_exposure`、`even_imaging_odd_exposure`或`left_imaging_right_exposure`，供受控对照；这些模式的输出仍在`results/verasonics_original_sector`，不混入新默认结果。原全64纯成像对照设置`cfg.mode='imaging_only'; cfg.partition.layout='full64_imaging_control';`；该旧control仅允许纯成像。全64元两用复用应使用新默认layout和`exposure_ranks=1:64`。

## 几何、重建与时序

Trans.type=0；默认间距0.13 mm、宽度0.11 mm、ConnectorES=1:64、connType=4，均沿用源码，非厂家标定。选元按ElementPos的x坐标升序排名，重排列表或倒序接线不改变所选物理位置。成像TX/Receive全部64元，照射TX只激活所选子集；每个向量仍为64项。新默认layout不允许通过成像apod关闭阵元；照射apod可在子集中加权或置零，但不可激活子集外阵元。依据D00163 Rev.K §4.3.2 p25及§13.1 p110：Apod禁用发射，ConnectorES映射ElementPos行。

源码均匀几何下，全64元成像活动间距0.13 mm，孔径跨度8.30 mm；默认偶32元照射活动间距0.26 mm、跨度8.17 mm，均是几何值。照射旁瓣/栅瓣及照射后PSF尚未验证。成像保留原虚拟顶点发散波、二维XZ扇形SectorFT和TX.Origin=[0,0,0]；照射按目标坐标算等到达延时，只允许y=0。TX.Delay以Trans.frequency周期为单位，除以MHz得到us；固定仰角透镜仅源码estimate。

事件顺序：全64元成像TX/RX和重建 → 必要TPC切换/等待 → 所选阵元逐焦点有限照射 → 完成/再充电等待 → 接收恢复 → 必要成像档位恢复。最后stop；人工unfreeze可能重跑。接收恢复、充电和换档等待均assumed；rcv=0不证明接收前端保护充分。Profile5选配unknown，不强制启用；共享阵元不代表同时成像和照射。

## 性能边界

新增`report.operating_envelope.per_element`记录实际非零TX权重阵元的成像、照射及合计burst包络时间。复用阵元计入两类负担；`total_element_on_time_us`为全阵列element-us计数，不能解释为能量。现有事件级`total_on_time_us`保留原口径，未乘阵元数。声功率状态为`unknown_requires_calibration`，硬件核准仍false；没有求出最低固化功率或安全最大输出。

共享阵元还将成像/照射发射起点合并（含配置TX.Delay），计算逐元相邻burst包络/起点间隔，与原两类局部比例共同参与`max_local_duty_cycle`声明值的比较。短的跨用途间隔不能被分别统计的PRI掩盖；这仍不是实测滑动窗口功率或热安全保证。

report.operating_envelope报告两类burst时长、局部占空比、累计burst包络on-time、整段名义duty和孔径宽度。局部duty取“burst/配置PRI”和“burst/编译后最短同用途发射间隔下界”中较大值，覆盖焦点/帧边界。PRI仅在同一焦点的脉冲列内编入事件；组间由显式等待决定，只有一个发射时没有可计算的重复间隔。cfg.hardware_limits中max_burst_us、max_local_duty_cycle、max_total_on_time_us、max_voltage_v默认NaN（unknown，JSON为null）。填入有来源的数值后，超出会报icevs:Limits；即使所有比较通过，hardware_qualified仍false，因为尚未做声学/热验证。限制应取探头、系统和已标定工作范围中最严格者。

原35 V是源码的软件限值；默认电压字段为[]，两者均缺省时不导出TPC.hv，限值计算采用手册缺省1.6 V（D00163 Rev.K §12 p96），不是原实验实测值或安全推荐。20周期、PRI=1000 us仍为assumed离线初值。不要用降低整段平均占空比来绕过短burst/局部duty限制；active_fraction=.67是周期内波形参数，与脉冲列duty不同。频率、周期、电压、PRI、焦点数、次数可以在配置中独立设置，但同一TPC档位不能请求两个有效电压。高功率硬件能力不等于诊断探头可承受能力。

完整实物证据、四份手册的版本/章节、待厂家核实清单和性能探索路径见[硬件研究记录](../../docs/verasonics/sonic_eyes_hardware_2026-10-12.md)。

## 验证

2026-11-01本轮58/58相关测试通过，23文件Code Analyzer 0消息；候选原版对照和静态结果见[本轮验证目录](../../results/shared_aperture_2026-11-01)。旧2026-10-12数据仅保留历史含义。

```matlab
r=runtests({'tests/test_verasonics_probe.m','tests/test_verasonics_events.m', ...
    'tests/test_verasonics_dual_mode.m','tests/test_verasonics_matrix.m', ...
    'tests/test_verasonics_linear64.m','tests/test_verasonics_oddeven.m', ...
    'tests/test_verasonics_original_baseline.m','tests/test_verasonics_shared_aperture.m'});
assertSuccess(r);
addpath('scripts'); verify_verasonics_dual_mode;
verify_shared_aperture; % 完整回归、静态检查及64/16、64/32、64/64离线候选
```

2026-10-12 MATLAB R2024b Update 2：相关43/43测试通过，19份MATLAB文件Code Analyzer 0消息。验证覆盖奇偶互补/用途互换/重排/接线独立性、解析和厂商延时数学对照、二维重建对象和接收范围、有限事件与互斥、限值检查、保存后MAT/JSON/CSV一致性；历史左右和矩阵测试使用显式配置。记录见[新版验证](../../results/verasonics_linear64_oddeven/validation.json)、[升级说明](../../docs/verasonics/linear64_oddeven_2026-10-12.md)。离线通过不代表VSX或实物运行通过。
