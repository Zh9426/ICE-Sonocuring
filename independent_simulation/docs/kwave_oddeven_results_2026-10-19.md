# 64阵元奇偶交替：k-Wave三维声压与聚焦验证

交付日期：2026-10-19。65 μm场于2026-10-12完成，52 μm场于2026-10-19恢复MATLAB账户验证后完成。两者均为真实`kspaceFirstOrder3D`传播结果。

## 聚焦判断

52 μm网格的前向域声压峰值位于 **(0.000, 0.000, 18.460) mm**，目标为(0,0,20) mm，位置误差 **1.540 mm**；未通过事先声明的proposed 0.5 mm数值定位检查。该阈值不是厂家指标或实物精度标准。

目标面横向峰值误差为0.000 mm（在最近z网格面评估）；目标点插值峰值声压为前向域峰值的95.89%。目标附近存在能量集中，轴向最大值与设定目标的偏差应单独保留，不能仅由目标面横向位置正确宣布三维精确聚焦。

峰值处x/y/z连续半幅宽度约 **0.717 / 2.894 / 13.477 mm**；定义为约−6.02 dB幅度交点，不是强度FWHM。本次宽度截断标记为`[False, False, False]`，峰值位于分析边界标记为`False`。搜索域排除源面和z<2 mm近场，包含其余已计算x/y/z范围；目标附近ROI另为±(2,2,4) mm。这里的“前向域峰值”不包括未计算的域外区域。

## 两网格结果

|间距(μm)|物理网格|前向域峰值坐标(mm)|位置误差(mm)|峰压(Pa，assumed源)|目标/峰值|求解调用耗时(s)|
|---:|---|---|---:|---:|---:|---:|
|65|160×80×480|(0.000, 0.000, 18.395)|1.605|1.406873|95.98%|222.13|
|52|200×100×600|(0.000, 0.000, 18.460)|1.540|1.408880|95.89%|505.95|

固定共同三维ROI x=[−4,4]、y=[−2,2]、z=[2,29] mm，按0.13 mm采样插值后，未归一化峰压场相对L2差 **0.749%**，峰压变化 **0.142%**，峰位置变化 **0.065 mm**。通过预设内部两网格检查（场L2/峰压变化≤5%，位置变化≤0.13 mm）。

这只是两档网格的一致性检查，不能宣布完整数值收敛；PML厚度、计算域大小和更细源离散化敏感性尚未运行。原始[比较JSON](../results/kwave_oddeven/grid_comparison.json)和[结果表](../results/kwave_oddeven/focus_summary.csv)保留未四舍五入值。

## 输入、单位与模型

- 输入为现有奇偶版保存MAT，TX16/第一候选照射焦点；64元线阵中物理偶数2,4,…,64共32元发射。几何、掩码和Delay从保存对象读取，不执行SetUp或VSX。输入SHA256：`e89b2e056538cff0f9fe6ba5a4a11cd23d35829be6019a7411391b9eb417bb3d`。
- 原始源码几何为existing_code_unverified：pitch 0.13 mm、宽0.11 mm、高2.02 mm；延时以Trans.frequency=6.5 MHz周期换算为秒，TW照射频率6 MHz、20周期、active_fraction=.67。电气高压请求不转换为声压。
- 声源为assumed平面矩形additive压力源，面积重叠映射保留阵元面积；名义PWM经assumed高斯带通后归一到1 Pa参考幅度。报告中的Pa只适用于该假设声源，不是探头已校准声压。
- 均匀线性无损流体，c=1540 m/s、ρ=1000 kg/m³，均assumed。未加入组织、吸收、非线性、声热或固化反应；未建模俯仰声透镜、匹配层、背衬和阵元耦合。源码30 mm俯仰焦距只保留为元数据。
- 求解器k-Wave 1.4.1 / kspaceFirstOrder3D；MATLAB 24.2.0.2773142 (R2024b) Update 2，GPU NVIDIA GeForce RTX 4070 Laptop GPU，gpuArray-single。物理域10.4×5.2×31.2 mm，源面距后边界0.52 mm，域外PML厚1.04 mm；CFL=0.2。细网格dt=6.7532 ns、Nt=4080；时间窗覆盖发射、延时和到域角点的传播。
- 单事件单次脉冲声场，不是整段30轮交替序列、成像采集电子学或材料固化。有限横向/俯仰计算域不能排除域外宽角栅瓣；本轮不作全空间旁瓣或安全结论。

Verasonics参数解释沿用D00163 Rev. K §4.3.2第24–25页与§13.1第107、110–111页的阵元/映射对象约定，硬件资料出处仍为原驱动研究记录。k-Wave记录语义见[官方三维求解器文档](https://www.k-wave.org/documentation/kspaceFirstOrder3D.php)：all类场记录在整个物理网格，传感器p记录时间序列。

## 三维记录及查看

- [交互三维等值面](../results/kwave_oddeven/pressure_3d_interactive.html)：可旋转、缩放，图例切换−12/−6.02/−3 dB等值面，同时标出设定目标与实际峰值；显示使用2倍降采样，数值指标来自全分辨率体数据。
- [细网格原始MAT](../results/kwave_oddeven/even32_focus20mm_dx52um.mat)和[静态切片/三维图](../results/kwave_oddeven/even32_focus20mm_dx52um.png)。MAT中`data.p_max_all`、`data.p_min_all`和`p_peak_pa`均为200×100×600，配套`x_m/y_m/z_m`是探头坐标系米。
- `p_peak_pa=max(abs(p_max_all),abs(p_min_all))`是各体素在整个时间窗内的最大绝对声压，**不是同一时刻的瞬时压力快照**。`data.p`保存4个传感器的p(t)，`sensor_coordinates_m`记录实际网格坐标，`t_s`为完整时间轴；未保存完整体积×全部时间的四维数据。
- [细网格JSON](../results/kwave_oddeven/even32_focus20mm_dx52um.json)包含原参数来源、网格、声源与指标；[实际求解日志](../results/kwave_oddeven/resumed_fresh_service_2026-10-19.log)包含启动、最小计算、传播及对照输出。

## 检查和复现

2026-10-19：独立目录20/20测试通过，7份本轮MATLAB文件Code Analyzer 0消息；上游k-Wave运行时有`ver('distcomp')`未来弃用提示，求解完成，不改写上游依赖。见[测试结果](../results/kwave_oddeven/test_results.csv)、[静态检查](../results/kwave_oddeven/code_analysis.json)、[验证日志](../results/kwave_oddeven/verification_2026-10-19.log)。

[数据回读审计](../results/kwave_oddeven/artifact_validation.json)已独立检查两份MAT的XYZ顺序、正负极值与峰值体一致性、4×Nt时序、峰值位置和输入SHA256；SetUp目录全部文件与此前保留哈希一致。未修改SetUp、许可证或硬件配置。

```matlab
cd('H:/print_transducer/independent_simulation')
reports=run_kwave_oddeven; % 重算两档；会覆盖对应同名声场结果
```

只复现细网格可运行`run_kwave_oddeven(52e-6); compare_kwave_oddeven;`，比较需保留65 μm结果。后处理脚本为`export_kwave_oddeven.py`、`audit_kwave_oddeven.py`、`write_kwave_oddeven_report.py`，使用已安装含numpy/h5py/plotly/scikit-image的Python环境。

下一步若要提高目标定位，应在保留本基线的基础上评估俯仰透镜/真实电声响应，或另外做名义目标与实际场峰位置的参数扫描；本轮没有改动驱动焦点来掩盖当前偏移。
