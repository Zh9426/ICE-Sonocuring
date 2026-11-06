"""Audit saved TX units and compare a separate monochromatic rectangle model.

The scalar exp(-ikr)/r surface integral is an assumed reference with arbitrary
gain. It is not the broadband k-Wave solver or a measured transducer response.
"""
from pathlib import Path
import csv
import hashlib
import json

import numpy as np
from scipy.io import loadmat


def delay_diagnostics(positions, delay_s, target_m, sound_speed):
    distance = np.linalg.norm(np.asarray(positions) - target_m, axis=1)
    expected = (distance.max() - distance) / sound_speed
    return {'max_delay_error_s': float(np.max(np.abs(delay_s - expected))),
            'arrival_spread_s': float(np.ptp(delay_s + distance / sound_speed))}


def onaxis_reference(positions, delay_s, width, height, frequency, sound_speed,
                     z_m, quadrature=(4, 32)):
    positions = np.asarray(positions, dtype=float)
    z_m = np.asarray(z_m, dtype=float)
    if np.any(z_m <= positions[:, 2].max()) or min(width, height) <= 0:
        raise ValueError('Positive aperture and forward axial samples required.')
    nx, ny = quadrature
    sx = ((np.arange(nx) + .5) / nx - .5) * width
    sy = ((np.arange(ny) + .5) / ny - .5) * height
    xs = np.broadcast_to(positions[:, 0, None, None] + sx[None, :, None],
                         (len(positions), nx, ny)).ravel()
    ys = np.broadcast_to(positions[:, 1, None, None] + sy[None, None, :],
                         (len(positions), nx, ny)).ravel()
    zs = np.repeat(positions[:, 2], nx * ny)
    delays = np.repeat(delay_s, nx * ny)
    amplitude = []
    for z in z_m:
        distance = np.sqrt(xs**2 + ys**2 + (z - zs)**2)
        response = np.exp(-2j * np.pi * frequency *
                          (distance / sound_speed + delays)) / distance
        amplitude.append(abs(response.sum()) * width * height / (nx * ny))
    return np.array(amplitude)


def audit(output_dir=None):
    root = Path(__file__).resolve().parent
    out = Path(output_dir) if output_dir else root / 'results' / 'kwave_singlepoint_validation_2026-10-22'
    out.mkdir(parents=True, exist_ok=True)
    source = root.parent / 'results' / 'verasonics_linear64_oddeven' / 'ICE_Linear64OddEven_interleaved.mat'
    saved = loadmat(source, simplify_cells=True)
    tr = saved['Trans']
    sound_speed = float(saved['Resource']['Parameters']['speedOfSound'])
    assert tr['units'] == 'wavelengths'
    scale = sound_speed / (tr['frequency'] * 1e6)
    positions = np.asarray(tr['ElementPos'])[:, :3] * scale
    tx_index = int(saved['ICEReport']['num_imaging_angles'])
    tx = saved['TX'][tx_index]
    active = np.flatnonzero(tx['Apod'])
    physical_order = np.argsort(positions[:, 0])
    assert np.array_equal(np.sort(physical_order[1::2]), active)
    target = np.asarray(saved['ICEConfig']['exposure']['foci_mm']).reshape(-1, 3)[0] * 1e-3
    delay = np.asarray(tx['Delay'])[active] / (tr['frequency'] * 1e6)
    diagnosis = delay_diagnostics(positions[active], delay, target, sound_speed)
    assert diagnosis['max_delay_error_s'] < 1e-12
    z_m = np.arange(.002, .030, 65e-6)
    waveform = saved['TW'][int(tx['waveform']) - 1]
    frequency = float(waveform['Parameters'][0]) * 1e6
    references = []
    fields = []
    for quadrature in ((4, 32), (8, 64)):
        amplitude = onaxis_reference(positions[active], delay, tr['elementWidth'] * scale,
                                     tr['elevationApertureMm'] * 1e-3,
                                     frequency, sound_speed, z_m, quadrature)
        normalized = amplitude / amplitude.max()
        fields.append(normalized)
        references.append({'quadrature_xy': list(quadrature),
                           'peak_z_m': float(z_m[np.argmax(amplitude)]),
                           'target_over_peak': float(np.interp(target[2], z_m, normalized))})
    result = {'input_sha256': hashlib.sha256(source.read_bytes()).hexdigest(),
              'tx_index_one_based': tx_index + 1, 'active_elements': (active + 1).tolist(),
              'delay_units_manual': 'D00163 Rev. K, TX.Delay A171-A172, computeTXDelays A176',
              'reference_frequency_hz': frequency, 'trans_reference_frequency_hz': float(tr['frequency'] * 1e6),
              'target_m': target.tolist(), **diagnosis,
              'monochromatic_reference': references,
              'normalized_reference_quadrature_l2': float(np.linalg.norm(fields[0] - fields[1]) / np.linalg.norm(fields[1])),
              'source_geometry': 'existing_code_unverified',
              'reference_model': 'assumed_scalar_monochromatic_finite_rectangle_exp_minus_ikr_over_r',
              'interpretation': 'A pre-focal maximum also occurs in this separate finite-aperture model. This supports a diffraction-focus-shift explanation but does not establish the sole cause or validate real-probe accuracy.',
              'absolute_pressure_calibration': 'unknown', 'hardware_run': False}
    (out / 'source_audit.json').write_text(json.dumps(result, indent=2), encoding='utf-8')
    with (out / 'onaxis_reference.csv').open('w', newline='', encoding='utf-8') as file:
        writer = csv.writer(file)
        writer.writerow(['z_m', 'normalized_reference_4x32', 'normalized_reference_8x64'])
        writer.writerows(zip(z_m, *fields))
    return result


if __name__ == '__main__':
    report = audit()
    print(json.dumps({'delay_error_s': report['max_delay_error_s'],
                      'reference_peak_z_m': report['monochromatic_reference'][-1]['peak_z_m']}))
