"""Audit boundary controls and sparse histories; pressure proxies, never cure."""
from pathlib import Path
import csv
import hashlib
import json
import h5py
import numpy as np

ROOT = Path(__file__).resolve().parent
OLD = ROOT / 'results/kwave_singlepoint_validation_2026-10-22'
OUT = ROOT / 'results/kwave_offaxis_diagnostic_2026-10-22'
TAGS = ('wide_pml20', 'wider_x256')


def trace_statistics(traces, dt):
    p = np.asarray(traces, dtype=float)
    if p.ndim != 2 or not p.shape[1] or not np.isfinite(p).all() or not np.isfinite(dt) or dt <= 0:
        raise ValueError('Finite sensor-by-time signals and positive dt required.')
    result = []
    t = np.arange(p.shape[1]) * dt
    for row in p:
        q = row**2 * dt; total = q.sum(); ip = int(np.abs(row).argmax())
        interval = None
        if total > 0:
            cumulative = np.cumsum(q) / total
            interval = [float(t[min(np.searchsorted(cumulative, f), len(t)-1)]) for f in (.05, .95)]
        result.append({'peak_abs_pa_assumed': float(abs(row[ip])), 'peak_signed_pa_assumed': float(row[ip]),
                       'peak_time_s': float(t[ip]), 'qp_pa2_s': float(total), 'qp90_interval_s': interval,
                       'last_5us_qp_fraction': float(q[t >= t[-1] - 5e-6].sum()/total) if total else None})
    return result


def band_peak(pressure, axes, z_min, z_max):
    iz = np.flatnonzero((axes[2] >= z_min - 1e-12) & (axes[2] < z_max - 1e-12))
    if not len(iz):
        raise ValueError('Empty depth band.')
    field = pressure[:, :, iz]
    i = np.unravel_index(field.ravel(order='F').argmax(), field.shape, order='F')
    xyz = [float(axes[0][i[0]]), float(axes[1][i[1]]), float(axes[2][iz[i[2]]])]
    boundary = any(j == 0 or j == n-1 for j, n in zip(i, field.shape))
    return {'peak_pa_assumed': float(field[i]), 'xyz_m': xyz, 'on_search_boundary': bool(boundary),
            'z_range_requested_m_half_open': [float(z_min), float(z_max)]}


def match_axes(reference, candidate):
    indices = []
    for old, new in zip(reference, candidate):
        index = np.abs(np.asarray(new)[:, None] - np.asarray(old)[None, :]).argmin(axis=0)
        if not np.allclose(np.asarray(new)[index], old, rtol=0, atol=1e-12):
            raise ValueError('Candidate does not contain reference coordinates.')
        indices.append(index)
    return indices


def read_volume(file, key):
    return np.asarray(file[key]).transpose(2, 1, 0)


def field_change(reference, candidate):
    a = reference.astype(float); b = candidate.astype(float)
    return {'raw_amplitude_relative_l2': float(np.linalg.norm(b-a)/np.linalg.norm(a)),
            'maximum_relative_change': float(abs(b.max()-a.max())/a.max())}


def criteria_pass(comparison, displacement, statistics):
    regions = ('all_old_physical_voxels', 'z0_to2', 'z2_to5', 'z5_plus')
    return (all(comparison[k]['raw_amplitude_relative_l2'] <= .05 and
                comparison[k]['maximum_relative_change'] <= .05 for k in regions)
            and displacement <= .13e-3+1e-12
            and bool(statistics)
            and all(abs(s['qp_relative_change_vs_wide65']) <= .05 for s in statistics))


def traces_in_label_order(raw, meta):
    return np.asarray(raw)[np.asarray(meta['trace_row']).astype(int)-1]


