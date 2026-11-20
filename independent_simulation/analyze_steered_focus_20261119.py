"""Pressure-amplitude focal geometry for synthetic, uncalibrated ICE fields.

CLI: python analyze_steered_focus_20261119.py INPUT_FOLDER OUTPUT_FOLDER
MATLAB v7.3 input arrays are reversed to Python (x,y,z) order. No acoustic
calibration, intensity, thermal, cure or clinical-safety inference is performed.
"""
import argparse
import csv
import hashlib
import json
from pathlib import Path

import h5py
import numpy as np
from scipy import ndimage
from scipy.interpolate import RegularGridInterpolator


def _profile(interpolator, peak, direction, axes, forward_min_z_m):
    lower = np.array([a[0] for a in axes]); lower[2] = max(lower[2],forward_min_z_m)
    upper = np.array([a[-1] for a in axes])
    lo, hi = -np.inf, np.inf
    for k,d in enumerate(direction):
        if abs(d) > 1e-12:
            ends = sorted(((lower[k]-peak[k])/d,(upper[k]-peak[k])/d))
            lo,hi = max(lo,ends[0]),min(hi,ends[1])
    step = min(np.diff(a).min() for a in axes)/4
    # Include the peak exactly: nearest crossings must bracket that sample.
    s = np.unique(np.r_[np.linspace(lo,0,max(2,int(np.ceil(-lo/step))+1)),
                           np.linspace(0,hi,max(2,int(np.ceil(hi/step))+1))])
    values = interpolator(peak + s[:,None]*direction)
    return s,values


def _crossing_width(s, values, threshold):
    center = int(np.argmin(abs(s)))
    crossings = []
    for indices in (range(center-1,-1,-1),range(center+1,len(s))):
        previous = center
        crossing = np.nan
        for i in indices:
            if values[i] < threshold:
                crossing = s[previous] + (threshold-values[previous])*(s[i]-s[previous])/(values[i]-values[previous])
                break
            previous = i
        crossings.append(crossing)
    truncated = not np.all(np.isfinite(crossings))
    return (np.nan if truncated else (crossings[1]-crossings[0])*1000),truncated


def _component_geometry(p, axes, peak_index, threshold, directions, first_forward):
    x,y,z = axes
    spacing = [axis[1]-axis[0] for axis in axes]
    mask = p>=threshold
    mask[:,:,:first_forward] = False
    labels,_ = ndimage.label(mask,structure=ndimage.generate_binary_structure(3,1))
    del mask
    component_id = int(labels[peak_index])
    bounds = ndimage.find_objects(labels,max_label=component_id)[component_id-1]
    minimum = np.array([axes[k][bounds[k].start] for k in range(3)])
    maximum = np.array([axes[k][bounds[k].stop-1] for k in range(3)])
    boundary = any(bounds[k].start==0 or bounds[k].stop==len(axes[k]) for k in range(3))
    forward_boundary = bounds[2].start==first_forward
    count = 0
    projection_min = {key:np.inf for key in directions}
    projection_max = {key:-np.inf for key in directions}
    # Only selected-component bbox planes are materialized. Even a clipped
    # component spanning the domain never creates an Nx3 coordinate table.
    for ix in range(bounds[0].start,bounds[0].stop):
        iy,iz = np.nonzero(labels[ix,bounds[1],bounds[2]]==component_id)
        count += len(iy)
        if len(iy)==0:
            continue
        cy,cz = y[iy+bounds[1].start],z[iz+bounds[2].start]
        for key,d in directions.items():
            projected = x[ix]*d[0]+cy*d[1]+cz*d[2]
            projection_min[key] = min(projection_min[key],float(projected.min()))
            projection_max[key] = max(projection_max[key],float(projected.max()))
    del labels
    m = dict(threshold_pa_assumed=threshold,voxel_count=count,
             volume_mm3=float(count*np.prod(spacing)*1e9),
             bbox_xyz_min_mm=(minimum*1000).tolist(),
             bbox_xyz_max_mm=(maximum*1000).tolist(),
             bbox_xyz_center_span_mm=((maximum-minimum)*1000).tolist(),
             touches_domain_boundary=bool(boundary),touches_forward_boundary=forward_boundary,
             truncated=bool(boundary or forward_boundary),
             valid_focal_region=not bool(boundary or forward_boundary),status="component")
    for key,d in directions.items():
        m[f'component_center_span_{key}_mm'] = (projection_max[key]-projection_min[key])*1000
    return m


