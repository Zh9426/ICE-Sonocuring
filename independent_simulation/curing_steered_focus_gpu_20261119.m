function rawPath=curing_steered_focus_gpu_20261119(angle_deg,dx_um,prepare_only)
%CURING_STEERED_FOCUS_GPU_20261119 Uncalibrated All64 CUDA steering experiment.
% Same BLI adapter and equal assumed 1 Pa source as the existing depth study.
% No VSX or hardware actions. prepare_only writes solver HDF5 without running it.
if nargin<2 || isempty(dx_um), dx_um=52; end
if nargin<3 || isempty(prepare_only), prepare_only=false; end
validateattributes(prepare_only,{'logical','numeric'},{'scalar'});
assert(isscalar(dx_um) && dx_um==52,'iceind:SteeredFocusGrid', ...
    'This study is specified at 52 um; do not silently change the grid.');
root=fileparts(mfilename('fullpath'));
old=path; cleanup=onCleanup(@()path(old)); %#ok<NASGU>
kwave=fullfile(root,'dependencies','k-wave-1.4.1','k-wave-toolbox-version-1.4.1');
assert(isfile(fullfile(kwave,'kWaveGrid.m')),'iceind:SteeredFocusDependency', ...
    'Missing local k-Wave MATLAB 1.4.1 toolbox.');
addpath(root,kwave);
binary='kspaceFirstOrder-CUDA-windows.exe';
bin=local_binary_dir(root,binary);
cases=iceind.curing_field_cases(true);
c=cases(find(strcmp({cases.variant},'All64') & abs([cases.dx_m]-52e-6)<1e-12,1));
base=fullfile(root,'results','curing_export_2026-11-10', ...
    'ICE_CuringOnly_ExposureFFFFFFFFFFFFFFFF_exposure_only.mat');
[s,target_m]=iceind.steered_focus_input_20261119(load(base),angle_deg);
if angle_deg<0, signTag='m'; else, signTag='p'; end
variant=sprintf('angle_%s%02d',signTag,abs(angle_deg));
tag=sprintf('%s_dx%d',variant,dx_um);
out=iceind.steered_focus_output_dir_20261119(root,getenv('ICE_STEERED_RUN_TAG'));
if ~isfolder(out), mkdir(out); end
rawPath=fullfile(out,[tag '_field.mat']);
partial=fullfile(out,[tag '_field.partial.mat']);
sub=fullfile(out,[tag '_gpu_io']);
assert(~isfile(rawPath) && ~isfile(partial) && ~isfolder(sub), ...
    'iceind:NoOverwrite','Existing final, partial, or GPU I/O; inspect before rerun.');
driver=fullfile(out,[variant '_simulation_input.mat']);
if isfile(driver)
    prior=load(driver);
    assert(isequaln(prior,s),'iceind:SteeredFocusInput','Existing simulation input differs.');
else
    save(driver,'-struct','s');
end
c.variant=variant; c.tag=tag; c.output_dir=out;
c.domain_m=[31.2 6.24 31.2]*1e-3;
domainOverride=getenv('ICE_STEERED_DOMAIN_MM');
if ~isempty(domainOverride)
    override=sscanf(strrep(domainOverride,',',' '),'%f')';
    assert(numel(override)==3 && all(isfinite(override)) && all(override>0), ...
        'iceind:SteeredFocusGrid','ICE_STEERED_DOMAIN_MM requires three positive lengths in mm.');
    c.domain_m=override*1e-3;
end
c.minimum_end_time_s=40e-6;
mkdir(sub);
manifest=struct('stage','source_preparation','angle_deg',angle_deg,'target_m',target_m, ...
    'grid_size',round(c.domain_m/c.dx_m),'domain_m',c.domain_m, ...
    'dx_m',c.dx_m,'pml_cells',round(c.pml_m/c.dx_m), ...
    'started',datestr(now,30),'input_driver',driver,'prepare_only',logical(prepare_only));
