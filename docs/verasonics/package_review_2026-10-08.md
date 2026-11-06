# Vantage NXT 2.3.2-p2 资料提取与 ICE 阅读索引

提取日期：2026-10-08。软件包：`H:/print_transducer/VantageNXT-2.3.2-p2`。

## 1. 本次提取范围与证据口径

已完成文件枚举、可读文本检索、全部 PDF 文本提取和主题索引、关键手册章节阅读、重复工具 SHA-256 比对，以及已有 ICE MAT 配置的只读解析。**批量提取不等于逐页人工审阅或运行验证。** 没有执行 ICE SetUp、VSX、activate、SDK 采集、固件更新或硬件测试，也没有修改软件包。

| 证据类型 | 本报告如何使用 |
|---|---|
| 用户提供的硬件信息 | 实物 96 阵元；来源为用户转述师兄和老师，独立核验状态 unknown |
| 源码及保存配置 | 可以确定软件写了什么；不直接证明实物参数、运行成功或电声输出 |
| 厂商手册 | 解释字段与平台能力；注明版本及页码，选配能力不等于本机已配备 |
| 配置推算 | 基于代码的 assumed 声速和标称频率；不当作测量结果 |
| 仿真散射点、仓库合成阵列 | synthetic；不作为实物结构或组织数据 |

本轮没有声场、热或固化求解器运行。没有测量探头阻抗、声压、温升或固化效果，也不形成临床安全结论。

## 2. 软件包中哪些部分最有用

枚举得到 **4,046 个文件**：803 个 `.m`、2,071 个 `.p`、347 个 PDF、46 个 MAT，另含平台相关 MEX、DLL、共享库、SDK 源码及图片。完整数据见[目录统计](reference_2026-10-08/inventory_summary.json)和[文件清单](reference_2026-10-08/file_inventory.csv)。

| 路径 | 本轮发现的用途 | 阅读优先级 |
|---|---|---|
| `XJD/SetUpP9_4TSICE_FlashAngles.m` | 当前 ICE 成像序列主入口 | 最高 |
| `Utilities/computeTrans.m` | 探头几何、标称频率、阵元与接口信号映射 | 最高 |
| `Utilities/computeUTA.m` | UTA 接口引脚及接口信号到系统通道的映射 | 最高 |
| `MatFiles/SetUpP9_4TSICE_FlashAngles.mat` | 已保存的 ICE 配置，交叉核对脚本 | 最高 |
| `Documentation/` | 16 份顶层文档；另有逐字段 HelpText 等文件 | 高 |
| `Tools/Structure_Visualization/` | 探头、几何、阵元/通道/Apod 映射可视化 | 高 |
| `Tools/RFDataViewer_Tool/`、`Tools/SaveRF_Tool/` | RF 数据检查与导出 | 高 |
| `Tools/EventAnalysis_Tool/`、`Tools/RF_Filters_Design_Tool/` | 事件索引及滤波核查 | 高 |
| `Example_Scripts/` | 498 个文件；按硬件、UTA、探头与功能组织 | 按问题选择 |
| `vsacqsdk/` | 309 个文件；C 接口、C++ 示例、库及本地 HTML 文档 | MATLAB 路线稳定后再深入 |
| `System/`、`Applications/` | 大量封装实现与应用组件 | 按依赖追踪，不能当作完整开放源码 |
| `MovieCreation/` | 300 张 JPG；不含足以在本轮归属为 ICE 实验的证据 | 暂不用于物理结论 |
| `UserData/AI/` | 模型 MAT 与示例 VRS 文件 | 与当前 ICE 身份核查无直接关联 |

`XJD` 同级的另外两个脚本仅纳入文件枚举，未作为当前 ICE 序列的功能依据。

## 3. 64 与 96 阵元：目前查到了什么

### 3.1 三份软件证据一致，实物身份仍未解决

