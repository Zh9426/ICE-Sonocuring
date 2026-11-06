"""Render the completed wide-grid audit into a source-linked Chinese report."""
from pathlib import Path
import json
import csv
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parent
OUT = ROOT/'results/kwave_widegrid_2026-10-24'


def xyz(values):
    return '('+', '.join(f'{v*1e3:.3f}' for v in values)+')'


def main():
    a = json.loads((OUT/'analysis.json').read_text())
    cases = a['cases']
    tests = list(csv.DictReader((OUT/'test_results.csv').open()))
    assert all(r['Passed']=='1' and r['Failed']=='0' and r['Incomplete']=='0' for r in tests)
    suites = ET.parse(OUT/'python_tests.xml').getroot().findall('testsuite')
    pytests = sum(int(s.attrib['tests']) for s in suites)
    assert all(int(s.attrib['failures'])+int(s.attrib['errors'])==0 for s in suites)
    lines = ['# 宽域52 μm对照：网格变化是否改变活动配置结论', '',
             '2026-10-24。实际数值依据保存的原始检查点、最终MAT及独立Python审计；所有绝对声压均来自assumed未标定压力源。', '',
             '## 本次只改变什么', '',
             '保持15.6×10.4×31.2 mm物理域、1.04 mm域外PML、0.52 mm源后偏移、CFL0.2和至少40 μs记录。65→52 μm使物理网格由240×160×480变为300×200×600，PML16→20格以保持实际厚度。波形时间采样、有限矩形源体素覆盖随网格变化，不是只改变观测分辨率。', '',
             '分别复核偶数32元及synthetic全64元。每组最终离散阵元信号的B统一为历史wide65预算：B=阵元面积×dt×sum(s²)，Pa²·s·m²。B不是实际声功率或能量；Qp=dt×sum(p²)，Pa²·s，不是吸收热量或固化剂量。aperture_control中预算是适配器缩放前阶段值，本轮最终值在widegrid_budget。', '',
             'MATLAB R2024b Update 2、k-Wave1.4.1、kspaceFirstOrder3D、RTX4070 Laptop、gpuArray-single。均匀无损介质c=1540 m/s、ρ=1000 kg/m³仍assumed，探头几何existing_code_unverified；未引入俯仰透镜、容器、吸收、温升或SonoInk反应。保存SetUp未修改，未运行VSX或硬件。', '',
             '|细网格工况|实际求解，s|B，Pa²·s·m²|B/该配置65μm参照|RMS对直接Qp偏差|',
             '|---|---:|---:|---:|---:|']
    for c in cases:
        lines.append(f'|{c["kind"]}|{c["runtime_s"]:.1f}|{c["budget_pa2_s_m2"]:.12g}|{c["budget_ratio_vs_coarse"]:.9f}|{c["rms_direct_relative_l2"]:.5%}|')
    lines += ['', '## 压力场网格敏感性', '',
              '两种互补评价均比较原始声压幅度，没有将两场各自峰值归一化：①细网格三线性插值到全部粗网格体素；②260 μm共同精确格点，不插值。共同格点检查较稀疏，不能代替近源细结构检查。native峰值另在各自完整网格的相同物理深度区间搜索。', '',
              '5%场差和0.13 mm峰位是proposed内部诊断，非设备或材料标准；两网格检查不建立完整数值收敛。单个argmax可能在近似等高的镜像瓣间切换，因此同时保留有符号坐标和镜像等价距离，仅将后者用作诊断，不能解释为实际峰迁移。', '',
              '|配置|区域|插值场L2|共同格点L2|插值最大值差|共同格点最大值差|两种场差均≤5%|',
              '|---|---|---:|---:|---:|---:|---|']
    for c in cases:
        for band, d in c['comparison'].items():
            lines.append(f'|{c["kind"]}|{band}|{d["linear"]["raw_amplitude_relative_l2"]:.3%}|{d["shared"]["raw_amplitude_relative_l2"]:.3%}|{d["linear"]["maximum_relative_change"]:.3%}|{d["shared"]["maximum_relative_change"]:.3%}|{d["field_5pct_both_evaluations"]}|')
    lines += ['', '区域：all_physical包括源平面及源后缓冲区；near_source为0<z<2 mm；shallow为2≤z<5 mm；deep为z≥5 mm；z2_plus为z≥2 mm。native区间包含的首末体素随dx变化，因此分区原生最大值还受边界采样差异影响。', '',
              '|配置|区域|65μm原生峰压，Pa|65μm位置，mm|52μm原生峰压，Pa|52μm位置，mm|52μm位于搜索边界|',
              '|---|---|---:|---|---:|---|---|']
    for c in cases:
        for band, p in c['native_peaks'].items():
            lines.append(f'|{c["kind"]}|{band}|{p["coarse"]["peak_pa_assumed"]:.6f}|{xyz(p["coarse"]["xyz_m"])}|{p["fine"]["peak_pa_assumed"]:.6f}|{xyz(p["fine"]["xyz_m"])}|{p["fine"]["on_search_boundary"]}|')
    lines += ['', '|配置|区域|原生argmax位置差，mm|镜像等价位置差，mm，仅诊断|原生位置差≤0.13 mm|',
              '|---|---|---:|---:|---|']
    for c in cases:
        for band, d in c['comparison'].items():
            lines.append(f'|{c["kind"]}|{band}|{d["native_peak_displacement_m"]*1e3:.3f}|{d["mirror_equivalent_argmax_displacement_m_diagnostic_only"]*1e3:.3f}|{d["native_peak_013mm"]}|')
    lines += ['', '## 测点Qp与配置差异', '',
              '12个请求测点保持相同物理坐标，但最近体素在52 μm与65 μm上不一定相同。下表及完整CSV明确实际坐标；这些测点变化不能单独称作相同物理点Qp收敛。旧32元Qp来自GPU RMS估计，旧64元和本次两组来自保存p(t)的双精度积分；RMS仅作0.1%实现一致性诊断。', '',
              '|配置|测点|65μm实际位置，mm|52μm实际位置，mm|65μm Qp，10⁻⁶ Pa²s|52μm Qp，10⁻⁶ Pa²s|',
              '|---|---|---|---|---:|---:|']
    for c in cases:
        for r in c['trace_comparison']:
            if r['label'] in ('target','near_main','offaxis_pos','offaxis_neg','near_source_peak'):
                lines.append(f'|{c["kind"]}|{r["label"]}|{xyz(r["coarse_xyz_m"])}|{xyz(r["fine_xyz_m"])}|{r["coarse_qp_pa2_s"]*1e6:.6f}|{r["fine_qp_pa2_s_direct"]*1e6:.6f}|')
    lines += ['', '|52μm配置|offaxis_pos/near_main Qp|target/near_main Qp|', '|---|---:|---:|']
    for c in cases:
        lines.append(f'|{c["kind"]}|{c["offaxis_over_near_main_qp"]:.9f}|{c["target_over_near_main_qp"]:.6f}|')
    sampling = json.loads((OUT/'source_sampling.json').read_text())
    selected = [r for r in sampling['selected_rows'] if r['angle_deg_xz']==75.]
    lines += ['', '阵元数量、活动间距、填充率、孔径和中心同时变化，结果只能归于当前活动配置整体，不能唯一认定真实探头栅瓣机制。固定点比值不是全空间最大旁瓣、目标内能量比例或材料效率；本次仍无全域新Qp。', '',
              '## 新发现的源面离散问题与解决方向', '',
              '宽度0.11 mm的矩形单元，在65/52 μm网格上仅约1.69/2.12格。现有代码采用单元与网格的面积重叠权重；面积严格守恒并不保证源的空间傅里叶谱一致。新增解析审计取中心x=-0.065 mm的代表偶数单元，沿XZ取ky=0；该谱也依赖单元相对网格的偏移。将离散权重谱与同一连续矩形面积积分比较，不计算传播声场，也不是实物指向性。', '',
              '|6 MHz、75°示例|连续矩形源谱|离散源谱幅值|相对连续积分偏差|', '|---|---:|---:|---:|']
    for r in selected:
        lines.append(f'|{r["dx_m"]*1e6:.0f} μm|{r["continuous_rectangle_source_transfer"]:.6f}|{r["cell_overlap_source_transfer_abs"]:.6f}|{r["amplitude_error_vs_continuous"]:.2%}|')
    lines += ['', '两网格在零空间频率均为1，使用同一物理面积作为分母；没有按各自最大声场归一化。这证明源表示的大角度空间分量发生变化，为浅层场网格敏感提供线索；尚未隔离其与时间采样、传播离散化各自造成的误差，不能认定所有差异由源表示导致。', '',
              '建议下一增量先测试kWaveArray带限源表示，并核对其非局域支撑是否被边界截断、信号尺度及BLI容差/积分密度敏感性，再与当前矩形源及细网格比较。该方法通过带限插值表示物理几何，见[k-Wave官方文档](https://www.k-wave.org/documentation/kWaveArray.php)及[Wise等，JASA 2019](https://doi.org/10.1121/1.5116132)。验收以连续源谱、面积/尺度及网格稳定性为依据，新的场幅值可能升高或降低。本次尚未替换源或执行带限源传播；不能用源谱诊断冒充改进后的声场结果。浅层幅值未稳定前，优先处理源表示，再推进焦深补偿和材料模型。', '',
              '![源面空间谱](../results/kwave_widegrid_2026-10-24/source_sampling.png)', '',
              '[源空间谱审计](../results/kwave_widegrid_2026-10-24/source_sampling.json)、[谱表](../results/kwave_widegrid_2026-10-24/source_sampling.csv)、[审计实现](../audit_source_sampling.py)。', '',
              '## 软件与数据完整性', '',
              f'MATLAB {len(tests)}/{len(tests)}、Python {pytests}/{pytests}测试通过；MATLAB静态检查见结果目录。独立审计确认{a["protected_files_unchanged"]}份历史文件哈希不变。原始检查点与最终文件的测点波形、阵元信号和坐标相符；另核对XYZ维序、极值、时窗、传感器行映射、预算、保存几何/TX推导的延时，以及共同时间格点处的最终阵元波形。', '',
              '资源探针仅128步、截短源信号，不能作为物理结果。第一次被保守显存估算阻止于求解前；实测探针占用约5.56 GiB并成功。完整求解前的JSON行/列向量门槛问题由回归测试修复，保留失败日志；未以缩小物理域解决资源问题。MATLAB首轮服务错误5201后顺序重试成功，未重启系统或修改许可。', '',
              '运行器控制台FINISHED中的“main peak”旧标签实际打印forward搜索区全局最大值；不等于主焦区，位置解读以本报告分区表和JSON为准。', '',
              '![浅层两网格两配置](../results/kwave_widegrid_2026-10-24/widegrid_shallow.png)', '',
              '![轴上峰压剖线](../results/kwave_widegrid_2026-10-24/widegrid_axial.png)', '',
              '[完整审计JSON](../results/kwave_widegrid_2026-10-24/analysis.json)、[完整测点表](../results/kwave_widegrid_2026-10-24/trace_comparison.csv)、[运行入口](../run_kwave_widegrid_R2024b.ps1)、[执行计划](superpowers/plans/2026-10-24-widegrid.md)。', '']
    (ROOT/'docs/widegrid_2026-10-24.md').write_text('\n'.join(lines), encoding='utf-8')
    print('Wrote docs/widegrid_2026-10-24.md')


if __name__ == '__main__':
    main()
