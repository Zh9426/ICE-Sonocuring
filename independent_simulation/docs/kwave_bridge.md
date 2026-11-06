# SetUp 发射事件到 k-Wave 三维声场

> 2026-10-12更新：当前实物方案为64阵元奇偶交替，新入口是`run_kwave_oddeven`，新结果在`results/kwave_oddeven`，见[方案](kwave_oddeven_plan.md)。下文`dual`导入路径和既往80/64 μm结果对应历史共享孔径序列，不能用来证明新版偶数32元的聚焦效果。

本入口使用 MATLAB R2024b 和 k-Wave 1.4.1，读取保存的 SetUp MAT 结构，不执行原 SetUp 脚本、VSX、activate 或硬件操作，不修改许可。下载来源和哈希见 [依赖说明](../dependencies/README.md)。

## 运行入口

```matlab
cd('H:/print_transducer/independent_simulation')
run_independent_tests
run_kwave_import
run_kwave_sequence('dual',16,80e-6)     % 20周期、20mm名义焦点的TX
run_kwave_sequence('dual',16,64e-6)     % 同一物理域的细网格
compare_kwave_grids
run_kwave_sequence('original',5,80e-6) % 原始成像模式第5个TX
```

默认 PowerShell 入口 `run_kwave_R2024b.ps1` 只做测试和导入；`-Task examples` 依次运行上述三个三维实例。`-Task all_original` 或 `all_dual` 运行对应序列的全部唯一TX，耗时按TX数增加。MATLAB也支持 `run_kwave_sequence('original','all',64e-6)`。

旧的 run_independent_demo 仍是单点成像解析基准，不是这个传播求解入口。

## 转换内容和边界

| SetUp内容 | k-Wave对应处理 |
|---|---|
| Trans.ElementPos、elementWidth、elevationApertureMm | 按明确单位转为m，建立64个有限宽高平面矩形阵元 |
| TX.Delay | 除以 Trans.frequency×1e6 得到秒，不用TW频率换算 |
| TX.Apod | 当前支持-1/0/1；其他PWM加权拒绝，避免伪装成模拟幅度加权 |
| TW.Parameters | 保留频率、半周期占空比例、半周期数、极性；生成名义三态波形，再通过assumed带通模型 |
| Event.tx | 每个非零TX产生声学求解任务；记录其原始事件编号和TW编号 |
| timeToNextAcq / noop | 转为秒，保留显式调度时间下界；不预测DMA、接收完成和主机延迟 |
| setTPCProfile / TPC.hv | 保留profile和电压元数据，不把电压当声压 |
| Receive / Recon / Process / transferToHost | 保留事件表，不生成声源、不模拟采集电子学或图像重建 |
| stop / 最后jump到1 | 一次有限遍历；原始循环不无限展开 |

当前拒绝其他SeqControl、其他TW类型、旋转/曲面阵列。没有实现任意Verasonics序列解释器。源文件变化后必须重新导出MAT并运行导入；不能仅修改.m却继续使用旧MAT。

输入为原ICE保存MAT和已经生成的双模式interleaved MAT。输入路径及SHA256写入manifest；原始481个事件含450次发射、15种TX；双模式933个事件含750次发射、16种TX。完整事件表位于 `results/kwave/original_events.csv` 和 `dual_events.csv`。

只求解用户选择的唯一TX；重复次数保留在事件表中。静态线性介质下可复用相同源的单次场，且调度间隔必须大于计算声学时间窗。本版本不拼接整段p(t)、不把不同时刻的声压相干相加。`*_execution_map.csv` 明确标出已计算TX对应事件和 `not_simulated`；事件编译通过不等于每个TX已经跑过。

## 声源与物理假设

原几何/频率/延时为 existing_code_unverified。介质声速沿用配置；密度1000 kg/m³、均匀线性无损介质为assumed；没有固化、温升或血流。

电声传递未知，因此不能忠实复现实际换能器输出：先在500MHz数值参考采样上生成按B居中的名义三态PWM（不声称硬件时钟量化），再经中心频率Trans.frequency、带宽Trans.Bandwidth跨度构造的assumed高斯带通。每种波形归一到assumed 1 Pa参考源幅度。归一化不保留不同TW/TPC之间的真实效率或能量比例；幅度结果必须写成“该假设声源下的Pa”，不是实物声压。

使用面积重叠权重将矩形阵元映射到单层source.p_mask，再施加每阵元延时；网格变化时保持阵元面积。source.p采用additive压力源。这个模型没有真实压电固体、匹配层、刚性挡板或声透镜。Trans.elevationFocusMm=30mm保留为元数据但未建模，不能声称已完整复现探头俯仰聚焦。

## 求解与输出