def audit_case(tag, old_report, old_axes, old_pressure, old_qp):
    report = json.loads((OUT / f'{tag}.json').read_text(encoding='utf-8-sig'))
    for key in ('input_mat', 'input_sha256', 'target_m', 'active_elements', 'element_area_m2',
                'waveform', 'source_model', 'source_z_offset_m', 'sound_speed_m_s'):
        assert report['source'][key] == old_report['source'][key], f'Changed source: {key}'
    for key in ('dx_m', 'cfl', 'source_amplitude_pa', 'density_kg_m3', 'source_offset_m'):
        assert report['config'][key] == old_report['config'][key], f'Changed control: {key}'
    assert report['Nt'] == old_report['Nt'] and report['dt_s'] == old_report['dt_s']
    with h5py.File(OUT / f'{tag}.mat', 'r') as f:
        axes = [np.asarray(f[key]).ravel() for key in ('x_m', 'y_m', 'z_m')]
        p = read_volume(f, 'p_peak_pa')
        assert np.array_equal(p, np.maximum(abs(read_volume(f, 'data/p_max_all')), abs(read_volume(f, 'data/p_min_all'))))
        raw = np.asarray(f['data/p']).T.astype(float)
        rms = np.asarray(f['data/p_rms']).ravel().astype(float)
        time = np.asarray(f['t_s']).ravel()
        assert raw.shape == (len(rms), report['Nt'])
        np.testing.assert_allclose(time, np.arange(report['Nt'])*report['dt_s'], rtol=1e-12, atol=0)
        direct = (raw**2).sum(axis=1)*report['dt_s']
        np.testing.assert_allclose(direct, report['trace_qp_pa2_s'], rtol=1e-12, atol=0)
        np.testing.assert_allclose(direct, np.asarray(f['trace_qp_pa2_s']).ravel(), rtol=1e-12, atol=0)
        rms_error = float(np.linalg.norm(direct-rms**2*report['Nt']*report['dt_s'])/np.linalg.norm(direct))
        assert report['integral_audit']['rms_consistency_passed']
        assert report['integral_audit']['rms_consistency_tolerance_relative'] == 1e-3
        assert rms_error <= 1e-3
        with h5py.File(report['raw_checkpoint'], 'r') as raw_file:
            np.testing.assert_array_equal(np.asarray(raw_file['data/p']).T, raw)
    meta = report['trace_meta']; traces = traces_in_label_order(raw, meta)
    statistics = trace_statistics(traces, report['dt_s'])
    labelled_rms_qp = rms[np.asarray(meta['trace_row']).astype(int)-1]**2*report['Nt']*report['dt_s']
    indices = match_axes(old_axes, axes); common = p[np.ix_(*indices)]
    comparison = {'all_old_physical_voxels': field_change(old_pressure, common)}
    for name, lo, hi in (('z0_to2', 1e-12, .002), ('z2_to5', .002, .005), ('z5_plus', .005, 1.)):
        z = (old_axes[2] >= lo-1e-13) & (old_axes[2] < hi-1e-13)
        comparison[name] = field_change(old_pressure[:, :, z], common[:, :, z])
    for j, (label, xyz) in enumerate(zip(meta['labels'], meta['actual_xyz_m'])):
        coord = np.asarray(xyz)
        loc = tuple(int(abs(a-value).argmin()) for a, value in zip(axes, coord))
        old_loc = tuple(int(abs(a-value).argmin()) for a, value in zip(old_axes, coord))
        np.testing.assert_allclose([a[i] for a, i in zip(axes, loc)], coord, atol=1e-12, rtol=0)
        np.testing.assert_allclose([a[i] for a, i in zip(old_axes, old_loc)], coord, atol=1e-12, rtol=0)
        assert abs(statistics[j]['peak_abs_pa_assumed']-float(p[loc])) <= 1e-6
        linear = np.ravel_multi_index(loc, p.shape, order='F')+1
        assert linear == meta['linear_indices'][j]
        s = statistics[j]; s.update({'tag': tag, 'label': label, 'xyz_m': xyz,
            'old_wide65_qp_pa2_s': float(old_qp[old_loc]),
            'qp_relative_change_vs_wide65': float(s['qp_pa2_s']/old_qp[old_loc]-1),
            'same_run_rms_qp_pa2_s': float(labelled_rms_qp[j]),
            'rms_qp_relative_change_vs_wide65': float(labelled_rms_qp[j]/old_qp[old_loc]-1),
            'old_wide65_peak_pa_assumed': float(old_pressure[old_loc]),
            'pressure_relative_change_vs_wide65': float(s['peak_abs_pa_assumed']/old_pressure[old_loc]-1)})
    bands = {name: band_peak(p, axes, lo, hi) for name, lo, hi in
             (('near_source_z0_to2', 1e-10, .002), ('shallow_z2_to5', .002, .005),
              ('deep_z5_plus', .005, 1.), ('original_z2_plus', .002, 1.))}
    old_peak = np.asarray(old_report['metrics']['forward_peak_xyz_m'])
    displacement = float(np.linalg.norm(np.asarray(bands['original_z2_plus']['xyz_m'])-old_peak))
    result = {'tag': tag, 'runtime_s': report['runtime_s'], 'pml_cells': report['pml_cells'],
              'domain_m': report['config']['domain_m'], 'source_controls_unchanged': True,
              'rms_direct_relative_l2': rms_error, 'pressure_comparison_vs_wide65': comparison,
              'peak_bands': bands, 'forward_peak_displacement_m': displacement,
              'trace_statistics': statistics,
              'within_proposed_criteria': criteria_pass(comparison, displacement, statistics)}
    return result, axes, p, time, traces, meta