| 证据 | 读取结果 | 定位 |
|---|---|---|
| ICE 主脚本 | `Trans.name='P9-4ULts'`；TX/Receive 的 Apod 均为 64 项 | [源码](../../VantageNXT-2.3.2-p2/XJD/SetUpP9_4TSICE_FlashAngles.m)，第 46、129–159 行 |
| `computeTrans` | 64 阵元、6.5 MHz、pitch 0.13 mm、阵元宽 0.11 mm | [定义](../../VantageNXT-2.3.2-p2/Utilities/computeTrans.m)，第 1854–1877 行 |
| 保存的 ICE MAT | `Trans.numelements=64`；15 个 TX，每个 64 权重；450 个 Receive，每个 64 权重 | [提取快照](reference_2026-10-08/ice_saved_mat_snapshot.json) |
| 用户提供的实物信息 | 师兄和老师告知为 96 阵元 | 本聊天；独立核验 unknown |

MAT 文件头记录的创建时间为 2026-07-26 12:48:47，属于历史配置而非当前设备状态。文件不含 `RcvData`、`IData`、`QData`、`ImgData`，没有实际 `TPC` 配置，`Trans` 也没有最终 `Connector` 字段。它与主脚本在 VSX 前保存配置的代码位置相符，但不能证明当时已经上机运行成功。

**结论只限于软件：目前这份 ICE 配置按 64 阵元编写。不能由此推翻实物 96 阵元的信息，也不能断言另外 32 个阵元没有接线或未被使用。** 最终需要实物型号、阵元排布、接线表，以及对应系统的实际 UTA/通道配置。

### 3.2 软件包确实包含其他 96 阵元定义

在 `computeTrans.m` 的阵元数常量分支中，找到：

| 软件名称 | 阵元数 | 标称频率 | pitch | 定义起始行 |
|---|---:|---:|---:|---:|
| `P4-1` | 96 | 2.5 MHz | 0.295 mm | 1691 |
| `P4-2gH` | 96 | 3.15 MHz | 0.200 mm | 1792 |
| `P9-4ULts` | 64 | 6.5 MHz | 0.130 mm | 1854 |

前两者不是已经确认的 ICE 实物型号。它们适合参考如何配置 96 阵元数组，不能直接拿来替换 ICE 参数。例子包括：

- [P4-2gH FlashAngles](../../VantageNXT-2.3.2-p2/Example_Scripts/Biomedical/VantageNXT_128_and_256/UTA-408-GE/P4-2gH/SetUpP4_2gHFlashAngles.m)。
- [P4-2gH 逐线成像](../../VantageNXT-2.3.2-p2/Example_Scripts/Biomedical/VantageNXT_128_and_256/UTA-408-GE/P4-2gH/SetUpP4_2gH_128RyLns.m)。

检索记录见[ICE 身份文本命中](reference_2026-10-08/ice_identity_text_hits.csv)。搜索覆盖 `.m/.cpp/.h/.hpp/.txt/.md/.csv/.json/.html`；PDF 也做了文字提取。关键词没有找到能将本实验室 96 阵元实物与 `P9-4ULts` 对应起来的资料。此处是“本次可读资料未找到”，不包括封装二进制、图片中的文字、未提供的接线文档或另一个安装目录。

仓库 `synthetic_dual_96_config` 的 12×8+12×8 是合成几何，不能填补这个证据缺口。依据仍为 [P0 升级记录](../upgrade_2026-09-24.md)。

## 4. 一个比阵元数更具体的接口线索

`P9-4ULts` 分支包含：

```matlab
Trans.connType = 4; % HDI connector
Trans.ConnectorES = [1:Trans.numelements]';
```

注释 `HDI connector` 与数字 4 的手册定义不一致。**D00163 Rev. L §13.1，第 110–111 页及附录 A122（PDF 第 265 页）规定：4 对应 Verasonics UTA-408；1 才是 HDI/Cannon DL-260；7 是 GE D-series 的 UTA-408-GE。** 因而不能按此处遗留注释识别实物插头，也不能把两个名称均含 408 的接口混为一谈。

映射至少要区分：

```text
阵元号及空间坐标
    → Trans.ConnectorES（阵元到接口信号号）
    → UTA.TransConnector（接口信号到系统 I/O 通道）
    → Trans.Connector（最终阵元到系统 I/O 通道）
    → RcvData 的列
```

