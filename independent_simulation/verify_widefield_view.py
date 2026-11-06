"""Independent HTML payload audit and a clearly labelled static preview."""
from pathlib import Path
import base64,gzip,json,re,hashlib
import h5py
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.colors import Normalize
from matplotlib.lines import Line2D
from mpl_toolkits.mplot3d.art3d import Poly3DCollection

ROOT=Path(__file__).resolve().parent
OUT=ROOT/'results/kwave_widegrid_2026-10-24/interactive'


def verify():
    path=OUT/'widefield_pressure_3d.html';text=path.read_text(encoding='utf-8')
    scripts=re.findall(r'<script>(.*?)</script>',text,re.S)
    assert len(scripts)==2 and not re.search(r'<script[^>]+src=',text)
    encoded=re.search("const PAYLOAD_B64='([^']+)'",text).group(1)
    data=json.loads(gzip.decompress(base64.b64decode(encoded)))
    # Syntax checking needs no duplicated 15 MB base64 literal.
    runtime=scripts[-1].replace(encoded,'')
    (OUT/'viewer_runtime_check.js').write_text(runtime,encoding='utf-8')
    audited=[]
    for c in data['cases']:
        axes=[np.asarray(a) for a in c['axes_mm']]
        with (ROOT/c['source_mat']).open('rb') as f: actual_hash=hashlib.file_digest(f,'sha256').hexdigest()
        assert actual_hash==c['source_sha256']
        with h5py.File(ROOT/c['source_mat']) as f:
            p=np.asarray(f['p_peak_pa']).transpose(2,1,0)
        iz=np.flatnonzero(axes[2]>1e-9); ix=abs(axes[0]).argmin();iy=abs(axes[1]).argmin()
        np.testing.assert_allclose(c['xz']['p'],p[:,iy,iz].T,atol=5.000001e-7,rtol=0)
        np.testing.assert_allclose(c['yz']['p'],p[ix,:,iz],atol=5.000001e-7,rtol=0)
        xi=[int(abs(axes[0]-v).argmin()) for v in c['xy']['x']]
        yi=[int(abs(axes[1]-v).argmin()) for v in c['xy']['y']]
        zi=[int(abs(axes[2]-v).argmin()) for v in c['xy']['z']]
        np.testing.assert_allclose(c['xy']['p'],p[np.ix_(xi,yi,zi)].transpose(2,1,0),atol=5.000001e-7,rtol=0)
        assert min(c['xz']['z'])>0 and max(c['xz']['x'])>6.344
        for r in c['regions']:
            inds=tuple(r['index_xyz']);assert float(p[inds])==r['pressure_pa_assumed']
            if r['id']=='shallow': assert r['xyz_mm'][2]<5
            lo,hi={'near_source':(0,2),'shallow':(2,5),'deep':(5,np.inf),'forward':(0,np.inf)}[r['id']]
            band=((axes[2]>1e-9) if lo==0 else (axes[2]>=lo-1e-9)) & (axes[2]<hi-1e-9)
            assert float(p[:,:,band].max())==r['pressure_pa_assumed']
        for m in c['meshes']:
            np.testing.assert_allclose(m['threshold_pa'],data['common_reference_pa']*10**(m['db']/20),atol=1e-14)
            v=np.asarray(m['xyz']).T;faces=np.asarray(m['ijk']).T
            assert np.isfinite(v).all() and faces.min()>=0 and faces.max()<len(v)
            assert v[:,2].min()>0
        audited.append({'case':c['id'],'source_sha256_unchanged':True,'xz_yz_and_all_exported_xy_planes_match_native_mat':True,
                        'mesh_indices_and_common_thresholds_valid':True,'native_region_peaks_match':True})
        del p
    assert data['cases'][0]['reference_pa']==data['cases'][1]['reference_pa']
    assert data['numerical_convergence']=='not_established'
    checks={'cases':audited,'unit_tests':5,'external_script_dependencies':0,
            'browser_runtime_validation':'not_completed; browser tool rejected file protocol; no workaround attempted',
            'static_preview':'Matplotlib rendering of exact exported meshes and sections; not a browser screenshot',
            'solver_rerun':False}
    (OUT/'validation.json').write_text(json.dumps(checks,indent=2,ensure_ascii=False),encoding='utf-8')
    preview(data)
    print(json.dumps(checks))


