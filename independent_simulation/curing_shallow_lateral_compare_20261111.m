function comparison=curing_shallow_lateral_compare_20261111(variant)
%CURING_SHALLOW_LATERAL_COMPARE_20261111 32.5 um wide/narrow common domain.
root=fileparts(mfilename('fullpath')); base=fullfile(root,'results','curing_field_2026-11-10','bli_gpu_shallow');
prefix=lower(variant);
wide=load(fullfile(base,[prefix '_dx32p5_field.mat']),'p_amp','qp','x_m','y_m','z_m','dt_s','Nt');
small=load(fullfile(base,[prefix '_dx32p5_narrow_field.mat']),'p_amp','qp','x_m','y_m','z_m','dt_s','Nt');
out=fullfile(base,[prefix '_dx32p5_lateral_domain_comparison.csv']);
assert(~isfile(out),'iceind:NoOverwrite','Comparison output exists.');
wx=wide.x_m(:); wy=wide.y_m(:); sx=small.x_m(:); sy=small.y_m(:);
ix=find(abs(wx-sx(1))<1e-12,1)+(0:numel(sx)-1);
iy=find(abs(wy-sy(1))<1e-12,1)+(0:numel(sy)-1);
assert(numel(ix)==numel(small.x_m) && numel(iy)==numel(small.y_m) && ...
    max(abs(wx(ix)-sx))<1e-12 && max(abs(wy(iy)-sy))<1e-12 && ...
    max(abs(wide.z_m(:)-small.z_m(:)))<1e-12 && abs(wide.dt_s-small.dt_s)<1e-18 && wide.Nt==small.Nt, ...
    'iceind:Shallow','Wide/narrow grids or time windows mismatch.');
z=small.z_m(:); names={'z0_source_plane';'z_gt0_to_0p26';'z_0p26_to_0p52'; ...
    'z_0p52_to_1';'z_1_to_2';'z_2_to_4';'z_0_to_2'};
masks={abs(z)<1e-12,z>1e-12 & z<.26e-3-1e-12, ...
    z>=.26e-3-1e-12 & z<.52e-3-1e-12,z>=.52e-3-1e-12 & z<1e-3-1e-12, ...
    z>=1e-3-1e-12 & z<2e-3-1e-12,z>=2e-3-1e-12 & z<4e-3-1e-12, ...
    z>=-1e-12 & z<2e-3-1e-12};
pl2=nan(7,1); ql2=pl2; pc=pl2; qc=pl2;
for k=1:numel(masks)
    zi=find(masks{k}); a=double(wide.p_amp(ix,iy,zi)); b=double(small.p_amp(:,:,zi));
    c=double(wide.qp(ix,iy,zi)); d=double(small.qp(:,:,zi));
    pl2(k)=norm(a(:)-b(:))/norm(a(:)); ql2(k)=norm(c(:)-d(:))/norm(c(:));
    pc(k)=max(b(:))/max(a(:))-1; qc(k)=max(d(:))/max(c(:))-1;
end
comparison=table(names,pl2,ql2,pc,qc,'VariableNames', ...
    {'region','pressure_l2_relative_wide','qp_l2_relative_wide', ...
    'pressure_peak_change_relative_wide','qp_peak_change_relative_wide'});
writetable(comparison,out); disp(comparison);
end
