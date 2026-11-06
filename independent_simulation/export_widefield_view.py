"""Read-only wide-field peak-pressure viewer from existing MATLAB v7.3 records.

No propagation, voltage calibration, Qp inference, heat or material model is run.
"""
from pathlib import Path
import base64
import csv
import gzip
import hashlib
import json
import sys
import h5py
import numpy as np
from plotly.offline import get_plotlyjs
from skimage.measure import marching_cubes

ROOT=Path(__file__).resolve().parent
SOURCE=ROOT/'results/kwave_widegrid_2026-10-24'
OUT=SOURCE/'interactive'
DB_LEVELS=(-12.,-6.020599913279624,-3.)
REGIONS={'near_source':(0.,2.),'shallow':(2.,5.),'deep':(5.,np.inf),'forward':(0.,np.inf)}


def sha256(path):
    with Path(path).open('rb') as f: return hashlib.file_digest(f,'sha256').hexdigest()


def read_pressure(path):
    with h5py.File(path,'r') as f:
        p=np.asarray(f['p_peak_pa']).transpose(2,1,0)
        axes=[np.asarray(f[k]).ravel()*1000 for k in ('x_m','y_m','z_m')]
    if any(len(a)<2 or not np.isfinite(a).all() or np.any(np.diff(a)<=0) for a in axes):
        raise ValueError('Finite strictly increasing coordinate axes required.')
    if p.shape!=tuple(len(a) for a in axes) or not np.isfinite(p).all() or np.any(p<0):
        raise ValueError('Nonnegative finite pressure with matching XYZ shape required.')
    return p,axes


def region_peaks(p,axes):
    result={}
    for name,(lo,hi) in REGIONS.items():
        zz=np.flatnonzero(((axes[2]>1e-9) if lo==0 else (axes[2]>=lo-1e-9)) & (axes[2]<hi-1e-9))
        if not len(zz): raise ValueError(f'Empty depth region {name}.')
        values=p[:,:,zz]
        loc=np.unravel_index(values.ravel(order='F').argmax(),values.shape,order='F')
        native=(int(loc[0]),int(loc[1]),int(zz[loc[2]]))
        result[name]={'pressure_pa_assumed':float(p[native]),'xyz_mm':[float(a[i]) for a,i in zip(axes,native)],
                      'index_xyz':list(native),'on_search_boundary':bool(any(i==0 or i==n-1 for i,n in zip(loc,values.shape))),
                      'z_interval_mm':'0<z<2' if name=='near_source' else ('2<=z<5' if name=='shallow' else ('z>=5' if name=='deep' else 'z>0'))}
    return result


def sample_indices(length,stride,protected=()):
    if length<2 or stride<1: raise ValueError('Positive display stride and >=2 coordinates required.')
    return np.unique([*range(0,length,stride),length-1,*[int(k) for k in protected if 0<=k<length]])


def vertex_coordinates(vertices,axes):
    return np.column_stack([np.interp(vertices[:,j],np.arange(len(a)),a) for j,a in enumerate(axes)])


def pressure_db(values,reference):
    if not np.isfinite(reference) or reference<=0: raise ValueError('Positive common pressure reference required.')
    return 20*np.log10(np.maximum(np.asarray(values,dtype=float)/reference,1e-4))


