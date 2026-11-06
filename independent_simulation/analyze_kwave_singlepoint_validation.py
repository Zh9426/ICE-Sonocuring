"""Independent MAT audit, physical-ROI comparisons, and standalone figures.

Qp is a pressure-squared-time proxy under an assumed source, never deposited
energy or a material-cure prediction. Run after the five actual solves finish.
"""
from pathlib import Path
import csv
import hashlib
import json

import h5py
import numpy as np
from scipy.interpolate import RegularGridInterpolator


ROOT = Path(__file__).resolve().parent
OUT = ROOT / 'results' / 'kwave_singlepoint_validation_2026-10-22'
TAGS = ('baseline65', 'pml65', 'wide65', 'long65', 'fine52')


def read_xyz(file, key):
    return np.asarray(file[key]).transpose(2, 1, 0)


def millimetres_or_none(value):
    return None if value is None else value * 1e3


def field_difference(reference, candidate):
    denominator = np.linalg.norm(reference)
    if denominator <= 0:
        raise ValueError('A nonzero reference field is required.')
    relative_l2 = float(np.linalg.norm(candidate - reference) / denominator)
    maximum_change = float(abs(candidate.max() - reference.max()) / reference.max())
    return {'relative_l2': relative_l2,
            'relative_maximum_change': maximum_change,
            'within_proposed_5percent': relative_l2 <= .05 and maximum_change <= .05}


def common_grid():
    axes = [np.arange(-4, 4 + 1e-9, .13) * 1e-3,
            np.arange(-2, 2 + 1e-9, .13) * 1e-3,
            np.arange(2, 29 + 1e-9, .13) * 1e-3]
    points = np.stack(np.meshgrid(*axes, indexing='ij'), axis=-1)
    return axes, points


def assert_source_controls(reports):
    """Refuse cross-case comparisons if a supposedly fixed source changed."""
    reference = reports['baseline65']
    for tag, report in reports.items():
        for key in ('input_mat', 'density_kg_m3', 'source_amplitude_pa', 'source_offset_m', 'cfl', 'provenance'):
            assert report['config'][key] == reference['config'][key], f'{tag}: changed config {key}'
        for key in ('input_sha256', 'target_m', 'active_elements', 'num_elements', 'tx_index',
                    'source_model', 'element_area_m2', 'source_z_offset_m', 'sound_speed_m_s', 'waveform'):
            assert report['source'][key] == reference['source'][key], f'{tag}: changed source {key}'


def observed_box_fraction(qp, axes, target_bounds, material_bounds):
    """Postprocess one unchanged field over different assumed material boxes."""
    target_bounds = np.asarray(target_bounds)
    material_bounds = np.asarray(material_bounds)
    indices = [np.flatnonzero((axis >= bound[0] - 1e-12) & (axis <= bound[1] + 1e-12))
               for axis, bound in zip(axes, material_bounds)]
    if any(len(index) == 0 for index in indices):
        raise ValueError('Empty observed material box.')
    grids = np.meshgrid(*[axis[index] for axis, index in zip(axes, indices)], indexing='ij')
    inside = np.logical_and.reduce([(grid >= bound[0] - 1e-12) & (grid <= bound[1] + 1e-12)
                                    for grid, bound in zip(grids, target_bounds)])
    q = qp[np.ix_(*indices)]
    volume = float(np.prod([np.median(np.diff(axis)) for axis in axes]))
    if not inside.any() or q.sum() <= 0:
        raise ValueError('Nonzero observed material and nonempty target required.')
    clipped = any(bound[0] < axis[0] - np.median(np.diff(axis)) / 2 - 1e-12 or
                  bound[1] > axis[-1] + np.median(np.diff(axis)) / 2 + 1e-12
                  for axis, bound in zip(axes, material_bounds))
    return {'material_bounds_m_assumed': material_bounds.tolist(),
            'target_qp_fraction': float(q[inside].sum() / q.sum()),
            'target_qp_integral_pa2_s_m3': float(q[inside].sum() * volume),
            'material_qp_integral_pa2_s_m3': float(q.sum() * volume),
            'material_voxels': int(q.size), 'material_clipped': bool(clipped)}


