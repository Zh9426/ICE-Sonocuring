"""Update the Chinese results section from audited numerical artifacts."""
from pathlib import Path
import csv
import json

ROOT = Path(__file__).resolve().parent
OUT = ROOT / 'results' / 'kwave_singlepoint_validation_2026-10-22'


def update_report():
    analysis = json.loads((OUT / 'analysis.json').read_text(encoding='utf-8'))
    reports = {tag: json.loads((OUT / f'{tag}.json').read_text(encoding='utf-8'))
               for tag in analysis['completed_cases']}
    validation = json.loads((OUT / 'validation.json').read_text(encoding='utf-8'))
    source = json.loads((OUT / 'source_audit.json').read_text(encoding='utf-8'))
    fine = reports['fine52']
    wide = reports['wide65']
    width = fine['metrics']['width_at_forward_peak_m']
    assert not any(fine['metrics']['width_clipped']) and all(value is not None for value in width), 'Revise the fine52 width interpretation before publishing.'
    assert all(abs(first - second) < 1e-12 for first, second in zip(
        fine['metrics']['forward_peak_xyz_m'], fine['metrics']['near_target_peak_xyz_m'])), 'Revise the fine52 global/local peak interpretation before publishing.'
    result = ['## 运行状态与结果', '',
              '**五个工况均已实际完成；有限公共ROI结果较接近，但扩大横向域发现更强离轴声压峰，因此全前向域峰值稳定性检查未通过。** 没有建立完整数值收敛，也没有实物或材料验证。', '',
              '|工况|求解耗时，s|已观察前向域峰值(x,y,z)，mm|该峰值是否在分析边界|目标附近局部峰值z，mm|',
              '|---|---:|---|---|---:|']
    for tag, report in reports.items():
        metrics = report['metrics']
        position = ', '.join(f'{value * 1000:.3f}' for value in metrics['forward_peak_xyz_m'])
        result.append(f"|{tag}|{report['runtime_s']:.1f}|({position})|{'是' if metrics['forward_peak_on_boundary'] else '否'}|{metrics['near_target_peak_xyz_m'][2] * 1000:.3f}|")
    result += ['', '“前向域峰值”与“目标附近局部峰值”是不同搜索范围；离轴强峰到目标的距离不能当作主焦区定位误差。目标附近搜索仍为±(2,2,4) mm，设定目标始终保持[0,0,20] mm。', '',
               '|对照baseline65|公共ROI峰压场L2差|公共ROI Qp场L2差|全前向域峰值位置变化，mm|综合内部敏感性检查|',
               '|---|---:|---:|---:|---|']
    for row in analysis['comparisons']:
        result.append(f"|{row['tag']}|{row['pressure']['relative_l2'] * 100:.4f}%|{row['qp']['relative_l2'] * 100:.4f}%|{row['peak_displacement_m'] * 1000:.3f}|{'通过' if row['within_proposed_sensitivity_checks'] else '未通过'}|")
    peak = wide['metrics']['forward_peak_xyz_m']
    gain = wide['metrics']['forward_peak_pa_assumed'] / wide['metrics']['near_target_peak_pa_assumed']
    result += ['', f"wide65在({peak[0] * 1000:.3f}, {peak[1] * 1000:.3f}, {peak[2] * 1000:.3f}) mm发现的压力幅度约{wide['metrics']['forward_peak_pa_assumed']:.6f} Pa（仅assumed源下），比同一工况目标附近局部峰高{(gain - 1) * 100:.2f}%。该位置超出旧横向域，并处于z≥2 mm搜索域的浅端；其x/z半幅交点不闭合，宽度记为缺失/截断，不能填成0或当作完整焦区。此结果支持“旧域没有覆盖所有较强离轴暴露”，不单独判定其为物理栅瓣、旁瓣或边界伪影。进一步扩大域、加厚该大域PML及近源区诊断仍待执行。", '',
               f"fine52的目标附近峰值位于z={fine['metrics']['near_target_peak_xyz_m'][2] * 1000:.3f} mm，距设定目标{fine['metrics']['near_target_peak_error_m'] * 1000:.3f} mm；该工况全前向峰也在此处。原proposed 0.5 mm数值定位诊断仍未通过，该阈值不是厂家精度标准。x/y/z声压连续半幅宽约{width[0] * 1000:.3f}/{width[1] * 1000:.3f}/{width[2] * 1000:.3f} mm，均闭合。这是约−6.02 dB压力幅度宽度，不是强度FWHM。", '',
               '![扩大域的压力与累计暴露代理](../results/kwave_singlepoint_validation_2026-10-22/wide_field.png)', '',
               '![公共ROI及轴向形状](../results/kwave_singlepoint_validation_2026-10-22/field_exposure.png)', '',
               '![局部敏感性和目标盒尺寸](../results/kwave_singlepoint_validation_2026-10-22/sensitivity.png)', '',
               '### 假设目标内外Qp', '',
               '下表固定assumed材料盒8×4×18 mm（z=10–28 mm），使用fine52。Qp比例是该观察体积内的压力平方时间积分比例；评价盒不包含上述大域浅层离轴强峰，不能把该比例当作全空间结果。', '',
               '|synthetic目标完整尺寸，mm|目标内Qp代理积分比例|目标外/目标内最大Qp|目标内Qp变异系数|',
               '|---|---:|---:|---:|']
    for item in fine['exposure']:
        dimensions = '×'.join(f'{value * 2000:g}' for value in item['target_halfwidth_m_assumed'])
        result.append(f"|{dimensions}|{item['target_qp_fraction_of_material'] * 100:.3f}%|{item['outside_over_target_max_qp']:.4f}|{item['target_cv_qp']:.4f}|")
    result += ['', '**补充探索性后处理：** 固定1×1×1 mm目标，对同一声场改变assumed材料积分盒的轴向厚度。这组材料盒在初始目标比例得到后补充，用于说明分母依赖，不属于预先声明的数值通过条件。', '',
               '|材料盒z范围，mm|厚度，mm|baseline65目标Qp比例|fine52目标Qp比例|',
               '|---|---:|---:|---:|']
    with (OUT / 'material_box_sensitivity.csv').open(encoding='utf-8', newline='') as file:
        layers = list(csv.DictReader(file))
    for lower, upper in ((19.5, 20.5), (19, 21), (18, 22), (10, 28)):
        values = {row['tag']: float(row['target_qp_fraction']) for row in layers
                  if float(row['z_min_mm_assumed']) == lower and float(row['z_max_mm_assumed']) == upper}
        result.append(f"|{lower:g}–{upper:g}|{upper - lower:g}|{values['baseline65'] * 100:.3f}%|{values['fine52'] * 100:.3f}%|")
    result += ['', '这里仅改变同一无损声场上的积分区域，目标内积分保持不变；没有重新求解不同材料厚度下的吸收、反射或温升。比例提高不等于固化率提高。样品形状与放置方式应在材料试验前明确，不能只选有利分母宣称聚焦有效。', '',
               '### 独立检查及实际验证', '',
               f"保存延时与几何公式的最大差为{source['max_delay_error_s']:.3g} s；阵元中心到达时间差{source['arrival_spread_s']:.3g} s。单频有限矩形参考的两档积分均给出约{source['monochromatic_reference'][-1]['peak_z_m'] * 1000:.3f} mm轴向峰，归一化剖线相对差{source['normalized_reference_quadrature_l2'] * 100:.4f}%。这为有限孔径焦移提供独立模型线索，不能证明唯一成因或实际探头准确度。", '',
               f"40 μs新基线相对历史65 μm峰压场的公共ROI L2差为{analysis['historic_baseline_to_40us']['relative_l2'] * 100:.8f}%。历史四个测点直接时序积分与新RMS采样值最大相对差{analysis['historic_sparse_time_integral_comparison']['max_absolute_relative_change'] * 100:.5f}%；其差异同时含时窗延长和数值递推影响，未将二者分离。", '',
               f"MATLAB R2024b独立模块{validation['matlab_tests_passed']}/{validation['matlab_tests_total']}项测试通过，{validation['code_analysis_file_count']}份新增MATLAB文件Code Analyzer 0消息；Python独立模块{validation['python_tests_passed']}/{validation['python_tests_total']}项测试通过。五份MAT已回读检查XYZ维序、极值、Qp、时间窗、峰值及假设区域积分；跨工况输入、波形和介质不变量一致。{len(analysis['preserved_files'])}份受保护源/旧基线文件哈希一致。`git diff --check`已执行，无空白错误。", '',
               '软件测试和产物完整性检查通过，不等于所有数值敏感性检查通过。运行时存在k-Wave上游`ver(\'distcomp\')`弃用提示及部分网格FFT质因子效率提示；求解完成，未改动上游依赖。', '',
               '原始证据：[综合审计](../results/kwave_singlepoint_validation_2026-10-22/analysis.json)、[验证汇总](../results/kwave_singlepoint_validation_2026-10-22/validation.json)、[峰值表](../results/kwave_singlepoint_validation_2026-10-22/focus_summary.csv)、[敏感性表](../results/kwave_singlepoint_validation_2026-10-22/sensitivity_summary.csv)、[目标盒表](../results/kwave_singlepoint_validation_2026-10-22/exposure_summary.csv)、[材料积分盒表](../results/kwave_singlepoint_validation_2026-10-22/material_box_sensitivity.csv)。', '',
               '### 下一步判断', '',
               '本轮不宜直接宣称“局部固化条件已具备”。优先追踪扩大域中的离轴强暴露及其边界/近源敏感性，同时核实真实俯仰透镜与几何。当前已有结果可作为后续SonoInk研究的声学基线；实际或明确文献配方、频段适用吸收、热学与聚合响应，以及声压标定仍是声热—材料预测的依赖。电子偏转和短线试验尚未执行。', '']
    path = ROOT / 'docs/singlepoint_validation_2026-10-22.md'
    text = path.read_text(encoding='utf-8')
    start = text.index('## 运行状态与结果')
    end = text.index('## 复现与产物保护', start)
    text = text[:start] + '\n'.join(result) + '\n' + text[end:]
    text = text.replace('当前阶段为离线数值验证；实际运行与汇总完成后更新本报告的结果章节。',
                        '五个离线声场工况及独立审计已完成；局部ROI较接近，扩大域全局声压峰值检查未通过。')
    path.write_text(text, encoding='utf-8')
    print(path)


if __name__ == '__main__':
    update_report()
