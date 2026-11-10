# BLI 阵列源首轮测试：失败记录

2026-11-10，MATLAB R2024a Update 9。仅运行 `curing_field_test_bli_prepare.m` 的前六项，不含第七项实际四版导出；1 项通过、5 项失败，其中 4 项未完成。

错误集中于 `iceind.curing_bli_prepare` 的 `iceind:CuringBLISource`：以 1% 幅值波形起点直接比较 TX.Delay，误把共同滤波延迟当作阵元延时错误；边界拒绝测试因此在到达边界检查前抛出此错误。第 4 项 rank 不匹配拒绝通过。

独立数值诊断：对实际 All64 的零延时阵元，`dt=0.00844155844 μs`，其 `kw_waveform` 1% 起点为 `0.303896104 μs`，记录的高斯滤波群延迟为 `0.45 μs`。两者并不要求相等：前者是1%阈值起点，后者是滤波器中心群延迟。因而 `onset≈TX.Delay` 不成立。实际命令的关键步骤为 `q=iceind.compile_kwave(load(...)); [w,m]=iceind.kw_waveform(q.tx(1),dt,...,1); find(abs(w(j,:))>0.01*max(abs(w(j,:))),1)`。

该记录是首轮失败，不代表修订后的状态；后续通过与否必须由重新运行的结果证明。
