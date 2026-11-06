# ICE 仿真验证记录：2026-10-09

## 当前结论

最初的 MATLAB R2024b Update 2 离线回归测试 85/85 通过，Verasonics 激活被版本检查阻塞。用户随后提供 `E:/MATLAB24a`，已实际启动 R2024a Update 9 并完成 systemInfo，版本阻塞解除。当前阻塞已确定为本机无 Verasonics 授权：activate 提示 `The host controller is not licensed`；本机报告明确写明 `The license file does not grant any features on this system.` 因此没有进入 VSX，没有模拟 RF、IQ 或图像，没有点目标定位通过结论。

本机许可诊断：[activation_r2024a.log](../../results/verification_2026-10-09/activation_r2024a.log)、[systemInfo_r2024a.txt](../../results/verification_2026-10-09/systemInfo_r2024a.txt)。systemInfo 成功生成报告、进程退出码为0，不表示已获授权。报告检测到无连接硬件，未运行硬件操作。旧 audit.json 保留第一次检查的历史状态；最新环境状态见本段。

R2024a Update 9 复核：85/85 项离线测试通过，0失败、0未完成，批处理退出码0。证据：[测试CSV](../../results/verification_2026-10-09/test_results_r2024a.csv)、[完整日志](../../results/verification_2026-10-09/tests_r2024a.log)。这仍不代表VSX已运行。

完整证据：[测试结果](../../results/verification_2026-10-09/test_results.csv)、[测试及激活日志](../../results/verification_2026-10-09/verification.log)、[基线生成日志](../../results/verification_2026-10-09/baseline_preparation.log)、[独立保存文件审计](../../results/verification_2026-10-09/audit.json)。

## 已执行

1. 读取 AGENTS 指定手册和原 ICE 脚本。原脚本设 simulateMode=0 且末尾直接调用 VSX，未执行原脚本。
2. 初始 MATLAB 启动发生 `File system inconsistency`；常规本机环境及仓库内独立 TEMP/TMP 下最小启动成功。不能据此断定原错误唯一原因。
3. MATLAB R2024b Update 2 执行全部 85 项测试，85 通过、0 失败、0 未完成；保存独立 CSV。测试通过后调用 systemInfo 时 activate 报错：`The MATLAB version R2024b is not supported. The supported MATLAB version is R2024a.` 整体批处理退出码 1 来自该激活失败，不是测试失败。
4. 生成三种双模式诊断 MAT/JSON/CSV；生成并执行原始 ICE 的仿真专用 SetUp 副本，保存基线 MAT。最初仅加载 Utilities 时缺失 vsv.seq.getBaseComp；补充 System/P_Files 数值工具路径后基线生成及保存重读断言通过。没有绕过 activate 或版本检查运行 VSX。
5. 独立检查四个 MAT 的仿真标志、固定目标、回调关闭、事件引用、有限 stop 和原文件哈希。此项不代替 VSX 检查。

## 用例与假设

诊断生成器：[prepare_ice_simulation_checks.m](../../scripts/prepare_ice_simulation_checks.m)。输出目录：[verification_2026-10-09](../../results/verification_2026-10-09)。

| 用例 | 事件数 | 仿真接收事件数 | 候选照射事件数 |
|---|---:|---:|---:|
| 原 ICE 基线副本 | 17 | 15 | 0 |
| imaging_only | 21 | 15 | 0 |
| exposure_only | 16 | 0 | 10 |
| interleaved | 34 | 15 | 10 |

共同设置：simulateMode=1、freezeOnStart=1、initializeOnly=1、1 帧、静止 synthetic 点目标 `[0,0,80]` 波长、关闭 Media 移动回调。以软件基线 Trans.frequency=6.5 MHz 和 assumed 声速 1540 m/s 换算，目标为 `[0,0,18.953846]` mm。此值是设定位置，不是重建位置。探头几何/接线仍 existing_code_unverified；照射和等待参数仍 assumed；电声与材料参数 unknown。

