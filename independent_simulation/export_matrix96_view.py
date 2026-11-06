"""Offline interactive 3-D pressure viewer and paired-field audit (no solver)."""
from pathlib import Path
import json
import h5py
import numpy as np
import plotly.graph_objects as go
from plotly.subplots import make_subplots
from skimage.measure import marching_cubes

ROOT = Path(__file__).resolve().parent / 'results' / 'matrix96'


def load(part):
    stem = ROOT / f'{part}_dx64.0um'
    report = json.loads(Path(str(stem)+'.json').read_text())
    with h5py.File(str(stem)+'.mat', 'r') as f:
        # MATLAB v7.3 reverses dimensions in HDF5.
        field = np.asarray(f['peak_abs']).transpose(2, 1, 0)
        xyz = [np.asarray(f[k]).ravel() for k in ('x', 'y', 'z')]
        pos = np.asarray(f['m/positions_m']).T
        active = np.asarray(f['m/active']).ravel().astype(bool)
    return report, field, xyz, pos, active


def width_minus6db(axis, values):
    k = int(np.argmax(values)); threshold = values[k]*10**(-6/20)
    lo = hi = k
    while lo > 0 and values[lo-1] >= threshold:
        lo -= 1
    while hi < len(values)-1 and values[hi+1] >= threshold:
        hi += 1
    if lo == 0 or hi == len(values)-1:
        return None
    a = axis[lo-1]+(threshold-values[lo-1])*(axis[lo]-axis[lo-1])/(values[lo]-values[lo-1])
    b = axis[hi]+(threshold-values[hi])*(axis[hi+1]-axis[hi])/(values[hi+1]-values[hi])
    return float((b-a)*1e3)