def preview(data):
    fig=plt.figure(figsize=(15.6,13.6),facecolor='#f4f7fa')
    cmap=plt.get_cmap('turbo');norm=Normalize(0,3)
    for n,c in enumerate(data['cases']):
        ax=fig.add_subplot(2,2,n+1,projection='3d',facecolor='white')
        for j in [1,2]:
            m=c['meshes'][j];v=np.asarray(m['xyz']).T;faces=np.asarray(m['ijk']).T
            poly=Poly3DCollection(v[faces],facecolor=['#1c9c9a','#ef963b'][j-1],edgecolor='none',alpha=[.12,.42][j-1],rasterized=True)
            ax.add_collection3d(poly)
        for name,color in [('shallow','#bd452b'),('deep','#087885')]:
            r=next(q for q in c['regions'] if q['id']==name);x,y,z=r['xyz_mm']
            ax.scatter([x],[y],[z],color=color,s=26,depthshade=False)
            ax.text(x,y,z+1,f"{name}: ({x:.3f},{y:.3f},{z:.3f})",fontsize=8,color=color)
        ax.scatter([0],[0],[20],marker='x',s=36,color='black',depthshade=False)
        a=c['axes_mm'];ax.set(xlim=(a[0][0],a[0][-1]),ylim=(a[1][0],a[1][-1]),zlim=(a[2][-1],0),xlabel='x lateral (mm)',ylabel='y elevation (mm)',zlabel='z axial (mm)')
        ax.set_box_aspect([15.6,10.4,30.6]);ax.view_init(elev=17,azim=-62)
        ax.set_title('Even 32' if n==0 else 'Full 64 | matched source proxy B',fontsize=13,pad=8)
        ax2=fig.add_subplot(2,2,n+3,facecolor='white')
        xz=c['xz'];im=ax2.pcolormesh(xz['x'],xz['z'],xz['p'],shading='auto',cmap=cmap,norm=norm,rasterized=True)
        r=next(q for q in c['regions'] if q['id']=='shallow');ax2.plot(r['xyz_mm'][0],r['xyz_mm'][2],'wo',ms=5,mfc='none',mew=1.4)
        ax2.plot(0,20,'w+',ms=9,mew=1.5);ax2.invert_yaxis();ax2.set(xlabel='x lateral (mm)',ylabel='z axial (mm)',title='Native 52 um XZ section | y=0')
        cb=fig.colorbar(im,ax=ax2,pad=.025);cb.set_label('max_t |p| (Pa, assumed source)')
    fig.suptitle('Wide-field 3D peak-pressure records | 2026-10-24',fontsize=19,y=.982)
    fig.text(.5,.948,'Static data preview: surfaces at common -6.02 / -3 dB; 0 dB = 1.408753 Pa. Black cross: requested target.',ha='center',fontsize=10)
    fig.text(.5,.025,'Surfaces: ~104 um display sampling, open at boundaries. Sections: native 52 um. Not a simultaneous snapshot.',ha='center',fontsize=10)
    fig.text(.5,.008,'Uncalibrated assumed pressure source; even32 near-source / shallow amplitudes remain grid-sensitive. No heat or cure result.',ha='center',fontsize=9,color='#805a17')
    fig.subplots_adjust(top=.91,bottom=.07,left=.05,right=.96,wspace=.17,hspace=.18)
    fig.savefig(OUT/'pressure_3d_preview.png',dpi=145);plt.close(fig)


if __name__=='__main__':verify()