[computeUTA.m](../../VantageNXT-2.3.2-p2/Utilities/computeUTA.m) 第 55–61 行明确描述组合关系 `Trans.Connector = UTA.TransConnector(Trans.ConnectorES)`。因此 `ConnectorES=1:64` 不是“已经证实阵元接到硬件物理通道 1–64”。

工具手册 **D00118 Rev. D §9，第 16–18 页（PDF 第 17–19 页）**解释了元素、I/O 通道、引脚和 Apod 之间的区别。`showEL/showCH/showAPOD` 展示的是载入配置的映射，不会独立测量导线连接是否正确。

## 5. 当前 ICE 参数基线

以下数值来自源码及已保存 MAT，实物对应关系均尚待核验。

| 参数 | 配置值/静态推算 | 说明 |
|---|---|---|
| 系统资源声明 | 128 发射 / 128 接收 | 不是探头阵元数或本机硬件检测结果 |
| 探头软件几何 | 64 元线性排列，pitch 0.13 mm | `Trans.type=0` 是几何类型，不排斥相控阵成像 |
| 探头频率/带宽 | 6.5 MHz / [4,9] MHz | 软件定义，实测 unknown |
| 声速 | 1540 m/s | assumed 介质值 |
| 深度参数 | 0–400 wavelengths | 按上述配置换算约 0–94.77 mm |
| 波形 | `[6,0.67,2,1]` | 6 MHz 请求值；0.67 是半周期内有效比例；2 个半周期；正起始极性 |
| 发射角 | 15 个，−22.5° 至 +67.5° | 步长约 6.4286°；与“±30°”注释不符 |
| 虚拟焦距 | `-P.radius` | 按配置约 −4.16 mm；发散波，非前方聚焦 |
| 接收模式 | NS200BW，demodFrequency=12 MHz | 请求输出 RF 采样率约 48 MS/s；实际量化值未加载核验 |
| 接收终点 | 432 wavelengths | 已保存 MAT 中为 432；不等于重建深度参数 400 |
| 高压上限 | 35 V | 限制项；实际 TPC 输出设定和声压 unknown |
| 探头 ID | −1 | 跳过 ID 检查；不能当作已识别正确探头 |
| 接收缓冲 | 122880×128×30，int16 | 声明容量 900 MiB；不等于已有有效 RF 数据量 |
| 事件 | 15 TX、450 Receive、481 Event | 30 组：15 次采集+1 次重建处理；末尾跳转 |
| 名义帧周期 | 20 ms | `14×400+14400` μs；名义采集 50 fps，非实测显示帧率 |
| 重建 | replaceIQ → accumIQ → accumIQ_replaceIntensity | 先复数相干复合再产生幅值图像 |
| 仿真散射体 | 19 个点 | synthetic；当前 simulateMode=0 |

单位语义依据 D00163 Rev. K §4.3.1（第 23–24 页）、第 121–122 页及附录 A54/A60/A66/A69/A110/A128；包内 Rev. L 同时保留供后续查阅。两版页码不可直接混用。

## 6. 已定位的代码依赖与可视化工具

### 6.1 读源码时沿这条路径走

| 文件 | 回答的问题 |
|---|---|
| [VSX.m](../../VantageNXT-2.3.2-p2/VSX.m) | 入口怎样转交给 `vsv.vsx.VSX`，如何清理 |
| [computeTrans.m](../../VantageNXT-2.3.2-p2/Utilities/computeTrans.m) | 探头几何、标称响应及映射是什么 |
| [computeUTA.m](../../VantageNXT-2.3.2-p2/Utilities/computeUTA.m) | 适配器怎样把接口信号对应到 I/O 通道 |
| [computeTXDelays.m](../../VantageNXT-2.3.2-p2/Utilities/computeTXDelays.m) | 聚焦/平面/发散波的阵元延时怎么计算 |
| [computeRegions.m](../../VantageNXT-2.3.2-p2/Utilities/computeRegions.m) | PData.Region 怎样转成重建像素集合 |
| [computeTGCWaveform.m](../../VantageNXT-2.3.2-p2/Utilities/computeTGCWaveform.m) | 接收增益控制点怎样变成曲线 |
| [computeRcvFilter.m](../../VantageNXT-2.3.2-p2/Utilities/computeRcvFilter.m) | 接收解调/采样/滤波配置怎样生成 |
| [text2cell.m](../../VantageNXT-2.3.2-p2/Utilities/text2cell.m) | 文本回调怎样转换为 UI 回调内容 |