manifest.domain_override_mm=domainOverride;
manifestPath=fullfile(sub,'stage.json'); local_stage(manifestPath,manifest);
try
    [g,medium,source,sensor,meta]=iceind.curing_bli_prepare(c,driver);
    n=meta.grid_size;
    assert(isequal(n,round(c.domain_m/c.dx_m)) && meta.pml_cells==20, ...
        'iceind:SteeredFocusGrid','Unexpected common domain or PML.');
    assert(islogical(sensor.mask) && isequal(size(sensor.mask),n) && all(sensor.mask(:)), ...
        'iceind:GPUField','Sensor mask must cover the physical grid.');
    assert(strcmp(source.p_mode,'additive') && g.t_array(end)>=40e-6 && ...
        g.t_array(end)>=meta.required_time_end_s-1e-12, ...
        'iceind:GPUField','Adapter source mode or full time window changed.');
    sensor.record={'p_max_all','p_min_all','p_rms','p_final'};
    sensor.record_start_index=1;
    meta.solver='kspaceFirstOrder3DG';
    meta.solver_device='cuda';
    meta.sensor_record=sensor.record;
    meta.solver_binary_path=fullfile(bin,binary);
    meta.solver_device_id=0;
    sourcePoints=nnz(source.p_mask); sourceSamples=size(source.p,2);
    [gpuInfoStatus,gpuInfo]=system( ...
        'nvidia-smi --query-gpu=name,driver_version,memory.total,memory.free --format=csv,noheader');
    runtime_metadata=struct('case',c,'matlab',version,'matlab_release',version('-release'), ...
        'kwave_matlab','1.4.1 local toolbox directory; commit unknown', ...
        'kwave_matlab_path',kwave, ...
        'kwave_grid_sha256',iceind.curing_field_sha256(fullfile(kwave,'kWaveGrid.m')), ...
        'cuda_release', ...
        'community kspacefirstorder-unified v1.4.2; binary CUDA v1.3 build 3.6', ...
        'adapter_sha256',iceind.curing_field_sha256(which('iceind.curing_bli_prepare')), ...
        'binary_path',fullfile(bin,binary), ...
        'binary_sha256',iceind.curing_field_sha256(fullfile(bin,binary)), ...
        'solver','kspaceFirstOrder3DG','device_id',0,'pml_inside',false, ...
        'pml_cells',meta.pml_cells,'record',{sensor.record},'record_start_index',1, ...
        'source_points',sourcePoints,'source_samples',sourceSamples, ...
        'gpu_info_status',gpuInfoStatus,'gpu_info',strtrim(gpuInfo), ...
        'input_h5',fullfile(sub,'field_input.h5'), ...
        'output_h5',fullfile(sub,'field_output.h5'),'solver_log',fullfile(sub,'solver_log.txt'), ...
        'qp_units','Pa^2 s','qp_definition','discrete Nt*dt*p_rms^2; uncalibrated');
    started=manifest.started;
    manifest.Nt=g.Nt; manifest.dt_s=g.dt; manifest.t_end_s=g.t_array(end);
    manifest.source_points=sourcePoints; manifest.source_samples=sourceSamples;
    manifest.source_matrix_bytes=meta.memory.source_matrix_bytes;
    save(fullfile(sub,'preparation_metadata.mat'),'meta','runtime_metadata','target_m','angle_deg');
    t=tic; gpuError=[];
    if prepare_only
        manifest.stage='writing_prepared_input'; local_stage(manifestPath,manifest);
        gpu_stdout=evalc("try; kspaceFirstOrder3D(g,medium,source,sensor,'PMLInside',false," + ...
            "'PMLSize',meta.pml_cells,'PlotSim',false,'DataCast','single'," + ...
            "'SaveToDisk',runtime_metadata.input_h5,'SaveToDiskExit',true); catch gpuError; end");
    else
        manifest.stage='solver_running'; local_stage(manifestPath,manifest);
        fprintf('Starting %s at %s, grid [%s], Nt=%d.\n',tag,started,num2str(n),g.Nt);
        diary(runtime_metadata.solver_log);
        diaryCleanup=onCleanup(@()diary('off'));
        try
            data=kspaceFirstOrder3DG(g,medium,source,sensor,'PMLInside',false, ...
                'PMLSize',meta.pml_cells,'PlotSim',false,'BinaryPath',bin,'BinaryName',binary, ...
                'DataPath',sub,'DataName','field','DeleteData',false,'DeviceNum',0,'VerboseLevel',1);
            fprintf('Solver completed %s at %s.\n',tag,datestr(now,30));
        catch gpuError
            fprintf('Solver failed %s at %s: %s\n',tag,datestr(now,30),gpuError.message);
        end
        diary('off'); clear diaryCleanup;
    end
    elapsed=toc(t);
    if prepare_only
        fid=fopen(runtime_metadata.solver_log,'w','n','UTF-8');
        assert(fid>=0,'iceind:GPUField','Could not write solver log.');
        fwrite(fid,gpu_stdout,'char'); fclose(fid);
    end
    if ~isempty(gpuError), rethrow(gpuError); end
    clear source sensor medium;
    mode=h5read(runtime_metadata.input_h5,'/p_source_mode');
    many=h5read(runtime_metadata.input_h5,'/p_source_many');
    storedSamples=h5read(runtime_metadata.input_h5,'/p_source_flag');
    assert(mode==2 && many==1 && storedSamples==sourceSamples,'iceind:GPUField', ...
        'GPU input source mode, multiple-source flag, or waveform length differs.');
    runtime_metadata.p_source_mode=double(mode); runtime_metadata.p_source_many=double(many);
    if prepare_only
        manifest.stage='prepared_only'; manifest.elapsed_s=elapsed;
        local_stage(manifestPath,manifest); rawPath=runtime_metadata.input_h5; return;
    end
    manifest.stage='saving_field'; local_stage(manifestPath,manifest);
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
    dt_s=g.dt; Nt=g.Nt; t_end_s=g.t_array(end);
    final_over_peak=max(abs(p_final),[],'all')/max(p_amp,[],'all');
    notes=['Synthetic steering, assumed equal uncalibrated source, homogeneous lossless fluid, ' ...
        'no elevation lens. Qp=Nt*dt*p_rms^2 is not energy, heat, dose, safety or cure. ' ...
        'Single 52 um grid does not establish convergence; p_final is one tail sample.'];
    save(partial,'p_amp','qp','p_final','x_m','y_m','z_m','target_m','angle_deg', ...
        'meta','runtime_metadata','dt_s','Nt','t_end_s','elapsed','started', ...
        'final_over_peak','notes','-v7.3');
    [ok,msg]=movefile(partial,rawPath); assert(ok,'iceind:GPUField','Rename failed: %s',msg);
    manifest.stage='complete'; manifest.elapsed_s=elapsed; manifest.raw_path=rawPath;
    local_stage(manifestPath,manifest);
    fprintf('Saved %s in %.1f s, final/global peak %.6g.\n',rawPath,elapsed,final_over_peak);