def make_figures(cases):
    import matplotlib
    matplotlib.use('Agg')
    import matplotlib.pyplot as plt
    plt.rcParams.update({'font.size': 10, 'axes.spines.top': False, 'axes.spines.right': False})
    fig, axs = plt.subplots(2, 2, figsize=(11, 7), constrained_layout=True)
    chosen = ('offaxis_pos', 'near_main')
    for result, _, _, time, traces, meta in cases:
        for col, label in enumerate(chosen):
            j = meta['labels'].index(label); row = traces[j]
            axs[0, col].plot(time*1e6, row, lw=1, label=result['tag'])
            axs[1, col].plot(time*1e6, np.cumsum(row**2)*(time[1]-time[0])*1e6, label=result['tag'])
    for col, label in enumerate(chosen):
        axs[0, col].set(title=label, ylabel='Pressure (Pa, assumed source)', xlim=(0, 25))
        axs[1, col].set(xlabel='Time (us)', ylabel='Cumulative Qp (1e-6 Pa^2 s)', xlim=(0, 40))
        axs[0, col].legend(frameon=False); axs[1, col].legend(frameon=False)
    fig.suptitle('Boundary controls: sparse histories (no absorption or cure model)')
    fig.savefig(OUT/'offaxis_traces.png', dpi=200); fig.savefig(OUT/'offaxis_traces.pdf'); plt.close(fig)
    fig, axs = plt.subplots(1, 2, figsize=(11, 4), constrained_layout=True)
    for ax, (result, axes, p, _, _, _) in zip(axs, cases):
        iy = int(abs(axes[1]).argmin()); iz = np.flatnonzero((axes[2] > 0) & (axes[2] <= .006))
        image = ax.pcolormesh(axes[0]*1e3, axes[2][iz]*1e3, p[:, iy, iz].T,
                              shading='auto', vmin=0, vmax=2.3, rasterized=True)
        ax.plot([6.37, -6.37], [2.015, 2.015], 'wo', ms=4, fillstyle='none')
        ax.set(xlabel='x (mm)', ylabel='z (mm)', title=result['tag'])
        ax.invert_yaxis()
    fig.colorbar(image, ax=axs, label='max_t |p| (Pa, assumed source)')
    fig.suptitle('Shallow field: common color scale; time extrema, not a snapshot')
    fig.savefig(OUT/'offaxis_shallow.png', dpi=200); fig.savefig(OUT/'offaxis_shallow.pdf'); plt.close(fig)


def main():
    old_report = json.loads((OLD/'wide65.json').read_text(encoding='utf-8-sig'))
    with h5py.File(OLD/'wide65.mat', 'r') as f:
        old_axes = [np.asarray(f[key]).ravel() for key in ('x_m', 'y_m', 'z_m')]
        old_p = read_volume(f, 'p_peak_pa'); old_q = read_volume(f, 'qp_pa2_s')
    cases = [audit_case(tag, old_report, old_axes, old_p, old_q) for tag in TAGS]
    protected = json.loads((OUT/'preserved_hashes_before.json').read_text(encoding='utf-8'))
    for item in protected:
        with Path(item['path']).open('rb') as stream:
            assert hashlib.file_digest(stream, 'sha256').hexdigest() == item['sha256'], item['path']
    results = [case[0] for case in cases]
    summary = {'reference': 'wide65', 'cases': results, 'protected_files_unchanged': len(protected),
               'method': 'Independent read of XYZ extrema and label-mapped sparse histories; raw amplitudes and rectangular dt*sum(p^2).',
               'limitations': 'Assumed uncalibrated lossless sources. Small X-domain/PML increments, unchanged Y/Z and finite time; not complete convergence or mechanism identification. No heat or cure prediction.'}
    (OUT/'analysis.json').write_text(json.dumps(summary, indent=2), encoding='utf-8')
    rows = []
    for result in results:
        for s in result['trace_statistics']:
            a, b = s['qp90_interval_s'] or (None, None)
            rows.append({**{k: s[k] for k in ('tag','label','peak_abs_pa_assumed','qp_pa2_s',
                         'qp_relative_change_vs_wide65','rms_qp_relative_change_vs_wide65',
                         'pressure_relative_change_vs_wide65','last_5us_qp_fraction')},
                         'peak_time_us': s['peak_time_s']*1e6,
                         'qp05_time_us': a*1e6 if a is not None else None,
                         'qp95_time_us': b*1e6 if b is not None else None})
    with (OUT/'trace_summary.csv').open('w', newline='', encoding='utf-8') as f:
        writer = csv.DictWriter(f, fieldnames=list(rows[0])); writer.writeheader(); writer.writerows(rows)
    make_figures(cases)
    print(json.dumps({'protected_files_unchanged': len(protected),
                      'case_criteria': {r['tag']: r['within_proposed_criteria'] for r in results}}, indent=2))


if __name__ == '__main__':
    main()
