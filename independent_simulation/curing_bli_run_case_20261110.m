function rawPath=curing_bli_run_case_20261110(variant,dx_um)
%CURING_BLI_RUN_CASE_20261110 Full-domain assumed BLI field; CPU only.
% WARNING: invoke only after the source adapter and its tests are reviewed.
% Saves peak pressure, discrete Qp, axes and assumptions; no hardware/VSX.
root=fileparts(mfilename('fullpath')); old=path; cleanup=onCleanup(@()path(old));
addpath(root,fullfile(root,'dependencies','k-wave-1.4.1','k-Wave'));
assert(ismember(dx_um,[65 52]) && ismember(string(variant),["All64","Center16"]), ...
    'iceind:CuringField','Only the two first-stage variants and grids are supported.');
cases=iceind.curing_field_cases(); idx=find(strcmp({cases.variant},variant) & ...
    abs([cases.dx_m]-dx_um*1e-6)<1e-12,1);
assert(~isempty(idx),'iceind:CuringField','No matching case.'); c=cases(idx);
driverNames=struct('All64','ICE_CuringOnly_ExposureFFFFFFFFFFFFFFFF_exposure_only.mat', ...
    'Center16','ICE_CuringOnly_Exposure000000FFFF000000_exposure_only.mat');
driver=fullfile(root,'results','curing_export_2026-11-10',driverNames.(variant));
out=fullfile(root,'results','curing_field_2026-11-10','bli_full');
if ~isfolder(out), mkdir(out); end
rawPath=fullfile(out,sprintf('%s_dx%d_field.mat',lower(variant),dx_um));
partialPath=fullfile(out,sprintf('%s_dx%d_field.partial.mat',lower(variant),dx_um));
assert(~isfile(rawPath) && ~isfile(partialPath),'iceind:NoOverwrite', ...
    'Final or partial field exists; inspect it before rerunning.');
[g,medium,source,sensor,meta]=iceind.curing_bli_prepare(c,driver);
n=meta.grid_size;
assert(islogical(sensor.mask) && isequal(size(sensor.mask),n) && all(sensor.mask(:)), ...
    'iceind:CuringField','Sensor mask must cover exactly the physical grid.');
sensor.record={'p_max_all','p_min_all','p_rms','p_final'}; sensor.record_start_index=1;
runtime_metadata=struct('case',c,'matlab',version,'matlab_release',version('-release'), ...
    'kwave_version','1.4.1','kwave_commit','0f1a70f00645f2493318faef63111069084ccba7', ...
    'adapter_sha256',iceind.curing_field_sha256(which('iceind.curing_bli_prepare')), ...
    'solver','kspaceFirstOrder3D','solver_device','cpu','data_cast','single', ...
    'pml_inside',false,'pml_cells',meta.pml_cells,'record',{sensor.record}, ...
    'record_start_index',sensor.record_start_index,'qp_units','Pa^2 s', ...
    'qp_definition','discrete Nt*dt*p_rms^2 = dt*sum(p^2), record_start_index=1');
started=datestr(now,30); fprintf('Starting %s %d um at %s; Nt=%d.\n',variant,dx_um,started,g.Nt);
t=tic; data=kspaceFirstOrder3D(g,medium,source,sensor,'PMLInside',false, ...
    'PMLSize',meta.pml_cells,'PlotSim',false,'DataCast','single'); elapsed=toc(t);
clear source sensor medium;
assert(isequal(size(data.p_max_all),n) && numel(data.p_rms)==prod(n), ...
    'iceind:CuringField','Unexpected full-domain sensor dimensions.');
p_amp=max(data.p_max_all,-data.p_min_all);
qp=reshape(single(double(data.p_rms).^2*double(g.Nt)*g.dt),n);
assert(all(isfinite(p_amp),'all') && all(isfinite(qp),'all') && any(p_amp(:)>0), ...
    'iceind:CuringField','Non-finite or zero field.');
p_final=data.p_final; clear data;
x_m=g.x_vec; y_m=g.y_vec; z_m=g.z_vec-meta.source_z_kgrid_m;
target_m=[0 0 .02]; dt_s=g.dt; Nt=g.Nt;
final_over_peak=max(abs(p_final),[],'all')/max(p_amp,[],'all');
notes=['Assumed equal per-element uncalibrated source; no elevation lens; ' ...
    'Qp=dt*sum(p^2), not measured energy or heat. p_final is only one tail sample.'];
save(partialPath,'p_amp','qp','p_final','x_m','y_m','z_m','target_m', ...
    'meta','runtime_metadata','dt_s','Nt','elapsed','started','final_over_peak','notes','-v7.3');
[ok,msg]=movefile(partialPath,rawPath);
assert(ok,'iceind:CuringField','Could not rename complete checkpoint: %s',msg);
fprintf('Saved %s in %.1f s, final/global peak = %.6g.\n',rawPath,elapsed,final_over_peak);
end