catch err
    manifest.stage='failed'; manifest.error_identifier=err.identifier;
    manifest.error_message=err.message; local_stage(manifestPath,manifest);
    fid=fopen(fullfile(sub,'failure.txt'),'w','n','UTF-8');
    if fid>=0, fprintf(fid,'%s\n',getReport(err,'extended','hyperlinks','off')); fclose(fid); end
    rethrow(err);
end
end

function bin=local_binary_dir(root,binary)
override=getenv('ICE_KWAVE_CUDA_DIR');
if ~isempty(override)
    assert(isfile(fullfile(override,binary)),'iceind:SteeredFocusDependency', ...
        'ICE_KWAVE_CUDA_DIR does not contain %s.',binary);
    bin=override; return;
end
candidates={fullfile(root,'dependencies','kwave-cuda-unified-v1.4.2'), ...
    'H:/HDSP/tools/kwave_unified_1p4p2'};
for k=1:numel(candidates)
    if isfile(fullfile(candidates{k},binary)), bin=candidates{k}; return; end
end
error('iceind:SteeredFocusDependency','Missing CUDA binary; set ICE_KWAVE_CUDA_DIR.');
end

function local_stage(filename,manifest)
manifest.updated=datestr(now,30);
fid=fopen(filename,'w','n','UTF-8');
assert(fid>=0,'iceind:SteeredFocusManifest','Could not write stage manifest.');
closeFile=onCleanup(@()fclose(fid)); %#ok<NASGU>
fwrite(fid,jsonencode(manifest,PrettyPrint=true),'char');
end
