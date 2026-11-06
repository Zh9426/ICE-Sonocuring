"""Read-only input audit and cross-grid pressure comparison; no cure model."""
from pathlib import Path
import csv
import hashlib
import json
import h5py
import numpy as np
from scipy.interpolate import RegularGridInterpolator
from scipy.io import loadmat
from analyze_kwave_offaxis import read_volume, band_peak, trace_statistics, traces_in_label_order

ROOT = Path(__file__).resolve().parent
OUT = ROOT/'results/kwave_widegrid_2026-10-24'
OLD = ROOT/'results/kwave_singlepoint_validation_2026-10-22'
APERTURE = ROOT/'results/kwave_aperture_control_2026-10-23'
BANDS = [('all_physical', -1., 1.), ('near_source', 1e-10, .002),
         ('shallow', .002, .005), ('deep', .005, 1.), ('z2_plus', .002, 1.)]


def check_trace_rows(linear_indices, trace_row):
    linear = np.asarray(linear_indices)
    assert len(np.unique(linear)) == len(linear)
    np.testing.assert_array_equal(np.argsort(np.argsort(linear))+1, trace_row)


def common_lattice(coarse_axes, fine_axes):
    coarse_indices, fine_indices = [], []
    for a, b in zip(coarse_axes, fine_axes):
        a, b = np.asarray(a), np.asarray(b)
        near = abs(b[:, None]-a[None, :]).argmin(axis=0)
        use = np.flatnonzero(abs(b[near]-a) < 1e-12)
        if not len(use):
            raise ValueError('No common physical lattice.')
        coarse_indices.append(use)
        fine_indices.append(near[use])
    return coarse_indices, fine_indices


def interpolated_change(coarse, ca, fine, fa):
    for a, b in zip(ca, fa):
        if a[0] < b[0]-1e-12 or a[-1] > b[-1]+1e-12:
            raise ValueError('Fine grid must cover all requested coarse coordinates.')
    interp = RegularGridInterpolator(fa, fine, bounds_error=True)
    denominator = difference = 0.
    maximum = -np.inf
    # Depth slabs avoid allocating a full 18M-by-3 interpolation query array.
    for z in ca[2]:
        x, y = np.meshgrid(ca[0], ca[1], indexing='ij')
        points = np.column_stack((x.ravel(), y.ravel(), np.full(x.size, z)))
        value = interp(points).reshape(x.shape)
        iz = int(np.argmin(abs(ca[2]-z)))
        reference = np.asarray(coarse[:, :, iz], dtype=float)
        denominator += float(np.sum(reference**2))
        difference += float(np.sum((value-reference)**2))
        maximum = max(maximum, float(value.max()))
    if denominator <= 0 or coarse.max() <= 0:
        raise ValueError('Nonzero reference pressure required.')
    return {'raw_amplitude_relative_l2': float(np.sqrt(difference/denominator)),
            'maximum_relative_change': float(abs(maximum-coarse.max())/coarse.max()),
            'voxels': int(coarse.size), 'evaluation': 'linear fine-to-coarse interpolation, no amplitude normalization'}


def direct_change(a, b):
    return {'raw_amplitude_relative_l2': float(np.linalg.norm(b.astype(float)-a)/np.linalg.norm(a.astype(float))),
            'maximum_relative_change': float(abs(b.max()-a.max())/a.max()),
            'voxels': int(a.size), 'evaluation': 'exact shared physical lattice, no interpolation'}


