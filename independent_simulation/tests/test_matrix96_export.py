"""Check MATLAB-HDF axis ordering with an asymmetric, identifiable field."""
import importlib.util
from pathlib import Path
import tempfile
import unittest
import json
import h5py
import numpy as np

SPEC = importlib.util.spec_from_file_location('matrixview', Path(__file__).parents[1]/'export_matrix96_view.py')
VIEW = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(VIEW)


class MatrixExportTest(unittest.TestCase):
    def test_matlab_axis_order_and_partition_labels(self):
        with tempfile.TemporaryDirectory(dir=Path(__file__).parents[1]/'tmp') as folder:
            old = VIEW.ROOT
            VIEW.ROOT = Path(folder)
            try:
                p = np.zeros((4, 6, 8), np.float32)
                p[1, 3, 5] = 7
                (VIEW.ROOT/'left_dx64.0um.json').write_text(json.dumps({'partition': 'left'}))
                with h5py.File(VIEW.ROOT/'left_dx64.0um.mat', 'w') as f:
                    f['peak_abs'] = p.transpose(2, 1, 0)
                    for key, n in [('x', 4), ('y', 6), ('z', 8)]:
                        f[key] = np.arange(n)[None, :]
                    f['m/positions_m'] = np.array([[-1., 1.], [0., 0.], [0., 0.]])
                    f['m/active'] = np.array([[1, 0]])
                r, field, axes, pos, active = VIEW.load('left')
                self.assertEqual(np.unravel_index(np.argmax(field), field.shape), (1, 3, 5))
                self.assertEqual(r['partition'], 'left')
                self.assertEqual([len(v) for v in axes], [4, 6, 8])
                self.assertEqual(pos[active, 0].tolist(), [-1.])
            finally:
                VIEW.ROOT = old


if __name__ == '__main__':
    unittest.main()