def historic_trace_comparison():
    old_path = ROOT / 'results/kwave_oddeven/even32_focus20mm_dx65um'
    old = json.loads(old_path.with_suffix('.json').read_text(encoding='utf-8-sig'))
    new = json.loads((OUT / 'baseline65.json').read_text(encoding='utf-8-sig'))
    with h5py.File(old_path.with_suffix('.mat'), 'r') as file:
        traces = np.asarray(file['data/p']).T.astype(float)
        coordinates = np.asarray(file['sensor_coordinates_m']).T
    with h5py.File(OUT / 'baseline65.mat', 'r') as file:
        actual = np.asarray(file['sample_qp_pa2_s']).ravel()
    assert traces.shape == (4, old['Nt'])
    np.testing.assert_allclose(coordinates, new['source']['sensor_coordinates_m'], atol=1e-14, rtol=0)
    expected = (traces**2).sum(axis=1) * old['dt_s']
    relative = (actual - expected) / expected
    result = {'sparse_coordinates_m': coordinates.tolist(), 'old_direct_qp_pa2_s': expected.tolist(),
              'new_full_rms_qp_pa2_s': actual.tolist(), 'relative_change': relative.tolist(),
              'max_absolute_relative_change': float(abs(relative).max()),
              'old_end_s': (old['Nt'] - 1) * old['dt_s'], 'new_end_s': new['record_window_end_s'],
              'interpretation': 'Same source/grid/coordinates; different recording windows and single-precision accumulation. Not an identical-window RMS identity test.'}
    (OUT / 'historic_sparse_qp.json').write_text(json.dumps(result, indent=2), encoding='utf-8')
    return result


def independent_exposure(qp, pressure, axes, exposure):
    bounds = np.asarray(exposure['material_bounds_m_assumed'])
    indices = [np.flatnonzero((axis >= bound[0] - 1e-12) & (axis <= bound[1] + 1e-12))
               for axis, bound in zip(axes, bounds)]
    coordinates = np.meshgrid(*[axis[index] for axis, index in zip(axes, indices)], indexing='ij')
    q = qp[np.ix_(*indices)]
    p = pressure[np.ix_(*indices)]
    target = exposure['target_m']
    halfwidth = exposure['target_halfwidth_m_assumed']
    inside = np.logical_and.reduce([abs(value - centre) <= width + 1e-12
                                    for value, centre, width in zip(coordinates, target, halfwidth)])
    volume = float(np.prod([np.median(np.diff(axis)) for axis in axes]))
    fraction = float(q[inside].sum() / q.sum())
    outside_ratio = float(q[~inside].max() / q[inside].max())
    pressure_ratio = float(p[~inside].max() / p[inside].max())
    assert int(inside.sum()) == exposure['target_voxels']
    assert q.size == exposure['material_voxels']
    assert np.isclose(volume * q[inside].sum(), exposure['target_qp_integral_pa2_s_m3'], rtol=1e-10, atol=0)
    assert np.isclose(fraction, exposure['target_qp_fraction_of_material'], rtol=1e-10, atol=0)
    assert np.isclose(outside_ratio, exposure['outside_over_target_max_qp'], rtol=1e-10, atol=0)
    assert np.isclose(pressure_ratio, exposure['outside_over_target_max_pressure'], rtol=1e-10, atol=0)
    assert np.isclose(sum(exposure[key] for key in
                          ('target_qp_fraction_of_material', 'prefocal_qp_fraction_of_material',
                           'postfocal_qp_fraction_of_material', 'lateral_qp_fraction_of_material')), 1, atol=1e-10)
    return {'target_fraction': fraction, 'outside_over_target_max_qp': outside_ratio,
            'target_voxels': int(inside.sum()), 'material_voxels': int(q.size)}


