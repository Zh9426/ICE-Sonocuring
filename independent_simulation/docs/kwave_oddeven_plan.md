# 64阵元奇偶版 k-Wave 聚焦验证方案

2026-10-12，用户要求保留SetUp，使用k-Wave求解、检验聚焦并记录三维声压。

## 实验定义

- 输入为已保存的`results/verasonics_linear64_oddeven/ICE_Linear64OddEven_interleaved.mat`；读取不执行SetUp。取TX16，即物理偶数32元的第一焦点发射，目标(0,0,20) mm。
- 使用MATLAB R2024b Update 2和仓库固定的k-Wave 1.4.1，实际调用`kspaceFirstOrder3D`，GPU单精度。波形、几何、Apod和Delay来自保存的MAT，延时以Trans.frequency换算为秒；输入SHA256写入结果。
- 均匀线性无损流体：声速1540 m/s、密度1000 kg/m³；原参数标existing_code_unverified，介质/源模型标assumed。矩形阵元0.11×2.02 mm，面积重叠映射到单层additive压力源。使用既有nominal PWM→assumed高斯带通→1 Pa归一声源，不把5 V电气请求换算为声压。俯仰30 mm焦距只作元数据，声透镜、背衬、匹配层、耦合未建模。
- 物理域10.4×5.2×31.2 mm，源面距后边界0.52 mm；域外PML物理厚度1.04 mm。两档间距65/52 μm，CFL 0.2。每档时间窗覆盖最远角点传播、最大延时、发射持续时间和额外余量。
- 原始全三维记录为p_max_all、p_min_all，另存p_peak_pa=max(abs(p_max_all),abs(p_min_all))；它是各体素整个时间窗的峰值，不是同一时刻的快照。四个点记录p(t)，坐标映射及完整时间轴一并保存。不保存体积×全部时间的巨大四维数组。

## 验收与判定

1. 单元测试检查保存的奇偶掩码、面积守恒、延时单位及到达时间；用合成偏移高斯场确认指标能检出偏移，用截断场确认宽度返回NaN而非假闭合。
2. 在整个前向z≥2 mm域寻找全局峰值，同时单独报告目标附近±(2,2,4) mm ROI的峰值与边界状态、目标面横向峰值、目标点插值压力、x/y/z半幅宽度。源近场z<2 mm不包含在该全局指标内，明确记录。
3. 位置误差≤0.5 mm且峰值不在分析边界，才通过**proposed数值定位检查**；该阈值不是厂家指标或实物精度。目标附近有峰但全域峰偏离时不得宣称精确聚焦。
4. 两网格在固定公共三维ROI上插值，比较未归一化峰压场L2、全域峰压与峰位置变化。proposed内部参考：L2及峰压变化≤5%、峰位置变化≤0.13 mm。只有两档，不能宣布完整收敛；PML/计算域敏感性未测试需明示。
5. 保存MAT/JSON/CSV/图及求解日志，复核文件可重读、SetUp SHA256保持一致。没有声热/固化/实际硬件能力结论。

## 实施入口

- `run_kwave_oddeven`：默认两档真实传播。
- `+iceind/prepare_kwave_focus`：只构造源/网格/传感器，便于测试。
- `+iceind/pressure_focus_metrics`：数值场指标；`compare_kwave_oddeven`：网格对照。
- `render_kwave_oddeven`：从已保存体数据生成切片与三维等值面。

本轮无独立子代理。参考[k-Wave三维求解器文档](https://www.k-wave.org/documentation/kspaceFirstOrder3D.php)及本地1.4.1源码，all类记录返回完整物理网格，PMLInside=false时PML在记录域外。
