"""Generate a traceable report only after both real solves and audits exist."""
from pathlib import Path
import csv
import json
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parent
OUT = ROOT/'results/kwave_offaxis_diagnostic_2026-10-22'
LINK = '../results/kwave_offaxis_diagnostic_2026-10-22/'


def xyz_mm(values):
    return '('+', '.join(f'{v*1e3:.3f}' for v in values)+')'


def main():
    audit = json.loads((OUT/'analysis.json').read_text(encoding='utf-8'))
    tests = list(csv.DictReader((OUT/'test_results.csv').open(encoding='utf-8-sig')))
    assert all(t['Passed'] == '1' and t['Failed'] == '0' for t in tests)
    static = json.loads((OUT/'code_analysis.json').read_text(encoding='utf-8'))
    assert all(not item['messages'] for item in static)
    py_suite = ET.parse(OUT/'python_tests_final.xml').getroot().find('testsuite')
    assert py_suite is not None and py_suite.attrib['failures'] == '0' and py_suite.attrib['errors'] == '0'
    py_count = int(py_suite.attrib['tests'])
    lines = [
        '# 离轴峰边界与时序诊断', '',
        '计划始于2026-10-22，扩域缺失工况于2026-10-23续算后完成。本报告在两组正式产物均存在并通过独立回读后生成。模型仍为assumed均匀线性无损流体与未标定压力源；没有材料、温度或固化结果。', '',
        '## 固定量和实际控制', '',
        '参照[上一轮wide65](singlepoint_validation_2026-10-22.md)，保持保存MAT/TX16、物理偶数32元、6 MHz名义20周期波形、assumed 1 Pa源、c=1540 m/s、密度1000 kg/m³、65 μm网格、CFL0.2、源面距后界0.52 mm及40.0045 μs记录窗。无俯仰透镜、匹配/背衬、耦合、吸收、容器或声热模型。', '',
        '原定PML24格工况在显存预检失败（估计7.77 GB、可用7.41 GB），没有完成该配置求解。正式工况调整为PML20格和X域256格，分别仅改变一项；不改变网格精度。X半宽只增加0.52 mm，扩域证据有限。', '',
        '|工况|物理域x/y/z，mm|PML，mm|实际求解时长，s|', '|---|---|---:|---:|',
        '|旧wide65|15.6 / 10.4 / 31.2|1.04|832.3|']
    for result in audit['cases']:
        report = json.loads((OUT/f"{result['tag']}.json").read_text(encoding='utf-8-sig'))
        domain = ' / '.join(f'{v*1e3:g}' for v in result['domain_m'])
        lines.append(f"|{result['tag']}|{domain}|{report['config']['pml_m']*1e3:g}|{result['runtime_s']:.1f}|")
    lines += ['', '每组同时记录12个稀疏测点的p(t)、RMS，以及全域正负压力极值；没有新增全域Qp体。稀疏Qp用dt×sum(p²)直接积分，并与同次RMS及旧wide65相同坐标的Qp对照。压力极值体是各点不同时刻的max_t|p|，不是一帧同时声压。', '',
              '测点按请求位置取最近体素，另保存标签到k-Wave输出行的映射：target实际(0,0,20.020) mm；near_main固定为旧峰(0,0,18.395) mm；offaxis_pos/neg固定(±6.370,0,2.015) mm；near_source_peak固定(1.820,0.520,0.130) mm。固定点不会随每组自由搜索峰移动，主峰位置与固定测点位置应分开阅读。', '',
              '### RMS交叉核对的修正记录', '',
              '首轮wide_pml20已完成求解，但原拟0.001%的RMS/直接积分容差未通过，且当时检查先于保存，未留下该轮正式场。该耗时和失败保留在solver_20261022_213212_540.log中。随后小网格同样4740步GPU模拟发现RMS-Qp偏差约0.0119%；以完全相同p(t)重放GPU递推精确复现保存RMS，而CPU单精度递推偏差约0.000418%。依据见[rms_replay_diagnosis.json](../results/kwave_offaxis_diagnostic_2026-10-22/rms_replay_diagnosis.json)。这是所用GPU单精度递推路径的累计误差证据，不是声场物理差异。', '',
              '正式复算保留保存时序的双精度直接积分为主值，RMS交叉核对采用proposed 0.1%实现容差，并逐案保存偏差。物理区域敏感性5%和峰位0.13 mm判据未变。运行器在分析前保存.raw.mat原始检查点，可在配置和输入哈希一致时恢复后处理，避免再次丢失已完成求解。10月22日的扩域任务中断且无完成产物，10月23日只续跑缺失的wider_x256；日志为resume_20261023.log，未覆盖已完成wide_pml20。', '',
              '旧wide65的Qp来自GPU单精度RMS；新直接积分与旧值的差异同时包含边界改变和估计方法差异，不能全部归因边界。测点CSV及JSON同时给出新RMS对旧RMS的变化供区分，小于该误差尺度的Qp差异不作物理优劣解释。', '',
              '## 边界敏感性', '',
              '|工况|旧物理域全部体素L2差|0<z<2 mm场L2差|z=2–5 mm场L2差|z≥5 mm场L2差|z≥2 mm峰值位移，mm|12测点最大Qp相对变化|内部诊断|',
              '|---|---:|---:|---:|---:|---:|---:|---|']
    for result in audit['cases']:
        c = result['pressure_comparison_vs_wide65']
        max_q = max(abs(s['qp_relative_change_vs_wide65']) for s in result['trace_statistics'])
        lines.append(f"|{result['tag']}|{c['all_old_physical_voxels']['raw_amplitude_relative_l2']:.4%}|{c['z0_to2']['raw_amplitude_relative_l2']:.4%}|{c['z2_to5']['raw_amplitude_relative_l2']:.4%}|{c['z5_plus']['raw_amplitude_relative_l2']:.4%}|{result['forward_peak_displacement_m']*1e3:.3f}|{max_q:.4%}|{'通过' if result['within_proposed_criteria'] else '未通过'}|")
    all_stable = all(r['within_proposed_criteria'] for r in audit['cases'])
    lines += ['', '内部判据沿用拟定尺度：完整公共域及三个深度层的原始幅度场L2、区域最大值变化、各测点Qp变化均≤5%，原z≥2 mm峰值位移≤0.13 mm。完整公共域包含近源和源后物理体素；深度层分别诊断，不能用深层稳定掩盖近源变化。不是厂家精度、材料固化或安全标准。', '',
              ('两种有限边界改变均未显著改变离轴峰。因而目前不支持把该峰主要解释为这两个边界设置造成；可优先检验源/阵列几何相关机制，但尚不能唯一判定栅瓣，也没有证明全空间/所有边界收敛。' if all_stable else
               '至少一个边界控制未满足内部诊断尺度。离轴峰的数值依赖仍需解释；在此之前不能将其唯一归因为物理栅瓣或据此排名阵列。'), '',
              '## 分层报告峰值', '',
              '|工况|搜索层，mm|最大声压，Pa（assumed源）|位置x/y/z，mm|位于该搜索边界|', '|---|---|---:|---|---|']
    names = {'near_source_z0_to2': '0<z<2', 'shallow_z2_to5': '2≤z<5', 'deep_z5_plus': 'z≥5'}
    for result in audit['cases']:
        for key, name in names.items():
            peak = result['peak_bands'][key]
            lines.append(f"|{result['tag']}|{name}|{peak['peak_pa_assumed']:.6f}|{xyz_mm(peak['xyz_m'])}|{'是' if peak['on_search_boundary'] else '否'}|")
    lines += ['', '浅层峰若贴着z=2 mm搜索边界，不应称完整离轴焦点；0<z<2 mm近源场单独列出。近源高峰既不能直接认定为非目标固化，也不能通过删除近源区域宣称全域结果合格。', '',
              '## 时序与累计暴露', '',
              '|工况|固定测点|峰压，Pa（assumed源）|Qp，10⁻⁶ Pa²·s|峰压时刻，μs|累计Qp的5%–95%时刻，μs|',
              '|---|---|---:|---:|---:|---|']
    for result in audit['cases']:
        for s in result['trace_statistics']:
            if s['label'] not in ('target','near_main','offaxis_pos','offaxis_neg','near_source_peak'):
                continue
            interval = '–'.join(f'{v*1e6:.3f}' for v in s['qp90_interval_s'])
            lines.append(f"|{result['tag']}|{s['label']}|{s['peak_abs_pa_assumed']:.6f}|{s['qp_pa2_s']*1e6:.6f}|{s['peak_time_s']*1e6:.3f}|{interval}|")
    last_fraction = max(s['last_5us_qp_fraction'] for result in audit['cases'] for s in result['trace_statistics'])
    lines += ['', f'12测点中最后5 μs的Qp占比最大为{last_fraction:.5%}。这是有限测点的窗尾诊断，不能证明更晚时刻或全域没有贡献。', '',
              '5%–95%区间是离散累计Qp的时间分位区间，不是脉冲连续非零时长或材料反应时间。不能仅凭峰压排序推断热源排序；当前无损模型中的Qp也尚未包含吸收与传热。', '',
              f'![固定测点时序与累计Qp]({LINK}offaxis_traces.png)', '',
              f'![浅层极值场]({LINK}offaxis_shallow.png)', '',
              '## 软件验证、复现与限制', '',
              f'MATLAB R2024b Update 2独立模块{len(tests)}/{len(tests)}项测试通过，{len(static)}份新增MATLAB文件Code Analyzer无消息。Python {py_count}/{py_count}项测试通过，记录见[JUnit]({LINK}python_tests_final.xml)；实际MAT独立回读核对时序、XYZ顺序、传感器排序、峰值、RMS积分、输入及时间窗。{audit["protected_files_unchanged"]}份受保护历史文件SHA-256一致。软件通过与数值/物理结论分开。', '',
              'k-Wave1.4.1、kspaceFirstOrder3D、gpuArray-single、RTX4070 Laptop GPU。保留上游ver(distcomp)弃用及FFT尺寸效率提示，未改依赖。没有运行VSX、硬件、材料实验或修改保存SetUp。', '',
              f'结果：[独立审计]({LINK}analysis.json)、[测点表]({LINK}trace_summary.csv)、[MATLAB测试]({LINK}test_results.csv)。', '',
              '入口：[R2024b脚本](../run_kwave_offaxis_diagnostic_R2024b.ps1)，先测试再执行两组，拒绝覆盖完成MAT/JSON。历史结果保持原目录。Python复现：`python independent_simulation/analyze_kwave_offaxis.py`，随后`python independent_simulation/write_kwave_offaxis_report.py`。', '',
              '原始检查点当前仅供同一实现版本恢复后处理；尚未建立跨代码/求解器版本的完整指纹迁移验证，本轮未执行跨版本恢复。', '',
              '原52 μm细网格物理域不含x=6.37 mm离轴点，因此原焦区网格检查不能替代该离轴结构的网格细化验证。本轮两个65 μm边界控制也不补足这一缺口。新工况仅有稀疏Qp，未证明全域Qp最大值或积分稳定。', '',
              '下一阶段由这组证据决定是否进入离线活动阵元间距/频率控制，并补充离轴结构的网格检查。当前加性压力源缺少真实单元指向性、匹配层及背衬；边界稳定也不能直接将结构归因于真实探头栅瓣。真实电声传递、俯仰透镜、SonoInk配方和吸收/热学/聚合参数继续unknown；真实设备能力须另查手册及本机/探头资料。本报告不提出上机驱动处方。', '']
    path = ROOT/'docs/offaxis_diagnostic_2026-10-22.md'
    path.write_text('\n'.join(lines), encoding='utf-8')
    print(path)


if __name__ == '__main__':
    main()