def analyze_arrays(p_amp, x_m, y_m, z_m, target_m, angle_deg,
                   local_radius_m=0.005, forward_min_z_m=0.002):
    """Analyze (x,y,z) pressure amplitudes; 6-connected, peak-anchored volumes.

    Threshold is relative to the highest voxel in a target-centered 5 mm ball,
    restricted to z >= 2 mm. Volume is occupied voxel count * dx*dy*dz;
    component extents are spans of voxel centers (explicitly not line widths).
    A ball-edge peak or any truncated component is flagged, never hidden.
    """
    axes = tuple(np.asarray(a,dtype=float).ravel() for a in (x_m,y_m,z_m))
    p = np.asarray(p_amp)
    if p.shape != tuple(len(a) for a in axes):
        raise ValueError('p_amp shape must match (len(x),len(y),len(z))')
    spacing = []
    for a in axes:
        d = np.diff(a)
        if len(d)==0 or np.any(d<=0) or not np.allclose(d,d[0],rtol=1e-5,atol=1e-12):
            raise ValueError('Volume requires uniformly spaced increasing axes')
        spacing.append(float(d[0]))
    # Plane-wise validation avoids full-domain boolean temporaries.
    if any(not np.all(np.isfinite(plane)) or np.any(plane<0) for plane in p) or p.max()<=0:
        raise ValueError('Pressure amplitude must be finite, nonnegative and nonzero')
    target = np.asarray(target_m,dtype=float).ravel()
    if target.shape != (3,):
        raise ValueError('target_m must have three elements')
    x,y,z = axes
    forward = z>=forward_min_z_m
    if not np.any(forward):
        raise ValueError('No forward-domain samples')
    first_forward = int(np.flatnonzero(forward)[0])
    # Search only the target's bounding subgrid, one yz plane at a time.
    ranges = [np.flatnonzero(abs(axis-target[k])<=local_radius_m) for k,axis in enumerate(axes)]
    ranges[2] = ranges[2][ranges[2]>=first_forward]
    if any(len(indices)==0 for indices in ranges):
        raise ValueError('Target search ball does not intersect forward domain')
    ys,zs = slice(ranges[1][0],ranges[1][-1]+1),slice(ranges[2][0],ranges[2][-1]+1)
    yz_distance2 = (y[ys]-target[1])[:,None]**2+(z[zs]-target[2])[None,:]**2
    best_value,peak_index = -np.inf,None
    for ix in ranges[0]:
        roi = yz_distance2+(x[ix]-target[0])**2 <= local_radius_m**2
        plane = np.where(roi,p[ix,ys,zs],-np.inf)
        index = np.unravel_index(np.argmax(plane),plane.shape)
        if plane[index] > best_value:
            best_value = float(plane[index])
            peak_index = (ix,index[0]+ys.start,index[1]+zs.start)
    if peak_index is None:
        raise ValueError('Target search ball does not intersect forward domain')
    peak = np.array([axes[k][peak_index[k]] for k in range(3)])
    peak_value = float(p[peak_index])
    if peak_value <= 0:
        raise ValueError('No positive pressure amplitude in local search ball')
    roi_boundary = (np.linalg.norm(peak-target) >= local_radius_m-np.linalg.norm(spacing)
                    or any(peak_index[k] in (0,len(axes[k])-1) for k in range(3))
                    or peak_index[2]==np.flatnonzero(forward)[0])
    del yz_distance2,roi,plane
    forward_value,forward_index = -np.inf,None
    for ix in range(len(x)):
        plane = p[ix,:,first_forward:]
        index = np.unravel_index(np.argmax(plane),plane.shape)
        if plane[index] > forward_value:
            forward_value = float(plane[index])
            forward_index = (ix,index[0],index[1]+first_forward)
    del plane
    a = np.deg2rad(angle_deg)
    directions = {'n':np.array([np.sin(a),0,np.cos(a)]),
                  'u':np.array([np.cos(a),0,-np.sin(a)]),'y':np.array([0,1,0])}
    interp = RegularGridInterpolator(axes,p,bounds_error=False,fill_value=np.nan)
    profiles = {key:_profile(interp,peak,d,axes,forward_min_z_m) for key,d in directions.items()}
    target_value = float(interp(target[None,:])[0])
    result = dict(angle_deg=float(angle_deg),target_xyz_mm=(target*1000).tolist(),
                  peak_xyz_mm=(peak*1000).tolist(),position_error_mm=float(np.linalg.norm(peak-target)*1000),
                  local_peak_pa_assumed=peak_value,target_pa_assumed=target_value,
                  target_over_local_peak=target_value/peak_value,
                  forward_max_pa_assumed=float(p[forward_index]),
                  forward_max_xyz_mm=[float(axes[k][forward_index[k]]*1000) for k in range(3)],
                  local_peak_roi_boundary=bool(roi_boundary),focal_peak_valid=not bool(roi_boundary))
    for db in (3,6):
        threshold = peak_value*10**(-db/20)
        m = _component_geometry(p,axes,peak_index,threshold,directions,first_forward)
        m['valid_focal_region'] &= not roi_boundary
        for key in directions:
            width,truncated = _crossing_width(*profiles[key],threshold)
            m[f'width_{key}_mm'],m[f'width_{key}_truncated'] = width,truncated
            m['truncated'] |= truncated
            m['valid_focal_region'] &= not truncated
        result[f'minus{db}db'] = m
    result['profiles'] = {key:dict(distance_mm=(s*1000).tolist(),pressure_pa_assumed=v.tolist()) for key,(s,v) in profiles.items()}
    return result