def read_fine(kind):
    report = json.loads((OUT/f'fine_{kind}.json').read_text(encoding='utf-8-sig'))
    with h5py.File(OUT/f'fine_{kind}.mat') as f:
        axes = [np.asarray(f[k]).ravel() for k in ('x_m', 'y_m', 'z_m')]
        p = read_volume(f, 'p_peak_pa')
        assert p.shape == tuple(report['grid_size']) and np.isfinite(p).all()
        np.testing.assert_array_equal(p, np.maximum(abs(read_volume(f, 'data/p_max_all')), abs(read_volume(f, 'data/p_min_all'))))
        raw = np.asarray(f['data/p']).T.astype(float)
        waves = np.asarray(f['element_signals']).T.astype(float)
        time = np.asarray(f['t_s']).ravel()
        rms = np.asarray(f['data/p_rms']).ravel().astype(float)
        np.testing.assert_allclose(time, np.arange(report['Nt'])*report['dt_s'], atol=0, rtol=1e-12)
        assert raw.shape == (len(rms), report['Nt'])
        direct = np.sum(raw**2, axis=1)*report['dt_s']
        np.testing.assert_allclose(direct, report['trace_qp_pa2_s'], atol=0, rtol=1e-12)
        np.testing.assert_allclose(direct, np.asarray(f['trace_qp_pa2_s']).ravel(), atol=0, rtol=1e-12)
    with h5py.File(report['raw_checkpoint']) as f:
        np.testing.assert_array_equal(np.asarray(f['data/p']).T, raw)
        np.testing.assert_array_equal(np.asarray(f['element_signals']).T, waves)
        for k, a in zip(('x_m', 'y_m', 'z_m'), axes):
            np.testing.assert_array_equal(np.asarray(f[k]).ravel(), a)
    rms_error = float(np.linalg.norm(direct-rms**2*report['Nt']*report['dt_s'])/np.linalg.norm(direct))
    assert rms_error <= 1e-3 and report['integral_audit']['rms_consistency_passed']
    c = report['config']
    np.testing.assert_allclose([a[1]-a[0] for a in axes], c['dx_m'], atol=1e-15, rtol=0)
    assert report['grid_size'] == [300, 200, 600] and report['pml_cells'] == 20
    assert time[-1] >= 40e-6 and time[-1] < 40e-6+report['dt_s']
    assert report['hardware_run'] is False and report['physical_validation'] == 'unknown'
    budget = float(report['source']['element_area_m2']*report['dt_s']*np.sum(waves**2))
    target_budget = report['source']['widegrid_budget']['reference_budget_pa2_s_m2']
    assert abs(budget/target_budget-1) < 1e-6
    np.testing.assert_allclose(budget, report['source']['widegrid_budget']['actual_budget_pa2_s_m2'], atol=0, rtol=1e-12)
    meta = report['trace_meta']
    assert len(set(meta['labels'])) == len(meta['linear_indices']) == len(meta['labels']) == raw.shape[0]
    check_trace_rows(meta['linear_indices'], meta['trace_row'])
    traces = traces_in_label_order(raw, meta)
    stats = trace_statistics(traces, report['dt_s'])
    assert np.max(abs(np.asarray(meta['requested_xyz_m'])-meta['actual_xyz_m'])) <= c['dx_m']/2+1e-12
    for xyz, linear, stat in zip(meta['actual_xyz_m'], meta['linear_indices'], stats):
        loc = tuple(int(abs(a-v).argmin()) for a, v in zip(axes, xyz))
        np.testing.assert_allclose([a[i] for a, i in zip(axes, loc)], xyz, atol=1e-12, rtol=0)
        assert np.ravel_multi_index(loc, p.shape, order='F')+1 == linear
        assert abs(p[loc]-stat['peak_abs_pa_assumed']) < 1e-6
    return report, axes, p, stats, budget, rms_error, waves


