import sys
from pathlib import Path
import numpy as np
import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from analyze_widegrid import common_lattice, interpolated_change
import analyze_widegrid as audit


def test_common_lattice_uses_exact_physical_coordinates():
    coarse = [np.arange(-4, 5)*.065]*3
    fine = [np.arange(-5, 6)*.052]*3
    ci, fi = common_lattice(coarse, fine)
    for a, b in zip(ci, fi):
        np.testing.assert_array_equal(a, [0, 4, 8])
        np.testing.assert_array_equal(b, [0, 5, 10])


def test_interpolation_recovers_linear_field_without_amplitude_normalization():
    ca = [np.linspace(-1, 1, 5)]*3
    fa = [np.linspace(-1.1, 1.1, 12)]*3
    def field(ax):
        x, y, z = np.meshgrid(*ax, indexing='ij')
        return 5+x+2*y+z
    r = interpolated_change(field(ca), ca, field(fa)*2, fa)
    assert r['raw_amplitude_relative_l2'] == pytest.approx(1)
    assert r['maximum_relative_change'] == pytest.approx(1)
    assert r['voxels'] == 125


def test_interpolation_rejects_extrapolation():
    with pytest.raises(ValueError, match='cover'):
        interpolated_change(np.ones((3, 3, 3)), [np.arange(3)]*3,
                            np.ones((2, 2, 2)), [np.arange(2)]*3)


def test_trace_row_mapping_rejects_permutation_even_with_equal_peaks():
    audit.check_trace_rows([8, 2, 5], [3, 1, 2])
    with pytest.raises(AssertionError):
        audit.check_trace_rows([8, 2, 5], [1, 3, 2])
