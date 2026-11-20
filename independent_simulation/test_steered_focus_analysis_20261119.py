"""Analytic pressure-amplitude geometry checks (synthetic, uncalibrated)."""
import importlib.util
import json
from pathlib import Path
import shutil
import uuid
import unittest
from unittest.mock import patch

import h5py
import numpy as np

MODULE = Path(__file__).with_name('analyze_steered_focus_20261119.py')


class FocusAnalysisTests(unittest.TestCase):
    def setUp(self):
        self.assertTrue(MODULE.exists(), 'steered focus analysis implementation is missing')
        spec = importlib.util.spec_from_file_location('focus_analysis', MODULE)
        self.mod = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(self.mod)

    def gaussian(self, angle=30, zmax=0.028):
        x = np.arange(-0.008, 0.00801, 0.0002)
        y = np.arange(-0.004, 0.00401, 0.0002)
        z = np.arange(0, zmax + 0.00001, 0.0002)
        target = np.array([0., 0., 0.018])
        a = np.deg2rad(angle)
        X,Y,Z = np.meshgrid(x,y,z,indexing='ij')
        n = X*np.sin(a)+(Z-target[2])*np.cos(a)
        u = X*np.cos(a)-(Z-target[2])*np.sin(a)
        p = np.exp(-0.5*((n/.002)**2+(u/.001)**2+(Y/.0008)**2))
        return p,x,y,z,target

    def test_rotated_gaussian_width_and_connected_volume(self):
        p,x,y,z,target = self.gaussian()
        result = self.mod.analyze_arrays(p,x,y,z,target,30)
        self.assertFalse(result['local_peak_roi_boundary'])
        for db in (3,6):
            metrics = result[f'minus{db}db']
            factor = 2*np.sqrt(db*np.log(10)/10)
            for key,sigma in [('n',2),('u',1),('y',.8)]:
                self.assertAlmostEqual(metrics[f'width_{key}_mm'],factor*sigma,delta=.04)
            expected_volume = 4*np.pi/3 * (factor/2)**3 * 2*.8
            self.assertAlmostEqual(metrics['volume_mm3'],expected_volume,delta=.2)
            self.assertFalse(metrics['truncated'])

    def test_higher_disconnected_lobe_does_not_replace_local_peak(self):
        p,x,y,z,target = self.gaussian(0)
        X,Y,Z = np.meshgrid(x,y,z,indexing='ij')
        p = np.maximum(p, 2*np.exp(-((X-.007)**2+Y**2+(Z-.006)**2)/(2*.0004**2)))
        result = self.mod.analyze_arrays(p,x,y,z,target,0)
        self.assertAlmostEqual(result['local_peak_pa_assumed'],1)
        self.assertAlmostEqual(result['forward_max_pa_assumed'],2)
        np.testing.assert_allclose(result['peak_xyz_mm'], target*1000,atol=1e-8)
        self.assertLess(result['minus6db']['bbox_xyz_max_mm'][0],2)

    def test_clipped_focus_has_nan_axial_width_and_truncation(self):
        p,x,y,z,target = self.gaussian(0,zmax=.019)
        result = self.mod.analyze_arrays(p,x,y,z,target,0)
        m = result['minus6db']
        self.assertTrue(m['touches_domain_boundary'])
        self.assertTrue(m['truncated'])
        self.assertTrue(np.isnan(m['width_n_mm']))

    def test_roi_boundary_and_forward_boundary_are_flagged(self):
        x = y = np.arange(-.002,.0021,.0002)
        z = np.arange(0,.0161,.0002)
        p = np.broadcast_to(z,(len(x),len(y),len(z))).copy()
        r = self.mod.analyze_arrays(p,x,y,z,[0,0,.006],0)
        self.assertTrue(r['local_peak_roi_boundary'])
        self.assertFalse(r['focal_peak_valid'])
        p[:] = 1
        r = self.mod.analyze_arrays(p,x,y,z,[0,0,.006],0)
        self.assertTrue(r['minus6db']['touches_forward_boundary'])

    def test_zero_pressure_in_local_search_is_rejected(self):
        p,x,y,z,target = self.gaussian(0)
        p[:] = 0
        p[0,0,0] = 1
        with self.assertRaisesRegex(ValueError,'local search'):
            self.mod.analyze_arrays(p,x,y,z,target,0)

    def test_diagonal_only_voxel_is_not_in_six_connected_component(self):
        x = y = np.arange(-.003,.0031,.001)
        z = np.arange(0,.0121,.001)
        p = np.zeros((len(x),len(y),len(z)))
        p[3,3,7] = 1
        p[4,4,8] = .8
        r = self.mod.analyze_arrays(p,x,y,z,[0,0,.007],0)
        self.assertEqual(r['minus6db']['voxel_count'],1)
        self.assertEqual(r['minus3db']['voxel_count'],1)

    def test_negative_angle_mirrors_geometry(self):
        args = self.gaussian(30)
        plus = self.mod.analyze_arrays(*args,30)
        minus = self.mod.analyze_arrays(*self.gaussian(-30),-30)
        for db in (3,6):
            for key in ('volume_mm3','width_n_mm','width_u_mm','width_y_mm',
                        'component_center_span_n_mm','component_center_span_u_mm'):
                self.assertAlmostEqual(plus[f'minus{db}db'][key],minus[f'minus{db}db'][key],places=8)

    def test_no_full_domain_where_or_argwhere_temporaries(self):
        p,x,y,z,target = self.gaussian(0)
        original_where,original_argwhere = np.where,np.argwhere
        def bounded_where(*args):
            result = original_where(*args)
            if isinstance(result,np.ndarray):
                self.assertLess(result.size,p.size,'full-domain np.where allocation')
            return result
        def bounded_argwhere(array):
            self.assertLess(array.size,p.size,'full-domain argwhere allocation')
            return original_argwhere(array)
        with patch.object(self.mod.np,'where',side_effect=bounded_where), patch.object(self.mod.np,'argwhere',side_effect=bounded_argwhere):
            self.mod.analyze_arrays(p,x,y,z,target,0)

    def test_common_threshold_shrinks_and_disappears_with_peak_amplitude(self):
        p,x,y,z,target = self.gaussian(0)
        relative = [self.mod.analyze_arrays(p*scale,x,y,z,target,0) for scale in (1,.8,.4)]
        for result in relative[1:]:
            self.assertEqual(result['minus6db']['voxel_count'],relative[0]['minus6db']['voxel_count'])
        thresholds = {3:10**(-3/20),6:10**(-6/20)}
        common = [self.mod.analyze_common_thresholds(p*scale,(x,y,z),result['peak_xyz_mm'],0,thresholds)
                  for scale,result in zip((1,.8,.4),relative)]
        self.assertGreater(common[0]['common_minus6db']['volume_mm3'],common[1]['common_minus6db']['volume_mm3'])
        self.assertGreater(common[1]['common_minus6db']['volume_mm3'],0)
        for db in (3,6):
            self.assertEqual(common[2][f'common_minus{db}db']['status'],'below_threshold')
            self.assertEqual(common[2][f'common_minus{db}db']['voxel_count'],0)
            self.assertEqual(common[2][f'common_minus{db}db']['volume_mm3'],0)

    def test_rotated_target_plane_area_width_and_below_threshold(self):
        p,x,y,z,target = self.gaussian(30)
        plane = self.mod.analyze_target_plane(p,(x,y,z),target,30,1.)
        for db in (3,6):
            m = plane[f'minus{db}db']
            radius_factor = np.sqrt(db*np.log(10)/10)
            self.assertAlmostEqual(m['area_mm2'],np.pi*radius_factor**2*.8,delta=.1)
            self.assertAlmostEqual(m['width_u_mm'],2*radius_factor,delta=.04)
            self.assertAlmostEqual(m['width_y_mm'],2*radius_factor*.8,delta=.04)
            self.assertFalse(m['truncated'])
        off_target = target+np.array([.004,0,0])
        plane = self.mod.analyze_target_plane(p,(x,y,z),off_target,30,1.)
        self.assertEqual(plane['minus6db']['status'],'below_threshold')
        self.assertEqual(plane['minus6db']['area_mm2'],0)

    def test_target_plane_constant_field_is_marked_clipped(self):
        p,x,y,z,target = self.gaussian(0)
        plane = self.mod.analyze_target_plane(np.ones_like(p),(x,y,z),target,0,1.)
        m = plane['minus6db']
        self.assertTrue(m['touches_sampling_boundary'])
        self.assertTrue(m['touches_physical_boundary'])
        self.assertTrue(m['truncated'])
        self.assertTrue(np.isnan(m['width_u_mm']))
        self.assertFalse(m['valid_target_plane_region'])

    def test_common_target_plane_area_shrinks_with_amplitude(self):
        p,x,y,z,target = self.gaussian(30)
        planes = [self.mod.analyze_target_plane(p*scale,(x,y,z),target,30,1.) for scale in (1,.8,.4)]
        self.assertGreater(planes[0]['minus6db']['area_mm2'],planes[1]['minus6db']['area_mm2'])
        self.assertGreater(planes[1]['minus6db']['area_mm2'],0)
        self.assertEqual(planes[2]['minus6db']['area_mm2'],0)
        self.assertEqual(planes[2]['minus6db']['status'],'below_threshold')

    def test_matlab_hdf5_axis_reversal_and_cli_artifacts(self):
        p,x,y,z,target = self.gaussian(0)
        tmp = MODULE.parent / ('focus_analysis_test_' + uuid.uuid4().hex)
        tmp.mkdir()
        try:
            inp = Path(tmp)/'input'; inp.mkdir()
            out = Path(tmp)/'output'
            with h5py.File(inp/'angle0_field.mat','w') as f:
                f['p_amp'] = p.transpose(2,1,0)
                for key,value in [('x_m',x),('y_m',y),('z_m',z),('target_m',target),('angle_deg',[0])]:
                    f[key] = np.asarray(value).reshape(-1,1)
            with h5py.File(inp/'angle10_field.mat','w') as f:
                f['p_amp'] = (p*.4).transpose(2,1,0)
                for key,value in [('x_m',x),('y_m',y),('z_m',z),('target_m',target),('angle_deg',[10])]:
                    f[key] = np.asarray(value).reshape(-1,1)
            self.mod.run_analysis(inp,out)
            for name in ['summary.csv','analysis_manifest.json','xz_maps.png','profiles.png','metrics_vs_angle.png','target_plane_maps.png','target_area_vs_angle.png']:
                self.assertTrue((out/name).is_file(),name)
            manifest = json.loads((out/'analysis_manifest.json').read_text())
            result = manifest['results'][0]
            np.testing.assert_allclose(result['peak_xyz_mm'],target*1000,atol=1e-8)
            self.assertAlmostEqual(result['target_over_zero_deg'],1)
            self.assertEqual(len(manifest['source_sha256']['angle0_field.mat']),64)
            self.assertIn('disconnected',manifest['settings']['xz_contours'])
            self.assertEqual(result['common_minus6db']['voxel_count'],result['minus6db']['voxel_count'])
            self.assertAlmostEqual(result['common_minus6db']['width_n_mm'],result['minus6db']['width_n_mm'])
            reduced = manifest['results'][1]
            self.assertGreater(reduced['target_plane']['minus6db']['area_mm2'],0)
            self.assertEqual(reduced['common_target_plane']['minus6db']['area_mm2'],0)
            self.assertEqual(reduced['common_target_plane']['minus6db']['status'],'below_threshold')
            self.assertEqual(reduced['common_minus6db']['width_n_mm'],0)
        finally:
            shutil.rmtree(tmp)


if __name__ == '__main__':
    unittest.main()