def compare_case(kind):
    r, axes, p, stats, budget, rms_error, waves = read_fine(kind)
    coarse_dir, tag = (OLD, 'wide65') if kind == 'even32' else (APERTURE, 'full64_matched')
    old = json.loads((coarse_dir/f'{tag}.json').read_text(encoding='utf-8-sig'))
    assert r['source']['input_sha256'] == old['source']['input_sha256']
    for key in ('domain_m', 'pml_m', 'source_offset_m', 'cfl', 'density_kg_m3', 'source_amplitude_pa'):
        assert r['config'][key] == old['config'][key], key
    assert r['source']['active_elements'] == old['source']['active_elements']
    for key in ('target_m', 'sound_speed_m_s', 'source_model', 'element_area_m2',
                'elevation_focus_m_metadata_only', 'source_z_offset_m'):
        assert r['source'][key] == old['source'][key], key
    for key in ('half_cycles', 'active_fraction', 'frequency_hz', 'nominal_drive_duration_s',
                'assumed_filter_group_delay_s', 'acoustic_duration_s', 'waveform_model'):
        assert r['source']['waveform'][key] == old['source']['waveform'][key], key
    with h5py.File(coarse_dir/f'{tag}.mat') as f:
        ca = [np.asarray(f[k]).ravel() for k in ('x_m', 'y_m', 'z_m')]
        cp = read_volume(f, 'p_peak_pa')
        cw = np.asarray(f['element_signals']).T.astype(float)
        if kind == 'even32':
            cq = read_volume(f, 'qp_pa2_s')
        else:
            coarse_raw = np.asarray(f['data/p']).T.astype(float)
    coarse_budget = float(old['source']['element_area_m2']*old['dt_s']*np.sum(cw**2))
    assert abs(budget/coarse_budget-1) < 1e-6
    saved = loadmat(r['config']['input_mat'], simplify_cells=True)
    with Path(r['config']['input_mat']).open('rb') as stream:
        assert hashlib.file_digest(stream, 'sha256').hexdigest() == r['source']['input_sha256']
    tr = saved['Trans']; speed = float(saved['Resource']['Parameters']['speedOfSound'])
    assert tr['units'] == 'wavelengths'
    np.testing.assert_allclose(speed, r['source']['sound_speed_m_s'], rtol=0, atol=0)
    positions = np.asarray(tr['ElementPos'])[:, :3]*speed/(float(tr['frequency'])*1e6)
    expected_area = float(tr['elementWidth'])*speed/(float(tr['frequency'])*1e6)*float(tr['elevationApertureMm'])*1e-3
    np.testing.assert_allclose(r['source']['element_area_m2'], expected_area, rtol=1e-12, atol=0)
    if kind == 'even32':
        tx = saved['TX'][r['source']['tx_index']-1]
        delays = np.asarray(tx['Delay'])/(float(tr['frequency'])*1e6)
    else:
        distance = np.linalg.norm(positions-np.asarray(r['source']['target_m']), axis=1)
        delays = (distance.max()-distance)/speed
    np.testing.assert_allclose(r['source']['aperture_control']['delay_s'], delays, rtol=0, atol=1e-12)
    active = np.asarray(r['source']['active_elements'])-1
    np.testing.assert_allclose(np.ptp(delays[active]+np.linalg.norm(positions[active]-r['source']['target_m'], axis=1)/speed), 0., atol=1e-12, rtol=0)
    temporal_ci, temporal_fi = common_lattice([np.arange(cw.shape[1])*old['dt_s']],
                                             [np.arange(waves.shape[1])*r['dt_s']])
    assert len(temporal_ci[0]) > 100
    fgain = r['source']['aperture_control']['signal_scale']*r['source']['widegrid_budget']['signal_scale_across_grids']
    cgain = 1. if kind == 'even32' else old['source']['aperture_control']['signal_scale']
    # The gains are prescribed source-budget controls, not fitted field normalization.
    waveform_error = float(np.max(abs(waves[:, temporal_fi[0]]/fgain-cw[:, temporal_ci[0]]/cgain)))
    assert waveform_error < 3e-6, 'Changed delayed element waveform at common physical time samples.'
    ci, fi = common_lattice(ca, axes)
    cs, fs = cp[np.ix_(*ci)], p[np.ix_(*fi)]
    shared_axes = [a[i] for a, i in zip(ca, ci)]
    comparisons, peaks = {}, {}
    for name, lo, hi in BANDS:
        cz = np.flatnonzero((ca[2] >= lo-1e-12) & (ca[2] < hi-1e-12))
        sz = np.flatnonzero((shared_axes[2] >= lo-1e-12) & (shared_axes[2] < hi-1e-12))
        linear = interpolated_change(cp[:, :, cz], [ca[0], ca[1], ca[2][cz]], p, axes)
        shared = direct_change(cs[:, :, sz], fs[:, :, sz])
        peaks[name] = {'coarse': band_peak(cp, ca, lo, hi), 'fine': band_peak(p, axes, lo, hi)}
        shift = float(np.linalg.norm(np.asarray(peaks[name]['fine']['xyz_m'])-peaks[name]['coarse']['xyz_m']))
        symmetry_shift = float(np.linalg.norm(abs(np.asarray(peaks[name]['fine']['xyz_m']))-abs(np.asarray(peaks[name]['coarse']['xyz_m']))))
        comparisons[name] = {'linear': linear, 'shared': shared, 'native_peak_displacement_m': shift,
                             'mirror_equivalent_argmax_displacement_m_diagnostic_only': symmetry_shift,
                             'argmax_caveat': 'Single voxel argmax may switch nearly equal mirror or repeated source lobes; inspect signed positions and field differences. Mirror-equivalent distance is diagnostic, not physical migration.',
                             'field_5pct_both_evaluations': bool(all(v[k] <= .05 for v in (linear, shared) for k in ('raw_amplitude_relative_l2', 'maximum_relative_change'))),
                             'native_peak_013mm': bool(shift <= .13e-3+1e-12)}
    np.testing.assert_allclose(peaks['z2_plus']['fine']['xyz_m'], r['metrics']['forward_peak_xyz_m'], rtol=0, atol=1e-12)
    np.testing.assert_allclose(peaks['z2_plus']['fine']['peak_pa_assumed'], r['metrics']['forward_peak_pa_assumed'], rtol=1e-12, atol=0)
    coarse_aperture_analysis = json.loads((APERTURE/'analysis.json').read_text())
    by_label = {v['label']: v for v in coarse_aperture_analysis['fixed_trace_comparison']}
    rows = []
    for label, xyz, stat in zip(r['trace_meta']['labels'], r['trace_meta']['actual_xyz_m'], stats):
        if kind == 'even32':
            original_xyz = np.asarray(by_label[label]['xyz_m'])
            loc = tuple(int(abs(a-v).argmin()) for a, v in zip(ca, original_xyz))
            oq = float(cq[loc]); op = float(cp[loc])
        else:
            original_xyz = np.asarray(old['trace_meta']['actual_xyz_m'][old['trace_meta']['labels'].index(label)])
            row = old['trace_meta']['trace_row'][old['trace_meta']['labels'].index(label)]-1
            oq = float(np.sum(coarse_raw[row]**2)*old['dt_s'])
            op = float(abs(coarse_raw[row]).max())
        rows.append({'kind': kind, 'label': label, 'coarse_xyz_m': original_xyz.tolist(), 'fine_xyz_m': xyz,
                     'sampling_displacement_m': float(np.linalg.norm(np.asarray(xyz)-original_xyz)),
                     'coarse_peak_pa_assumed': op, 'fine_peak_pa_assumed': stat['peak_abs_pa_assumed'],
                     'coarse_qp_pa2_s': oq, 'fine_qp_pa2_s_direct': stat['qp_pa2_s'],
                     'qp_relative_change_at_nearest_voxels': stat['qp_pa2_s']/oq-1,
                     'last_5us_qp_fraction': stat['last_5us_qp_fraction'],
                     'coarse_qp_method': 'GPU RMS' if kind == 'even32' else 'double direct',
                     'coordinate_caveat': 'Nearest voxels differ across grids; not an exact fixed-point Qp convergence test.'})
    by = {v['label']: v for v in rows}
    result = {'kind': kind, 'runtime_s': r['runtime_s'], 'budget_pa2_s_m2': budget,
              'budget_ratio_vs_coarse': budget/coarse_budget, 'rms_direct_relative_l2': rms_error,
              'normalized_source_waveform_max_abs_difference_pa': waveform_error,
              'comparison': comparisons, 'native_peaks': peaks, 'trace_comparison': rows,
              'offaxis_over_near_main_qp': by['offaxis_pos']['fine_qp_pa2_s_direct']/by['near_main']['fine_qp_pa2_s_direct'],
              'target_over_near_main_qp': by['target']['fine_qp_pa2_s_direct']/by['near_main']['fine_qp_pa2_s_direct']}
    return result, (ca, cp, axes, p)


