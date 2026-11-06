"""Read back actual k-Wave MAT volumes and independently check saved metrics."""
from pathlib import Path
import hashlib
import json
import h5py
import numpy as np


def audit() -> dict:
    root = Path(__file__).resolve().parent
    out = root / 'results' / 'kwave_oddeven'
    records = []
    for stem in sorted(out.glob('even32_focus20mm_dx*um.json')):
        report = json.loads(stem.read_text(encoding='utf-8-sig'))
        with h5py.File(stem.with_suffix('.mat'), 'r') as f:
            p = np.asarray(f['p_peak_pa']).transpose(2, 1, 0)
            pmax = np.asarray(f['data/p_max_all']).transpose(2, 1, 0)
            pmin = np.asarray(f['data/p_min_all']).transpose(2, 1, 0)
            axes = [np.asarray(f[key]).ravel() for key in ('x_m', 'y_m', 'z_m')]
            times = np.asarray(f['t_s']).ravel()
            traces = np.asarray(f['data/p']).T
            sensor_xyz = np.asarray(f['sensor_coordinates_m']).T
        assert p.shape == tuple(report['grid_size'])
        assert all(np.isfinite(a).all() and np.all(np.diff(a) > 0) for a in axes)
        assert np.isfinite(p).all() and np.all(p >= 0)
        assert np.array_equal(p, np.maximum(np.abs(pmax), np.abs(pmin)))
        assert traces.shape == (4, report['Nt']) and len(times) == report['Nt']
        assert np.isfinite(traces).all() and np.max(traces) > 0 and np.min(traces) < 0
        assert sensor_xyz.shape == (4, 3)
        forward = np.where(axes[2] >= .002)[0]
        field = p[:, :, forward]
        index = list(np.unravel_index(np.argmax(field), field.shape))
        index[2] = forward[index[2]]
        xyz = np.array([axis[i] for axis, i in zip(axes, index)])
        error = np.linalg.norm(xyz - report['source']['target_m'])
        assert np.allclose(xyz, report['metrics']['forward_peak_xyz_m'], atol=1e-12, rtol=0)
        assert abs(error - report['metrics']['forward_peak_error_m']) < 1e-12
        source = Path(report['source']['input_mat'])
        assert hashlib.sha256(source.read_bytes()).hexdigest() == report['source']['input_sha256']
        records.append({'file': stem.with_suffix('.mat').name, 'grid_size': list(p.shape),
                        'finite_volume': True, 'peak_volume_matches_signed_extrema': True,
                        'sensor_time_shape': list(traces.shape),
                        'independent_peak_xyz_m': xyz.tolist(), 'independent_peak_error_m': float(error),
                        'input_mat_hash_matches': True})
    assert records, 'No completed pressure volumes found.'
    before = json.loads((out / 'setup_hashes_before.json').read_text(encoding='utf-8-sig'))
    hashes = [{'path': item['path'],
               'matches': hashlib.sha256(Path(item['path']).read_bytes()).hexdigest().lower() == item['sha256'].lower()}
              for item in before]
    assert all(item['matches'] for item in hashes), 'A preserved SetUp file changed.'
    result = {'date': '2026-10-19', 'completed_volumes_checked': len(records),
              'records': records, 'setup_hashes': hashes, 'setup_preserved': True,
              'scope': 'Saved-volume integrity and independent numerical metric calculation; not physical calibration.'}
    (out / 'artifact_validation.json').write_text(json.dumps(result, indent=2), encoding='utf-8')
    return result


if __name__ == '__main__':
    result = audit()
    print(json.dumps({'volumes_checked': result['completed_volumes_checked'],
                      'setup_preserved': result['setup_preserved']}))
