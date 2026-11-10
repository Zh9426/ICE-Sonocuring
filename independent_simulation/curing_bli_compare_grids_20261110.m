function comparison=curing_bli_compare_grids_20261110(variant,out)
%CURING_BLI_COMPARE_GRIDS_20261110 Compare common 260 um physical samples.
% Two grids describe sensitivity, not a proof of continuous convergence.
% The 260 um lattice can miss between-point maxima; also compare regional
% peak values and positions on each native grid.
if nargin<2
    root=fileparts(mfilename('fullpath'));
    out=fullfile(root,'results','curing_field_2026-11-10','bli_full');
end
coarsePath=fullfile(out,sprintf('%s_dx65_field.mat',lower(variant)));
finePath=fullfile(out,sprintf('%s_dx52_field.mat',lower(variant)));
assert(isfile(coarsePath) && isfile(finePath),'iceind:CuringField', ...
    'Both completed full-field raw files are required.');
csvPath=fullfile(out,sprintf('%s_grid_comparison.csv',lower(variant)));
assert(~isfile(csvPath),'iceind:NoOverwrite','Comparison output already exists.');
a=load(coarsePath,'p_amp','qp','x_m','y_m','z_m');
b=load(finePath,'p_amp','qp','x_m','y_m','z_m');
ia=1:4:numel(a.x_m); ja=1:4:numel(a.y_m); ka=1:4:numel(a.z_m);
ib=1:5:numel(b.x_m); jb=1:5:numel(b.y_m); kb=1:5:numel(b.z_m);
assert(isequal(size(a.p_amp(ia,ja,ka)),size(b.p_amp(ib,jb,kb))) && ...
    max(abs(a.x_m(ia)-b.x_m(ib)))<1e-12 && ...
    max(abs(a.y_m(ja)-b.y_m(jb)))<1e-12 && ...
    max(abs(a.z_m(ka)-b.z_m(kb)))<1e-12,'iceind:CuringField', ...
    'Grid positions do not coincide on the proposed 260 um lattice.');
[X,Y,Z]=ndgrid(a.x_m(ia),a.y_m(ja),a.z_m(ka));
target=abs(X)<=2e-3 & abs(Y)<=2e-3 & abs(Z-20e-3)<=4e-3;
masks={Z>=0 & Z<2e-3,Z>=2e-3 & Z<5e-3,Z>=5e-3 & Z<16e-3, ...
    target,Z>=2e-3 & ~target,Z>24e-3,Z>=2e-3};
names={'shallow_0_2mm','shallow_2_5mm','prefocal_5_16mm','target_box', ...
    'outside_target_forward','postfocal_beyond_24mm','forward_z_ge_2mm'};
pa=double(a.p_amp(ia,ja,ka)); pb=double(b.p_amp(ib,jb,kb));
qa=double(a.qp(ia,ja,ka)); qb=double(b.qp(ib,jb,kb));
pressure_l2=nan(numel(names),1); qp_l2=pressure_l2; points=zeros(numel(names),1);
for j=1:numel(names)
    mask=masks{j}; points(j)=nnz(mask);
    pressure_l2(j)=relative_l2(pa(mask),pb(mask));
    qp_l2(j)=relative_l2(qa(mask),qb(mask));
end
comparison=table(names',points,pressure_l2,qp_l2, ...
    'VariableNames',{'region','common_points','pressure_l2_relative_to_dx65', ...
    'qp_l2_relative_to_dx65'});
writetable(comparison,csvPath); disp(comparison);
end
function value=relative_l2(a,b)
if isempty(a) || norm(a)==0, value=NaN; else, value=norm(a-b)/norm(a); end
end