def check_hashes():
    protected = json.loads((OUT/'preserved_hashes_before.json').read_text())
    for item in protected:
        with Path(item['path']).open('rb') as stream:
            assert hashlib.file_digest(stream, 'sha256').hexdigest() == item['sha256'], item['path']
    return len(protected)


def main():
    results, fields = [], []
    for kind in ('even32', 'full64_matched'):
        result, field = compare_case(kind)
        results.append(result); fields.append(field)
    unchanged = check_hashes()
    result = {'cases': results, 'protected_files_unchanged': unchanged,
              'pressure_comparison': 'Raw amplitudes; fine-to-coarse linear interpolation and separate exact 260um common lattice.',
              'numerical_convergence': 'not_established', 'physical_validation': 'unknown', 'hardware_run': False,
              'limitations': 'Two grids only, finite domain/PML/time, uncalibrated flat source and lossless medium; source surface rasterization and waveform time sampling vary with dx. Nearest-point Qp includes coordinate mismatch. No lens, absorption, heat or SonoInk cure model.'}
    (OUT/'analysis.json').write_text(json.dumps(result, indent=2), encoding='utf-8')
    rows = [row for c in results for row in c['trace_comparison']]
    with (OUT/'trace_comparison.csv').open('w', newline='', encoding='utf-8') as f:
        w = csv.DictWriter(f, fieldnames=list(rows[0])); w.writeheader(); w.writerows(rows)
    make_figure(fields)
    print(json.dumps({c['kind']: {'ratios': [c['offaxis_over_near_main_qp'], c['target_over_near_main_qp']],
                                 'z2_plus': c['comparison']['z2_plus'], 'deep_peak': c['native_peaks']['deep']}
                      for c in results}, indent=2))