def read_field(path):
    with h5py.File(path,'r') as f:
        return (np.asarray(f['p_amp']).transpose(2,1,0),
                *(np.asarray(f[k]).ravel() for k in ('x_m','y_m','z_m','target_m')),
                float(np.asarray(f['angle_deg']).ravel()[0]))


def analyze_target_plane(p_amp, axes, target_m, angle_deg, local_peak_pa,
                         max_half_extent_m=0.005):
    """Sample F+u*t+y*v; 4-connected threshold area anchored at target.

    Uniform node area is dt*dv; extents are sample-center spans. The symmetric
    transverse half-extent is capped at 5 mm and by physical x/z limits.
    Elevation covers all physical y sample centers on a target-anchored grid.
    """
    axes = tuple(np.asarray(axis).ravel() for axis in axes)
    target = np.asarray(target_m,dtype=float).ravel()
    step = min(float(np.diff(axis).min()) for axis in axes)
    angle = np.deg2rad(angle_deg)
    u = np.array([np.cos(angle),0.,-np.sin(angle)])
    domain_cap = np.inf
    for k in (0,2):
        if abs(u[k])>1e-12:
            domain_cap = min(domain_cap,(target[k]-axes[k][0])/abs(u[k]),(axes[k][-1]-target[k])/abs(u[k]))
    cap = min(max_half_extent_m,domain_cap)
    if cap<=0 or not axes[1][0]<=target[1]<=axes[1][-1]:
        raise ValueError('Target plane center must lie inside physical domain')
    nt = max(1,int(np.ceil(cap/step)))
    t = np.linspace(-cap,cap,2*nt+1)
    v = np.arange(int(np.ceil((axes[1][0]-target[1])/step)),
                  int(np.floor((axes[1][-1]-target[1])/step))+1)*step
    center = (nt,int(np.argmin(abs(v))))
    T,V = np.meshgrid(t,v,indexing='ij')
    points = target+T[...,None]*u+V[...,None]*np.array([0.,1.,0.])
    physical = np.ones(T.shape,dtype=bool)
    for k,axis in enumerate(axes):
        physical &= (points[...,k]>=axis[0]-1e-12)&(points[...,k]<=axis[-1]+1e-12)
        points[...,k] = np.clip(points[...,k],axis[0],axis[-1])
    pressure = RegularGridInterpolator(axes,p_amp,bounds_error=False,fill_value=np.nan)(points)
    pressure[~physical] = np.nan
    dt,dv = float(t[1]-t[0]),step
    result = dict(transverse_half_extent_limit_mm=float(max_half_extent_m*1000),
                  transverse_half_extent_sampled_mm=float(cap*1000),sample_step_u_mm=dt*1000,
                  sampled_extent_u_mm=float(2*cap*1000),sampled_extent_y_mm=float((v[-1]-v[0])*1000),
                  transverse_sampling_limited_by_domain=bool(domain_cap<=max_half_extent_m),
                  sample_step_y_mm=dv*1000,u_range_mm=[float(t[0]*1000),float(t[-1]*1000)],
                  y_offset_range_mm=[float(v[0]*1000),float(v[-1]*1000)],
                  target_pressure_pa_assumed=float(pressure[center]),
                  plane_data=dict(u_mm=t*1000,y_offset_mm=v*1000,pressure_pa_assumed=pressure))
    for db in (3,6):
        threshold = local_peak_pa*10**(-db/20)
        m = dict(threshold_pa_assumed=float(threshold),area_mm2=0.,sample_count=0,
                 status='below_threshold',touches_sampling_boundary=False,
                 touches_physical_boundary=False,truncated=False,
                 valid_target_plane_region=False,
                 width_u_mm=np.nan,width_y_mm=np.nan,width_u_truncated=False,width_y_truncated=False)
        if pressure[center]>=threshold:
            labels,_ = ndimage.label((pressure>=threshold)&physical,structure=ndimage.generate_binary_structure(2,1))
            component = labels==labels[center]
            count = int(np.count_nonzero(component))
            border = bool(component[0,:].any() or component[-1,:].any() or component[:,0].any() or component[:,-1].any())
            # y endpoints cover the physical range within one step. The u ends
            # are physical only when the domain, rather than 5 mm, sets cap.
            physical_border = bool(component[:,0].any() or component[:,-1].any()
                                   or (domain_cap<=max_half_extent_m+1e-12
                                       and (component[0,:].any() or component[-1,:].any()))
                                   or np.any(ndimage.binary_dilation(component)&~physical))
            m.update(area_mm2=count*dt*dv*1e6,sample_count=count,status='component',
                     touches_sampling_boundary=border,touches_physical_boundary=physical_border,truncated=border or physical_border)
            for key,s,line in [('u',t,pressure[:,center[1]]),('y',v,pressure[center[0],:])]:
                width,clipped = _crossing_width(s,line,threshold)
                m[f'width_{key}_mm'],m[f'width_{key}_truncated'] = width,clipped
                m['truncated'] |= clipped
            m['valid_target_plane_region'] = not m['truncated']
        result[f'minus{db}db'] = m
    return result


