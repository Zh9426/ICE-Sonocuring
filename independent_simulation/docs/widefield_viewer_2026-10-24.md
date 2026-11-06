# 宽域三维声压HTML

用户要求补足旧版未显示的浅层离轴结构。本增量只读取已有数据，不重跑传播、不修改序列或输入MAT。

## 输出与使用

- [三维交互HTML](../results/kwave_widegrid_2026-10-24/interactive/widefield_pressure_3d.html)：约19.7 MB，内嵌Plotly与gzip数据，不依赖CDN。保存后用支持WebGL与DecompressionStream的Chrome/Edge直接打开；初次解压及绘图需要时间。
- [静态数据预览](../results/kwave_widegrid_2026-10-24/interactive/pressure_3d_preview.png)：根据同一导出网格及原生XZ切片用Matplotlib渲染，非浏览器截图。
- [分区原生峰值CSV](../results/kwave_widegrid_2026-10-24/interactive/region_peaks.csv)、[来源与显示摘要](../results/kwave_widegrid_2026-10-24/interactive/viewer_summary.json)。

默认显示偶数32元全部保存的z>0前向域，包含0<z<2 mm近源层和2≤z<5 mm浅层。提供全64元synthetic等B候选切换、三档等值面、XY深度切片及XZ/YZ切片、完整域/浅层/主焦区视角。

32元原生浅层峰为(6.344,0,2.028) mm、1.673194 Pa assumed；主焦区峰为(0,0,18.460) mm、1.408753 Pa assumed。更靠近源面的0<z<2 mm峰为(-1.456,-0.520,0.104) mm、2.543033 Pa assumed。这三者分别标注，不把前向域最大值称为主焦点。浅层峰贴着分区边界，不认定为第二个完整焦点。

## 来源与数值口径

输入为`kwave_widegrid_2026-10-24/fine_even32.mat`及`fine_full64_matched.mat`中的`p_peak_pa`和坐标；HDF5 ZYX转XYZ后为300×200×600，52 μm网格，物理域15.6×10.4×31.2 mm。校验两份MAT的SHA-256保持不变，并与保存报告核对主焦区及z≥2 mm搜索区峰值。

场为max_t|p|，不是同一时刻快照，不能进行全域时间动画或由此推断全域Qp。XZ/YZ采用原生52 μm切片；XY通常104 μm横向抽样、416 μm深度平面，并包含各分区峰值、目标和端点原生坐标。三维等值面通常104 μm抽样，也保留分区峰值与目标索引；非均匀抽样顶点通过实际坐标映射。表格采用完整原生网格，压力切片保留至10^-6 Pa。

等值面采用共同-12、-6.0206、-3 dB阈值，共同0 dB为32元52 μm深层峰1.4087532758712769 Pa；两配置保持相同0-3 Pa切片标尺。源平面z=0及后缓冲区z<0不画入前向传播等值面，原MAT仍保留；不平滑、不封边、不做max pooling，触边曲面保持开放。抽样显示不能用于精确焦宽或收敛判断。

模型来自已有k-Wave1.4.1 kspaceFirstOrder3D、R2024b、gpuArray-single、CFL0.2；c=1540 m/s、ρ=1000 kg/m³均匀无损流体与压力源为assumed，几何existing_code_unverified，真实能力unknown。全64是synthetic离线候选。两配置源端预算B匹配，不等于真实声能或功率。无真实俯仰透镜、吸收、容器、声热或材料反应。

## 验证及限制

新增5项Python测试覆盖非立方HDF5维序、源平面排除、深度分区、受保护索引、非均匀顶点映射、共同标尺及非法坐标拒绝。初始缺实现测试产生预期失败；pytest临时目录受权限限制，随后改用模块tmp中的单文件fixture并禁用tmpdir插件，5/5通过。数据审计将所有导出XY平面及XZ/YZ切片与原MAT逐点比较，并检查网格面索引、共同等值阈值、原生分区峰值和输入哈希。

运行命令：`python -m pytest independent_simulation/tests/test_widefield_viewer.py -q -p no:cacheprovider -p no:tmpdir`；`python independent_simulation/export_widefield_view.py`；`python independent_simulation/verify_widefield_view.py`。另由Node对页面脚本做语法和交互逻辑检查，使用模拟DOM/Plotly，不能代替WebGL渲染验收。

当前环境的浏览器工具拒绝file协议，未绕过此策略；因此实际浏览器三维渲染、旋转和控件点击尚未完成目视验收。此前独立headless浏览器也因进程权限失败。交付保留此限制；静态PNG仅验证同一数据的空间分布。详细记录见[数据验证](../results/kwave_widegrid_2026-10-24/interactive/validation.json)与[脚本逻辑检查](../results/kwave_widegrid_2026-10-24/interactive/runtime_logic_validation.json)。

32元近源/浅层幅值仍网格敏感；完整数值收敛未建立；软件/图形检查不能证明真实探头表现、温升、材料固化或临床安全。旧HTML和已有仿真结果保持原样。
