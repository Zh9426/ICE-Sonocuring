# 纯照射核验：本机环境记录

2026-11-10，Asia/Shanghai。仅离线使用；未运行 VSX、activate 或硬件。

## 实际探测

- MATLAB MCP `detect_matlab_toolboxes`：R2024a Update 9（24.1.0.3303086）；安装列表有 MATLAB、Signal Processing Toolbox、Curve Fitting Toolbox，未列出 Parallel Computing Toolbox。`which('gpuDevice')` 为空，因此不能把 `license('test',...)` 的返回值单独当作工具箱已安装。
- `nvidia-smi`：NVIDIA GeForce RTX 5060 Ti，8151 MiB，探测时空闲 5931 MiB，驱动 616.92。显卡存在不代表 MATLAB GPU 求解可用。
- MATLAB `memory`：探测时物理内存总计约 34.19 GB，可用于数组约 15.67 GB；动态余量不保证后续运行资源。PowerShell `ProcessorCount` 为 20，MATLAB `feature('numcores')` 返回 14；磁盘 F 盘探测时剩余约 287.65 GiB。
- 项目原版 `VantageNXT-2.3.2-p2/MatFiles/SetUpP9_4TSICE_FlashAngles.mat` 存在。历史四版 `.mat` 按 Git 忽略规则未随仓库同步，需在新目录重新离线生成并回读；此处不声称已完成。

## k-Wave 与兼容性

仓库 `independent_simulation/dependencies/` 初始只有 README。原官网 `https://www.k-wave.org/getfile.php?id=13` 本机下载超时；之后从官方 `https://github.com/ucl-bug/k-wave.git` 拉取 v1.4.1，提交 `0f1a70f00645f2493318faef63111069084ccba7`，位于本机忽略目录 `independent_simulation/dependencies/k-wave-1.4.1/k-Wave/`，不同于历史 README 中的原压缩包目录结构，且本次不声称 ZIP 哈希相同。该目录不随 Git 同步。

在 MATLAB MCP 中临时添加上述 k-Wave 目录，运行 CPU `kspaceFirstOrder3D`：16×16×16、dx=0.2 mm、PML=4、76 步、均匀介质 c=1500 m/s、rho=1000 kg/m³、点状初始压力，`DataCast='single'`。返回76个有限采样值，最大绝对值约0.157474，总耗时约11.68秒；另能实例化 `kWaveArray` 并添加一个矩形元素。此测试仅证明 R2024a 对小型 CPU 传播及对象构建的基本兼容；该网格最高支持频率为3.75 MHz，**不是 6 MHz传播精度或四版驱动的验证**。没有调用旧 R2024b 强绑定入口。

实际执行的 MATLAB 语句（在仓库根目录，显示与计时语句略去）：

```matlab
addpath(fullfile(pwd,'independent_simulation','dependencies','k-wave-1.4.1','k-Wave'));
k=kWaveGrid(16,0.0002,16,0.0002,16,0.0002); k.makeTime(1500,0.2,2e-6);
m.sound_speed=1500; m.density=1000;
src.p0=zeros(16,16,16); src.p0(8,8,8)=1;
sen.mask=zeros(16,16,16); sen.mask(10,8,8)=1;
z=kspaceFirstOrder3D(k,m,src,sen,'PMLInside',false,'PMLSize',4,'PlotSim',false,'DataCast','single');
a=kWaveArray(); a.addRectElement([0 0 0],0.00011,0.00202,[0 0 0]);
```

另执行小型 6 MHz CPU 时间域兼容检查：32³、dx=100 μm、c=1540 m/s、PML=8、386 步、单点源、20 个周期的假设正弦信号；最高支持频率7.7 MHz，传感点返回386个有限值，最大绝对值0.0261714，传播耗时约3.55 s。首次尝试误复用已有 MATLAB 工作区变量 `s`（仍含序列的 `Trans` 字段），k-Wave 因 source 字段非法拒绝；随后使用新建 `src6=struct()` 和 `sen6=struct()` 修正并成功运行。小域与单点源不构成真实阵列或聚焦数值验证。

```matlab
g=kWaveGrid(32,1e-4,32,1e-4,32,1e-4); g.makeTime(1540,0.2,5e-6);
m=struct('sound_speed',1540,'density',1000); src6=struct();
src6.p_mask=false(32,32,32); src6.p_mask(16,16,4)=true;
t=g.t_array; src6.p=single(sin(2*pi*6e6*t).*(t<20/6e6));
sen6=struct(); sen6.mask=false(32,32,32); sen6.mask(16,16,20)=true;
y=kspaceFirstOrder3D(g,m,src6,sen6,'PMLInside',false,'PMLSize',8,'PlotSim',false,'DataCast','single');
```

随后运行**资源探针**：320×80×480、65 μm、域20.8×5.2×31.2 mm、域外PML16、16时间步、c=1540 m/s、单精度点状初始源、单点传感器。CPU 求解16步约21.30秒（含预计算总约22.26秒），全部返回值有限；仅用于粗略识别时空成本，不是阵列传播或完整时窗。输出提示扩展后网格维度的最大质因子为11、7、2，FFT性能可能受网格尺寸影响。耗时按时步外推仅是粗估，不能当作实际完整算例耗时；原始资源探针命令：

```matlab
gp=kWaveGrid(320,65e-6,80,65e-6,480,65e-6);
gp.setTime(16,0.2*65e-6/1540);
mp=struct('sound_speed',1540,'density',1000); sp=struct();
sp.p0=zeros(320,80,480,'single'); sp.p0(160,40,32)=1;
vp=struct(); vp.mask=false(320,80,480); vp.mask(160,40,240)=true;
yp=kspaceFirstOrder3D(gp,mp,sp,vp,'PMLInside',false,'PMLSize',16,'PlotSim',false,'DataCast','single');
```

## 手册

指定的 `F:/xwechat_files/wxid_quwpem6vchzg22_3c29/msg/file/2026-10/` 目录不可访问。软件包随附四份手册在本机可读：D00108 Rev.L、D00109 Rev.E、D00107 Rev.L、D00163 Rev.L。除产品规格书外均不同于指定版本，不能混用页码；D00163 Rev.L §4.3.1–4.3.2 p23–25 描述参数波形/延时和量化，D00108 Rev.L §1.4 p8区分系统保护与探头/声输出限制。软硬件包和这些本机资料跨电脑可能不可用。
