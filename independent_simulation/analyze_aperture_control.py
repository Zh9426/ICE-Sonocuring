"""Independent aperture comparison, normalized by an explicit source proxy."""
from pathlib import Path
import csv
import hashlib
import json
import h5py
import numpy as np
from scipy.io import loadmat
from analyze_kwave_offaxis import read_volume, trace_statistics, band_peak, traces_in_label_order

ROOT = Path(__file__).resolve().parent
OLD = ROOT/'results/kwave_singlepoint_validation_2026-10-22'
BOUNDARY = ROOT/'results/kwave_offaxis_diagnostic_2026-10-22'
OUT = ROOT/'results/kwave_aperture_control_2026-10-23'


def linear_counterfactual(peak, qp, scale):
    if not np.isfinite(scale) or scale <= 0:
        raise ValueError('Positive finite pressure scale required.')
    return {'peak_pa_assumed_derived': peak/scale, 'qp_pa2_s_derived': qp/scale**2}


def main():
    boundary = json.loads((BOUNDARY/'analysis.json').read_text(encoding='utf-8'))
    assert all(c['within_proposed_criteria'] for c in boundary['cases']), 'Boundary prerequisite not met.'
    reference = json.loads((OLD/'wide65.json').read_text(encoding='utf-8-sig'))
    report = json.loads((OUT/'full64_matched.json').read_text(encoding='utf-8-sig'))
    assert report['source']['input_sha256'] == reference['source']['input_sha256']
    assert report['source']['active_elements'] == list(range(1,65))
    for key in ('dx_m','domain_m','pml_m','cfl','source_offset_m','density_kg_m3','source_amplitude_pa'):
        assert report['config'][key] == reference['config'][key], key
    assert report['Nt'] == reference['Nt'] and report['dt_s'] == reference['dt_s']
    saved = loadmat(report['config']['input_mat'], simplify_cells=True)
    c = float(saved['Resource']['Parameters']['speedOfSound']); tr = saved['Trans']
    assert tr['units']=='wavelengths', 'This audit expects the saved wavelength-unit probe geometry.'
    pos = np.asarray(tr['ElementPos'])[:,:3]*c/(float(tr['frequency'])*1e6)
    distances = np.linalg.norm(pos-np.asarray(report['source']['target_m']), axis=1)
    delay = np.asarray(report['source']['aperture_control']['delay_s'])
    np.testing.assert_allclose(delay,(distances.max()-distances)/c,rtol=0,atol=1e-12)
    with h5py.File(OLD/'wide65.mat','r') as f:
        axes0=[np.asarray(f[k]).ravel() for k in ('x_m','y_m','z_m')]
        p0=read_volume(f,'p_peak_pa'); q0=read_volume(f,'qp_pa2_s')
        waves0=np.asarray(f['element_signals']).T.astype(float)
    with h5py.File(OUT/'full64_matched.mat','r') as f:
        axes=[np.asarray(f[k]).ravel() for k in ('x_m','y_m','z_m')]
        p=read_volume(f,'p_peak_pa'); waves=np.asarray(f['element_signals']).T.astype(float)
        raw=np.asarray(f['data/p']).T.astype(float); rms=np.asarray(f['data/p_rms']).ravel()
        time=np.asarray(f['t_s']).ravel()
        assert raw.shape==(len(rms),report['Nt']) and len(time)==report['Nt']
        np.testing.assert_allclose(time,np.arange(report['Nt'])*report['dt_s'],rtol=1e-12,atol=0)
        np.testing.assert_array_equal(p,np.maximum(abs(read_volume(f,'data/p_max_all')),abs(read_volume(f,'data/p_min_all'))))
        direct=(raw**2).sum(axis=1)*report['dt_s']
        np.testing.assert_allclose(direct,report['trace_qp_pa2_s'],rtol=1e-12,atol=0)
        rms_error=float(np.linalg.norm(direct-rms**2*report['Nt']*report['dt_s'])/np.linalg.norm(direct))
        assert rms_error <= 1e-3 and report['integral_audit']['rms_consistency_passed']
    with h5py.File(report['raw_checkpoint'],'r') as f:
        np.testing.assert_array_equal(np.asarray(f['data/p']).T,raw)
    for a,b in zip(axes0,axes):np.testing.assert_allclose(a,b,rtol=0,atol=1e-12)
    area=report['source']['element_area_m2']; dt=report['dt_s']
    b0=float(area*dt*(waves0**2).sum()); b1=float(area*dt*(waves**2).sum())
    assert abs(b1/b0-1)<1e-6
    np.testing.assert_allclose(b1,report['source']['aperture_control']['actual_budget_pa2_s_m2'],rtol=1e-12,atol=0)
    meta=report['trace_meta']; traces=traces_in_label_order(raw,meta); statistics=trace_statistics(traces,dt)
    rows=[]; gain=report['source']['aperture_control']['signal_scale']
    for label,xyz,s in zip(meta['labels'],meta['actual_xyz_m'],statistics):
        loc=tuple(int(abs(a-v).argmin()) for a,v in zip(axes,xyz))
        np.testing.assert_allclose([a[i] for a,i in zip(axes,loc)],xyz,rtol=0,atol=1e-12)
        assert abs(float(p[loc])-s['peak_abs_pa_assumed'])<1e-6
        rows.append({'label':label,'xyz_m':xyz,'even32_peak_pa_assumed':float(p0[loc]),
                     'full64_matched_peak_pa_assumed':s['peak_abs_pa_assumed'],
                     'even32_qp_pa2_s_rms_estimate':float(q0[loc]),'full64_matched_qp_pa2_s_direct':s['qp_pa2_s'],
                     'pressure_ratio_full64_over_even32':float(s['peak_abs_pa_assumed']/p0[loc]),
                     'qp_ratio_full64_over_even32':float(s['qp_pa2_s']/q0[loc]),
                     **linear_counterfactual(s['peak_abs_pa_assumed'],s['qp_pa2_s'],gain)})
    peaks={}
    for name,lo,hi in [('near_source',1e-10,.002),('shallow',.002,.005),('deep',.005,1.),('z2_plus',.002,1.)]:
        peaks[name]={'even32':band_peak(p0,axes0,lo,hi),'full64_matched':band_peak(p,axes,lo,hi)}
    main_row=next(r for r in rows if r['label']=='near_main')
    off_row=next(r for r in rows if r['label']=='offaxis_pos')
    ratios={'even32_offaxis_over_fixed_main_qp':off_row['even32_qp_pa2_s_rms_estimate']/main_row['even32_qp_pa2_s_rms_estimate'],
            'full64_offaxis_over_fixed_main_qp':off_row['full64_matched_qp_pa2_s_direct']/main_row['full64_matched_qp_pa2_s_direct']}
    protected=json.loads((OUT/'preserved_hashes_before.json').read_text(encoding='utf-8'))
    for item in protected:
        with Path(item['path']).open('rb') as f:assert hashlib.file_digest(f,'sha256').hexdigest()==item['sha256'],item['path']
    geometry={}
    width=float(tr['elementWidth'])*c/(float(tr['frequency'])*1e6)
    for name,active in [('even32',np.asarray(reference['source']['active_elements'])-1),('full64',np.arange(64))]:
        xx=np.sort(pos[active,0])
        geometry[name]={'active_count':len(xx),'active_pitch_m':float(np.median(np.diff(xx))),
                        'active_center_x_m':float(xx.mean()),'outer_aperture_x_m':float(np.ptp(xx)+width)}
    result={'budget_even32_pa2_s_m2':b0,'budget_full64_pa2_s_m2':b1,'signal_scale':gain,'geometry_controls':geometry,
            'rms_direct_relative_l2':rms_error,'peaks':peaks,'fixed_trace_comparison':rows,
            'selectivity_ratios':ratios,'protected_files_unchanged':len(protected),
            'limitations':'Synthetic aperture changes count/pitch/fill/centroid/aperture together. Proxy budget is not acoustic power or energy. No full-volume new Qp, heat or cure; no fine-grid offaxis verification. Same-element-amplitude numbers are linear derived counterfactuals, not extra solves.'}
    (OUT/'analysis.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
    with (OUT/'comparison.csv').open('w',newline='',encoding='utf-8') as f:
        writer=csv.DictWriter(f,fieldnames=list(rows[0]));writer.writeheader();writer.writerows(rows)
    make_figure(axes,p0,p,rows)
    write_report(report,result)
    print(json.dumps({'budget_ratio':b1/b0,'ratios':ratios,'peaks':peaks['z2_plus']},indent=2))


def make_figure(axes,p0,p,rows):
    import matplotlib
    matplotlib.use('Agg')
    import matplotlib.pyplot as plt
    fig,axs=plt.subplots(2,2,figsize=(11,8),constrained_layout=True)
    iy=int(abs(axes[1]).argmin()); iz=np.flatnonzero((axes[2]>0)&(axes[2]<.030))
    maximum=max(float(p0[:,:,iz].max()),float(p[:,:,iz].max()))
    for ax,field,title in zip(axs[0],[p0,p],['even32 reference','full64 matched source proxy']):
        im=ax.pcolormesh(axes[0]*1e3,axes[2][iz]*1e3,field[:,iy,iz].T,shading='auto',vmin=0,vmax=maximum,rasterized=True)
        ax.plot([6.37,-6.37],[2.015,2.015],'wo',ms=4,fillstyle='none');ax.set(xlabel='x (mm)',ylabel='z (mm)',title=title);ax.invert_yaxis()
    fig.colorbar(im,ax=axs[0],label='max_t |p| (Pa, assumed source)')
    ix=int(abs(axes[0]).argmin())
    axs[1,0].plot(axes[2]*1e3,p0[ix,iy,:],label='even32');axs[1,0].plot(axes[2]*1e3,p[ix,iy,:],label='full64 matched')
    axs[1,0].set(xlabel='z (mm)',ylabel='On-axis max_t |p| (Pa)',xlim=(2,30));axs[1,0].legend()
    main=next(r for r in rows if r['label']=='near_main')
    chosen=[next(r for r in rows if r['label']==s) for s in ['target','offaxis_pos','near_source_peak']]
    x=np.arange(3)
    axs[1,1].bar(x-.18,[r['even32_qp_pa2_s_rms_estimate']/main['even32_qp_pa2_s_rms_estimate'] for r in chosen],.36,label='even32 RMS')
    axs[1,1].bar(x+.18,[r['full64_matched_qp_pa2_s_direct']/main['full64_matched_qp_pa2_s_direct'] for r in chosen],.36,label='full64 direct')
    axs[1,1].set(xticks=x,xticklabels=['target','offaxis','near source'],ylabel='Qp / fixed main-point Qp');axs[1,1].legend()
    fig.suptitle('Synthetic active-aperture control: no lens, absorption, heat or cure')
    fig.savefig(OUT/'aperture_comparison.png',dpi=200);fig.savefig(OUT/'aperture_comparison.pdf');plt.close(fig)


def write_report(report,result):
    g=result['signal_scale']; ratios=result['selectivity_ratios']
    lines=['# 活动阵元配置对照：偶数32元与全64元','','2026-10-23。只进行离线合成声场对照；未改变保存SetUp或硬件奇偶角色。', '',
           '## 模型、预算与实际运行','',
           f'kspaceFirstOrder3D/k-Wave1.4.1，MATLAB R2024b，gpuArray-single；full64_matched实际求解{report["runtime_s"]:.1f}s。相同65um、15.6×10.4×31.2mm物理域、PML16格、CFL0.2、40us、6MHz波形、assumed均匀无损流体和无透镜矩形加性压力源。参照为上一轮wide65；[边界诊断](offaxis_diagnostic_2026-10-22.md)先完成。','',
           f'全64元重算几何聚焦延时，不使用奇数成像延时。统一信号缩放{g:.9f}，源端预算B=阵元面积×dt×sum_e,t(s²)从{result["budget_even32_pa2_s_m2"]:.12g}到{result["budget_full64_pa2_s_m2"]:.12g} Pa²·s·m²。B是明确的源端代理，不能称相同实际声能/声功率。','',
           '数量、活动间距、填充率、孔径和中心同时变化，不能把配置总体差异唯一归因pitch。探头几何仍existing_code_unverified；full64激励为synthetic，不是已批准的硬件序列。','',
           '|配置|活动数|活动间距，mm|外缘孔径，mm|活动中心x，mm|','|---|---:|---:|---:|---:|']
    for name,gc in result['geometry_controls'].items():
        lines.append(f'|{name}|{gc["active_count"]}|{gc["active_pitch_m"]*1e3:.3f}|{gc["outer_aperture_x_m"]*1e3:.3f}|{gc["active_center_x_m"]*1e3:.3f}|')
    lines += ['',
           '## 固定测点结果','',
           '|测点|32元峰压，Pa|64元等代理预算峰压，Pa|32元Qp，10⁻⁶ Pa²s|64元Qp，10⁻⁶ Pa²s|',
           '|---|---:|---:|---:|---:|']
    for r in result['fixed_trace_comparison']:
        if r['label'] in ['near_main','target','offaxis_pos','offaxis_neg','near_source_peak']:
            lines.append(f'|{r["label"]}|{r["even32_peak_pa_assumed"]:.6f}|{r["full64_matched_peak_pa_assumed"]:.6f}|{r["even32_qp_pa2_s_rms_estimate"]*1e6:.6f}|{r["full64_matched_qp_pa2_s_direct"]*1e6:.6f}|')
    lines += ['',f'固定正侧离轴点/固定主焦区测点Qp比：32元{ratios["even32_offaxis_over_fixed_main_qp"]:.6f}，全64元{ratios["full64_offaxis_over_fixed_main_qp"]:.6f}。这些比值不依赖整体幅度缩放，但只适用于已采样点，不是全空间最大旁瓣或材料固化对比。','',
              '32元Qp为旧GPU单精度RMS估计，全64元为保存时序的双精度直接积分，极小差异含估计口径误差。新RMS交叉核对偏差为'+f'{result["rms_direct_relative_l2"]:.5%}，实现容差0.1%。','',
              '## 搜索区域的最大压力','', '|区域|配置|峰压，Pa|位置x/y/z，mm|搜索边界|','|---|---|---:|---|---|']
    band_labels={'near_source':'0<z<2 mm','shallow':'2≤z<5 mm','deep':'z≥5 mm','z2_plus':'z≥2 mm'}
    for band,pair in result['peaks'].items():
        for name,peak in pair.items():
            xyz=', '.join(f'{v*1e3:.3f}' for v in peak['xyz_m'])
            lines.append(f'|{band_labels[band]}|{name}|{peak["peak_pa_assumed"]:.6f}|({xyz})|{peak["on_search_boundary"]}|')
    lines += ['', '## 验证与限制','',
              f'{result["protected_files_unchanged"]}份历史输入/结果哈希一致；Python独立回读XYZ、全域极值、传感器行映射、原始检查点、时序积分、源端预算以及64元几何延时。软件验证记录位于同结果目录。','',
              '全64相同单元幅度的值只由线性模型按p/g、Qp/g²推导，已在comparison.csv标derived；不是另一次实际求解，也不具有等预算含义。','',
              '当前没有新全域Qp、吸收、温度、SonoInk反应或真实探头验证。不能报告新的材料积分效率、固化尺寸或安全结论；离轴结构仍缺宽域细网格验证。下一步应先复核真实源/俯仰透镜、网格及实际样品区域，再决定配置和焦深优化。','',
              '![声场与固定点累计暴露对比](../results/kwave_aperture_control_2026-10-23/aperture_comparison.png)','',
              '[数值审计](../results/kwave_aperture_control_2026-10-23/analysis.json)、[完整测点与线性推导表](../results/kwave_aperture_control_2026-10-23/comparison.csv)、[运行入口](../run_kwave_aperture_control_R2024b.ps1)。','']
    (ROOT/'docs/aperture_control_2026-10-23.md').write_text('\n'.join(lines),encoding='utf-8')


if __name__=='__main__':main()