def load_and_audit(tag):
    report = json.loads((OUT / f'{tag}.json').read_text(encoding='utf-8-sig'))
    with h5py.File(OUT / f'{tag}.mat', 'r') as file:
        axes = [np.asarray(file[key]).ravel() for key in ('x_m', 'y_m', 'z_m')]
        pressure = read_xyz(file, 'p_peak_pa')
        qp = read_xyz(file, 'qp_pa2_s')
        positive = read_xyz(file, 'data/p_max_all')
        negative = read_xyz(file, 'data/p_min_all')
        assert np.array_equal(pressure, np.maximum(abs(positive), abs(negative)))
        rms = np.asarray(file['data/p_rms']).ravel().reshape(pressure.shape, order='F')
        reconstructed = rms.astype(float)**2 * (report['Nt'] * report['dt_s'])
        assert np.allclose(qp, reconstructed, rtol=5e-13, atol=1e-25)
        indices = np.asarray(file['sample_indices']).ravel().astype(int) - 1
        samples = np.asarray(file['sample_qp_pa2_s']).ravel()
        np.testing.assert_allclose(qp.ravel(order='F')[indices], samples, rtol=1e-12)
        time = np.asarray(file['t_s']).ravel()
        assert len(time) == report['Nt'] and time[0] == 0
        assert np.isclose(time[-1], report['record_window_end_s'], atol=1e-15)
    assert pressure.shape == tuple(report['grid_size']) == tuple(map(len, axes))
    assert np.isfinite(qp).all() and np.all(qp >= 0)
    assert np.isfinite(pressure).all() and np.all(pressure >= 0)
    assert report['record_start_index'] == 1 and time[-1] >= 40e-6
    forward = np.flatnonzero(axes[2] >= .002)
    forward_pressure = pressure[:, :, forward]
    peak_index = list(np.unravel_index(np.argmax(forward_pressure.ravel(order='F')), forward_pressure.shape, order='F'))
    peak_index[2] = forward[peak_index[2]]
    xyz = np.array([axis[index] for axis, index in zip(axes, peak_index)])
    np.testing.assert_allclose(xyz, report['metrics']['forward_peak_xyz_m'], atol=1e-12, rtol=0)
    assert np.isclose(pressure[tuple(peak_index)], report['metrics']['forward_peak_pa_assumed'], rtol=1e-12, atol=0)
    assert hashlib.sha256(Path(report['source']['input_mat']).read_bytes()).hexdigest() == report['source']['input_sha256']
    assert report['source']['active_center_arrival_spread_s'] < 1e-12
    assert report['source']['active_elements'] == list(range(2, 65, 2))
    exposure_audits = [independent_exposure(qp, pressure, axes, item) for item in report['exposure']]
    forward_integral = float(qp[:, :, forward].sum() * report['dx_m']**3)
    assert np.isclose(forward_integral, report['observed_forward_qp_integral_pa2_s_m3'], rtol=1e-10, atol=0)
    return report, axes, pressure, qp, {'tag': tag, 'grid': list(pressure.shape),
            'extrema_consistent': True, 'rms_integral_consistent': True,
            'time_window_checked': True, 'independent_peak_xyz_m': xyz.tolist(),
            'exposure_audits': exposure_audits, 'saved_input_hash_matches': True}