def mesh_data(p,axes,reference,protected):
    # Nonuniform protected sampling is mapped back to physical coordinates explicitly.
    pos=np.flatnonzero(axes[2]>1e-9)
    ids=[sample_indices(len(a),2,[q[j] for q in protected]) for j,a in enumerate(axes)]
    ids[2]=ids[2][np.isin(ids[2],pos)]
    ids[2]=np.unique([pos[0],*ids[2],pos[-1]])
    a=[v[i] for v,i in zip(axes,ids)]
    volume=p[np.ix_(*ids)].astype(np.float32)
    meshes=[]
    for db in DB_LEVELS:
        level=reference*10**(db/20)
        if not volume.min()<level<volume.max(): continue
        verts,faces,_,_=marching_cubes(volume,level,allow_degenerate=False)
        xyz=vertex_coordinates(verts,a)
        boundary=bool(any(np.any(np.isclose(verts[:,j],0)) or np.any(np.isclose(verts[:,j],len(v)-1)) for j,v in enumerate(a)))
        meshes.append({'db':db,'threshold_pa':level,'xyz':np.round(xyz,6).T.tolist(),'ijk':faces.T.tolist(),
                       'touches_display_boundary':boundary,'vertices':len(verts),'triangles':len(faces)})
    return meshes,{'nominal_stride':2,'sampled_shape':list(volume.shape),
                   'actual_min_step_mm':[float(np.diff(v).min()) for v in a],
                   'actual_max_step_mm':[float(np.diff(v).max()) for v in a],
                   'preserved_region_peak_indices':protected,'method':'native point subsampling plus band extrema and endpoints; not max pooling or full-resolution geometry'}


def load_case(kind,reference):
    stem=SOURCE/f'fine_{kind}'; path=stem.with_suffix('.mat')
    before=sha256(path)
    report=json.loads(stem.with_suffix('.json').read_text(encoding='utf-8-sig'))
    p,axes=read_pressure(path)
    if p.shape!=(300,200,600): raise ValueError('Expected saved wide-grid 52 um data.')
    peaks=region_peaks(p,axes)
    # Independently compare the saved near-target and forward-domain pressure maxima.
    np.testing.assert_allclose(peaks['deep']['xyz_mm'],np.asarray(report['metrics']['near_target_peak_xyz_m'])*1000,atol=1e-8)
    np.testing.assert_allclose(peaks['deep']['pressure_pa_assumed'],report['metrics']['near_target_peak_pa_assumed'],rtol=1e-12)
    pz=np.flatnonzero(axes[2]>=2-1e-9); v=p[:,:,pz]
    np.testing.assert_allclose(v.max(),report['metrics']['forward_peak_pa_assumed'],rtol=1e-12)
    target=np.asarray(report['source']['target_m'])*1000
    target_ids=[int(abs(a-v).argmin()) for a,v in zip(axes,target)]
    protected=[q['index_xyz'] for q in peaks.values()]+[target_ids]
    meshes,sampling=mesh_data(p,axes,reference,protected)
    zi=np.flatnonzero(axes[2]>1e-9); iy=int(abs(axes[1]).argmin()); ix=int(abs(axes[0]).argmin())
    xi=sample_indices(len(axes[0]),2,[q[0] for q in protected]); yi=sample_indices(len(axes[1]),2,[q[1] for q in protected])
    depth=sample_indices(len(axes[2]),8,[q[2] for q in protected]);depth=depth[axes[2][depth]>1e-9]
    depth=np.unique([zi[0],*depth,zi[-1]])
    regions=[{'id':name,**q} for name,q in peaks.items()]
    case={'id':kind,'label':'偶数32元' if kind=='even32' else '全64元 等B 离线候选',
          'source_mat':str(path.relative_to(ROOT)).replace('\\','/'),'source_sha256':before,
          'axes_mm':[a.tolist() for a in axes],'shape_xyz':list(p.shape),'regions':regions,
          'target_requested_mm':target.tolist(),'target_sampled_mm':[float(a[i]) for a,i in zip(axes,target_ids)],
          'target_sampled_pressure_pa':float(p[tuple(target_ids)]),'reference_pa':reference,
          'meshes':meshes,'mesh_sampling':sampling,
          'xz':{'x':axes[0].tolist(),'z':axes[2][zi].tolist(),'p':np.round(p[:,iy,zi].T,6).tolist(),'y_mm':float(axes[1][iy])},
          'yz':{'y':axes[1].tolist(),'z':axes[2][zi].tolist(),'p':np.round(p[ix,:,zi],6).tolist(),'x_mm':float(axes[0][ix])},
          'xy':{'x':axes[0][xi].tolist(),'y':axes[1][yi].tolist(),'z':axes[2][depth].tolist(),
                'p':np.round(p[np.ix_(xi,yi,depth)].transpose(2,1,0),6).tolist(),
                'nominal_xy_stride':2,'nominal_depth_stride':8},
          'solver':report['solver'] if 'solver' in report else 'kspaceFirstOrder3D / k-Wave 1.4.1',
          'budget_pa2_s_m2':report['source']['widegrid_budget']['actual_budget_pa2_s_m2']}
    assert sha256(path)==before, 'Read-only export changed input.'
    return case


