"""Independent delay and monochromatic-model checks, without MATLAB runtime."""
import sys
from pathlib import Path

import numpy as np
import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from singlepoint_source_audit import delay_diagnostics, onaxis_reference


def test_delay_audit_detects_wrong_cycle_frequency():
    positions = np.array([[-.004, 0, 0], [0, 0, 0], [.004, 0, 0]])
    target = np.array([0, 0, .020])
    distance = np.linalg.norm(positions - target, axis=1)
    delay = (distance.max() - distance) / 1540
    correct = delay_diagnostics(positions, delay, target, 1540)
    wrong = delay_diagnostics(positions, delay * 6.5 / 6, target, 1540)
    assert correct['max_delay_error_s'] < 1e-18
    assert correct['arrival_spread_s'] < 1e-18
    assert wrong['arrival_spread_s'] > 1e-9


def test_small_single_rectangle_follows_inverse_distance():
    z = np.array([.01, .02, .03])
    amplitude = onaxis_reference(np.zeros((1, 3)), np.zeros(1), 1e-7, 1e-7,
                                 6e6, 1540, z, (4, 8))
    np.testing.assert_allclose(amplitude / amplitude[0], z[0] / z, rtol=1e-7)


def test_reference_rejects_source_plane():
    with pytest.raises(ValueError):
        onaxis_reference(np.zeros((1, 3)), np.zeros(1), .00011, .00202,
                         6e6, 1540, np.array([0, .020]), (4, 8))
