"""Tests that comparisons detect gain errors and MATLAB dimension mistakes."""
import sys
import copy
from pathlib import Path

import h5py
import numpy as np
import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from analyze_kwave_singlepoint_validation import field_difference, read_xyz, independent_exposure, assert_source_controls, millimetres_or_none, observed_box_fraction


def test_comparison_does_not_normalize_away_gain_change():
    reference = np.arange(1, 25).reshape(2, 3, 4).astype(float)
    statistics = field_difference(reference, 1.1 * reference)
    assert np.isclose(statistics['relative_l2'], .1)
    assert np.isclose(statistics['relative_maximum_change'], .1)
    assert not statistics['within_proposed_5percent']


def test_matlab_hdf5_dimension_order_is_reversed_once():
    expected = np.arange(24).reshape(2, 3, 4)
    with h5py.File('dimension_order_test.h5', 'w', driver='core', backing_store=False) as file:
        file['volume'] = expected.transpose(2, 1, 0)
        np.testing.assert_array_equal(read_xyz(file, 'volume'), expected)


def test_tiny_si_integral_is_not_accepted_as_zero():
    axes = [np.array([-.001, 0, .001]), np.array([-.001, 0, .001]), np.array([.019, .020, .021])]
    q = np.full((3, 3, 3), 1e-6)
    report = {'material_bounds_m_assumed': [[-.001, .001], [-.001, .001], [.019, .021]],
              'target_m': [0, 0, .020], 'target_halfwidth_m_assumed': [.0004] * 3,
              'target_voxels': 1, 'material_voxels': 27,
              'target_qp_integral_pa2_s_m3': 0, 'target_qp_fraction_of_material': 1/27,
              'outside_over_target_max_qp': 1, 'outside_over_target_max_pressure': 1,
              'prefocal_qp_fraction_of_material': 9/27, 'postfocal_qp_fraction_of_material': 9/27,
              'lateral_qp_fraction_of_material': 8/27}
    with pytest.raises(AssertionError):
        independent_exposure(q, np.sqrt(q), axes, report)


def test_source_gain_change_is_not_treated_as_boundary_sensitivity():
    base = {'config': {'input_mat': 'same.mat', 'density_kg_m3': 1000,
                       'source_amplitude_pa': 1, 'source_offset_m': .00052, 'cfl': .2,
                       'provenance': 'assumed'},
            'source': {'input_sha256': 'same', 'target_m': [0, 0, .020],
                       'active_elements': [2, 4], 'num_elements': 4, 'tx_index': 16,
                       'source_model': 'assumed', 'element_area_m2': 2e-7,
                       'source_z_offset_m': .00052, 'sound_speed_m_s': 1540,
                       'waveform': {'frequency_hz': 6e6}}}
    reports = {'baseline65': copy.deepcopy(base), 'pml65': copy.deepcopy(base)}
    assert_source_controls(reports)
    reports['pml65']['config']['source_amplitude_pa'] = 2
    with pytest.raises(AssertionError):
        assert_source_controls(reports)


def test_clipped_width_does_not_become_a_zero_width():
    assert millimetres_or_none(None) is None
    assert millimetres_or_none(.001) == 1


def test_material_thickness_changes_only_the_declared_denominator():
    axes = [np.array([-.001, 0, .001]), np.array([-.001, 0, .001]), np.arange(18, 23) * .001]
    q = np.ones((3, 3, 5))
    target = np.array([[-.0004, .0004], [-.0004, .0004], [.0196, .0204]])
    thin = np.array([[-.001, .001], [-.001, .001], [.0196, .0204]])
    thick = np.array([[-.001, .001], [-.001, .001], [.018, .022]])
    first = observed_box_fraction(q, axes, target, thin)
    second = observed_box_fraction(q, axes, target, thick)
    assert np.isclose(first['target_qp_fraction'], 1/9)
    assert np.isclose(second['target_qp_fraction'], 1/45)
    assert first['target_qp_integral_pa2_s_m3'] == second['target_qp_integral_pa2_s_m3']
