function tests=curing_field_test_gpu_analyze
tests=functiontests(localfunctions);
end
function testTargetAndOutsidePeakAndPlots(t)
root=fileparts(fileparts(fileparts(mfilename('fullpath')))); addpath(root);
folder=tempname; mkdir(folder); cleanup=onCleanup(@()cleanup_folder(folder));
x_m=(-5:.2:5)*1e-3; y_m=(-3:.2:3)*1e-3; z_m=(0:.2:30)*1e-3;
[X,Y,Z]=ndgrid(x_m,y_m,z_m);
p_amp=single(exp(-(X.^2+Y.^2+(Z-.020).^2)/(2*.0006^2)) + ...
    2*exp(-((X-.003).^2+Y.^2+(Z-.010).^2)/(2*.0004^2)));
qp=p_amp.^2*single(1e-6); target_m=[0 0 .02]; dt_s=1e-8; Nt=100; elapsed=1; final_over_peak=0;
meta=struct(); runtime_metadata=struct('case',struct('variant','Test','dx_m',.0002,'tag','test'));
raw=fullfile(folder,'synthetic.mat');
save(raw,'p_amp','qp','x_m','y_m','z_m','target_m','meta','runtime_metadata','dt_s','Nt','elapsed','final_over_peak');
out=fullfile(folder,'analysis'); r=curing_gpu_analyze_20261111(raw,out,[0 2.1]);
verifyEqual(t,r.metrics.target_peak_xyz_m,[0 0 .02],'AbsTol',.0002);
verifyEqual(t,r.outside_all_z_ge_zero_peak_xyz_m,[.003 0 .010],'AbsTol',.0002);
verifyEqual(t,r.outside_all_z_ge_zero_peak_assumed_pa,2,'AbsTol',1e-5);
verifyTrue(t,all(~r.metrics.target_peak_width_clipped));
regions=readtable(fullfile(out,'axial_regions.csv'));
verifyEqual(t,regions.qp_peak_assumed_pa2_s(3),4e-6,'AbsTol',1e-10);
files={'metrics.json','metrics.csv','axial_regions.csv','pressure_xz.png','pressure_xy.png', ...
    'pressure_xy_forward_peak.png','profiles_xyz.png','profile_x.csv','profile_y.csv','profile_z.csv'};
for k=1:numel(files), verifyTrue(t,isfile(fullfile(out,files{k}))); end
end
function cleanup_folder(folder)
out=fullfile(folder,'analysis');
files={'metrics.json','metrics.csv','axial_regions.csv','pressure_xz.png','pressure_xy.png', ...
    'pressure_xy_forward_peak.png','profiles_xyz.png','profile_x.csv','profile_y.csv','profile_z.csv'};
for k=1:numel(files)
    f=fullfile(out,files{k}); if isfile(f), delete(f); end
end
if isfolder(out), rmdir(out); end
f=fullfile(folder,'synthetic.mat'); if isfile(f), delete(f); end
if isfolder(folder), rmdir(folder); end
end
