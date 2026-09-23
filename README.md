# ICE-Sonocuring

GitHub 私有仓库：[Zh9426/ICE-Sonocuring](https://github.com/Zh9426/ICE-Sonocuring)。

用于 ICE 相控阵导管 imaging + ultrasound-triggered curing 研究的 MATLAB 声场仿真底座。第一阶段面向低阈值声响应材料的目标覆盖与阵列架构筛选。**所有内置参数均为演示值；没有真实 ICE 型号、材料固化验证或硬件控制代码。**

## 快速开始

要求 MATLAB R2024b 或兼容版本；仅用基础 MATLAB 与内置单元测试框架，不依赖 k-Wave、Field II 或信号处理工具箱。已验证的版本见 `docs/verification.md`。

在项目根目录运行：

```matlab
startup_ice
run_tests                         % 全部测试，失败时抛错
run_demo                          % 2 类阵列 × 3 种声束模式
compare_architectures             % 默认线阵：5 种孔径 × 3 种模式
compare_architectures(demo_config('matrix'))
run_parameter_sweep               % 固定假设源速度的频率扫描
run_grating_demo                  % 规则稀疏孔径的远场栅瓣诊断
run_convergence                   % 积分与体素细化，较慢
```

默认输出位于 `results/`，包括 PNG 图、CSV 指标、带配置的 MAT 数据和不能直接执行的接口 JSON。重复运行更新同名输出。

## 单次实验

```matlab
cfg = demo_config('linear');        % 或 'matrix'
cfg.excitation.mode = 'expanded';   % focused / broad / expanded
cfg.architecture.type = 'partitioned';
cfg.architecture.pattern = 'checkerboard';
cfg.threshold.type = 'intensity';
cfg.threshold.intensity_basis = 'temporal_average';
cfg.threshold.scale = 'relative';
cfg.threshold.value = 0.25;         % 公共基线强度的 25%
r = ice.simulate(cfg);
ice.plot_result(r, 'results/my_case.png');
disp(r.metrics)
```

`expanded` 是多个焦点的时序扫描，可以用 `regional_points_m` 和 `dwell_weights` 设定扫描区域与停留比例。压力取各 shot 的峰值包络，强度按停留权重平均；不把不同时刻的复声压直接相加。`broad` 是有限孔径未聚焦波束，不保证平面内均匀。

## 已实现

- 平面 side-looking 单行阵列与二维矩阵阵列；尺寸、阵元数、间距、频率、孔径、加窗、延时与焦点均可配置。
- 有限矩形阵元的 Rayleigh 表面积分，复数峰值声压以 Pa 输出，三维网格以 m 定义。
- 全阵元时分复用与空间分区；中央固化、外围固化、棋盘交错、固定种子随机稀疏、自定义掩码。
- 压力/等效强度、相对/绝对阈值；体积覆盖率、目标外超阈值比例、目标内 CV、切线 -6 dB 宽度与可判定的次级峰。
- 公共阈值参考下的架构比较和单因素扫描；远场规则稀疏栅瓣示例。
- 模块单元测试、数值收敛验证和 k-Wave/Verasonics 数据交接接口。

## 使用前先读

**真实参数**：编辑 `config/real_ice_template.m` 的副本，填入资料来源、实测标定和单位。模板中的 NaN/空值故意不可运行；“400”的单位保留为 UNKNOWN。确认后将 `provenance.kind` 改为 `confirmed`，仍需验证全部字段。绝对阈值另外要求 `source.calibrated=true` 和有效 `calibration_note`，不能仅为绕过检查而修改标记。

**解释指标**：相对阈值沿用全阵元共享聚焦案例的公共参考。白色 -6 dB 轮廓按各案例自身峰值绘制，仅描述形状；紫色表示目标。目标外比例的分母依赖所选 ROI。CSV 的 NaN 表示无法定义或边界截断。

**数值精度**：默认粗网格便于快速演示。实际细化检查发现覆盖率仍对体素分辨率敏感，当前示例不宜用于精细排名；误差和原始数值见 [验证记录](docs/verification.md)。

**物理边界**：模型为均匀、线性、单频、无损介质中的平面刚性挡板阵列。未模拟真实导管曲率、声透镜、非线性、吸收、流动、气泡或温升。由声压换算的强度是平面行波等效值。跨线阵/矩阵的默认尺寸和通道数不同，不能将演示差异归因于阵列维度本身。

**尚未接入**：k-Wave 接口目前输出数据与待补决策清单，不运行求解器；Verasonics 接口不转换 TX.Delay 单位、不生成硬件事件。成像部分目前只有阵元掩码。自动稀疏优化、温升和材料反应动力学留待后续数据支持。

## 项目布局

```text
config/                 演示配置、真实探头待填模板
simulation/+ice/        几何、激励、传播、聚合、指标和绘图
simulation/             几何/声场/热场/扫描模块说明
scripts/                测试、演示、架构比较、扫描与验证入口
adapters/+iceio/         可检查的 JSON 交接契约
verasonics/             examples / imaging_mode / curing_mode / dual_mode
tests/                  MATLAB function-based tests
docs/                   物理定义、参数字典、研究问题、实验计划与验证记录
data/                   后续原始资料与实测数据
results/                可复现输出
```

详细说明：[完整实施与结果报告](docs/project_implementation_report.md)、[物理与架构](docs/system_architecture.md)、[参数字典](docs/parameter_dictionary.md)、[研究问题](docs/research_questions.md)、[实验计划](docs/experiment_plan.md)、[接口](adapters/README.md)。