实际调用 `kspaceFirstOrder3D`；优先gpuArray-single，显式CFL=0.2。物理域长10.24×2.56×23.04 mm；阵元面距后边界0.64 mm，阵元坐标的前向z范围约0..22.3 mm。PML在物理域外，厚1.28 mm。粗网格80um、细网格64um；这只是初步网格对照，尚不能认定网格充分。

传感器请求坐标为(0,0,20)、(-2,0,20)、(2,0,20)、(0,0,10) mm，采用最近网格点；MAT中的sensorCoordinates给出实际记录位置和返回行顺序。不同网格可能有轻微坐标差异，不直接用未配准时序做误差比较。

每个结果MAT包含：

- `data.p`：稀疏sensor声压时序，时间步见report.dt_s。
- `data.p_max/p_min/p_rms`：sensor统计，rms针对整个记录时间窗，并非稳态强度。
- `data.p_max_all/p_min_all`：全物理网格压力极值。
- `xz/xy`：y=0和最接近z=20mm截面的max(abs(p))。
- `x/y/z`：探头坐标系m；`wave/waveMeta`：实际输入声源及其假设；`report`：求解器、网格、输入哈希、配置与限制。

ROI峰值只在x=±3mm、y=±1mm、z=18..22mm内搜索，不是全域最大值或焦点准确性证明。扫描域横向/俯仰有限，宽角成像束会离开ROI；不能凭图中未出现声束就说该角度没有发射。

## 2026-10-09 暂停状态

按用户要求暂停：k-Wave 与另一深度学习任务争用显存。本轮两个 k-Wave MATLAB 进程已停止，未停止深度学习任务；不会自动恢复。

- 已完成并保留：dual TX16、80 μm 网格的 MAT/JSON/PNG。
- 已中断：dual TX16、64 μm 网格，无完成结果。
- 尚未运行：两网格比较、后续 original TX5 成像声场。
- 保留 64 μm 网格配置，不因当前资源冲突继续降低精度。恢复时先检查可用显存，再做网格、计算域及 PML 敏感性验证；当前不能认定精度充分。
- 转换测试曾有 10 项通过；随后新增的 mm 几何单位回归测试尚未有效验证。恢复开发需检查 `TX.focus` 元数据换算（应与几何单位解耦）及导入脚本的数组增长提示。

## 2026-10-09 恢复结果（取代上面的暂停状态）

用户确认 GPU 空闲后恢复 R2024b 求解，11/11 项独立测试通过（含 mm 几何单位回归）；已修正 TX.focus 元数据单位换算。64 μm 照射 TX16 完成，求解调用耗时101.22秒；64 μm 原始成像 TX5 完成，耗时86.70秒。两者均保存 MAT/JSON/PNG，求解器报告显存使用约1.66 GB。

80/64 μm 照射场固定 XZ ROI 相对 L2 差0.86517%，局部峰压变化0.072669%，通过proposed 5%两网格内部检查；完整收敛及计算域/PML敏感性仍未验证。结果见 `results/kwave/grid_comparison.json`。阵元高度方向计算域有限，图中的场不能用于完整焦域或总能量结论。

首次恢复在场文件保存后遇到调度层空结构体赋值错误，已修正；随后成像 TX5 成功经过调度层并生成 `original_execution_map.csv`。照射场无需重算，其 execution map 未在该次失败运行中更新，照射完成状态应以 `dual_tx16_dx64.0um.mat/json` 为准。日志为 `resumed_fine_and_imaging.log`（含该错误）和 `resumed_comparison_imaging.log`（比较与后续成像）。未执行全15角度/全16种TX。

## 验证口径

先写转换测试并观察缺少实现时失败；再检查事件数、单位换算、未知命令/波形拒绝、原循环有限化、波形半周期与幅度元数据。原5项成像基准测试保留。

网格比较在固定XZ ROI x=±3mm、z=10..22mm插值到共同采样位置，计算未归一化场相对L2差及局部峰压变化。5%是proposed内部门槛，不是厂商或临床标准。即使两网格差异小于5%，也仅为初步一致性；至少还需更细网格、PML/计算域敏感性、声源离散化验证和独立基准，才可谈数值可信度。

## 依据

- AGENTS指定 D00163 Rev.K 第89页：parametric TW四参数；A171：TX.Delay单位及Apod PWM语义；A107：noop 200ns与stop；A110：timeToNextAcq单位与下界含义。
- [k-Wave三维求解器](https://www.k-wave.org/documentation/kspaceFirstOrder3D.php)。
- [k-Wave阵列示例](https://www.k-wave.org/documentation/example_at_linear_array_transducer.php)。本版本使用面积重叠网格声源，不使用kWaveArray的带限插值，因此仍需空间离散化收敛验证。

本轮没有任何固化、硬件可行性或临床安全结论。
