# 参数字典

模块内部统一 SI，绘图显示 mm/MHz。每个 MATLAB 函数的头注释说明输入输出。下表是配置接口；没有真实探头的默认值。

| 配置字段 | 含义 / 单位 | 约束与说明 |
|---|---|---|
| provenance.kind | synthetic / confirmed / unconfirmed | unconfirmed 拒绝运行 |
| provenance.description | 来源与假设 | 实测时保留型号、资料、日期 |
| array.type | linear / matrix | 平面模型 |
| array.size | [Nx Ny] | 正整数；linear 要求 Ny=1 |
| array.pitch_m | [px py] / m | 中心间距；一维 y 间距不参与排列 |
| array.element_width_m | 单元 x 宽度 / m | 正数且不大于 px |
| array.element_height_m | 单元 y 高度 / m | 矩阵多行时不大于 py |
| acoustics.frequency_hz | 中心频率 / Hz | 单频，正数 |
| acoustics.sound_speed_m_s | 均匀声速 / m/s | 正数 |
| acoustics.density_kg_m3 | 密度 / kg/m³ | 正数；强度换算所需 |
| source.velocity_m_s | 均匀单元法向速度峰值 / m/s | 非负；不是发射电压 |
| source.calibrated | 是否具有绝对幅值标定 | logical；绝对阈值要求 true |
| source.calibration_note | 标定来源、工况与日期 | 不能为空；不替代标定数据 |
| architecture.type | shared / partitioned | shared 的成像和固化掩码都为全部 |
| architecture.pattern | central_curing / peripheral_curing / checkerboard / random_sparse / custom | 分区时生效 |
| architecture.curing_fraction | 期望固化单元占比 | (0,1)，离散计数取整并保留两类单元 |
| architecture.seed | 随机种子 | 局部随机流，不改变全局 RNG |
| architecture.custom_curing_mask | N×1 logical | 成像掩码为补集；不可全空或全满 |
| excitation.mode | focused / broad / expanded | 聚焦、未聚焦平面延时、时序多焦点 |
| excitation.focus_m | 1×3 目标焦点 / m | z>0；同时定义默认基线 |
| excitation.regional_points_m | K×3 扫描焦点 / m | 每行对应单独一次发射 |
| excitation.dwell_weights | K×1 时间占比 | 非负和为1；空值为均匀分配 |
| excitation.aperture_size_m | [x y] / m | 以原点为中心，按单元中心筛选；Inf 表示不限 |
| excitation.apodization | uniform / hann / N×1 非负幅值 | Hann 为几何位置加窗，不压缩稀疏孔洞 |
| excitation.normalization | fixed_element / fixed_total | 保留单元幅值 / 面积加权平方驱动积分固定 |
| excitation.steering_deg | [azimuth elevation] / 度 | broad 使用，各角严格在 (-90,90) |
| excitation.custom_delay_s | N×1 延时 / s | 空值自动设计；否则覆盖全部 shot 延时 |
| exposure.duty_cycle | 固化发射占总时间比例 | [0,1]；必须包含成像等停发间隔 |
| exposure.exposure_time_s | 总曝光时长 / s | 正数；当前只保留，不预测剂量反应 |
| grid.x_m / y_m / z_m | 体素中心坐标 / m | 每轴至少2个，严格递增且等间距，z>0 |
| target.center_m | 椭球中心 / m | 1×3；完整目标必须落在 ROI 内 |
| target.radii_m | 椭球三轴半径 / m | 正数；目标至少被一个体素中心采到 |
| threshold.type | pressure / intensity | 峰值包络压力 / 等效强度 |
| threshold.scale | relative / absolute | 公共基线比例 / SI绝对数值 |
| threshold.value | 比例、Pa 或 W/m² | 非负；相对值也允许大于1 |
| threshold.intensity_basis | pulse_average / temporal_average | 强度阈值必须明确平均窗口 |
| solver.patch_count | [nx ny] 积分分片数 | 空值按波长自动选，正整数覆盖自动规则 |
| solver.patches_per_wavelength | 每波长分片数 | 自动规则；实际仍需收敛验证 |
| solver.chunk_size | 每批空间采样点数 | 控制内存，正整数 |
| output.db_floor | 图像下限 / dB | 演示 -40，参考公共基线 |
| output.visible | on / off | 是否显示 MATLAB 图窗 |

## 换算与命名

压力使用峰值相量幅度，不是 RMS。若原材料阈值为正弦 RMS，转换为峰值需乘 √2；宽带/非对称波形不能照搬。强度 `1 W/cm² = 10^4 W/m²`；声压 `1 MPa = 10^6 Pa`。未知“400”不做任何换算。

`intensity_pulse_average_w_m2` 是整个扫描中正停留 shots 的脉冲内强度平均，不代表每个焦点单独的峰值强度。`intensity_temporal_average_w_m2` 再乘总体占空比。`pressure_peak_pa` 是曾达到的峰值包络。三者是不同物理统计量。
