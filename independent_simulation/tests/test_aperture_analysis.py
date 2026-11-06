import sys
from pathlib import Path
import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import analyze_aperture_control as analysis


def test_same_element_counterfactual_scales_pressure_and_qp_differently():
    r = analysis.linear_counterfactual(2., 3e-6, .5)
    assert r['peak_pa_assumed_derived'] == 4.
    assert r['qp_pa2_s_derived'] == pytest.approx(12e-6)
    with pytest.raises(ValueError):
        analysis.linear_counterfactual(2., 3e-6, 0.)