`Utilities` 与 `UserData/Utilities` 下 40 对同路径文件的 SHA-256 全部一致，包括 `computeTrans.m`。本快照没有同名文件内容分歧；MATLAB 实际路径优先级未运行验证，未来修改其中一份后仍需 `which computeTrans -all` 核对。

### 6.2 工具按问题使用

| 问题 | 工具入口 | 输入/限制 |
|---|---|---|
| 64/96 元、阵元位置怎样画出来 | [showTrans](../../VantageNXT-2.3.2-p2/Tools/Structure_Visualization/ShowTrans_Tools/showTrans.m) | 绘制软件结构，不测量实物 |
| 阵元对应哪个通道、Apod、引脚 | [showEL](../../VantageNXT-2.3.2-p2/Tools/Structure_Visualization/ElementToChannelMapping_Tools/showEL.m)、[showCH](../../VantageNXT-2.3.2-p2/Tools/Structure_Visualization/ElementToChannelMapping_Tools/showCH.m)、[showAPOD](../../VantageNXT-2.3.2-p2/Tools/Structure_Visualization/ElementToChannelMapping_Tools/showAPOD.m) | 需要最终 Trans.Connector 或 HVMux 映射；引脚还依赖 UTA 信息 |
| 成像区域和探头相对位置 | [showGeometry](../../VantageNXT-2.3.2-p2/Tools/Structure_Visualization/ShowGeometry_Tools/showGeometry.m)、[showPData](../../VantageNXT-2.3.2-p2/Tools/Structure_Visualization/ShowGeometry_Tools/showPData.m) | 使用工作区几何配置 |
| 每个 Event 指向哪里 | [EventAnalysisTool](../../VantageNXT-2.3.2-p2/Tools/EventAnalysis_Tool/EventAnalysisTool.m) | 按事件查看 TX/Receive/Recon/SeqControl；本轮未启动 |
| 12 MHz 接收到底滤掉哪些频率 | [filterTool](../../VantageNXT-2.3.2-p2/Tools/RF_Filters_Design_Tool/filterTool.m) | 检查实际生成的滤波器，不能仅看频率字段 |
| 某帧某次发射的逐通道回波 | [showRcvData](../../VantageNXT-2.3.2-p2/Tools/RFDataViewer_Tool/showRcvData.m) | 需要 RcvData；支持 channel/element 排序，后者依赖正确映射 |
| 导出 RF 供离线分析 | [saveRF](../../VantageNXT-2.3.2-p2/Tools/SaveRF_Tool/saveRF.m) | 正在运行 VSX 时先 Freeze；导出 RcvData、RcvLastFrame、Resource、Receive |
| 发射覆盖的模型预览 | [showTXPD](../../VantageNXT-2.3.2-p2/Tools/Structure_Visualization/ShowTXPD_Tool/showTXPD.m) | 软件模型预览，不能代替声场标定；部分 GUI 操作会写回配置 |

工具依据：D00118 Rev. D §3（印刷第 5 页）、§6（第 10–12 页）、§7–12（第 13–21 页）。`saveRF.m` 第 54 行附近没有保存 `Trans/TW/TX/SeqControl/Event`；为完整复现实验，应另外保存相应配置，不能仅保留 RF 数组。这里记录的是资料中已有功能，本轮没有调用这些工具。

## 7. 手册版本与查阅入口

原 AGENTS 指定的 F 盘四份手册继续保留；软件包内文档作为与当前包对应的补充，不静默替换仓库规则。

