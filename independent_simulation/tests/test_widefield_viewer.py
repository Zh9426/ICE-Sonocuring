"""Scientific export guards: non-cubic axes, peak preservation and honest scales."""
import importlib.util
from pathlib import Path
import sys
import uuid
import h5py
import numpy as np
import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))


def viewer():
    assert importlib.util.find_spec('export_widefield_view') is not None, 'wide-field exporter not implemented'
    import export_widefield_view
    return export_widefield_view


@pytest.fixture
def h5_path():
    directory=Path(__file__).resolve().parents[1]/'tmp'
    directory.mkdir(exist_ok=True)
    path=directory/('viewer_test_'+uuid.uuid4().hex+'.h5')
    yield path
    if path.exists(): path.unlink()


def test_matlab_zyx_is_decoded_to_xyz_without_cubic_shape_assumption(h5_path):
    m=viewer()
    axes=[np.array([-1.,0.,1.])*1e-3,np.arange(4)*2e-3,np.arange(5)*3e-3]
    p=np.arange(60,dtype=float).reshape(3,4,5)
    path=h5_path
    with h5py.File(path,'w') as f:
        f['p_peak_pa']=p.transpose(2,1,0)
        for k,a in zip(('x_m','y_m','z_m'),axes): f[k]=a[None,:]
    got, xyz=m.read_pressure(path)
    np.testing.assert_array_equal(got,p)
    for a,b in zip(axes,xyz): np.testing.assert_array_equal(a*1000,b)


def test_depth_bands_exclude_source_plane_and_keep_shallow_peak():
    m=viewer()
    axes=[np.array([-6.,0.,6.]),np.array([-1.,0.,1.]),np.array([0.,.1,2.,4.,18.46,20.02])]
    p=np.ones((3,3,6));p[0,0,0]=100;p[0,1,1]=5;p[2,1,2]=4;p[1,1,4]=3
    b=m.region_peaks(p,axes)
    assert b['near_source']['pressure_pa_assumed']==5
    assert b['shallow']['xyz_mm']==[6.,0.,2.]
    assert b['shallow']['on_search_boundary'] is True
    assert b['deep']['xyz_mm']==[0.,0.,18.46]
    assert b['forward']['pressure_pa_assumed']==5


def test_display_sampling_preserves_endpoints_and_protected_peak_indices():
    m=viewer()
    indices=m.sample_indices(12,4,[3,7])
    np.testing.assert_array_equal(indices,[0,3,4,7,8,11])
    verts=np.array([[1.5,0.,2.]])
    axes=[np.array([0.,1.,3.]),np.array([2.,4.]),np.array([0.,.5,2.])]
    np.testing.assert_allclose(m.vertex_coordinates(verts,axes),[[2.,2.,2.]])


def test_shared_db_reference_does_not_normalize_each_case_to_own_peak():
    m=viewer()
    np.testing.assert_allclose(m.pressure_db(np.array([1.,2.]),2.),[-6.020599913,0.])
    with pytest.raises(ValueError): m.pressure_db([1.],0)


def test_invalid_or_permuted_axes_are_rejected(h5_path):
    m=viewer(); path=h5_path
    with h5py.File(path,'w') as f:
        f['p_peak_pa']=np.ones((5,4,3))
        f['x_m']=[0.,2.,1.]; f['y_m']=np.arange(4); f['z_m']=np.arange(5)
    with pytest.raises(ValueError,match='increasing'): m.read_pressure(path)
