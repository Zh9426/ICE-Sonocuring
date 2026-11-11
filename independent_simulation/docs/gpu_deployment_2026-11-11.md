# k-Wave GPU 部署与初步数值核验（2026-11-11）

用户要求继续解决 MATLAB/GPU 工具不匹配。本机 MATLAB R2024a Update 9 可用，但未安装 Parallel Computing Toolbox；此前 k-Wave 1.4.1 已从官方仓库恢复到本机项目依赖目录。RTX 5060 Ti 为 compute capability 12.0；MathWorks 对 R2024a 原生 GPU 支持列为 5.0–9.x，因此不应仅凭安装 PCT 就声称兼容，也不能仅凭此断定所有前向兼容尝试必然失败。

## 项目内 CUDA 求解器

部署社区维护的 `waltsims/kspacefirstorder-unified` v1.4.2 Windows CUDA 发行文件，非 MathWorks 工具箱、非 k-Wave 官方 MATLAB 发布包。发布页明确列出 RTX 50 系列架构支持：[版本说明](https://github.com/waltsims/kspacefirstorder-unified/releases/tag/v1.4.2)、[资产与 SHA-256](https://github.com/waltsims/kspacefirstorder-unified/releases/expanded_assets/v1.4.2)。下载脚本 `independent_simulation/install_kwave_gpu_20261111.ps1` 将可执行文件和运行库放在 `independent_simulation/dependencies/kwave-cuda-unified-v1.4.2/`，逐项校验发布页 SHA-256；此目录被 Git 忽略，另一台电脑需要重新部署。Windows 证书吊销服务离线，下载时禁用了吊销在线检查，但保留 TLS 证书/主机名和逐文件哈希校验。

`--version` 实际报告 CUDA v1.3、build 3.6、设备 RTX 5060 Ti、CUDA code arch 12.0。v1.4.2 是社区二进制打包版本，不能与程序自身报告的求解器版本混为一谈。MATLAB 通过 k-Wave `kspaceFirstOrder3DG` 启动独立进程，不依赖 PCT；`BinaryPath`、`BinaryName` 显式指定。未修改 MATLAB 安装或硬件驱动。

## 已运行的比较

- `curing_gpu_smoke_20261111.m`：32³、6 MHz 20 周期假设点源、386 步；GPU 日志实际识别 RTX 5060 Ti，输入 HDF5 中 pressure source mode=2（additive）。CPU/GPU 3 个传感点全时序相对 L2 为 3.57e-6，Qp 相对 L2 为 7.45e-7，峰值相对差为 5.26e-7。原始 CPU/GPU 时序及输入输出 HDF5 位于 `results/curing_field_2026-11-10/gpu_smoke_20261111/`。
- `curing_gpu_bli_cpu_compare_20261111.m`：复现上一轮单个带限矩形源 65/52 μm、各 5 点、1659/2074 步 CPU 原始波形；GPU 源模式仍为2。时序相对 L2 分别为 3.15e-5/1.44e-5，Qp 相对 L2 为 9.34e-6/8.61e-6。原始记录和表格见 `results/curing_field_2026-11-10/gpu_bli_cpu_compare_20261111/`。
- `curing_gpu_rms_compare_20261111.m`：与此前 24×20×16 CPU 全域记录比较，起始索引1/37 时 Qp 相对 L2 为 7.15e-7/7.24e-7，最大/最小压力场相对 L2 均约 1.6e-6。数据见 `results/curing_field_2026-11-10/gpu_rms_compare_20261111/`。
- `curing_gpu_resource_probe_20261111.m`：实际 All64 MAT、正式 65/52 μm 域各运行16步，GPU 程序分别报告峰值显存 3281/5745 MiB；输入为 mode 2，输出包含全域 p_rms、p_max_all、p_min_all、p_final。16步还不足以代表完整脉冲或完整计算耗时；显存余量随桌面其他程序变化。输入/输出 HDF5 在 `results/curing_field_2026-11-10/gpu_resource_all64_dx65_20261111/`、`...dx52_20261111/`；日志中的显存数字来自本轮 MATLAB MCP 输出，尝试使用 diary 生成的同名日志实际为空，不应视为已捕获原始控制台日志。

这些只验证所列模型条件下的工具可运行与数值一致性，不证明正式全阵列声场已收敛。源和介质为 assumed；未运行 VSX、连接或发射探头，未得到实际声功率、热量、温升或固化效果。

## 首批正式网格结果：65 μm

All64 与 Center16 在相同假设源下各完成一次完整脉冲传播，各 4740 步，原始三维 `p_amp`、`qp` 和 `p_final` 存于 `results/curing_field_2026-11-10/bli_gpu_full/`。这是一发波形的模型压力平方积分，不能直接解释为 300 次发射的实测能量或热量。All64 的 CUDA 求解约 161.8 秒；Sol 将保存的输入、输出 HDF5 与 MAT 全量独立比对，物理域裁剪后的三个数组逐元素一致，见 `bli_gpu_full/all64_dx65_hashes.csv`。

先行粗网格检查：All64 的目标盒内最大压力为 2.83138 assumed Pa，位置 `[0,0,18.395] mm`；Center16 的目标盒内最大值位于盒的浅侧边界 16.055 mm，且轴向 −6 dB 宽度未在计算域两侧闭合，须报告“无法完整测得”。Center16 全前向域最大值位于 5.135 mm，与目标盒内峰不同；不能将盒边界极值径称为焦点。两档网格和区域完整比较尚待结果。

首个 MAT 的 `runtime_metadata` 正确记录 CUDA 求解；其源适配器 `meta` 的历史 `solver_device` 仍写 CPU，它描述旧默认入口而非实际执行设备，以 `runtime_metadata` 和 HDF5 为准。首例末帧峰值为全程峰值约 0.0236%，单个末时刻不能证明时间窗收敛。

All64 52 μm 完整结果已由 Sol 对 HDF5 和 MAT 逐元素核对：5925 步、源模式2，目标盒内峰值位于 z=18.460 mm，与65 μm 的18.395 mm接近；目标盒三方向压力−6 dB宽度分别约 0.715/2.887/13.411 mm。两档共同物理格点的目标盒压力/Qp相对L2约 0.265%/0.099%，但 **0–2 mm 原生网格的 Qp 峰值在源面处差 8.97%**（2.77913e-6 vs 3.02830e-6 assumed Pa²·s），未通过建议的5%内部诊断阈值。共同格点浅层 L2 较小不能替代原生峰值检查；该差异正在排查，不能据此声称全区域网格收敛。52 μm 的 HDF5 和 MAT 哈希见 `bli_gpu_full/all64_dx52_hashes.csv`。

浅层进一步检查：四个工况的实际带限源掩码均只占 z=0 一个网格面。对于 All64，52 μm 的缩短轴向域 `[15.6,10.4,5.2] mm` 与完整域相同 52 μm、相同时窗的浅层 Qp 分层相对 L2 最大约 1.81e-5；在这一验证前提下，已计算该短域的 43.333 μm 第三档。All64 源面 Qp 原生峰从 52 μm 的 3.0283e-6 变为 43.333 μm 的 2.7319e-6 assumed Pa²·s（−9.79%），未显示稳定收敛；离开源面的浅层子区峰变化较小。Center16 两档源面峰变化 −6.10%，不能因为其整层0–2 mm峰较稳定而省略该差异。完整数据、定义和未包含共同格点的空子区见 `bli_gpu_full/shallow_audit_20261111/`、`bli_gpu_shallow/all64_*comparison.csv`。短域第三档只支持浅层诊断，不能替代目标深度全域传播。

Center16 的短域 52 μm 与完整域同网格结果也已核对，浅层 Qp 分层相对 L2 最大约 1.77e-5；52→43.333 μm 时源面 Qp 原生峰变化 +0.98%，但 `0<z<0.26 mm` 子区原生峰变化 +7.21%，该子区没有两档的 260 μm 共同采样点，不能将不同原生采样峰直接理解为同位置差异。详见 `bli_gpu_shallow/center16_*comparison.csv`。后续在短域进一步加密和核查峰点与阵元中心相对位置，不将这两个源附近指标写成通过。

All64 短域已进一步加密至 32.5 μm，43.333→32.5 μm 的源面 Qp 原生峰变化 +5.49%，`0<z<0.26 mm` 子区变化 +7.02%；两项仍超过本次5%内部诊断阈值，不能宣称源面附近已数值稳定。两档共同格点间距为 130 μm，以上是各原生网格的峰值比较，峰值可发生在不同位置。进一步结果以实际输出为准。

Center16 的 43.333→32.5 μm 短域对照，源面 Qp 原生峰变化 +1.53%，`0<z<0.26 mm` 子区变化 +4.41%；两档的共同点压力/Qp分层L2见 `bli_gpu_shallow/center16_shallow_dx43p333_dx32p5_comparison.csv`。源面各网格 Qp 最大值与实际代码阵元中心的相对位置记录在 `bli_gpu_shallow/source_plane_alignment.csv`：最大点在不同阵元边缘及对称位置间切换，表明有必要核查取样与源表示，但仅凭位置不足以证明误差机制。

为适配8 GB显卡，对 All64 32.5 μm 比较了宽浅域 `[15.6,10.4,5.2] mm` 与窄浅域 `[10.4,5.2,5.2] mm` 的重叠部分：各浅层分区Qp相对L2均低于0.001%，源面峰差约−0.00047%；原始记录见 `bli_gpu_shallow/all64_dx32p5_lateral_domain_comparison.csv`。这一验证支持在该窄域评估26 μm浅层，但不保证窄域可用于目标深度或其他阵元配置。

首批两版四个工况使用统一 `[0,3]` assumed Pa 色标；`bli_gpu_full/combined_metrics.csv`、`combined_axial_regions.csv` 分别汇总目标区指标和各深度层压力/Qp独立峰值。Center16 的目标盒峰位于盒边界，因此另输出通过全前向峰的 x-y 图；轴向 −6 dB 交点超出计算域时记录 NaN 和 clipped，而不是填入域宽。

## 协作记录

Terra 负责部署、实际 GPU/CPU 运行、绘图和结果整理；Astra 建议在保留源面数据的前提下按深度分层，并先验证缩域再加密，后续该代理触及用量限制。Sol 独立回读正式 All64 两档的 HDF5/MAT、核对 CPU/GPU 对照、区域峰和索引；对 GPU/CPU 关键数据的检查结果已写入本文。DeepSeek 经 dsh-baton 实现带限阵列源并修订滤波前沿错误；后续也编写了三阵元 GPU 对照草稿，因其自身 shell 启动失败而未能自行运行，不将它记为已执行的验证。旧绘图任务的 Harness 已关闭，无法取回结果，当前图由 Terra 实际生成。已测求解耗时以各输入输出与 solver_log 为准；未记录的模型调用耗时不补造。