| 手册 | AGENTS 基础资料 | 软件包内版本 | 重点章节 |
|---|---|---|---|
| [Product Specification](../../VantageNXT-2.3.2-p2/Documentation/Vantage%20NXT%20System%20Product%20Specification.pdf) | D00108 Rev. L | D00108 Rev. L，文件哈希也相同 | §1 配置及选配；§3 发射；§4 接收；§5 时序；§7 接口 |
| [Initial Setup](../../VantageNXT-2.3.2-p2/Documentation/Vantage%20NXT%20System%20Initial%20Setup%20Instructions.pdf) | D00109 Rev. D | D00109 Rev. E | §3 连接；§4 激活与自检 |
| [User Manual](../../VantageNXT-2.3.2-p2/Documentation/Vantage%20NXT%20System%20User%20Manual.pdf) | D00107 Rev. K | D00107 Rev. L | §3.5–3.6 收发链；§7 兼容性；§8.8 目录；§9.2 激活；§11 UTA |
| [Sequence Programming](../../VantageNXT-2.3.2-p2/Documentation/Vantage%20NXT%20Sequence%20Programming%20Manual.pdf) | D00163 Rev. K | D00163 Rev. L | §4 基础序列；§13 自定义探头；附录字段定义 |
| [Tool Summary](../../VantageNXT-2.3.2-p2/Documentation/Application%20Note%20-%20Vantage%20NXT%20Tool%20Summary.pdf) | — | D00118 Rev. D | 映射、事件、滤波、RF 导出和几何可视化 |
| [Release Notes 2.3.2](../../VantageNXT-2.3.2-p2/Documentation/Vantage%20NXT%20System%20Release%20Notes%202.3.2.pdf) | — | D00297 Rev. C，覆盖 2.3.2/p1/p2 | 已修复项及仍存在的问题 |
| [Acquisition SDK Guide](../../VantageNXT-2.3.2-p2/Documentation/Vantage%20NXT%20Acquisition%20SDK%20Programming%20Guide.pdf) | — | D00253 Rev. B | C 采集接口模型与示例 |

全部 347 份 PDF、918 页已提取文本，零提取异常、零整份无文字的 PDF。**没有进行全面 OCR；有文字的 PDF 中仍可能有仅存在于插图里的未提取信息。** [主题索引](reference_2026-10-08/pdf_topic_index.csv)中的页码始终是从 1 起算的 PDF 页，不是印刷页。其 408 行是主题到页面的匹配，不是 408 个独立文档。

### 环境兼容性的重要发现

包内 D00107 Rev. L **第 36 页 Table 4** 列出 MATLAB **R2024a**，要求 Signal Processing Toolbox，并说明其他 MATLAB 版本会在 activate 时被拒绝。该表列出的 Verasonics Device Driver 为 16.5.0。此页已渲染目视核对。

本机 `Get-Command matlab` 指向 `C:/Program Files/MATLAB/R2024b/bin/matlab.exe`。这只是当前命令解析结果，不是所有已安装 MATLAB 的完整盘点。不能把仓库自有仿真在 R2024b 下的历史测试结果当成 Vantage 包已兼容。

本轮尝试用 MATLAB 仅读 MAT 时，MATLAB 在审计脚本执行前报 `System Error: File system inconsistency`。随后改用现有 Python 环境的 SciPy 1.18.1 成功读取。**没有调用 activate，因此不能把此次启动失败归因为 Vantage 的版本检查。** 实际系统驱动、许可证及设备连接状态均未检测。

## 8. 版本已知问题中与 ICE 迭代相关的内容

依据 D00297 Rev. C §4–5，以下为厂商记录；本轮没有复现或修复：