def analyze_common_thresholds(p_amp, axes, peak_xyz_mm, angle_deg, thresholds,
                              forward_min_z_m=0.002):
    """Supplement own-peak shape metrics with common absolute pressure levels.

    thresholds maps positive dB magnitudes to assumed-Pa levels derived from
    the zero-degree local peak. An absent component has zero occupied volume;
    it is not evidence of target efficacy or a calibrated exposure endpoint.
    """
    p = np.asarray(p_amp)
    axes = tuple(np.asarray(axis).ravel() for axis in axes)
    peak_m = np.asarray(peak_xyz_mm)/1000
    peak_index = tuple(int(np.argmin(abs(axis-peak_m[k]))) for k,axis in enumerate(axes))
    first_forward = int(np.searchsorted(axes[2],forward_min_z_m))
    a = np.deg2rad(angle_deg)
    directions = {'n':np.array([np.sin(a),0,np.cos(a)]),
                  'u':np.array([np.cos(a),0,-np.sin(a)]),'y':np.array([0,1,0])}
    result = {}
    for db,threshold in thresholds.items():
        if not np.isfinite(threshold) or float(p[peak_index]) < threshold:
            missing_baseline = not np.isfinite(threshold)
            m = dict(threshold_pa_assumed=float(threshold),voxel_count=0,
                     volume_mm3=np.nan if missing_baseline else 0.,
                     status='baseline_unavailable' if missing_baseline else 'below_threshold',
                     bbox_xyz_min_mm=[np.nan]*3,bbox_xyz_max_mm=[np.nan]*3,
                     bbox_xyz_center_span_mm=[np.nan]*3,touches_domain_boundary=False,
                     touches_forward_boundary=False,truncated=False,valid_focal_region=False,
                     **{f'component_center_span_{key}_mm':np.nan for key in directions})
        else:
            m = _component_geometry(p,axes,peak_index,float(threshold),directions,first_forward)
        result[f'common_minus{db}db'] = m
    return result


