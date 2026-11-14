function rawPath=curing_multifocus_gpu_20261114(variant,dx_um)
%CURING_GPU_RUN_CASE_20261111 Full-grid uncalibrated BLI field using CUDA.
% Records a single pulse's max_t|p| and Qp=dt*sum(p^2); no VSX/hardware.
root=fileparts(mfilename('fullpath')); old=path; cleanup=onCleanup(@()path(old));
addpath(root,fullfile(root,'dependencies','k-wave-1.4.1','k-wave-toolbox-version-1.4.1'));
bin=getenv('ICE_KWAVE_CUDA_DIR');
if isempty(bin), bin='H:/HDSP/tools/kwave_unified_1p4p2'; end
binary='kspaceFirstOrder-CUDA-windows.exe';
assert(ismember(dx_um,[65 52]) && ismember(string(variant),["Baseline","Dual","Quad"]));
cases=iceind.curing_field_cases(true);
c=cases(find(strcmp({cases.variant},'All64') & abs([cases.dx_m]-dx_um*1e-6)<1e-12,1));
c.variant=variant; c.tag=sprintf('%s_dx%d',lower(variant),dx_um);
out=fullfile(root,'results','multifocus_2026-11-14');
driver=fullfile(out,[lower(variant) '_simulation_input.mat']);
if ~isfolder(out), mkdir(out); end
tag=sprintf('%s_dx%d',lower(variant),dx_um);
rawPath=fullfile(out,[tag '_field.mat']); partial=fullfile(out,[tag '_field.partial.mat']);
sub=fullfile(out,[tag '_gpu_io']);
assert(~isfile(rawPath) && ~isfile(partial) && ~isfolder(sub),'iceind:NoOverwrite', ...
    'Existing final, partial, or GPU I/O; inspect before rerun.'); mkdir(sub);
[g,medium,source,sensor,meta]=iceind.curing_bli_prepare(c,driver);
if ~strcmp(variant,'Baseline')
    input=load(driver,'multifocus_assumption');
    meta.multifocus_assumption=input.multifocus_assumption;
    meta.delay_vs_geometric_focus_max_error_s=NaN;
    meta.active_center_arrival_spread_s=NaN;
    meta.single_focus_diagnostics_note='Not applicable to simultaneous multifocus; use curing_multifocus_check_20261114.';
end
n=meta.grid_size;
assert(islogical(sensor.mask) && isequal(size(sensor.mask),n) && all(sensor.mask(:)), ...
    'iceind:GPUField','Sensor mask must cover exactly the physical grid.');
sensor.record={'p_max_all','p_min_all','p_rms','p_final'}; sensor.record_start_index=1;
sourcePoints=nnz(source.p_mask); sourceSamples=size(source.p,2);
[gpuInfoStatus,gpuInfo]=system('nvidia-smi --query-gpu=name,driver_version,memory.total --format=csv,noheader');
runtime_metadata=struct('case',c,'matlab',version,'matlab_release',version('-release'), ...
    'kwave_matlab','1.4.1 commit 0f1a70f00645f2493318faef63111069084ccba7', ...
    'cuda_release','community kspacefirstorder-unified v1.4.2; binary CUDA v1.3 build 3.6', ...
    'adapter_sha256',iceind.curing_field_sha256(which('iceind.curing_bli_prepare')), ...
    'binary_sha256',iceind.curing_field_sha256(fullfile(bin,binary)), ...
    'solver','kspaceFirstOrder3DG','device_id',0,'pml_inside',false, ...
    'pml_cells',meta.pml_cells,'record',{sensor.record},'record_start_index',1, ...
    'source_points',sourcePoints,'source_samples',sourceSamples, ...
    'gpu_info_status',gpuInfoStatus,'gpu_info',strtrim(gpuInfo), ...
    'input_h5',fullfile(sub,'field_input.h5'),'output_h5',fullfile(sub,'field_output.h5'), ...
    'solver_log',fullfile(sub,'solver_log.txt'), ...
    'qp_units','Pa^2 s','qp_definition','discrete Nt*dt*p_rms^2; uncalibrated');
started=datestr(now,30); fprintf('Starting %s dx%d GPU at %s, Nt=%d.\n',variant,dx_um,started,g.Nt);
t=tic;
gpuError=[];
gpu_stdout=evalc("try; data=kspaceFirstOrder3DG(g,medium,source,sensor,'PMLInside',false," + ...
    "'PMLSize',meta.pml_cells,'PlotSim',false,'BinaryPath',bin,'BinaryName',binary," + ...
    "'DataPath',sub,'DataName','field','DeleteData',false,'DeviceNum',0,'VerboseLevel',1); " + ...
    "catch gpuError; end");
elapsed=toc(t);
fid=fopen(runtime_metadata.solver_log,'w','n','UTF-8');
assert(fid>=0,'iceind:GPUField','Could not write solver log.');
fwrite(fid,gpu_stdout,'char'); fclose(fid);
if ~isempty(gpuError), rethrow(gpuError); end
clear source sensor medium;
inputFile=fullfile(sub,'field_input.h5');
mode=h5read(inputFile,'/p_source_mode'); many=h5read(inputFile,'/p_source_many');
storedSamples=h5read(inputFile,'/p_source_flag');
assert(mode==2 && many==1 && storedSamples==sourceSamples,'iceind:GPUField', ...
    'GPU input source mode, multiple-source flag, or waveform length differs.');
runtime_metadata.p_source_mode=double(mode); runtime_metadata.p_source_many=double(many);
assert(isequal(size(data.p_max_all),n) && isequal(size(data.p_min_all),n) && ...
    isequal(size(data.p_final),n) && numel(data.p_rms)==prod(n), ...
    'iceind:GPUField','Unexpected full-domain sensor dimensions.');
p_amp=max(data.p_max_all,-data.p_min_all);
qp=reshape(single(double(data.p_rms).^2*double(g.Nt)*g.dt),n);
assert(all(isfinite(p_amp),'all') && all(isfinite(qp),'all') && ...
    all(isfinite(data.p_final),'all') && any(p_amp(:)>0), ...
    'iceind:GPUField','Non-finite or zero field.');
p_final=data.p_final; clear data;
x_m=g.x_vec; y_m=g.y_vec; z_m=g.z_vec-meta.source_z_kgrid_m;
target_m=[0 0 .02]; dt_s=g.dt; Nt=g.Nt;
final_over_peak=max(abs(p_final),[],'all')/max(p_amp,[],'all');
notes=['Assumed equal per-element uncalibrated source; no elevation lens; ' ...
    'Qp=dt*sum(p^2), not measured energy or heat. p_final is only one tail sample.'];
save(partial,'p_amp','qp','p_final','x_m','y_m','z_m','target_m', ...
    'meta','runtime_metadata','dt_s','Nt','elapsed','started','final_over_peak','notes','-v7.3');
[ok,msg]=movefile(partial,rawPath); assert(ok,'iceind:GPUField','Rename failed: %s',msg);
fprintf('Saved %s in %.1f s, final/global peak %.6g.\n',rawPath,elapsed,final_over_peak);
end