| 问题/变更 | 定位 | 对本项目的意义 |
|---|---|---|
| p2 修复第三方驱动影响设备识别（10622） | 印刷第 2 页 / PDF 第 3 页 | 设备识别问题需结合版本检查，不能直接归因于脚本 |
| p1 修复同步脚本改变 startEvent 后 DMA timeout（10456） | 同上 | 修改启动事件时要保留实际软件版本 |
| rowsPerFrame 应为 128 整数倍（10404） | 印刷第 3 页 / PDF 第 4 页 | ICE 当前 122880 可被 128 整除；改变深度/采样后仍需确认容量，不能只检查整除 |
| 同一触发连接器不能在一个序列中同时定义输入和输出（6952） | 同上 | 后续同步设计的约束 |
| 关闭图像窗不等于停止发射（6080） | 印刷第 4 页 / PDF 第 5 页 | 显示生命周期与采集生命周期分开理解 |
| 有 transferToHost 但无 Receive 可导致 MATLAB 崩溃（7454） | 印刷第 5 页 / PDF 第 6 页 | 删除接收事件时要同步审查 DMA 事件 |
| 同一事件不支持同时 Trigger In/Out（7673） | 印刷第 6 页 / PDF 第 7 页 | 应分开事件设计 |
| showTXPD 打开时改变 Range 后 Write TX 可报尺寸不一致（8406） | 同上 | 与现有 Range 回调直接相关 |

本报告没有把这些版本记录泛化为其他软件版本的现状。

## 9. 可复用示例与 SDK 边界

### MATLAB 示例

| 目的 | 软件包入口 | 使用边界 |
|---|---|---|
| 核对 ICE 脚本的模板来源 | [P4-2v FlashAngles](../../VantageNXT-2.3.2-p2/Example_Scripts/Biomedical/VantageNXT_128_and_256/UTA-260-S_and_260-D/P4-2v/SetUpP4_2vFlashAngles.m) | 用来理解模板结构，不继承其探头映射 |
| 96 元多角度复合示例 | [P4-2gH FlashAngles](../../VantageNXT-2.3.2-p2/Example_Scripts/Biomedical/VantageNXT_128_and_256/UTA-408-GE/P4-2gH/SetUpP4_2gHFlashAngles.m) | 阵元数相同不代表 ICE 硬件相同 |
| RF 采集并观察频谱 | [RF/频谱查看示例](../../VantageNXT-2.3.2-p2/Example_Scripts/Biomedical/VantageNXT_128_and_256/UTA-260-S_and_260-D/L11-5v/SetUpL11_5vAcquireRFSigSpctrmViewer.m) | 可学习排查 6/12 MHz 频率配置的方法 |
| 导出序列和全部 RF 帧 | [SequenceStorage/SaveRF 示例](../../VantageNXT-2.3.2-p2/Example_Scripts/VantageNXT_Features/Data_Import_Export/SetUpL11_5vFlashAngles_Export_SequenceStorage_SaveRFallFrames.m) | 结构供参考；不能原样套用探头参数 |
| 外部同步 | [Triggers 示例](../../VantageNXT-2.3.2-p2/Example_Scripts/VantageNXT_Features/Triggers/SetUpL11_5vFlash_Triggers.m) | 先核对实际连接与许可 |
| 采集时间戳 | [RFData TimeTag 示例](../../VantageNXT-2.3.2-p2/Example_Scripts/VantageNXT_Features/RFData_TimeTag/SetUpL11_5vFlashTimeTag.m) | 可用于后续真实帧周期核对 |

另有 `Dual_Transducer`、`Probe_Temperature_Sensing`、`GPU`、`Custom_Summation` 等功能目录。当前只定位，不宣称已完成适配或设备具备对应能力。

### C/C++ SDK

[vsacqsdk/README.md](../../VantageNXT-2.3.2-p2/vsacqsdk/README.md) 提供 CMake 构建入口；[本地 API 目录](../../VantageNXT-2.3.2-p2/vsacqsdk/docs/html/index.html) 可查函数。

| 示例目录 | 内容 |
|---|---|
| `transducers` | 查询 SDK 已知探头及其孔径信息 |
| `hwinfo` | 查询检测到的系统信息；本轮未运行 |
| `flash_synchronous` / `flash_asynchronous` | 同步/异步采集模型 |
| `flashangles_synchronous` | 多角度发射与同步采集；`--trans` 参数用于仿真，见本地 README |
| `custom_waveform` | 通过 cStates 定义自定义波形 |
| `tgc_hv_update` | 在运行序列中更新 TGC 和发射电压的例子 |
| `triggers` / `analog_inputs` | 触发及模拟输入 |
| `extended_transmit` / `hifu` | 扩展发射及 HIFU 接口示例；本实验室硬件/许可/探头适用性 unknown |

