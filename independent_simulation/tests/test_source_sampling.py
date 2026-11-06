import sys
from pathlib import Path
import numpy as np
import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from audit_source_sampling import rectangle_transfer


def test_same_physical_area_at_zero_spatial_frequency():
    r = rectangle_transfer(110e-6, 65e-6, -65e-6, np.array([0.]))
    assert r['represented_area_per_height_m'] == pytest.approx(110e-6)
    np.testing.assert_allclose(r['discrete'], [1.], atol=1e-14)
    np.testing.assert_allclose(r['continuous'], [1.], atol=1e-14)


def test_spatial_phase_uses_actual_element_center():
    kx = np.linspace(0, 2e4, 30)
    a = rectangle_transfer(110e-6, 65e-6, 0., kx)
    b = rectangle_transfer(110e-6, 65e-6, 65e-6, kx)
    np.testing.assert_allclose(a['discrete'], b['discrete'], atol=1e-14)


def test_fine_rectangle_sampling_approaches_continuous_integral():
    kx = np.linspace(0, 2e4, 30)
    r = rectangle_transfer(110e-6, 1e-6, .25e-6, kx)
    np.testing.assert_allclose(r['discrete'], r['continuous'], atol=2e-5)


def test_invalid_sampling_parameters_are_rejected():
    with pytest.raises(ValueError):
        rectangle_transfer(110e-6, 0., 0., np.array([0.]))