原始基线只改变诊断所需的模式、目标、帧数、移动回调、终止方式和保存路径；原文件不修改。原始基线与改造后成像的网格/虚拟焦点等仍存在既有差异，后续应分别对已知目标定位，不能直接要求逐像素相等。仅照射用例不采集回波，没有图像不能判为失败。

所有 MAT 当前只用于初始化检查，即使 VSX 加载成功，也不代表实际执行过仿真采集。stop 是冻结语义，人工 unfreeze 可能重新开始，不是永久锁止。

## 在兼容环境中继续

当前已安装并验证 `E:/MATLAB24a`（R2024a Update 9），无需再次下载 MATLAB。下一步由实验室设备负责人核实可分配的 Simulator 许可，并将本次生成的 systemInfo_r2024a.txt 用于申请本机授权。不要用另一台机器的 systemInfo.txt 申请。报告依据 D00107 Rev.K §14，指定许可联系邮箱为 licensing-request@verasonics.com；本轮没有发送邮件或修改许可文件。

取得更新的许可文件并按 D00107 Rev.K §14.1 安装后，在 R2024a 中重新核验（systemInfo 会调用 activate）：

```matlab
cd('H:/print_transducer/VantageNXT-2.3.2-p2')
systemInfo('H:/print_transducer/results/verification_2026-10-09/systemInfo_current.txt')
```

许可核验成功后，先只加载基线：

```matlab
filename = 'H:/print_transducer/results/verification_2026-10-09/ICE_baseline_point.mat';
check = load(filename,'Resource');
assert(check.Resource.Parameters.simulateMode == 1)
assert(check.Resource.Parameters.initializeOnly == 1)
assert(check.Resource.Parameters.freezeOnStart == 1)
VSX(filename)
```

依次对三个 `ICE_ImagingCuring_*.mat` 做相同初始化检查，保存完整警告/错误。初始化全部通过后，再另存实际采集用仿真副本，保持 simulateMode=1，在明确有限执行/退出方案后启用采集；检查非零 RF、缓冲是否截断、重建峰值位置与已知目标的误差、交替后成像是否恢复。验收容差应按采样间距和 PSF 预先定义，目前不凭空设置“通过”阈值。

复现离线准备：

```matlab
cd('H:/print_transducer'); startup_ice
prepare_ice_simulation_checks
addpath('H:/print_transducer/VantageNXT-2.3.2-p2/Utilities', ...
        'H:/print_transducer/VantageNXT-2.3.2-p2/System/P_Files')
run('H:/print_transducer/results/verification_2026-10-09/SetUpICE_BaselinePoint_SimOnly.m')
```

生成器和基线副本不调用 activate 或 VSX。重复准备覆盖本次诊断文件；不覆盖原厂商文件。生成器 preparation.json 中 baseline_status 表示副本刚生成时的阶段；后续成功执行证据见 baseline_preparation.log 和 audit.json。

## 手册依据与限制

- D00163 Rev. K 第18页、A97：simulateMode=1 使用软件模拟采集；A29：Media 点目标位置以 Trans.frequency 波长为单位；第67页：mode 2 对已有数据回放；A107：stop 冻结。
- D00107 Rev. K 第54页 §14：许可文件及 systemInfo；第59页：SetUp 生成 MAT，再由 VSX 加载。
- D00108 Rev. L 第10页 §1.5：仿真许可绑定计算机。当前版本要求另由本次 activate 实际输出确认。
- D00109 Rev. D 用于后续设备连接与自检，本轮未执行任何设备连接或硬件操作。

本轮只验证 MATLAB 结构生成与离线逻辑，不包含传播求解、声场收敛、绝对声压、温升、材料固化或临床安全结论。助手未安装 MATLAB（使用用户提供的安装目录）、未修改许可、提交或推送代码。
