function result=curing_rms_resource_probe_20261110(dx_um)
%CURING_RMS_RESOURCE_PROBE Short full-domain CPU resource check.
% Area-overlap source and 16 steps only: not a field or BLI solver result.
root=fileparts(mfilename('fullpath')); old=path; cleanup=onCleanup(@()path(old));
addpath(root,fullfile(root,'dependencies','k-wave-1.4.1','k-Wave'));
if nargin<1, dx_um=65; end
assert(ismember(dx_um,[65 52]),'iceind:QpResource','Use dx_um=65 or 52.');
if dx_um==65, folder='rms_resource_probe'; else, folder='rms_resource_probe_dx52'; end
out=fullfile(root,'results','curing_field_2026-11-10',folder);
assert(~isfolder(out),'iceind:NoOverwrite','Resource output already exists.'); mkdir(out);
cases=iceind.curing_field_cases(); c=cases(find(abs([cases.dx_m]-dx_um*1e-6)<1e-12,1));
driver=fullfile(root,'results','curing_export_2026-11-10', ...
    'ICE_CuringOnly_ExposureFFFFFFFFFFFFFFFF_exposure_only.mat');
[g,medium,source,sensor,meta]=iceind.curing_field_prepare(c,driver);
steps=16; g.setTime(steps,g.dt); source.p=source.p(:,1:steps);
sensor.record={'p_max_all','p_min_all','p_rms'}; sensor.record_start_index=1;
p=System.Diagnostics.Process.GetCurrentProcess(); p.Refresh();
baseline=double(p.WorkingSet64); t=tic;
data=kspaceFirstOrder3D(g,medium,source,sensor,'PMLInside',false, ...
    'PMLSize',meta.pml_cells,'PlotSim',false,'DataCast','single'); elapsed=toc(t);
p.Refresh(); endWorking=double(p.WorkingSet64); lifetimePeak=double(p.PeakWorkingSet64);
assert(numel(data.p_rms)==prod(meta.grid_size) && all(isfinite(data.p_rms)), ...
    'iceind:QpResource','Unexpected RMS data.');
result=struct('purpose','16-step CPU resource check only; area-overlap, not BLI or a field', ...
    'grid',meta.grid_size,'pml_cells',meta.pml_cells,'dt_s',g.dt,'steps',steps, ...
    'record',{sensor.record},'runtime_s',elapsed, ...
    'points_steps_per_s',prod(double(meta.grid_size))*steps/elapsed, ...
    'baseline_working_set_bytes',baseline,'end_working_set_bytes',endWorking, ...
    'lifetime_peak_working_set_bytes',lifetimePeak, ...
    'memory_note','lifetime peak cannot be attributed to this solve', ...
    'matlab',version,'generated_local',datestr(now,30));
iceind.curing_field_write_json(fullfile(out,'resource.json'),result);
disp(result);
end
