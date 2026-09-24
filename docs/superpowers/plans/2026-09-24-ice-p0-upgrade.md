# ICE 双功能探头仿真 P0 升级实施计划

> **For agentic workers:** 本计划按可独立验证的任务执行；若采用代理开发，先使用 `superpowers:subagent-driven-development`，否则按 `superpowers:executing-plans` 顺序实施。每一步保留可运行的旧基线。

**Goal:** 将已有均匀介质 Rayleigh 声场原型升级为可筛选独立双阵列与可制造分区方案、三维焦点扫描和非目标声学暴露的参数化 ICE 平台。

**Architecture:** 保留 `simulation/+ice` 的 SI 单位数据链。探头几何层可选单阵列或两组独立共面阵列，输出统一的阵元列表及成像/固化掩码；快速求解器不改为硬件控制器。激励层保持旧模式兼容，同时提供明确的单焦点和顺序扫描名称。新增声学安全指标和可核验的驱动约束，不推断真实固化、热损伤或设备电压。

**Tech Stack:** MATLAB R2024b、基础 MATLAB、`matlab.unittest`；无强制 k-Wave/Verasonics 依赖。

---

## 1. 需求来源与执行边界

2026-09-24 的 `D:\ICE_Sonocuring_Codex_Guidance.md` 是研究背景和升级建议，不是用户在本轮发出的逐条操作命令。用户本轮明确要求先拟定仿真升级计划，再升级仿真系统。研究主线改为真实双功能探头的硬件方案筛选与动物实验前验，当前实现仅交付能验证的 **P0 声学筛选增量**。不编造真实 ICE、血液/组织、材料或功放参数；不生成 Verasonics 控制代码；不把超阈值称为成功固化。

已有模块：单平面线/矩阵阵列、共享/分区 mask、focused/broad/expanded、三维 Rayleigh 场、体积阈值、x/y/z 切线、频率扫描、测试与结果导出。差距：独立 96+96 阵列缺位；左右/上下连续块缺位；三维 steering 虽可通过 `focus_m` 表达，但命名和逐点停留协议不清楚；焦前/焦后与最大目标外暴露未汇总；驱动限值没有明确的 pass/fail/unknown 评估；结果未记录完整的新指标与协议。

## 2. 阶段划分与验收

| 阶段 | 交付 | 验收口径 |
|---|---|---|
| P0-A（本轮） | 双阵列共面几何、连续块分区、焦点/扫描语义别名、轴向/目标外指标、显式驱动限值、可复现合成示例 | 旧测试通过；新增几何/对称性/延时/暴露/限值测试通过；示例输出配置与单位；无真实硬件结论 |
| P0-B（下一增量） | 候选阵列数/pitch/孔径/频率/位置扰动的受控扫描；等约束比较；网格收敛门槛 | 每个比较声明固定量与变量；体素阈值结果在细化前不排名 |
| P1 | k-Wave 3D 后端、异质介质/吸收、热-血流、材料剂量、成像 PSF、硬件模型 | 每个后端有独立物理基准和资料来源；热/材料/成像结果不得由当前声场指标冒充 |
| P2 | 心动/导管位姿扰动、标定与动物前验决策 | 依水听器、材料、流体和探头实测数据建立不确定性与 GO/MODIFY/NO-GO 判据 |

`shared`、`broad`、`random_sparse` 和旧 `expanded` 继续可运行，文档标为 benchmark/legacy；本轮不删原功能或大规模移动目录。96+96 是**合成的两组 12×8**示例，不是已知探头的实测几何。双阵列本轮仅支持相同 +z 法线、z=0 的独立矩形阵列及显式 x/y 位移；曲率、任意法线和封装传播列入 P1，若输入超出本轮模型应拒绝而非默默近似。

## 3. P0-A 文件与任务

### Task 1: 双阵列配置和共面几何

**Files:** Create `simulation/+ice/make_probe_geometry.m`, `config/synthetic_dual_96_config.m`, `tests/test_probe_architectures.m`; modify `simulation/+ice/simulate.m`, `simulation/+ice/validate_config.m`, `simulation/+ice/partition_elements.m`.

- [x] 在测试中定义两组 12×8 矩阵，各组 96 元、尺寸/pitch/偏移显式、掩码互斥；检查总数 192、中心/边界、左右对称及非法重叠输入被拒绝。
- [x] 运行 `startup_ice; runtests('tests/test_probe_architectures.m')`，确认新接口未定义时失败。
- [x] 实现 `cfg.probe.kind='dual_array'` 的共面组合几何。`cfg.probe.imaging` 和 `.curing` 各自含 `array`（现有格式）与 `offset_m=[x y 0]`；对 z 位移、组间实体矩形重叠、空组报错。组合几何保留 `positions_m`、`width_m`、`height_m`、`shape`，新增 `imaging_mask`、`curing_mask` 和 `subarray_id`。单阵列配置继续走原路径。
- [x] 复跑新测试及 `run_tests`。双阵列的共享基线只用于理论上限；实际双阵列发射仅取 curing 组。

