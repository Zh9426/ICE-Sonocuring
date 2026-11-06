# 独立 ICE 仿真（MATLAB R2024b）

这里是独立仿真的唯一入口。脚本、配置、测试和结果均放在本目录，不加载 `VantageNXT-2.3.2-p2`、不调用 VSX/activate、不使用或修改 license.enc。原 Verasonics 序列仍留在仓库原目录。

## 如何运行

2026-10-24已完成宽域52 μm两组对照：主焦点均18.460 mm，原离轴/主焦区测点Qp比为32元0.9390、全64元0.000623；全64仍为synthetic等源端代理预算候选。32元近源/浅层场L2约11.68%/6.89%，未过5%内部判据，不能宣布浅层幅值已收敛。源空间谱审计指向单元表示的网格敏感性，下一步先验证带限源表示；尚未替换源或模拟材料。见[最新解读](docs/findings_2026-10-24.md)、[完整报告](docs/widegrid_2026-10-24.md)及[新入口](run_kwave_widegrid_R2024b.ps1)。两组完成产物拒绝覆盖，勿重复启动。

2026-10-23完成边界诊断及synthetic全64元对照：PML20格/X域256格的公共域L2差约0.077%/0.022%，原搜索峰位不变；全64等源端代理预算使原固定离轴/主焦点Qp比从0.7669降至0.000373，轴上主峰仍在约18.4 mm。见[结果解读与下一步](docs/findings_2026-10-23.md)、[边界报告](docs/offaxis_diagnostic_2026-10-22.md)及[阵元对照](docs/aperture_control_2026-10-23.md)。没有完整数值收敛、真实探头或固化结论。

新入口为`run_kwave_offaxis_diagnostic_R2024b.ps1`及`run_kwave_aperture_control_R2024b.ps1`，完成产物拒绝覆盖。Python分析使用`C:/Users/Zh89/anaconda3/python.exe`；本机系统`python`当前可能指向缺少依赖的其他环境。Qp和源预算均不是实际声能/热量。

2026-10-21近期研究范围调整为ICE体外单点聚焦与线条固化概念验证；阶段、证据要求及机械/电子扫描区别见[体外验证方案](docs/ice_bench_poc_plan_2026-10-21.md)。

2026-10-22新增单点计算域/PML/网格对照及全域Qp累计暴露代理，状态、假设尺寸、实际运行和限制见[本轮验证报告](docs/singlepoint_validation_2026-10-22.md)。独立入口为`run_kwave_singlepoint_validation_R2024b.ps1`，结果单独保存到`results/kwave_singlepoint_validation_2026-10-22`；默认拒绝覆盖已完成工况。Qp及其空间比例不代表沉积能量或固化结果。

本轮五个工况已完成：公共ROI峰压/Qp较接近，但扩大横向域发现更强离轴声压峰且位于分析边界，因此全前向域峰值稳定性未通过。MATLAB独立模块26/26及Python10/10软件测试通过，不代表所有数值敏感性或实物检查通过。

当前研究入口为 **64元线阵奇偶交替**：`run_kwave_oddeven`读取最新保存的奇偶SetUp MAT，以偶数32元的TX16进行实际k-Wave三维传播，检查(0,0,20) mm聚焦；不修改或执行SetUp。见[实验方案](docs/kwave_oddeven_plan.md)。结果在`results/kwave_oddeven`，与历史结果分开。

2026-10-19已完成65/52 μm两档传播：细网格峰值在(0,0,18.460) mm，相对20 mm目标前移1.540 mm；两网格场L2差0.749%。见[实际结果与限制](docs/kwave_oddeven_results_2026-10-19.md)、[可旋转三维视图](results/kwave_oddeven/pressure_3d_interactive.html)。此为assumed均匀无损/无俯仰透镜模型，不能视为实物聚焦精度或固化验证。

```matlab
cd('H:/print_transducer/independent_simulation')
reports = run_kwave_oddeven; % 65/52 um两档，需GPU；MATLAB R2024b
```