def make_wide_figure(axes, pressure, qp, report):
    """Show the expanded observed domain, including peaks outside common ROI."""
    import matplotlib
    matplotlib.use('Agg')
    import matplotlib.pyplot as plt
    iy = int(np.argmin(abs(axes[1])))
    forward = np.flatnonzero(axes[2] >= .002)
    fig, panels = plt.subplots(1, 2, figsize=(12, 6), constrained_layout=True)
    peak = report['metrics']['forward_peak_xyz_m']
    for panel, field, factor, title in ((panels[0], pressure, 20, 'Pressure max over time'),
                                       (panels[1], qp, 10, 'Qp pressure-squared-time proxy')):
        values = field[:, iy, :][:, forward]
        display = factor * np.log10(np.maximum(values / values.max(), 1e-8))
        image = panel.pcolormesh(axes[0] * 1e3, axes[2][forward] * 1e3, display.T,
                                cmap='inferno', vmin=-35, vmax=0, shading='auto')
        panel.plot(peak[0] * 1e3, peak[2] * 1e3, 'co', ms=7, fillstyle='none', label='pressure forward maximum')
        panel.plot(0, 20, 'c+', ms=10, label='set target')
        panel.add_patch(plt.Rectangle((-4, 10), 8, 18, fill=False, edgecolor='cyan', ls='--', label='assumed material box'))
        panel.add_patch(plt.Rectangle((-.5, 19.5), 1, 1, fill=False, edgecolor='white', lw=1))
        panel.axvline(-5.2, color='grey', ls=':', label='old x extent')
        panel.axvline(5.135, color='grey', ls=':')
        panel.set(xlabel='x (mm)', ylabel='z (mm)', title=f'Expanded domain: {title}, y=0 mm')
        panel.invert_yaxis()
        panel.legend(fontsize=7, loc='lower center')
        fig.colorbar(image, ax=panel, label='dB relative to this displayed slice maximum')
    fig.suptitle('Stronger off-axis peak pressure outside old lateral extent; z >= 2 mm search is still truncated', fontsize=11)
    fig.savefig(OUT / 'wide_field.png', dpi=150)
    plt.close(fig)


def write_csv(name, rows):
    with (OUT / name).open('w', newline='', encoding='utf-8') as file:
        writer = csv.DictWriter(file, fieldnames=list(rows[0]))
        writer.writeheader()
        writer.writerows(rows)


