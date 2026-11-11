function result=curing_shallow_refinement_compare_20261111(variant,fineGrid)
%CURING_SHALLOW_REFINEMENT_COMPARE_20261111 Adjacent shallow-grid diagnostic.
% This does not establish full-domain convergence; retain 52um domain check.
root=fileparts(mfilename('fullpath')); base=fullfile(root,'results','curing_field_2026-11-10','bli_gpu_shallow');
if nargin<2, fineGrid='dx43p333'; end
if strcmp(fineGrid,'dx43p333')
    coarseGrid='dx52'; coarseStep=5; fineStep=6;
    suffix='_shallow_refinement_comparison.csv';
elseif strcmp(fineGrid,'dx32p5')
    coarseGrid='dx43p333'; coarseStep=3; fineStep=4;
    suffix='_shallow_dx43p333_dx32p5_comparison.csv';
elseif strcmp(fineGrid,'dx26')
    coarseGrid='dx32p5_narrow'; fineGrid='dx26_narrow'; coarseStep=4; fineStep=5;
    suffix='_shallow_narrow_dx32p5_dx26_comparison.csv';
else
    error('iceind:Shallow','Unsupported fine grid.');
end
prefix=lower(variant); f=load(fullfile(base,[prefix '_' coarseGrid '_field.mat']), ...
    'p_amp','qp','x_m','y_m','z_m','dt_s','Nt');
s=load(fullfile(base,[prefix '_' fineGrid '_field.mat']), ...
    'p_amp','qp','x_m','y_m','z_m','dt_s','Nt');
out=fullfile(base,[prefix suffix]);
assert(~isfile(out),'iceind:NoOverwrite','Comparison already exists.');
ix=1:coarseStep:numel(f.x_m); iy=1:coarseStep:numel(f.y_m); iz=1:coarseStep:numel(f.z_m);
jx=1:fineStep:numel(s.x_m); jy=1:fineStep:numel(s.y_m); jz=1:fineStep:numel(s.z_m);
assert(max(abs(f.x_m(ix)-s.x_m(jx)))<1e-12 && ...
    max(abs(f.y_m(iy)-s.y_m(jy)))<1e-12 && ...
    max(abs(f.z_m(iz)-s.z_m(jz)))<1e-12 && ...
    abs((f.Nt-1)*f.dt_s-(s.Nt-1)*s.dt_s)<=max(f.dt_s,s.dt_s)+1e-15, ...
    'iceind:Shallow','Common grid or time window mismatch.');
labels={'z0_source_plane';'z_gt0_to_0p26';'z_0p26_to_0p52'; ...
    'z_0p52_to_1';'z_1_to_2';'z_2_to_4';'z_0_to_2'};
zf=f.z_m(:); zs=s.z_m(:); zc=zf(iz);
rf=layer_masks(zf); rs=layer_masks(zs); rc=layer_masks(zc);
pf=double(f.p_amp(ix,iy,iz)); ps=double(s.p_amp(jx,jy,jz));
qf=double(f.qp(ix,iy,iz)); qs=double(s.qp(jx,jy,jz));
commonCount=zeros(7,1); pressureL2=nan(7,1); qpL2=pressureL2;
pmax52=pressureL2; pmax43=pressureL2; qmax52=pressureL2; qmax43=pressureL2;
for k=1:7
    af=f.p_amp(:,:,rf{k}); as=s.p_amp(:,:,rs{k});
    bf=f.qp(:,:,rf{k}); bs=s.qp(:,:,rs{k});
    pmax52(k)=double(max(af,[],'all')); pmax43(k)=double(max(as,[],'all'));
    qmax52(k)=double(max(bf,[],'all')); qmax43(k)=double(max(bs,[],'all'));
    commonCount(k)=nnz(rc{k})*numel(ix)*numel(iy);
    if commonCount(k)>0
        a=pf(:,:,rc{k}); b=ps(:,:,rc{k}); c=qf(:,:,rc{k}); d=qs(:,:,rc{k});
        if norm(a(:))>0, pressureL2(k)=norm(a(:)-b(:))/norm(a(:)); end
        if norm(c(:))>0, qpL2(k)=norm(c(:)-d(:))/norm(c(:)); end
    end
end
result=table(labels,commonCount,pressureL2,qpL2,pmax52,pmax43, ...
    100*(pmax43./pmax52-1),qmax52,qmax43,100*(qmax43./qmax52-1), ...
    'VariableNames',{'region','common_points','pressure_common_l2','qp_common_l2', ...
    ['pmax_' coarseGrid(3:end)],['pmax_' fineGrid(3:end)],'pmax_change_percent', ...
    ['qpmax_' coarseGrid(3:end)],['qpmax_' fineGrid(3:end)],'qpmax_change_percent'});
writetable(result,out); disp(result);
end
function masks=layer_masks(z)
masks={abs(z)<1e-12,z>1e-12 & z<.26e-3-1e-12, ...
    z>=.26e-3-1e-12 & z<.52e-3-1e-12,z>=.52e-3-1e-12 & z<1e-3-1e-12, ...
    z>=1e-3-1e-12 & z<2e-3-1e-12,z>=2e-3-1e-12 & z<4e-3-1e-12, ...
    z>=-1e-12 & z<2e-3-1e-12};
end