def _sha256(path):
    digest = hashlib.sha256()
    with open(path,'rb') as stream:
        for chunk in iter(lambda:stream.read(8*1024*1024),b''):
            digest.update(chunk)
    return digest.hexdigest()


def _json_safe(value):
    if isinstance(value,dict):
        return {k:_json_safe(v) for k,v in value.items()}
    if isinstance(value,list):
        return [_json_safe(v) for v in value]
    if isinstance(value,float) and not np.isfinite(value):
        return None
    return value


def run_analysis(input_folder,output_folder):
    import matplotlib
    matplotlib.use('Agg')
    import matplotlib.pyplot as plt
    source = sorted(Path(input_folder).glob('*_field.mat'))
    if not source:
        raise ValueError('No *_field.mat inputs found')
    out = Path(output_folder); out.mkdir(parents=True,exist_ok=True)
    records,maps,hashes = [],[],{}
    for path in source:
        p,x,y,z,target,angle = read_field(path)
        r = analyze_arrays(p,x,y,z,target,angle)
        r['source_file'] = path.name
        records.append(r)
        # Small sagittal slice retained, never the raw 3-D array.
        maps.append((angle,x*1000,z*1000,p[:,np.argmin(abs(y)),:].copy(),target*1000,np.asarray(r['peak_xyz_mm'])))
        hashes[path.name] = _sha256(path)
        del p
    records.sort(key=lambda r:r['angle_deg']); maps.sort(key=lambda m:m[0])
    baseline = next((r['target_pa_assumed'] for r in records if abs(r['angle_deg'])<1e-9),np.nan)
    baseline_peak = next((r['local_peak_pa_assumed'] for r in records if abs(r['angle_deg'])<1e-9),np.nan)
    baseline_peak_valid = next((r['focal_peak_valid'] for r in records if abs(r['angle_deg'])<1e-9),False)
    common_thresholds = {db:baseline_peak*10**(-db/20) for db in (3,6)}
    # Sequential second pass retains a single raw field in memory.
    target_planes = []
    for r in records:
        p,x,y,z,_,angle = read_field(Path(input_folder)/r['source_file'])
        r.update(analyze_common_thresholds(p,(x,y,z),r['peak_xyz_mm'],angle,common_thresholds))
        target_plane = analyze_target_plane(p,(x,y,z),np.asarray(r['target_xyz_mm'])/1000,angle,r['local_peak_pa_assumed'])
        target_planes.append((angle,target_plane.pop('plane_data'),r['local_peak_pa_assumed']))
        r['target_plane'] = target_plane
        common_plane = analyze_target_plane(p,(x,y,z),np.asarray(r['target_xyz_mm'])/1000,angle,baseline_peak)
        common_plane.pop('plane_data')
        common_plane['reference_focal_peak_valid'] = baseline_peak_valid
        common_plane['reference_zero_deg_peak_pa_assumed'] = baseline_peak
        r['common_target_plane'] = common_plane
        for db in (3,6):
            r['target_plane'][f'minus{db}db']['valid_target_plane_region'] &= r['focal_peak_valid']
            common_metric = common_plane[f'minus{db}db']
            common_metric['valid_target_plane_region'] &= baseline_peak_valid and r['focal_peak_valid']
            if not np.isfinite(baseline_peak):
                common_metric.update(status='baseline_unavailable',area_mm2=np.nan)
        for db in (3,6):
            m=r[f'common_minus{db}db']
            m['valid_focal_region'] &= r['focal_peak_valid'] and baseline_peak_valid
            for key,profile in r['profiles'].items():
                if m['status']=='component':
                    width,clipped=_crossing_width(np.asarray(profile['distance_mm'])/1000,
                                                 np.asarray(profile['pressure_pa_assumed']),common_thresholds[db])
                else:
                    width=0. if m['status']=='below_threshold' else np.nan
                    clipped=False
                m[f'width_{key}_mm']=width
                m[f'width_{key}_truncated']=clipped
                m['truncated'] |= clipped
                m['valid_focal_region'] &= not clipped
        del p
    rows = []
    for r in records:
        r['target_over_zero_deg'] = r['target_pa_assumed']/baseline if baseline>0 else np.nan
        row = {k:v for k,v in r.items() if not isinstance(v,(dict,list))}
        for db in (3,6):
            row.update({f'minus{db}db_{k}':v for k,v in r[f'minus{db}db'].items() if not isinstance(v,list)})
            row.update({f'common_minus{db}db_{k}':v for k,v in r[f'common_minus{db}db'].items() if not isinstance(v,list)})
            row.update({f'target_plane_minus{db}db_{k}':v for k,v in r['target_plane'][f'minus{db}db'].items()})
            row.update({f'common_target_plane_minus{db}db_{k}':v for k,v in r['common_target_plane'][f'minus{db}db'].items()})
        row.update({f'target_plane_{k}':v for k,v in r['target_plane'].items() if not isinstance(v,(list,dict))})
        row.update({f'common_target_plane_{k}':v for k,v in r['common_target_plane'].items() if not isinstance(v,(list,dict))})
        for key in ('peak_xyz_mm','target_xyz_mm','forward_max_xyz_mm'):
            row.update({f'{key}_{axis}':v for axis,v in zip('xyz',r[key])})
        for db in (3,6):
            for key in ('bbox_xyz_min_mm','bbox_xyz_max_mm','bbox_xyz_center_span_mm'):
                row.update({f'minus{db}db_{key}_{axis}':v for axis,v in zip('xyz',r[f'minus{db}db'][key])})
        rows.append(row)
    with (out/'summary.csv').open('w',newline='',encoding='utf-8') as stream:
        writer=csv.DictWriter(stream,fieldnames=list(rows[0])); writer.writeheader(); writer.writerows(rows)
    manifest = dict(status='synthetic; pressure units assumed Pa; uncalibrated',
                    settings=dict(local_radius_mm=5,forward_min_z_mm=2,thresholds_db=[-3,-6],
                                  threshold_basis='pressure amplitude: peak * 10 ** (-dB / 20)',connectivity=6,
                                  common_absolute_threshold_basis='Zero-degree local peak * 10 ** (-dB / 20); supplemental peak-connected component, not exposure efficacy',
                                  common_absolute_thresholds_pa_assumed=common_thresholds,
                                  common_absolute_baseline_focal_peak_valid=baseline_peak_valid,
                                  target_plane='F+u*t+y*v, target centered; 4 connectivity; own-local-peak thresholds; area=count*dt*dv; sample-border components truncated',
                                  common_target_plane='Same target-normal plane and 4-connected target component, threshold derived from zero-degree local peak; supplemental common absolute level',
                                  volume='voxel_count * dx * dy * dz',bbox='occupied voxel center extrema',
                                  xz_contours='Scalar pressure threshold contours; include disconnected lobes, not selected focal component boundaries',
                                  profile_sampling='linear interpolation, step <= min grid spacing / 4',
                                  roi_boundary='within one voxel diagonal of ball edge, or physical/forward boundary',
                                  caution='Forward maximum can be source/near-field dominated. No intensity, cure or safety inference.'),
                    source_sha256=hashes,analysis_script_sha256=_sha256(Path(__file__)),results=records)
    (out/'analysis_manifest.json').write_text(json.dumps(_json_safe(manifest),indent=2,allow_nan=False),encoding='utf-8')
    plane_vmax = max(float(np.nanmax(plane['pressure_pa_assumed'])) for _,plane,_ in target_planes)
    fig,axs = plt.subplots(1,len(target_planes),figsize=(max(5,3*len(target_planes)),5),squeeze=False,constrained_layout=True)
    for ax,(angle,plane,local_peak) in zip(axs[0],target_planes):
        pressure = plane['pressure_pa_assumed']
        im = ax.pcolormesh(plane['u_mm'],plane['y_offset_mm'],pressure.T,
                          vmin=0,vmax=plane_vmax,cmap='inferno',shading='auto')
        levels = [local_peak*10**(-db/20) for db in (6,3)]
        usable = [level for level in levels if np.nanmin(pressure)<level<np.nanmax(pressure)]
        if usable:
            contours = ax.contour(plane['u_mm'],plane['y_offset_mm'],pressure.T,levels=usable,colors='cyan',linewidths=.7)
            ax.clabel(contours,fmt={levels[0]:'-6 dB',levels[1]:'-3 dB'},fontsize=6)
        ax.plot(0,0,'wx',label='Target'); ax.set(title=f'{angle:g} deg',xlabel='Transverse u from target (mm)',ylabel='Elevation from target (mm)')
        ax.set_aspect('equal'); ax.legend(fontsize=7)
    fig.colorbar(im,ax=list(axs[0]),label='Pressure amplitude (assumed Pa; uncalibrated)')
    fig.suptitle('Synthetic target-normal planes\nCommon absolute scale (uncalibrated)\nScalar contours: all regions; areas: target-connected only',fontsize=10)
    fig.savefig(out/'target_plane_maps.png',dpi=160); plt.close(fig)
    vmax = max(float(m[3].max()) for m in maps)
    fig,axs = plt.subplots(1,len(maps),figsize=(max(5,3*len(maps)),5),squeeze=False,constrained_layout=True)
    for ax,(angle,x,z,p,target,peak) in zip(axs[0],maps):
        im=ax.pcolormesh(x,z,p.T,vmin=0,vmax=vmax,shading='auto',cmap='inferno')
        r=next(r for r in records if r['angle_deg']==angle)
        levels=[r['local_peak_pa_assumed']*10**(-db/20) for db in (6,3)]
        contour=ax.contour(x,z,p.T,levels=levels,colors=['cyan','lime'],linewidths=.7)
        ax.clabel(contour,fmt={levels[0]:'-6 dB',levels[1]:'-3 dB'},fontsize=6)
        ax.plot(target[0],target[2],'cx',label='Target'); ax.plot(peak[0],peak[2],'w+',label='Local peak')
        ax.axhline(2,color='gray',linestyle=':'); ax.set(title=f'{angle:g} deg',xlabel='x (mm)',ylabel='z (mm)')
        ax.set_aspect('equal'); ax.legend(fontsize=7)
    fig.colorbar(im,ax=list(axs[0]),label='Pressure amplitude (assumed Pa; uncalibrated)')
    fig.suptitle('Synthetic ICE x-z slices, y nearest 0\nCommon absolute scale (uncalibrated)\nScalar contours include disconnected lobes',fontsize=10)
    fig.savefig(out/'xz_maps.png',dpi=160); plt.close(fig)
    fig,axs = plt.subplots(1,3,figsize=(14,4),constrained_layout=True)
    for ax,key,title in zip(axs,('n','u','y'),('Longitudinal n','Transverse u','Elevation y')):
        for r in records:
            profile=r['profiles'][key]
            ax.plot(profile['distance_mm'],np.asarray(profile['pressure_pa_assumed'])/r['local_peak_pa_assumed'],label=f"{r['angle_deg']:g} deg")
        for db in (3,6): ax.axhline(10**(-db/20),color='gray',linestyle=':')
        ax.set(title=title,xlabel='Distance from actual local peak (mm)',ylabel='Pressure / local peak')
        ax.legend(fontsize=7)
    fig.suptitle('Synthetic, uncalibrated pressure profiles through local peak')
    fig.savefig(out/'profiles.png',dpi=160); plt.close(fig)
    fig,axs=plt.subplots(1,3,figsize=(14,4),constrained_layout=True)
    angles=[r['angle_deg'] for r in records]
    for db in (3,6):
        axs[0].plot(angles,[r[f'minus{db}db']['volume_mm3'] for r in records],'o-',label=f'-{db} dB volume')
        axs[0].plot(angles,[r[f'common_minus{db}db']['volume_mm3'] for r in records],'x--',label=f'Common -{db} dB volume')
        for key in ('n','u','y'):
            axs[1].plot(angles,[r[f'minus{db}db'][f'width_{key}_mm'] for r in records],'o-',label=f'-{db} dB {key}')
    for r in records:
        if not r['minus6db']['valid_focal_region']:
            axs[0].annotate('INVALID / truncated', (r['angle_deg'],r['minus6db']['volume_mm3']),fontsize=6,rotation=60)
    axs[2].plot(angles,[r['target_over_zero_deg'] for r in records],'o-',label='Target / 0 deg target')
    axs[2].plot(angles,[r['target_over_local_peak'] for r in records],'s-',label='Target / local peak')
    for ax,label in zip(axs,('Component volume (mm3)','Peak-crossing width (mm)','Pressure amplitude ratio')):
        ax.set(xlabel='Steering angle (deg)',ylabel=label); ax.legend(fontsize=7); ax.grid(alpha=.2)
    fig.suptitle('Synthetic, uncalibrated focal geometry; clipped volumes are incomplete')
    fig.savefig(out/'metrics_vs_angle.png',dpi=160); plt.close(fig)
    fig,axs=plt.subplots(1,2,figsize=(11,4),constrained_layout=True)
    for db in (3,6):
        for key,style,label in [('target_plane','o-',f'-{db} dB relative to each peak'),
                                ('common_target_plane','s--',f'-{db} dB relative to 0 deg peak')]:
            axs[0].plot(angles,[r[key][f'minus{db}db']['area_mm2'] for r in records],style,label=label)
            for r in records:
                m=r[key][f'minus{db}db']
                if not m['valid_target_plane_region'] and m['status']!='below_threshold':
                    axs[0].annotate('incomplete / invalid',(r['angle_deg'],m['area_mm2']),fontsize=6,rotation=60)
        for key in ('u','y'):
            axs[1].plot(angles,[r['target_plane'][f'minus{db}db'][f'width_{key}_mm'] for r in records],
                        'o-',label=f'-{db} dB {key}, each peak')
    axs[0].set(ylabel='Target-connected area (mm2)')
    axs[1].set(ylabel='Width through nominal target (mm)')
    for ax in axs:
        ax.set(xlabel='Steering angle (deg)'); ax.legend(fontsize=7); ax.grid(alpha=.2)
    fig.suptitle('At 20 mm slant range: plane normal to nominal beam\nSynthetic, uncalibrated pressure; areas are not cure coverage',fontsize=11)
    fig.savefig(out/'target_area_vs_angle.png',dpi=160); plt.close(fig)
    return records


if __name__ == '__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('input_folder',type=Path); parser.add_argument('output_folder',type=Path)
    args=parser.parse_args()
    run_analysis(args.input_folder,args.output_folder)