def make_figures(reports, fields, common_axes, curves, comparisons):
    import matplotlib
    matplotlib.use('Agg')
    import matplotlib.pyplot as plt
    plt.rcParams.update({'font.size': 10, 'figure.dpi': 150})
    xyz, y, z = common_axes
    centre_y = int(np.argmin(abs(y)))
    fig, panels = plt.subplots(2, 2, figsize=(12, 8), constrained_layout=True)
    for panel, name, multiplier, title in (
        (panels[0, 0], 'p', 20, 'Pressure max over time (baseline65)'),
        (panels[0, 1], 'qp', 10, 'Pressure-squared-time Qp (baseline65)')):
        values = fields[name][:, centre_y, :]
        display = multiplier * np.log10(np.maximum(values / fields[name].max(), 1e-8))
        image = panel.pcolormesh(xyz * 1e3, z * 1e3, display.T, cmap='inferno', vmin=-35, vmax=0, shading='auto')
        panel.plot(0, 20, 'c+', ms=10, label='set target')
        panel.add_patch(plt.Rectangle((-.5, 19.5), 1, 1, fill=False, edgecolor='cyan', lw=1))
        panel.set(xlabel='x (mm)', ylabel='z (mm)', title=f'{title}, y={y[centre_y] * 1e3:.2f} mm')
        panel.invert_yaxis()
        panel.legend(loc='upper right', fontsize=8)
        fig.colorbar(image, ax=panel, label='dB relative to volume maximum')
    for tag in TAGS:
        row = curves[tag]
        panels[1, 0].plot(row['z_m'] * 1e3, row['pressure'] / row['pressure'].max(), label=tag)
        panels[1, 1].plot(row['z_m'] * 1e3, row['qp'] / row['qp'].max(), label=tag)
    reference = np.genfromtxt(OUT / 'onaxis_reference.csv', delimiter=',', names=True)
    panels[1, 0].plot(reference['z_m'] * 1e3, reference['normalized_reference_8x64'], 'k--', lw=1, label='monochromatic reference')
    for panel, title in ((panels[1, 0], 'On-axis pressure shape (each curve normalized)'),
                         (panels[1, 1], 'On-axis Qp shape (each curve normalized)')):
        panel.axvline(20, color='grey', ls=':')
        panel.set(xlabel='z (mm)', ylabel='relative amplitude', title=title, xlim=(2, 29), ylim=(0, 1.07))
        panel.grid(alpha=.25)
        panel.legend(fontsize=7, ncol=2)
    fig.suptitle('Assumed homogeneous lossless fluid, flat even32 source, no elevation lens or calibration', fontsize=11)
    fig.savefig(OUT / 'field_exposure.png')
    plt.close(fig)

    fig, panels = plt.subplots(1, 2, figsize=(12, 4.5), constrained_layout=True)
    labels = [row['tag'] for row in comparisons]
    positions = np.arange(len(labels))
    panels[0].bar(positions - .18, [row['pressure']['relative_l2'] * 100 for row in comparisons], .36, label='pressure')
    panels[0].bar(positions + .18, [row['qp']['relative_l2'] * 100 for row in comparisons], .36, label='Qp')
    panels[0].axhline(5, color='red', ls='--', label='proposed 5% diagnostic')
    panels[0].set(xticks=positions, xticklabels=labels, ylabel='Raw field relative L2 difference (%)',
                  title='Common ROI vs baseline65\nGlobal peak tests are reported separately')
    panels[0].legend(fontsize=8)
    for offset, tag in ((-.18, 'baseline65'), (.18, 'fine52')):
        items = reports[tag]['exposure']
        panels[1].bar(np.arange(4) + offset, [item['target_qp_fraction_of_material'] * 100 for item in items], .36, label=tag)
    panels[1].set(xticks=np.arange(4), xticklabels=['1 x 1 x 1', '1 x 2 x 1', '2 x 2 x 2', '1 x 2 x 4'],
                  xlabel='Synthetic target box full dimensions (mm)', ylabel='Target Qp proxy fraction (%)',
                  title='Assumed material box: 8 x 4 x 18 mm')
    panels[1].legend(fontsize=8)
    fig.suptitle('Qp spatial fractions are observed-volume proxies, not energy or cure efficiency', fontsize=11)
    fig.savefig(OUT / 'sensitivity.png')
    plt.close(fig)