def make_figure(fields):
    import matplotlib
    matplotlib.use('Agg')
    import matplotlib.pyplot as plt
    fig, axs = plt.subplots(2, 2, figsize=(11, 8), constrained_layout=True)
    maximum = max(max(float(cp.max()), float(p.max())) for ca, cp, fa, p in fields)
    for row, ((ca, cp, fa, p), kind) in enumerate(zip(fields, ('even32', 'full64 matched B'))):
        for col, (axes, pressure, dx) in enumerate(((ca, cp, 65), (fa, p, 52))):
            iy = int(abs(axes[1]).argmin()); iz = np.flatnonzero((axes[2] > 0) & (axes[2] < .006))
            ax = axs[row, col]
            im = ax.pcolormesh(axes[0]*1e3, axes[2][iz]*1e3, pressure[:, iy, iz].T,
                               shading='auto', vmin=0, vmax=maximum, rasterized=True)
            ax.plot([6.37, -6.37], [2.015, 2.015], 'wo', ms=4, fillstyle='none')
            ax.set(xlabel='x (mm)', ylabel='z (mm)', title=f'{kind}, dx={dx} um'); ax.invert_yaxis()
    fig.colorbar(im, ax=axs, label='max_t |p| (Pa, assumed source)')
    fig.suptitle('Wide-domain grid check: matched source proxy, no lens or cure')
    fig.savefig(OUT/'widegrid_shallow.png', dpi=180); fig.savefig(OUT/'widegrid_shallow.pdf'); plt.close(fig)
    fig, axs = plt.subplots(1, 2, figsize=(11, 4), constrained_layout=True)
    for ax, (ca, cp, fa, p), kind in zip(axs, fields, ('even32', 'full64 matched B')):
        for axes, pressure, dx in ((ca, cp, 65), (fa, p, 52)):
            ix = int(abs(axes[0]).argmin()); iy = int(abs(axes[1]).argmin())
            ax.plot(axes[2]*1e3, pressure[ix, iy, :], label=f'{dx} um')
        ax.axvline(20, ls='--', color='grey', lw=1)
        ax.set(xlabel='z (mm)', ylabel='On-axis max_t |p| (Pa, assumed)', xlim=(2, 30), title=kind); ax.legend()
    fig.savefig(OUT/'widegrid_axial.png', dpi=180); fig.savefig(OUT/'widegrid_axial.pdf'); plt.close(fig)


if __name__ == '__main__':
    main()