def export():
    OUT.mkdir(parents=True,exist_ok=True)
    common=json.loads((SOURCE/'fine_even32.json').read_text(encoding='utf-8-sig'))['metrics']['near_target_peak_pa_assumed']
    cases=[load_case(kind,common) for kind in ('even32','full64_matched')]
    # All case switches retain the same absolute reference and color limits.
    payload={'cases':cases,'common_reference_pa':common,'field':'max_t |p|',
             'color_max_pa':3.,'z_min_exclusive_mm':0,'date':'2026-10-24',
             'geometry_provenance':'existing_code_unverified','medium_source_provenance':'assumed',
             'physical_validation':'unknown','numerical_convergence':'not_established'}
    raw=json.dumps(payload,separators=(',',':'),ensure_ascii=False,allow_nan=False).encode()
    encoded=base64.b64encode(gzip.compress(raw,compresslevel=6,mtime=0)).decode()
    template=(ROOT/'widefield_viewer.html').read_text(encoding='utf-8')
    html=template.replace('__PLOTLY_JS__',get_plotlyjs()).replace('__PAYLOAD_GZIP_BASE64__',encoded)
    path=OUT/'widefield_pressure_3d.html';path.write_text(html,encoding='utf-8')
    summary={k:v for k,v in payload.items() if k!='cases'}
    summary.update({'cases':[{k:v for k,v in c.items() if k not in ('xz','yz','xy','meshes','axes_mm')} for c in cases],
                    'html_bytes':path.stat().st_size,'uncompressed_payload_bytes':len(raw),
                    'mesh_counts':[[{'db':m['db'],'vertices':m['vertices'],'triangles':m['triangles'],'touches_display_boundary':m['touches_display_boundary']} for m in c['meshes']] for c in cases],
                    'html_sha256':sha256(path),'source_mats_unchanged':True,'solver_rerun':False,
                    'xz_yz_sampling':'native full-resolution y=0 / x=0 sections; pressure rounded to 1e-6 Pa',
                    'xy_sampling':'native strided x/y (nominal 104 um), depth planes (nominal 416 um); extra native region-peak / target / endpoint coordinates',
                    'surface_sampling':'native strided 3D grid (nominal 104 um); preserves band extrema / target / endpoints; physical interpolation of mesh vertices',
                    'excluded_source_plane':'z<=0 excluded from forward visualization; saved source/back buffer retained in original MAT',
                    'is_not':'not a simultaneous snapshot, time animation, Qp, heat, cure, real probe measurement or full convergence proof'})
    (OUT/'viewer_summary.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2),encoding='utf-8')
    with (OUT/'region_peaks.csv').open('w',encoding='utf-8-sig',newline='') as f:
        writer=csv.writer(f);writer.writerow(['case','region','x_mm','y_mm','z_mm','peak_pressure_pa_assumed','on_search_boundary'])
        for c in cases:
            for r in c['regions']:writer.writerow([c['id'],r['id'],*r['xyz_mm'],r['pressure_pa_assumed'],r['on_search_boundary']])
    print(json.dumps({'html':str(path),'bytes':path.stat().st_size,'cases':len(cases),'mesh_counts':summary['mesh_counts']},ensure_ascii=True))
    return path


if __name__=='__main__':
    sys.stdout.reconfigure(encoding='utf-8')
    export()