def analyze():
    common_axes, points = common_grid()
    reports, curves, audits, comparisons, summary, exposure_rows, layer_rows = {}, {}, [], [], [], [], []
    baseline_fields = None
    for tag in TAGS:
        report, axes, pressure, qp, audit = load_and_audit(tag)
        reports[tag] = report
        audits.append(audit)
        interpolated = {name: RegularGridInterpolator(axes, field)(points)
                        for name, field in (('p', pressure), ('qp', qp))}
        if baseline_fields is None:
            baseline_fields = interpolated
        else:
            displacement = float(np.linalg.norm(np.array(report['metrics']['forward_peak_xyz_m']) -
                                                reports['baseline65']['metrics']['forward_peak_xyz_m']))
            p_difference = field_difference(baseline_fields['p'], interpolated['p'])
            qp_difference = field_difference(baseline_fields['qp'], interpolated['qp'])
            comparisons.append({'tag': tag, 'pressure': p_difference, 'qp': qp_difference,
                                'peak_displacement_m': displacement,
                                'global_peak_on_boundary': report['metrics']['forward_peak_on_boundary'],
                                'global_peak_amplitude_ratio_vs_baseline': report['metrics']['forward_peak_pa_assumed'] /
                                reports['baseline65']['metrics']['forward_peak_pa_assumed'],
                                'near_target_peak_displacement_m': float(np.linalg.norm(
                                    np.array(report['metrics']['near_target_peak_xyz_m']) -
                                    reports['baseline65']['metrics']['near_target_peak_xyz_m'])),
                                'within_proposed_sensitivity_checks': p_difference['within_proposed_5percent'] and
                                qp_difference['within_proposed_5percent'] and displacement <= .13e-3 + 1e-12 and
                                not report['metrics']['forward_peak_on_boundary']})
        ix, iy = [int(np.argmin(abs(axis))) for axis in axes[:2]]
        curves[tag] = {'z_m': axes[2], 'pressure': pressure[ix, iy, :], 'qp': qp[ix, iy, :]}
        metrics = report['metrics']
        if tag == 'wide65':
            make_wide_figure(axes, pressure, qp, report)
        summary.append({'tag': tag, 'dx_um': report['dx_m'] * 1e6, 'runtime_s': report['runtime_s'],
                        'peak_x_mm': metrics['forward_peak_xyz_m'][0] * 1e3,
                        'peak_y_mm': metrics['forward_peak_xyz_m'][1] * 1e3,
                        'peak_z_mm': metrics['forward_peak_xyz_m'][2] * 1e3,
                        'forward_peak_distance_to_target_mm': metrics['forward_peak_error_m'] * 1e3,
                        'pressure_pa_assumed': metrics['forward_peak_pa_assumed'],
                        'global_peak_on_boundary': metrics['forward_peak_on_boundary'],
                        'near_target_peak_z_mm': metrics['near_target_peak_xyz_m'][2] * 1e3,
                        'near_target_peak_error_mm': metrics['near_target_peak_error_m'] * 1e3,
                        'near_target_peak_pa_assumed': metrics['near_target_peak_pa_assumed'],
                        'global_peak_width_x_mm': millimetres_or_none(metrics['width_at_forward_peak_m'][0]),
                        'global_peak_width_y_mm': millimetres_or_none(metrics['width_at_forward_peak_m'][1]),
                        'global_peak_width_z_mm': millimetres_or_none(metrics['width_at_forward_peak_m'][2]),
                        'width_x_clipped': metrics['width_clipped'][0],
                        'width_y_clipped': metrics['width_clipped'][1],
                        'width_z_clipped': metrics['width_clipped'][2],
                        'end_time_us': report['record_window_end_s'] * 1e6})
        for item in report['exposure']:
            exposure_rows.append({'tag': tag, 'full_x_mm_assumed': item['target_halfwidth_m_assumed'][0] * 2e3,
                                  'full_y_mm_assumed': item['target_halfwidth_m_assumed'][1] * 2e3,
                                  'full_z_mm_assumed': item['target_halfwidth_m_assumed'][2] * 2e3,
                                  'target_qp_fraction': item['target_qp_fraction_of_material'],
                                  'outside_over_target_max_qp': item['outside_over_target_max_qp'],
                                  'target_cv_qp': item['target_cv_qp'],
                                  'target_relative_halfmax_coverage': item['target_relative_halfmax_coverage'],
                                  'target_clipped': item['target_clipped'], 'material_clipped': item['material_clipped']})
        target_bounds = np.array([[-.5, .5], [-.5, .5], [19.5, 20.5]]) * 1e-3
        for z_bounds in ([19.5, 20.5], [19, 21], [18, 22], [10, 28]):
            material_bounds = np.array([[-4, 4], [-2, 2], z_bounds]) * 1e-3
            item = observed_box_fraction(qp, axes, target_bounds, material_bounds)
            layer_rows.append({'tag': tag, 'z_min_mm_assumed': z_bounds[0], 'z_max_mm_assumed': z_bounds[1],
                               'material_thickness_mm_assumed': z_bounds[1] - z_bounds[0],
                               'fixed_target_full_dimensions_mm': '1x1x1',
                               'target_qp_fraction': item['target_qp_fraction'],
                               'target_qp_integral_pa2_s_m3': item['target_qp_integral_pa2_s_m3'],
                               'material_qp_integral_pa2_s_m3': item['material_qp_integral_pa2_s_m3'],
                               'material_clipped': item['material_clipped']})
        del pressure, qp, interpolated
    assert_source_controls(reports)
    expected_domains = {'baseline65': [10.4, 5.2, 31.2], 'pml65': [10.4, 5.2, 31.2],
                        'wide65': [15.6, 10.4, 31.2], 'long65': [10.4, 5.2, 41.6], 'fine52': [10.4, 5.2, 31.2]}
    for tag, report in reports.items():
        np.testing.assert_allclose(report['config']['domain_m'], np.array(expected_domains[tag]) * 1e-3, atol=1e-14, rtol=0)
        assert np.isclose(report['config']['pml_m'], .00156 if tag == 'pml65' else .00104, atol=1e-14, rtol=0)
        assert np.isclose(report['dx_m'], 52e-6 if tag == 'fine52' else 65e-6, atol=1e-15, rtol=0)
    with h5py.File(ROOT / 'results/kwave_oddeven/even32_focus20mm_dx65um.mat', 'r') as file:
        axes = [np.asarray(file[key]).ravel() for key in ('x_m', 'y_m', 'z_m')]
        old_field = RegularGridInterpolator(axes, read_xyz(file, 'p_peak_pa'))(points)
    historic_difference = field_difference(old_field, baseline_fields['p'])
    preserved = json.loads((OUT / 'preserved_hashes_before.json').read_text(encoding='utf-8'))
    for item in preserved:
        item['matches'] = hashlib.sha256(Path(item['path']).read_bytes()).hexdigest() == item['sha256']
    assert all(item['matches'] for item in preserved), 'Preserved baseline/source changed.'
    result = {'date': '2026-10-22', 'completed_cases': list(TAGS), 'audits': audits,
              'comparisons': comparisons, 'historic_baseline_to_40us': historic_difference,
              'common_sample_axes_bounds_m': [[float(axis[0]), float(axis[-1])] for axis in common_axes],
              'common_sample_spacing_m': .13e-3, 'individual_amplitude_normalization': False,
              'proposed_limits': {'relative_l2_and_max_change': .05, 'peak_displacement_m': .13e-3},
              'preserved_files': preserved, 'all_preserved_files_match': True,
              'cross_case_fixed_source_controls_checked': True,
              'all_space_convergence_established': False, 'physical_validation': 'unknown',
              'interpretation': 'Controlled finite-domain numerical sensitivity and observed-volume acoustic proxy analysis only.'}
    (OUT / 'analysis.json').write_text(json.dumps(result, indent=2), encoding='utf-8')
    write_csv('focus_summary.csv', summary)
    write_csv('exposure_summary.csv', exposure_rows)
    write_csv('material_box_sensitivity.csv', layer_rows)
    write_csv('sensitivity_summary.csv', [{'tag': row['tag'], 'pressure_l2': row['pressure']['relative_l2'],
                'qp_l2': row['qp']['relative_l2'], 'peak_displacement_mm': row['peak_displacement_m'] * 1e3,
                'global_peak_on_boundary': row['global_peak_on_boundary'],
                'global_peak_amplitude_ratio_vs_baseline': row['global_peak_amplitude_ratio_vs_baseline'],
                'near_target_peak_displacement_mm': row['near_target_peak_displacement_m'] * 1e3,
                'within_proposed_checks': row['within_proposed_sensitivity_checks']} for row in comparisons])
    result['historic_sparse_time_integral_comparison'] = historic_trace_comparison()
    (OUT / 'analysis.json').write_text(json.dumps(result, indent=2), encoding='utf-8')
    make_figures(reports, baseline_fields, common_axes, curves, comparisons)
    return result


if __name__ == '__main__':
    result = analyze()
    print(json.dumps({'completed_cases': result['completed_cases'],
                      'preserved': result['all_preserved_files_match'],
                      'sensitivity': result['comparisons']}))
