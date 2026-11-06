# ICE-Sonocuring

GitHub 私有仓库：[Zh9426/ICE-Sonocuring](https://github.com/Zh9426/ICE-Sonocuring)。

跨电脑使用：首次运行 `git clone https://github.com/Zh9426/ICE-Sonocuring.git`；已有本地副本时，先处理本地未提交修改，再运行 `git pull --ff-only`。每台电脑需自行配置 MATLAB、相关工具箱和有授权的 Vantage 软件；`VantageNXT-2.3.2-p2/`、许可证、临时文件和大型 MATLAB 仿真数组不随 Git 同步。依赖原厂安装、原成像脚本或原保存 MAT 的核验须在另一台电脑单独取得相应授权资料；大型结果若需继续分析也须另行传输。脚本中出现的本机绝对路径须按新电脑环境调整。四份指定手册亦需在新电脑上单独提供或调整 `AGENTS.md` 中的路径。

用于未来 imaging + ultrasound-triggered curing 双功能 ICE 探头结构、驱动与局部声学暴露筛选的 MATLAB 仿真平台。当前 P0 增量支持独立双矩阵阵列与连续块分区比较，后续逐步接入 k-Wave、热/血流、材料剂量和成像模型。**仿真参数为合成示例；新增Verasonics序列基于现有ICE软件配置，实物对应与材料固化仍未验证。**

2026-11-03新增[纯照射最小驱动](verasonics/curing_mode/README.md)：单独验证探头固化能力，提供全64、中央48、中央32、中央16元四个MATLAB入口；只构建有限照射，无成像/接收/重建对象，沿用原探头定义和现有发射后端。四版及验证见[对照表](results/curing_only_2026-11-03/variant_summary.csv)。尚未运行VSX或硬件，不把assumed默认照射称为已实现固化。

2026-11-01更新[ICE双模式离线序列入口](verasonics/dual_mode/README.md)：原全64元成像TX/RX，照射从同一阵列选择部分或全部阵元，时间交替；奇偶和左右互斥分区作为显式历史对照。驱动保留已恢复的原成像链路，矩阵分支仅作synthetic回归。探索准则与参数来源见[共享阵元方案](docs/verasonics/shared_aperture_2026-11-01.md)，硬件依据见[研究记录](docs/verasonics/sonic_eyes_hardware_2026-10-12.md)。默认不启动VSX；最低固化功率、器件安全可用上限和恢复时间尚未实测。

2026-09-24 升级范围、差距和阶段验收见 [P0 升级计划](docs/superpowers/plans/2026-09-24-ice-p0-upgrade.md)，代码与数值解释见 [P0-A 升级报告](docs/upgrade_2026-09-24.md)。旧版结果报告记录升级前的基线，不代表新模型的结果。

项目更新与下一步判断见 [更新公告](CHANGELOG.md)；提交说明规则见 [AGENTS.md](AGENTS.md)。

课题整体推进见 [2026-09-26 课题计划](docs/superpowers/plans/2026-09-26-ice-research-roadmap.md)、[实验合同](refine-logs/EXPERIMENT_PLAN.md)和[执行台账](refine-logs/EXPERIMENT_TRACKER.md)。其中 12 周排期与人力是待确认假设，后续模块与实验均按门槛推进，不代表已经实现或验证。

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
run_p0_probe_compare              % 合成 96+96 双阵列与连续分区比较
run_p0_convergence                % 上述示例的局部积分与体素细化诊断
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

新配置可用 `single_focus` 代替 `focused`、用 `focal_scan`/`multi_point_scan`/`trajectory_scan` 代替旧 `expanded`；这些扫描名称当前都表示离散焦点的顺序发射，不包含连续移动期间的传播。`exposure.dwell_time_s` 可指定每个焦点的秒数，总和必须等于 `exposure_time_s`。同时指定 `pulse_cycles` 与 `prf_hz` 时，程序检查它们与频率和占空比一致，但单频声场模型不模拟具体脉冲波形。

## 已实现

- 平面 side-looking 单行阵列与二维矩阵阵列；尺寸、阵元数、间距、频率、孔径、加窗、延时与焦点均可配置。
- 有限矩形阵元的 Rayleigh 表面积分，复数峰值声压以 Pa 输出，三维网格以 m 定义。
- 全阵元时分复用与空间分区；中央固化、外围固化、棋盘交错、固定种子随机稀疏、自定义掩码。
- 压力/等效强度、相对/绝对阈值；体积覆盖率、目标外超阈值比例、目标内 CV、切线 -6 dB 宽度与可判定的次级峰。
- 公共阈值参考下的架构比较和单因素扫描；远场规则稀疏栅瓣示例。
- 两组独立共面矩阵阵列与左右/上下连续块分区；焦前/焦后及目标外的采样 ROI 暴露指标；显式驱动限值检查，其结果可为 pass/fail/unknown。
- 模块单元测试、数值收敛验证和 k-Wave/Verasonics 数据交接接口。

## 使用前先读

**真实参数**：编辑 `config/real_ice_template.m` 的副本，填入资料来源、实测标定和单位。模板中的 NaN/空值故意不可运行；“400”的单位保留为 UNKNOWN。确认后将 `provenance.kind` 改为 `confirmed`，仍需验证全部字段。绝对阈值另外要求 `source.calibrated=true` 和有效 `calibration_note`，不能仅为绕过检查而修改标记。

**解释指标**：相对阈值沿用全阵元共享聚焦案例的公共参考。白色 -6 dB 轮廓按各案例自身峰值绘制，仅描述形状；紫色表示目标。目标外比例的分母依赖所选 ROI。CSV 的 NaN 表示无法定义或边界截断。

**数值精度**：默认粗网格便于快速演示。实际细化检查发现覆盖率仍对体素分辨率敏感，当前示例不宜用于精细排名；误差和原始数值见 [验证记录](docs/verification.md)。

**物理边界**：模型为均匀、线性、单频、无损介质中的平面刚性挡板阵列。未模拟真实导管曲率、声透镜、非线性、吸收、流动、气泡或温升。由声压换算的强度是平面行波等效值。跨线阵/矩阵的默认尺寸和通道数不同，不能将演示差异归因于阵列维度本身。

**尚未接入**：k-Wave 接口目前输出数据与待补决策清单，不运行求解器；旧 `adapters/+iceio` Verasonics JSON接口仍不转换延时或生成事件。新增 `verasonics/dual_mode` 独立完成波长单位延时与事件编排，尚未接入P0仿真结果或通过VSX/硬件验证。P0独立双阵列仅限同一平面、同一 +z 法线，其成像部分仍只有阵元掩码。电压/功率到表面速度的映射、自动稀疏优化、温升、血流和材料反应动力学留待后续数据支持。驱动限值通过只表示已填数值约束未越界，不能据此认定真实硬件可行。

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
