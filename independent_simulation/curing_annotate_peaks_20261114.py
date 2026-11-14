"""Annotate archived x-z plots and redraw multifocus from saved simulated fields."""
from pathlib import Path
import csv
import h5py
import numpy as np
from PIL import Image
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.colors import ListedColormap, Normalize
from matplotlib.lines import Line2D
from matplotlib.patches import Rectangle
from matplotlib import patheffects

ROOT = Path(__file__).resolve().parent
OUT = ROOT / 'results' / 'peak_annotation_2026-11-14'
MULTI = ROOT / 'results' / 'multifocus_2026-11-14'
OLD = ROOT / 'results' / 'curing_field_2026-11-10' / 'bli_gpu_full'
FOUR = OLD / 'four_variant_comparison_20261112'
SPARSE = ROOT / 'results' / 'curing_sparse_2026-11-12' / 'comparison_20261113'
OUT.mkdir(parents=True, exist_ok=True)
plt.rcParams.update({'font.family':'DejaVu Sans','font.size':10,'savefig.facecolor':'white'})

# Pixel crops preserve the archived MATLAB color rendering. These panels are
# visual excerpts, not recovered quantitative arrays; peak data come from CSV.
archives = {
    'decreasing': (FOUR/'four_xz_dx52.png', [(58,310),(509,761),(960,1212),(1411,1663)], (236,740), 3.0),
    'sparse': (SPARSE/'comparison_xz_dx52.png', [(65,339),(548,822),(1031,1305),(1514,1788)], (149,699), 3.3),
}
# Original grid centers span x [-7.8, 7.748] and z [-0.52, 30.628] mm.
# imshow places image edges half a 0.052 mm cell beyond the end centers.
extent = (-7.826, 7.774, -0.546, 30.654)


def read_rows(path):
    with path.open(encoding='utf-8-sig', newline='') as f:
        return list(csv.DictReader(f))


def pick(rows, name):
    return next(r for r in rows if r['variant'] == name and float(r['dx_um']) == 52)


def old_peaks(r):
    target = (float(r['target_peak_x_mm']), float(r['target_peak_y_mm']),
              float(r['target_peak_z_mm']), float(r['target_peak_assumed_pa']),
              bool(int(r['target_peak_on_roi_boundary'])))
    outside = (float(r['outside_forward_x_mm']), float(r['outside_forward_y_mm']),
               float(r['outside_forward_z_mm']), float(r['outside_forward_peak_assumed_pa']))
    forward = target[:4] if target[3] >= outside[3] else outside
    return target, forward


def plot_marks(ax, targets, peaks, forward, halfwidth):
    for target in targets:
        ax.add_patch(Rectangle((target-halfwidth,16),2*halfwidth,8, fill=False,
                               edgecolor='white', linewidth=.65, linestyle='--', alpha=.85))
        ax.plot(target,20, marker='+', markersize=11, markeredgewidth=2.1,
                color='#ffdf4d', path_effects=[patheffects.withStroke(linewidth=3.6,foreground='black')],zorder=8)
    for x,y,z,p,boundary in peaks:
        ax.plot(x,z, marker='x',markersize=8,markeredgewidth=2.0,color='#e21b23',
                path_effects=[patheffects.withStroke(linewidth=3.5,foreground='white')],zorder=10)
    x,y,z,p=forward
    ax.plot(x,z, marker='o',markersize=10,markerfacecolor='none',markeredgecolor='white',
            markeredgewidth=1.7,path_effects=[patheffects.withStroke(linewidth=3.4,foreground='black')],zorder=9)
    ax.set_xlim(-7.8,7.75); ax.set_ylim(-0.52,30.63); ax.set_aspect('equal')
    ax.set_xlabel('x (mm)'); ax.set_yticks([0,5,10,15,20,25,30]); ax.set_xticks([-5,0,5])


def finish(fig, axs, title, source_note, vmax):
    handles=[Line2D([0],[0],marker='+',color='#a87000',markersize=10,markeredgewidth=2,linestyle='',label='Preset target'),
             Line2D([0],[0],marker='x',color='#e21b23',markersize=8,markeredgewidth=2,linestyle='',label='Maximum within target ROI'),
             Line2D([0],[0],marker='o',color='black',markerfacecolor='none',markersize=8,linestyle='',label='Forward maximum (z ≥ 2 mm)'),
             Line2D([0],[0],color='#777777',linestyle='--',label='Target ROI, z = 16–24 mm')]
    fig.suptitle(title,fontsize=14,y=.96)
    fig.legend(handles=handles,loc='upper center',bbox_to_anchor=(.50,.90),ncol=2,frameon=False,fontsize=9)
    fig.text(.5,.045,source_note,ha='center',fontsize=8,color='#444444')
    fig.text(.5,.020,'ROI maxima and forward maxima are simulated; individual voxel maxima are not a simultaneous snapshot.',ha='center',fontsize=8,color='#444444')
    fig.subplots_adjust(left=.065,right=.92,bottom=.14,top=.78,wspace=.32)


