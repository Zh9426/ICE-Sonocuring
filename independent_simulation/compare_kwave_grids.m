function report=compare_kwave_grids()
%COMPARE_KWAVE_GRIDS Compare fixed-ROI fields; two grids are not proof of convergence.
root=fileparts(mfilename('fullpath')); out=fullfile(root,'results','kwave');
a=load(fullfile(out,'dual_tx16_dx80.0um.mat'),'report','x','z','xz');
b=load(fullfile(out,'dual_tx16_dx64.0um.mat'),'report','x','z','xz');
[X,Z]=ndgrid((-3:.08:3)*1e-3,(10:.08:22)*1e-3);
fa=griddedInterpolant({a.x,a.z},a.xz,'linear','none');
fb=griddedInterpolant({b.x,b.z},b.xz,'linear','none');
pa=fa(X,Z);pb=fb(X,Z);
assert(all(isfinite(pa(:))) && all(isfinite(pb(:))),'iceind:ROI','ROI outside a grid.');
relative=norm(pa(:)-pb(:))/norm(pb(:));
pk=abs(a.report.roi_max_abs_pressure_pa_assumed-b.report.roi_max_abs_pressure_pa_assumed)/ ...
    b.report.roi_max_abs_pressure_pa_assumed;
report=struct('coarse_dx_m',80e-6,'fine_dx_m',64e-6, ...
    'xz_fixed_roi_relative_l2',relative,'roi_peak_relative_change',pk, ...
    'proposed_internal_tolerance',.05,'two_grid_check_passed',relative<.05 && pk<.05, ...
    'convergence','not_established_two_grids_only', ...
    'pml_domain_and_source_bandwidth_sensitivity','pending', ...
    'scope','assumed_model_not_measured_probe');
fid=fopen(fullfile(out,'grid_comparison.json'),'w');
fwrite(fid,jsonencode(report,'PrettyPrint',true),'char');fclose(fid);
disp(report);
end
