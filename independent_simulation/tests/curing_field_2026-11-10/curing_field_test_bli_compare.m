function tests=curing_field_test_bli_compare
tests=functiontests(localfunctions);
end
function testCommonGridComparisonUsesMatchedPhysicalPoints(t)
root=fileparts(fileparts(fileparts(mfilename('fullpath')))); addpath(root);
folder=tempname; mkdir(folder); cleanup=onCleanup(@()cleanup_folder(folder));
x_m=(-20:19)*65e-6; y_m=x_m; z_m=(0:399)*65e-6;
[X,Y,Z]=ndgrid(x_m,y_m,z_m); p_amp=single(1+X.^2+Y.^2+Z.^2); qp=2*p_amp;
save(fullfile(folder,'all64_dx65_field.mat'),'p_amp','qp','x_m','y_m','z_m');
x_m=(-25:24)*52e-6; y_m=x_m; z_m=(0:499)*52e-6;
[X,Y,Z]=ndgrid(x_m,y_m,z_m); p_amp=single(1.1*(1+X.^2+Y.^2+Z.^2)); qp=2*p_amp;
save(fullfile(folder,'all64_dx52_field.mat'),'p_amp','qp','x_m','y_m','z_m');
c=curing_bli_compare_grids_20261110('All64',folder);
verifyTrue(t,all(c.common_points>0));
verifyEqual(t,c.pressure_l2_relative_to_dx65,0.1*ones(height(c),1),'AbsTol',2e-7);
verifyEqual(t,c.qp_l2_relative_to_dx65,0.1*ones(height(c),1),'AbsTol',2e-7);
end
function cleanup_folder(folder)
files={'all64_dx65_field.mat','all64_dx52_field.mat','all64_grid_comparison.csv'};
for k=1:numel(files)
    f=fullfile(folder,files{k}); if isfile(f), delete(f); end
end
if isfolder(folder), rmdir(folder); end
end