### Task 2: 工程连续分区

**Files:** Modify `simulation/+ice/partition_elements.m`, `tests/test_probe_architectures.m`; update `docs/parameter_dictionary.md`.

- [x] 写左右与上下半平面测试，要求掩码互补、指定计数、固定索引下结果确定；对不可形成非空两组的输入报错。
- [x] 增加 `left_curing`、`right_curing`、`upper_curing`、`lower_curing`。坐标排序及索引破平局写入文档；`central/peripheral` 继续保留并注明可能因计数破坏几何对称。
- [x] 运行分区测试和全套测试。随机稀疏仍只用于数值基线。

### Task 3: 焦点与曝光协议

**Files:** Modify `simulation/+ice/make_sequence.m`, `simulation/+ice/validate_config.m`; create `tests/test_scan_protocol.m`; update `config/synthetic_dual_96_config.m`.

- [x] 用测试确认 `single_focus` 等价于旧 `focused`、`focal_scan` 等价于旧 `expanded`；任意三维 `K×3` 焦点产生 K 个独立 shot 且相位在各自焦点对齐。
- [x] 协议显式接受 `dwell_time_s`（K×1）或旧 `dwell_weights`，以总曝光时间转换为归一化停留权重并保存各 shot 秒数。若两者同时提供则检查一致；零/负或总时间冲突报错。
- [x] `pulse_cycles`、`prf_hz` 为可选已声明参数；两者齐备时验证 `pulse_cycles*prf_hz/frequency_hz` 与 `duty_cycle` 一致。现有演示未声明二者时保持兼容。记录为协议元数据，不改变单频压力求解。
- [x] 运行新增测试与全套测试；文档明确“多焦点顺序而非同时面打印”。

### Task 4: 目标外/轴向声学指标

**Files:** Create `simulation/+ice/acoustic_safety_metrics.m`, `tests/test_acoustic_safety_metrics.m`; modify `simulation/+ice/simulate.m`, `simulation/+ice/summary_row.m`.

- [x] 构造小体素人工场测试：目标、焦前（`z < target z-min radius`）、焦后（`z > target z+radius`）、其余目标外区域；验证压力/等效强度最大值与超阈值体积，空区域返回 `NaN` 加状态。
- [x] 输出目标外最大峰压、最大等效强度、焦前/焦后最大值及超阈值体积、目标/目标外峰值比、单焦点局部目标最大值与设定焦点的采样坐标误差。扫描序列的单点误差标记不可定义，避免把多点峰值当单焦点偏差。
- [x] 结果注明只在已采样 ROI 内成立；受限视野不可证明区域外没有次级焦点。复跑新测试及集成测试。

### Task 5: 驱动约束与可复现示例

**Files:** Create `simulation/+ice/check_drive_limits.m`, `tests/test_drive_limits.m`, `scripts/run_p0_probe_compare.m`; modify `simulation/+ice/simulate.m`, `simulation/+ice/summary_row.m`, `README.md`, `docs/system_architecture.md`, `docs/research_questions.md`, `docs/experiment_plan.md`.

- [x] 测试 `max_element_velocity_m_s`、`max_duty_cycle`、`max_exposure_time_s`、`max_total_channels`、`max_curing_channels`：越线 fail，所有已声明限值满足 pass，无已声明限值 unknown；电压/声功率无校准映射时不作数值合格判断。
- [x] 示例显式选取 synthetic 96+96 共面阵列和单矩阵分区，采用可核验的同一频率/焦点/介质/目标/阈值；分别报告几何与通道代价，避免把不同孔径比较说成架构因果。输出 CSV、PNG/MAT 中的配置与来源。
- [x] 运行 `run_tests` 和示例；检查 `summary_row` 的新增字段、图像和数值范围。更新 README 的项目定位与本轮真实能力边界。

## 4. 数值与结论门槛

保持旧 49 项测试或等价测试通过。新测试包括元件数/相互排斥、共面与重叠拒绝、左右镜像、三维焦点相位、停留时间守恒、阈值分区体积、零驱动/空区域、限值边界；测试不能只复述实现。代表性案例检查 Rayleigh 表面小片收敛，阈值体积网格加密敏感性照实报告。结果附 `cfg`、provenance、求解器名称/假设、网格、归一化、阈值定义。没有标定的结果仅用 `exposure`、`screening proxy` 语言。

每个任务先执行针对性失败测试，再最小实现、复测通过，最终检查 `git diff --check`。若结果超出本轮共面、均匀无损、单频模型范围，返回明确错误或 `unknown`，不填猜测值。

**执行记录（2026-09-24）：**P0-A 五个任务已实施；全套 MATLAB 测试 60/60 通过，39 个 MATLAB 文件 Code Analyzer 0 警告。双阵列示例及局部数值诊断见 [升级报告](../../upgrade_2026-09-24.md)。P0-B、P1、P2 仍是后续阶段，尚未实现。