def export():
    datasets = [load(p) for p in ('left', 'right')]
    fig = make_subplots(rows=1, cols=2, specs=[[{'type': 'scene'}]*2],
                        subplot_titles=['Left 48 elements', 'Right 48 elements'])
    reference = max(d[0]['roi_peak_pa_assumed'] for d in datasets)
    summary = {'reference_pa_assumed': reference, 'isosurface_reference': 'shared ROI maximum',
               'display_stride': 2, 'full_resolution_data': 'MAT files', 'parts': []}
    plane_indices, roi_traces, full_traces = [], [], []
    global_reference = max(float(d[1].max()) for d in datasets)
    for col, (r, p, axes, positions, active) in enumerate(datasets, 1):
        x, y, z = axes
        zidx = np.where((z >= r['config']['roi_z_m'][0]) & (z <= r['config']['roi_z_m'][1]))[0][::2]
        volume = p[::2, ::2, zidx]
        origin = np.array([x[0], y[0], z[zidx[0]]])*1e3
        spacing = tuple(float(v[1]-v[0])*2e3 for v in axes)
        for db, color in [(-12, '#367ac7'), (-6, '#24a68b'), (-3, '#ee7935')]:
            threshold = reference*10**(db/20)
            if not volume.min() < threshold < volume.max():
                continue
            verts, faces, _, _ = marching_cubes(volume, threshold, spacing=spacing)
            verts += origin
            roi_traces.append(len(fig.data))
            fig.add_trace(go.Mesh3d(x=verts[:, 0], y=verts[:, 1], z=verts[:, 2],
                i=faces[:, 0], j=faces[:, 1], k=faces[:, 2], opacity=.22,
                color=color, name=f'{db} dB ({threshold:.3g} Pa assumed)',
                showlegend=col == 1, legendgroup=str(db)), row=1, col=col)
        full_z = np.where(z >= 0)[0][::3]
        full_volume = p[::3, ::3, full_z]
        full_origin = np.array([x[0], y[0], z[full_z[0]]])*1e3
        for db, color in [(-12, '#367ac7'), (-6, '#24a68b'), (-3, '#ee7935')]:
            threshold = global_reference*10**(db/20)
            if not full_volume.min() < threshold < full_volume.max():
                continue
            verts, faces, _, _ = marching_cubes(full_volume, threshold,
                spacing=tuple(float(v[1]-v[0])*3e3 for v in axes))
            verts += full_origin
            full_traces.append(len(fig.data))
            fig.add_trace(go.Mesh3d(x=verts[:, 0], y=verts[:, 1], z=verts[:, 2],
                i=faces[:, 0], j=faces[:, 1], k=faces[:, 2], opacity=.3, color=color,
                name=f'Global {db} dB', visible=False, showlegend=col == 1), row=1, col=col)
        fig.add_trace(go.Scatter3d(x=positions[:, 0]*1e3, y=positions[:, 1]*1e3,
            z=positions[:, 2]*1e3, mode='markers', name='Array: active / inactive',
            marker=dict(size=3, color=np.where(active, '#ec4b37', '#888888')),
            showlegend=col == 1), row=1, col=col)
        target = np.array(r['target_requested_m'])*1e3
        fig.add_trace(go.Scatter3d(x=[target[0]], y=[target[1]], z=[target[2]],
            mode='markers', marker=dict(size=6, color='black', symbol='diamond'),
            name='Requested focus', showlegend=col == 1), row=1, col=col)
        xx, yy = np.meshgrid(x[::2]*1e3, y[::2]*1e3, indexing='ij')
        zi = np.argmin(abs(z-r['target_requested_m'][2]))
        plane_indices.append(len(fig.data))
        fig.add_trace(go.Surface(x=xx, y=yy, z=np.full_like(xx, z[zi]*1e3),
            surfacecolor=p[::2, ::2, zi], cmin=0, cmax=reference, colorscale='Viridis',
            opacity=.65, showscale=col == 2, colorbar=dict(title='Pa assumed'),
            name='Movable XY slice'), row=1, col=col)
        summary['parts'].append({k: r[k] for k in ('partition', 'target_peak_pa_assumed',
            'roi_peak_xyz_m', 'roi_peak_on_boundary', 'minus6db_surface_touches_roi_boundary')})
        ix, iy = np.argmin(abs(x)), np.argmin(abs(y))
        summary['parts'][-1].update(target_plane_x_minus6db_width_mm=width_minus6db(x, p[:, iy, zi]),
            target_plane_y_minus6db_width_mm=width_minus6db(y, p[ix, :, zi]),
            width_scope='profiles through requested x=y=0 at nearest target z; own profile peak')
    scene = dict(xaxis_title='x (mm)', yaxis_title='y (mm)', zaxis_title='z (mm)',
                 aspectmode='data', camera=dict(eye=dict(x=1.8, y=1.8, z=.8)))
    fig.update_layout(title='96-element 12x8 | assumed geometry, uncalibrated pressure',
        scene=scene, scene2=scene, height=850, margin=dict(t=105, b=90),
        annotations=list(fig.layout.annotations)+[dict(x=.5, y=-.08, xref='paper', yref='paper',
            showarrow=False, text='Peak over time, not one wavefront. ROI mode clips surfaces to z=12–24 mm; full mode uses z >= 0.<br>'
            'Drag to rotate; scroll to zoom; click legend to hide levels. Full fields are saved in MAT.')])
    steps = []
    for depth_mm in range(12, 25, 2):
        zs, values = [], []
        for _, p, (x, y, z), _, _ in datasets:
            zi = np.argmin(abs(z-depth_mm*1e-3))
            values.append(p[::2, ::2, zi])
            zs.append(np.full(values[-1].shape, z[zi]*1e3))
        steps.append(dict(label=str(depth_mm), method='restyle',
            args=[{'z': zs, 'surfacecolor': values}, plane_indices]))
    fig.update_layout(sliders=[dict(active=4, currentvalue=dict(prefix='XY depth (mm): '),
                                    steps=steps, y=-.03, len=.8)])
    roi_visible = [i not in full_traces for i in range(len(fig.data))]
    full_visible = [i not in roi_traces for i in range(len(fig.data))]
    fig.update_layout(updatemenus=[dict(type='buttons', direction='right', x=.2, y=1.12,
        buttons=[dict(label='Target ROI surfaces', method='update', args=[{'visible': roi_visible}]),
                 dict(label='Full forward field surfaces', method='update', args=[{'visible': full_visible}])])])
    summary['global_surface_reference_pa_assumed'] = global_reference
    summary['global_display_stride'] = 3
    fig.write_html(ROOT/'matrix96_3d.html', include_plotlyjs=True, full_html=True)
    # Mirror comparison on exactly matched x coordinates (exclude the unmatched edge).
    a, b = datasets[0][1], datasets[1][1]
    x = datasets[0][2][0]
    idx = np.array([np.argmin(abs(x+v)) for v in x])
    ok = np.abs(x[idx]+x) < 1e-12
    aa = a[ok]; bb = b[idx[ok]]
    summary['mirror_relative_l2'] = float(np.linalg.norm(aa-bb)/np.linalg.norm(aa))
    summary['mirror_scope'] = 'matched x locations; same y,z; excludes unmatched negative edge'
    summary['target_relative_difference'] = float(abs(datasets[0][0]['target_peak_pa_assumed']-
        datasets[1][0]['target_peak_pa_assumed'])/datasets[0][0]['target_peak_pa_assumed'])
    summary['convergence'] = 'not_established_single_grid'
    (ROOT/'comparison.json').write_text(json.dumps(summary, indent=2), encoding='utf-8')
    print(json.dumps(summary, indent=2))


if __name__ == '__main__':
    export()
