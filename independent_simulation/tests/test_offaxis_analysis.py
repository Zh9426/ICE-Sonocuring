"""Independent temporal and spatial metric checks for the off-axis diagnosis."""
import sys
from pathlib import Path
import numpy as np
import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import analyze_kwave_offaxis as analysis


def test_temporal_peak_does_not_rank_integrated_exposure():
    high_peak = np.zeros(12); high_peak[5] = -2
    long_pulse = np.zeros(12); long_pulse[1:10] = 1
    a, b = analysis.trace_statistics(np.array([high_peak, long_pulse]), 1e-8)
    assert a['peak_abs_pa_assumed'] > b['peak_abs_pa_assumed']
    assert a['qp_pa2_s'] == pytest.approx(4e-8)
    assert b['qp_pa2_s'] == pytest.approx(9e-8)
    assert a['peak_time_s'] == pytest.approx(5e-8)
    assert a['qp90_interval_s'] == pytest.approx([5e-8, 5e-8])
    assert b['qp90_interval_s'] == pytest.approx([1e-8, 9e-8])


def test_trace_statistics_reject_nonfinite_or_nonpositive_time():
    with pytest.raises(ValueError):
        analysis.trace_statistics(np.ones((2, 5)), 0)
    with pytest.raises(ValueError):
        analysis.trace_statistics(np.array([[1, np.nan]]), 1e-8)
    result = analysis.trace_statistics(np.zeros((1, 5)), 1e-8)[0]
    assert result['qp_pa2_s'] == 0
    assert result['qp90_interval_s'] is None


def test_band_peak_respects_half_open_depth_range_and_matlab_tie_order():
    axes = [np.array([-1., 0., 1.]), np.array([-1., 0., 1.]), np.arange(4.)]
    p = np.ones((3, 3, 4)); p[2, 1, 1] = 4; p[0, 2, 1] = 4
    p[1, 1, 2] = 10
    r = analysis.band_peak(p, axes, 0., 2.)
    assert r['peak_pa_assumed'] == 4
    assert r['xyz_m'] == [1., 0., 1.]
    assert r['on_search_boundary'] is True
    r = analysis.band_peak(p, axes, 2., 4.)
    assert r['peak_pa_assumed'] == 10
    assert r['on_search_boundary'] is True


def test_common_grid_preserves_raw_amplitudes_with_larger_domain():
    old = [np.array([-1., 0., 1.]), np.array([0., 1.]), np.array([0., 1.])]
    new = [np.array([-2., -1., 0., 1., 2.]), old[1], old[2]]
    indices = analysis.match_axes(old, new)
    p = np.arange(20.).reshape(5, 2, 2)
    np.testing.assert_equal(p[np.ix_(*indices)], p[1:4])
    with pytest.raises(ValueError):
        analysis.match_axes(old, [new[0] + .1, new[1], new[2]])


def test_near_source_change_cannot_be_hidden_by_stable_deep_field():
    comparison = {k: {'raw_amplitude_relative_l2': .001, 'maximum_relative_change': .001}
                  for k in ('all_old_physical_voxels','z0_to2','z2_to5','z5_plus')}
    traces = [{'qp_relative_change_vs_wide65': .001}]
    assert analysis.criteria_pass(comparison, 0., traces)
    comparison['z0_to2']['raw_amplitude_relative_l2'] = .06
    assert not analysis.criteria_pass(comparison, 0., traces)
    comparison['z0_to2']['raw_amplitude_relative_l2'] = .001
    comparison['all_old_physical_voxels']['maximum_relative_change'] = .06
    assert not analysis.criteria_pass(comparison, 0., traces)


def test_permuted_matlab_sensor_rows_keep_qp_attached_to_labels():
    raw = np.array([[1., 0., 0.], [0., 2., 0.], [0., 0., 3.]])
    meta = {'labels': ['near_main', 'offaxis_pos', 'target'], 'trace_row': [3, 1, 2]}
    labelled = analysis.traces_in_label_order(raw, meta)
    stats = analysis.trace_statistics(labelled, 1e-8)
    np.testing.assert_allclose([s['qp_pa2_s'] for s in stats], np.array([9., 1., 4.])*1e-8)
    assert [s['peak_time_s'] for s in stats] == pytest.approx([2e-8, 0., 1e-8])
