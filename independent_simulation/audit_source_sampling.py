"""Analytic source-space audit, not a radiation solver or real directivity."""
from pathlib import Path
import json
import csv
import numpy as np
from scipy.io import loadmat

ROOT = Path(__file__).resolve().parent
OUT = ROOT/'results/kwave_widegrid_2026-10-24'


def rectangle_transfer(width, dx, center, kx):
    kx = np.atleast_1d(np.asarray(kx, dtype=float))
    if width <= 0 or dx <= 0 or not np.isfinite([width, dx, center]).all() or not np.isfinite(kx).all():
        raise ValueError('Finite center/kx and positive finite width/dx required.')
    indices = np.arange(np.floor((center-width/2)/dx)-2, np.ceil((center+width/2)/dx)+3)
    x = indices*dx
    overlap = np.maximum(0., np.minimum(x+dx/2, center+width/2)-np.maximum(x-dx/2, center-width/2))
    # This is exactly the existing cell-overlap geometry, expressed as a
    # spatial source spectrum; both cases divide by the SAME physical width.
    discrete = np.exp(-1j*kx[:, None]*(x-center)[None, :])@overlap/width
    continuous = np.sinc(kx*width/(2*np.pi))
    return {'discrete': discrete, 'continuous': continuous, 'represented_area_per_height_m': float(overlap.sum())}


def main():
    old = json.loads((ROOT/'results/kwave_singlepoint_validation_2026-10-22/wide65.json').read_text(encoding='utf-8-sig'))
    saved = loadmat(old['config']['input_mat'], simplify_cells=True)
    tr = saved['Trans']; c = float(saved['Resource']['Parameters']['speedOfSound'])
    assert tr['units'] == 'wavelengths'
    scale = c/(float(tr['frequency'])*1e6)
    width = float(tr['elementWidth'])*scale
    positions = np.asarray(tr['ElementPos'])[:, 0]*scale
    active = np.asarray(old['source']['active_elements'])-1
    center = float(positions[active[np.argmin(abs(positions[active]))]])
    angles = np.arange(0., 85.01, .5)
    rows = []
    for f in (6e6, 6.5e6, 8e6):
        kx = 2*np.pi*f/c*np.sin(np.deg2rad(angles))
        for dx in (65e-6, 52e-6):
            r = rectangle_transfer(width, dx, center, kx)
            assert abs(r['represented_area_per_height_m']/width-1) < 1e-12
            for theta, d, exact in zip(angles, r['discrete'], r['continuous']):
                rows.append({'frequency_hz': f, 'dx_m': dx, 'angle_deg_xz': theta,
                             'continuous_rectangle_source_transfer': float(exact),
                             'cell_overlap_source_transfer_abs': float(abs(d)),
                             'amplitude_error_vs_continuous': float(abs(d)/abs(exact)-1),
                             'source_transfer_phase_rad': float(np.angle(d))})
    result = {'width_m_existing_code_unverified': width, 'representative_even_element_center_x_m': center,
              'cells_across_width': {'65um': width/65e-6, '52um': width/52e-6},
              'definition': 'Per-element XZ spatial Fourier source transfer, ky=0, kx=2*pi*f/c*sin(theta); divide by identical physical rectangle area. Not field normalization.',
              'selected_rows': [r for r in rows if r['frequency_hz']==6e6 and r['angle_deg_xz'] in (0., 60., 75.)],
              'interpretation': 'Different cell-overlap source spectra are demonstrated. Causal share of the observed full-field change is not isolated: time sampling and propagation grid also change.',
              'limitations': 'Ideal continuous flat pressure-source geometry only; not actual probe directivity, array beam, radiated power, thermal or cure model. No replacement k-Wave source or propagation implemented.',
              'candidate_followup': 'Test kWaveArray band-limited geometry as an independent source representation; its nonlocal mask support, clipping, scaling and BLI tolerance must be audited before comparison.',
              'primary_documentation': 'https://www.k-wave.org/documentation/kWaveArray.php',
              'source_representation_paper_doi': '10.1121/1.5116132'}
    (OUT/'source_sampling.json').write_text(json.dumps(result, indent=2), encoding='utf-8')
    with (OUT/'source_sampling.csv').open('w', newline='', encoding='utf-8') as stream:
        writer = csv.DictWriter(stream, fieldnames=list(rows[0])); writer.writeheader(); writer.writerows(rows)
    make_figure(rows)
    print(json.dumps(result, indent=2))


def make_figure(rows):
    import matplotlib
    matplotlib.use('Agg')
    import matplotlib.pyplot as plt
    fig, ax = plt.subplots(figsize=(7, 4), constrained_layout=True)
    for dx, label in ((65e-6, 'cell overlap, 65 um'), (52e-6, 'cell overlap, 52 um')):
        r = [v for v in rows if v['frequency_hz']==6e6 and v['dx_m']==dx]
        ax.plot([v['angle_deg_xz'] for v in r], [v['cell_overlap_source_transfer_abs'] for v in r], label=label)
    r = [v for v in rows if v['frequency_hz']==6e6 and v['dx_m']==65e-6]
    ax.plot([v['angle_deg_xz'] for v in r], [v['continuous_rectangle_source_transfer'] for v in r], 'k--', label='continuous rectangle integral')
    ax.set(xlabel='Spatial-spectrum angle in XZ (degrees)', ylabel='Source transfer / same physical area',
           title='6 MHz source geometry audit: not actual probe directivity', xlim=(0, 85), ylim=(0, 1.05))
    ax.legend(); fig.savefig(OUT/'source_sampling.png', dpi=180); fig.savefig(OUT/'source_sampling.pdf'); plt.close(fig)


if __name__ == '__main__':
    main()
