"""Export a standalone interactive view from solved k-Wave peak-pressure data."""
from pathlib import Path
import json
import h5py
import numpy as np
import plotly.graph_objects as go
from plotly.subplots import make_subplots
from skimage.measure import marching_cubes


def export(stem: Path) -> Path:
    report = json.loads(stem.with_suffix('.json').read_text(encoding='utf-8'))
    with h5py.File(stem.with_suffix('.mat'), 'r') as f:
        pressure = np.asarray(f['p_peak_pa']).transpose(2, 1, 0)
        axes = [np.asarray(f[k]).ravel() * 1000 for k in ('x_m', 'y_m', 'z_m')]
    x, y, z = axes
    assert pressure.shape == (len(x), len(y), len(z))
    target = np.asarray(report['source']['target_m']) * 1000
    peak = np.asarray(report['metrics']['forward_peak_xyz_m']) * 1000
    reference = report['metrics']['forward_peak_pa_assumed']
    forward = np.where(z >= 2)[0][::2]
    volume = pressure[::2, ::2, forward]
    origin = np.array([x[0], y[0], z[forward[0]]])
    spacing = tuple(float(a[1] - a[0]) * 2 for a in axes)
    fig = make_subplots(rows=2, cols=1, specs=[[{'type': 'scene'}], [{'type': 'xy'}]],
                        row_heights=[.58, .42], vertical_spacing=.12,
                        subplot_titles=['3D peak-pressure surfaces', 'XZ section through target y = 0'])
    for db, color, opacity in [(-12, '#397bb6', .14), (-6.0206, '#22a49a', .3), (-3, '#f28b47', .65)]:
        threshold = reference * 10 ** (db / 20)
        if not volume.min() < threshold < volume.max():
            continue
        vertices, faces, _, _ = marching_cubes(volume, threshold, spacing=spacing)
        vertices += origin
        fig.add_trace(go.Mesh3d(x=vertices[:, 0], y=vertices[:, 1], z=vertices[:, 2],
                               i=faces[:, 0], j=faces[:, 1], k=faces[:, 2],
                               color=color, opacity=opacity, showlegend=True,
                               name=f'{db:.2g} dB ({threshold:.3g} Pa, assumed)'), row=1, col=1)
    for xyz, color, name in [(target, '#cc3030', 'Requested focus'), (peak, '#17202a', 'Forward-domain peak')]:
        fig.add_trace(go.Scatter3d(x=[xyz[0]], y=[xyz[1]], z=[xyz[2]], mode='markers',
                                  marker={'size': 5, 'color': color}, name=name), row=1, col=1)
    iy = int(np.argmin(np.abs(y - target[1])))
    image = 20 * np.log10(np.maximum(pressure[:, iy, :] / reference, 1e-3))
    fig.add_trace(go.Heatmap(x=x, y=z, z=image.T, colorscale='Turbo', zmin=-40, zmax=0,
                            colorbar={'title': 'dB', 'len': .32, 'y': .2}, showscale=True,
                            hovertemplate='x=%{x:.3f} mm<br>z=%{y:.3f} mm<br>%{z:.2f} dB<extra></extra>'), row=2, col=1)
    fig.add_trace(go.Scatter(x=[target[0]], y=[target[2]], mode='markers',
                             marker={'symbol': 'cross', 'size': 12, 'color': 'white'},
                             showlegend=False), row=2, col=1)
    fig.update_layout(template='plotly_white', height=1250,
                      title=(f"Even 32 / 64 | k-Wave 3D<br>{report['dx_m']*1e6:.0f} um grid | "
                             f"focus error {report['metrics']['forward_peak_error_m']*1e3:.3f} mm"),
                      title_font_size=15,
                      scene={'xaxis_title': 'x (mm)', 'yaxis_title': 'y (mm)', 'zaxis_title': 'z (mm)',
                             'aspectmode': 'data'},
                      legend={'orientation': 'h', 'y': -.08}, margin={'b': 220})
    fig.update_xaxes(title_text='x (mm)', row=2, col=1)
    fig.update_yaxes(title_text='z (mm)', range=[2, float(z[-1])], row=2, col=1)
    fig.add_annotation(text=('max_t |p|, not a simultaneous snapshot.<br>Assumed 1 Pa source; no lens or attenuation.<br>'
                             '3D display uses stride 2; full-resolution values remain in MAT.<br>'
                             'Double-click legend to isolate a surface.'),
                       x=.5, y=-.24, xref='paper', yref='paper', showarrow=False,
                       font={'size': 11, 'color': '#444'})
    output = stem.parent / 'pressure_3d_interactive.html'
    fig.write_html(output, include_plotlyjs=True, full_html=True, auto_open=False)
    return output


if __name__ == '__main__':
    root = Path(__file__).resolve().parent / 'results' / 'kwave_oddeven'
    print(export(root / 'even32_focus20mm_dx52um'))
