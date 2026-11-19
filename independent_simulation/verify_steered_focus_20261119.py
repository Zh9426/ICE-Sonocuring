"""Independent saved-input and raw CUDA-to-MAT readback for the steering study.

Does not run a solver. Raw arrays remain local; writes small audit tables.
"""
import argparse
import csv
import hashlib
import json
from pathlib import Path

import h5py
import numpy as np
from scipy.io import loadmat
from scipy.interpolate import interp1d


def sha256(path):
    digest = hashlib.sha256()
    with path.open('rb') as stream:
        for block in iter(lambda: stream.read(8 * 1024 * 1024), b''):
            digest.update(block)
    return digest.hexdigest()


def main(folder):
    folder = Path(folder)
    rows, input_rows, profiles = [], [], {}
    reference_input,reference_source,reference_axes = None,None,None
    for mat in sorted(folder.glob('*_field.mat')):
        tag = mat.name.removesuffix('_field.mat')
        driver = folder / (tag.removesuffix('_dx52') + '_simulation_input.mat')
        io = folder / (tag + '_gpu_io')
        s = loadmat(driver, simplify_cells=True)
        angle = float(s['synthetic_angle_deg'])
        target = np.asarray(s['synthetic_target_m'])
        c = float(s['Resource']['Parameters']['speedOfSound'])
        frequency = float(s['Trans']['frequency']) * 1e6
        scale = c / frequency if s['Trans']['units'] == 'wavelengths' else 1e-3
        positions = np.asarray(s['Trans']['ElementPos'])[:, :3] * scale
        delay = np.asarray(s['TX']['Delay']) / frequency
        expected_target = np.array([np.sin(np.deg2rad(angle)), 0, np.cos(np.deg2rad(angle))]) * .02
        assert np.allclose(target, expected_target, rtol=0, atol=1e-14)
        assert np.allclose(np.asarray(s['ICEConfig']['exposure']['foci_mm']) * .001, target, atol=1e-14)
        assert np.all(np.asarray(s['TX']['Apod']) == 1) and len(delay) == 64
        arrival = delay + np.linalg.norm(positions - target, axis=1) / c
        assert np.ptp(arrival) < 1e-12
        with h5py.File(io / 'field_input.h5') as inp:
            assert int(np.asarray(inp['p_source_mode']).item()) == 2
            assert int(np.asarray(inp['p_source_many']).item()) == 1
            common={k:np.asarray(inp[k]).item() for k in
                    ('Nx','Ny','Nz','Nt','dt','dx','dy','dz','c0','rho0','pml_x_size','pml_y_size','pml_z_size')}
            source_index=np.asarray(inp['p_source_index']).ravel()
            assert (common['Nx'],common['Ny'],common['Nz']) == (640,160,640)
            assert common['c0']==1540 and common['rho0']==1000
            assert all(common[k]==20 for k in ('pml_x_size','pml_y_size','pml_z_size'))
            assert all(abs(common[k]-52e-6)<1e-12 for k in ('dx','dy','dz'))
            if reference_input is None:
                reference_input,reference_source=common,source_index
            else:
                assert common==reference_input, 'Common grid/time/medium/PML parameters differ'
                assert np.array_equal(source_index,reference_source), 'Source support differs'
        input_rows.append(dict(angle_deg=angle, range_mm=np.linalg.norm(target)*1000,
                               arrival_spread_s=np.ptp(arrival), active_elements=64,
                               driver_sha256=sha256(driver)))
        with h5py.File(mat) as f, h5py.File(io / 'field_output.h5') as out:
            assert float(np.asarray(f['angle_deg']).item()) == angle
            assert np.allclose(np.asarray(f['target_m']).ravel(), target, rtol=0, atol=1e-14)
            binary_hash=''.join(chr(int(v)) for v in np.asarray(f['runtime_metadata/binary_sha256']).ravel())
            assert binary_hash=='806f20c2529c2454cef89badbfcc9c19c2360260236af5a4e98735a336899b09'
            # MATLAB stores long z chunks per x column. Loading each float32
            # array once avoids decompressing the same chunks for every z plane.
            amp, qp, final = (np.asarray(f[k]) for k in ('p_amp','qp','p_final'))
            nz, ny, nx = amp.shape
            assert qp.shape == final.shape == amp.shape
            pml = 20
            assert out['p_max_all'].shape == (nz + 2*pml, ny + 2*pml, nx + 2*pml)
            assert out['p_min_all'].shape == out['p_max_all'].shape
            dt, nt = float(np.asarray(f['dt_s']).item()), int(np.asarray(f['Nt']).item())
            rms = np.asarray(out['p_rms']).reshape(nz, ny, nx)
            max_amp_error = max_qp_error = max_final_error = 0.
            for iz in range(nz):
                crop = (iz+pml, slice(pml,pml+ny), slice(pml,pml+nx))
                expected = np.maximum(out['p_max_all'][crop], -out['p_min_all'][crop])
                observed_amp = amp[iz]
                assert np.all(np.isfinite(expected)) and np.all(np.isfinite(observed_amp))
                assert np.array_equal(observed_amp, expected), 'Pressure readback differs'
                max_amp_error = max(max_amp_error, float(np.max(np.abs(observed_amp - expected))))
                expected_q = np.asarray(rms[iz], dtype=np.float64)**2 * nt * dt
                observed_q, expected_q = qp[iz], expected_q.astype(np.float32)
                observed_final, expected_final = final[iz], out['p_final'][crop]
                assert np.all(np.isfinite(observed_q)) and np.all(np.isfinite(expected_q))
                assert np.all(np.isfinite(observed_final)) and np.all(np.isfinite(expected_final))
                assert np.array_equal(observed_q, expected_q), 'Qp readback differs'
                assert np.array_equal(observed_final, expected_final), 'Final frame readback differs'
                max_qp_error = max(max_qp_error, float(np.max(np.abs(observed_q - expected_q))))
                max_final_error = max(max_final_error, float(np.max(np.abs(observed_final - expected_final))))
            assert max_amp_error == max_qp_error == max_final_error == 0
            x, y, z = (np.asarray(f[k]).ravel() for k in ('x_m', 'y_m', 'z_m'))
            assert np.allclose(np.diff(x),52e-6) and np.allclose(np.diff(y),52e-6) and np.allclose(np.diff(z),52e-6)
            if reference_axes is None:
                reference_axes=(x,y,z)
            else:
                assert all(np.array_equal(a,b) for a,b in zip(reference_axes,(x,y,z)))
            ix, iy = int(np.argmin(abs(x))), int(np.argmin(abs(y)))
            profiles[angle] = (z, np.asarray(amp[:,iy,ix]))
            rows.append(dict(angle_deg=angle, amplitude_max_abs_difference=max_amp_error,
                             qp_max_abs_difference=max_qp_error, final_max_abs_difference=max_final_error,
                             Nt=nt, dt_s=dt, mat_sha256=sha256(mat),
                             output_h5_sha256=sha256(io/'field_output.h5')))
            del amp,qp,final,rms
    assert rows, 'No completed field files'
    for name, data in [('raw_readback.csv', rows), ('input_checks.csv', input_rows)]:
        with (folder/name).open('w',newline='',encoding='utf-8') as stream:
            writer=csv.DictWriter(stream,fieldnames=list(data[0])); writer.writeheader(); writer.writerows(data)
    audit=dict(completed_fields=len(rows), raw_readback='exact stored numeric equality of float32 fields',
               source_models='assumed; not calibrated', verifier_sha256=sha256(Path(__file__)),
               common_input_parameters=reference_input,common_source_points=int(len(reference_source)),
               common_source_support_equal=True,physical_coordinates_equal=True,
               common_solver_binary_sha256=binary_hash)
    results_root=next(parent for parent in (folder,*folder.parents) if parent.name=='results')
    old=results_root/'focus_depth_2026-11-14'/'focus20_axial_dx52.csv'
    if 0 in profiles and old.exists():
        prior=np.genfromtxt(old,delimiter=',',names=True)
        z,p=profiles[0]
        q=interp1d(z*1000,p,bounds_error=False,fill_value=np.nan)(prior['z_mm'])
        keep=(prior['z_mm']>=2)&np.isfinite(q)
        delta=q[keep]-prior['peak_pressure_assumed_pa'][keep]
        audit['zero_vs_old_axial_z_ge2_relative_l2']=float(np.linalg.norm(delta)/np.linalg.norm(prior['peak_pressure_assumed_pa'][keep]))
        audit['zero_vs_old_axial_max_abs_assumed_pa']=float(abs(delta).max())
    mirrors=[]
    for angle in (10,20,30):
        pos=folder/f'angle_p{angle:02d}_dx52_field.mat'
        neg=folder/f'angle_m{angle:02d}_dx52_field.mat'
        if not pos.exists() or not neg.exists():
            continue
        error2=norm2=0.
        with h5py.File(pos) as fp,h5py.File(neg) as fn:
            xp=np.asarray(fp['x_m']).ravel()
            assert np.allclose(xp[1:],-xp[:0:-1],rtol=0,atol=1e-14)
            positive,negative=np.asarray(fp['p_amp']),np.asarray(fn['p_amp'])
            for iz in range(positive.shape[0]):
                p=np.asarray(positive[iz,:,1:],dtype=np.float64)
                n=np.asarray(negative[iz,:,1:][:,::-1],dtype=np.float64)
                error2+=float(np.sum((p-n)**2)); norm2+=float(np.sum(p*p))
            del positive,negative
        mirrors.append(dict(angle_abs_deg=angle,pressure_mirror_relative_l2=float(np.sqrt(error2/norm2)),
                            scope='common x coordinates excluding unpaired first x plane'))
    audit['positive_negative_pressure_mirrors']=mirrors
    (folder/'verification_summary.json').write_text(json.dumps(audit,indent=2),encoding='utf-8')
    print(json.dumps(audit,indent=2))


if __name__ == '__main__':
    parser=argparse.ArgumentParser(); parser.add_argument('folder')
    main(parser.parse_args().folder)