def archived_figure(kind, names, rows, filename):
    path,boxes,yrange,vmax=archives[kind]
    image=np.asarray(Image.open(path).convert('RGB'))
    fig,axs=plt.subplots(1,4,figsize=(13,7.4))
    output=[]
    for ax,name,(left,right) in zip(axs,names,boxes):
        r=pick(rows,name); target,forward=old_peaks(r)
        ax.imshow(image[yrange[0]:yrange[1],left:right],extent=extent,origin='upper',interpolation='nearest')
        plot_marks(ax,[0],[target],forward,2)
        ax.set_title(name,weight='bold'); ax.set_ylabel('z (mm)')
        output.append({'group':kind,'variant':name,'target_x_mm':0,'roi_peak_x_mm':target[0],
                       'roi_peak_y_mm':target[1],'roi_peak_z_mm':target[2], 'roi_peak_assumed_pa':target[3],
                       'roi_boundary':target[4],'forward_x_mm':forward[0],'forward_y_mm':forward[1],
                       'forward_z_mm':forward[2],'forward_assumed_pa':forward[3], 'source':'archived 3D metrics CSV'})
    # Colorbar sampled from the archived MATLAB-rendered colorbar, preserving its palette.
    cbx=boxes[0][1]+28 if kind=='decreasing' else boxes[0][1]+30
    samples=image[yrange[0]+3:yrange[1]-3,cbx,:][::-1]/255.0
    cmap=ListedColormap(samples)
    cax=fig.add_axes([.935,.20,.014,.53]); cbar=fig.colorbar(plt.cm.ScalarMappable(norm=Normalize(0,vmax),cmap=cmap),cax=cax)
    cbar.set_label('Peak |p| (assumed Pa)')
    finish(fig,axs,'Annotated x–z pressure: '+('central apertures' if kind=='decreasing' else 'sparse apertures'),
           'Background is the original 52 μm image; marker coordinates use archived 3D metrics.',vmax)
    fig.savefig(OUT/filename,dpi=180); plt.close(fig)
    return output


def raw_peak(a,x,y,z,target,halfwidth):
    ix=np.flatnonzero(abs(x-target)<=halfwidth+1e-9); iy=np.flatnonzero(abs(y)<=2+1e-9)
    iz=np.flatnonzero(abs(z-20)<=4+1e-9)
    block=a[iz[0]:iz[-1]+1,iy[0]:iy[-1]+1,ix[0]:ix[-1]+1]
    j=np.unravel_index(np.argmax(block),block.shape)
    boundary=any(k==0 or k==n-1 for k,n in zip(j,block.shape))
    return float(x[ix[j[2]]]),float(y[iy[j[1]]]),float(z[iz[j[0]]]),float(block[j]),boundary


def multifocus_figure():
    records=read_rows(MULTI/'comparison.csv'); output=[]
    names=['All64','Dual','Quad']; files=['baseline','dual','quad']; targetsets=[[0],[-2,2],[-3,-1,1,3]]
    palette_image=np.asarray(Image.open(archives['decreasing'][0]).convert('RGB'))
    cmap=ListedColormap(palette_image[239:737,338,:][::-1]/255.0)
    fig,axs=plt.subplots(1,3,figsize=(11,7.4))
    for ax,name,file,targets in zip(axs,names,files,targetsets):
        with h5py.File(MULTI/(file+'_dx52_field.mat'),'r') as f:
            x=f['x_m'][:].ravel()*1000; y=f['y_m'][:].ravel()*1000; z=f['z_m'][:].ravel()*1000
            a=f['p_amp']; iy=int(np.argmin(abs(y))); plane=a[:,iy,:]
            halfwidth=2 if name=='All64' else 1
            peaks=[raw_peak(a,x,y,z,t,halfwidth) for t in targets]
            r=pick(records,name); forward=tuple(float(r[k]) for k in ['forward_peak_x_mm','forward_peak_y_mm','forward_peak_z_mm','forward_peak'])
            ax.imshow(plane,extent=extent,origin='lower',cmap=cmap,vmin=0,vmax=3,interpolation='nearest')
            plot_marks(ax,targets,peaks,forward,halfwidth)
            ax.set_title(name,weight='bold'); ax.set_ylabel('z (mm)')
            for t,p in zip(targets,peaks):
                output.append({'group':'multifocus','variant':name,'target_x_mm':t,'roi_peak_x_mm':p[0],
                    'roi_peak_y_mm':p[1],'roi_peak_z_mm':p[2],'roi_peak_assumed_pa':p[3],
                    'roi_boundary':p[4],'forward_x_mm':forward[0],'forward_y_mm':forward[1],
                    'forward_z_mm':forward[2],'forward_assumed_pa':forward[3],'source':'saved 3D field MAT'})
    cax=fig.add_axes([.935,.20,.014,.53]); cbar=fig.colorbar(plt.cm.ScalarMappable(norm=Normalize(0,3),cmap=cmap),cax=cax)
    cbar.set_label('Peak |p| (assumed Pa)')
    finish(fig,axs,'Annotated x–z pressure: single, dual and quad','Background and ROI peaks use saved 52 μm fields; see the coordinate table for boundary flags.',3)
    fig.savefig(OUT/'multifocus_annotated.png',dpi=180); plt.close(fig)
    return output


def main():
    values=multifocus_figure()
    values+=archived_figure('decreasing',['All64','Center48','Center32','Center16'],
                            read_rows(FOUR/'metrics_four_variants.csv'),'decreasing_annotated.png')
    values+=archived_figure('sparse',['All64','Center32','Odd32','Even32'],
                            read_rows(SPARSE/'metrics.csv'),'sparse_annotated.png')
    with (OUT/'peak_coordinates.csv').open('w',newline='',encoding='utf-8') as f:
        writer=csv.DictWriter(f,fieldnames=list(values[0])); writer.writeheader(); writer.writerows(values)
    print('Wrote',len(values),'target ROI measurements to',OUT)

if __name__=='__main__':
    main()