**96元12×8矩阵是已撤回实物适用性的synthetic历史模型**，配置边界见[矩阵模型说明](docs/matrix96_model.md)。`run_matrix96`及`run_matrix96_R2024b.ps1`仅用于历史复现，不能作为当前64元实物模型。旧解析基准和早期共享孔径64元k-Wave入口也只用于追溯。

结果目录 `results/matrix96`：完整三维MAT、静态PNG、可旋转FIG、左右对照 `matrix96_3d.html`。参考间距160μm和6MHz来自不同排布的ICE研究，140μm阵元宽度为assumed；这些不是实物规格。旧解析基准与64元k-Wave入口保留用于追溯。

在 **MATLAB R2024b** 中运行：

```matlab
cd('H:/print_transducer/independent_simulation')
run_independent_tests
report = run_independent_demo
```

也可在 PowerShell 中使用明确绑定 R2024b 的入口：

```powershell
& 'H:/print_transducer/independent_simulation/run_R2024b.ps1'
```

PowerShell 入口默认使用 `C:/Program Files/MATLAB/R2024b/bin/matlab.exe`，检查版本后先测试再运行；TEMP/TMP 临时指向本目录，结束时恢复。无需运行根目录的 startup_ice，也不要对整个仓库执行 addpath(genpath(...))。函数入口临时添加本目录，结束后恢复 MATLAB path，不调用 savepath。

## 目录

```text
independent_simulation/
  run_R2024b.ps1             Windows 一键测试和演示
  run_independent_demo.m     单点回波与重建入口
  run_independent_tests.m    只运行本目录测试
  +iceind/
    default_config.m        集中参数，内部统一使用 SI 单位
    simulate_rf.m           解析单点 RF 模型
    reconstruct.m           延时求和重建
  tests/                    本目录独立测试
  docs/                     方案、模型说明与验证记录
  results/                  PNG / JSON / MAT / 测试 CSV / 日志
  tmp/                      本目录临时文件
```

修改参数从 `+iceind/default_config.m` 开始。重复运行覆盖本目录同名结果，不覆盖原项目结果。

## 当前已经实现和验证

首版是**理想平面波照射一个静止散射点**的解析基准：模拟64个接收通道的RF，随后做相干延时求和，得到点目标重建图。使用基础 MATLAB，暂不依赖额外工具箱；继续使用 R2024b，为后续模型和工具箱扩展保留环境。

2026-10-09，R2024b Update 2 实际运行：5/5项测试通过。synthetic目标 `[0.830,20.030]` mm，图像峰值 `[0.825,20.025]` mm，定位误差 `0.007071` mm；网格间距0.025 mm，误差小于网格对角线0.035355 mm。这是内部软件验收门槛，不是实物精度或临床标准。

- [首个结果图](results/point_target.png)
- [参数与指标](results/point_target_report.json)
- [测试结果](results/test_results.csv)
- [模型和验证边界](docs/model_and_validation.md)

## 尚未实现

解析成像基准的幅度仍为 arbitrary units，正反演共享简化假设，定位成功只证明内部一致性。未完成15角度复合成像、照射扫描、热、流动或固化模型。

## k-Wave 三维声场

已新增独立 k-Wave 1.4.1 求解路径，读取保存的 SetUp 结构，将阵元、TW、TX 延时及 Event 引用转换为有限孔径声源和单次发射任务。使用 R2024b；入口为 `run_kwave_sequence`，配置映射、运行方式和限制见[声场说明](docs/kwave_bridge.md)。原厂商脚本不执行。

已保存照射 TX16 的 80 μm 与 64 μm 场；两网格固定 XZ 区域相对 L2 差为 0.8652%，局部峰压变化为 0.07267%，见[比较结果](results/kwave/grid_comparison.json)。这仅为初步网格一致性，尚需计算域、PML 和更细网格验证。声源为 assumed 1 Pa，介质及电声响应未标定；不能解释为实物输出或固化结果。