**Acquisition SDK 不提供完整成像链。** D00253 Rev. B，印刷第 1–2 页（PDF 第 2–3 页）说明它面向采集，不包含重建、波束形成和图像显示；示例是 C++，公共 API 是 C。因此当前 ICE 以 MATLAB 序列为阅读和迭代主线更直接。

头文件中还定位到 `VKU_TransducerCreateCustom` 和 `VK_VdasSequenceCheck`，分别用于自定义探头与序列检查。SDK 检查不能替代实际探头接线、电声标定或生物效应验证。

## 10. 现有 ICE 代码待核实项

| 优先级 | 问题 | 当前可支持的判断 |
|---|---|---|
| P0 | 实物 96 元、软件 64 元 | 差异确认存在；原因 unknown，未擅自改阵元数 |
| P0 | `connType=4`、注释 HDI | 注释与手册语义不一致；实际 UTA 与接线 unknown |
| P0 | 实际 TPC、高压与声输出 | 35 V 是上限；保存 MAT 无 TPC，声压/功率 unknown |
| P1 | 发射角不对称 | 实际为 −22.5° 至 +67.5°；是否有意设计 unknown |
| P1 | 6 MHz 发射、12 MHz 解调 | 值已确认；不能仅凭 2 倍关系认定谐波成像 |
| P1 | `wlsPer128=128/(4*2)` | 需要结合实际解调频率、samplesPerWave 与 VSX 计算后的样本区间检查；不能只沿用“四样本/波长”注释 |
| P1 | Range 回调只更新 PData.Size(1) | 增大深度时横向网格不随之扩展，存在重建区域覆盖不足的静态疑点；待几何检查，不宣称已复现 |
| P1 | PData 扇形顶点与负焦距的几何关系 | 当前 Position=[0,0,0]、半径含 P.radius；需要结合实际图像 ROI 核对设计意图 |
| P2 | 遗留 P4-2v 名称、InterBuffer “未使用”注释 | 与当前配置/重建流程不一致，容易误导阅读 |

上述是资料审阅结果，不是已确认的上机故障清单。

## 11. 提取文件、验证及阅读顺序

全部索引在 [reference_2026-10-08](reference_2026-10-08/)：

- `file_inventory.csv`、`inventory_summary.json`：目录与类型统计。
- `pdf_catalog.csv`、`pdf_topic_index.csv`：文档元数据和主题到 PDF 页映射。
- `probe_definitions.csv`：75 个可提取阵元数常量的单名称分支；只解析静态表达式，不执行条件分支。
- `ice_identity_text_hits.csv`、`ice_identity_pdf_hits.csv`：限定关键词命中；后者无匹配行，不代表 PDF 完全没有“96”这个数字。
- `duplicate_utilities.csv`：40 对重复工具全相同。
- `ice_saved_mat_snapshot.json`：历史 ICE 配置及变量目录。
- `manual_version_comparison.json`：四份基础手册与随包文档的版本/哈希对照。
- `key_source_hashes.json`：关键软件证据的 SHA-256。
- `extraction_status.json`、`validation.json`：提取覆盖范围、失败记录和交付核验。

提取只使用本地文件；没有下载资料。没有复制 `license.enc` 内容，也没有将历史 `systemInfo.txt` 中的主机标识作为当前硬件身份。PDF 全文缓存留在仓库 `tmp/vantage_reference`，交付目录保留索引与摘要，后续查结论应回到原文。

本次验证包含：CSV/JSON 重读、文件路径与 PDF 页码有效性、文件数与扩展名统计、配置计数与数组长度一致性、关键源文件哈希不变，以及新增文档链接检查。MATLAB 本轮没有成功运行；没有执行硬件或仿真测试。检查结果详见 `validation.json`。

后续阅读按以下顺序最有效：先看本报告第 3–4 节解决身份和映射；再看 ICE 的 Trans/TW/TX/Receive；随后看 Event/SeqControl 和 Recon；最后用工具检查几何、滤波和 RF。实物资料齐备后再形成探头定义修改方案。
