function rawPath=curing_gpu_shallow_run_20261111(variant,gridLabel)
%CURING_GPU_SHALLOW_RUN_20261111 Reduced-z diagnostic, not full-field comparison.
% Check the 52 um reduced domain against the full domain before using 43.333 um.
root=fileparts(mfilename('fullpath')); old=path; cleanup=onCleanup(@()path(old));
addpath(root,fullfile(root,'dependencies','k-wave-1.4.1','k-Wave'));
bin=fullfile(root,'dependencies','kwave-cuda-unified-v1.4.2'); binary='kspaceFirstOrder-CUDA-windows.exe';
assert(ismember(string(variant),["All64","Center16"]) && ...
    ismember(string(gridLabel),["dx52","dx43p333","dx32p5"]),'iceind:Shallow','Unsupported case.');
cases=iceind.curing_field_cases(); i=find(strcmp({cases.variant},variant) & ...
    abs([cases.dx_m]-52e-6)<1e-12,1); c=cases(i);
if strcmp(gridLabel,'dx43p333'), c.dx_m=130e-6/3; end
if strcmp(gridLabel,'dx32p5'), c.dx_m=32.5e-6; end
c.domain_m=[15.6 10.4 5.2]*1e-3; c.tag=[lower(variant) '_' gridLabel '_shallow'];
drivers=struct('All64','ICE_CuringOnly_ExposureFFFFFFFFFFFFFFFF_exposure_only.mat', ...
    'Center16','ICE_CuringOnly_Exposure000000FFFF000000_exposure_only.mat');
driver=fullfile(root,'results','curing_export_2026-11-10',drivers.(variant));
out=fullfile(root,'results','curing_field_2026-11-10','bli_gpu_shallow');
if ~isfolder(out), mkdir(out); end
tag=[lower(variant) '_' gridLabel]; rawPath=fullfile(out,[tag '_field.mat']);
partial=fullfile(out,[tag '_field.partial.mat']); io=fullfile(out,[tag '_gpu_io']);
assert(~isfile(rawPath) && ~isfile(partial) && ~isfolder(io),'iceind:NoOverwrite', ...
    'Existing final, partial, or GPU I/O; inspect before rerun.'); mkdir(io);
[g,medium,source,sensor,meta]=iceind.curing_bli_prepare(c,driver);
n=meta.grid_size; assert(islogical(sensor.mask) && isequal(size(sensor.mask),n) && all(sensor.mask(:)));
sourcePoints=nnz(source.p_mask); sourceSamples=size(source.p,2);
sensor.record={'p_max_all','p_min_all','p_rms','p_final'}; sensor.record_start_index=1;
[status,gpuInfo]=system('nvidia-smi --query-gpu=name,driver_version,memory.total --format=csv,noheader');
runtime=struct('case',c,'matlab',version,'kwave_matlab','1.4.1', ...
    'cuda_release','community kspacefirstorder-unified v1.4.2', ...
    'adapter_sha256',iceind.curing_field_sha256(which('iceind.curing_bli_prepare')), ...
    'binary_sha256',iceind.curing_field_sha256(fullfile(bin,binary)), ...
    'gpu_info_status',status,'gpu_info',strtrim(gpuInfo),'record',{sensor.record}, ...
    'source_points',sourcePoints,'source_samples',sourceSamples, ...
    'qp_definition','Nt*dt*p_rms^2; assumed Pa^2 s for one pulse');
t=tic; txt=evalc("data=kspaceFirstOrder3DG(g,medium,source,sensor,'PMLInside',false," + ...
    "'PMLSize',meta.pml_cells,'PlotSim',false,'BinaryPath',bin,'BinaryName',binary," + ...
    "'DataPath',io,'DataName','field','DeleteData',false,'DeviceNum',0,'VerboseLevel',1);");
elapsed=toc(t); fid=fopen(fullfile(io,'solver_log.txt'),'w','n','UTF-8');
assert(fid>=0); fwrite(fid,txt,'char'); fclose(fid); clear medium source sensor;
input=fullfile(io,'field_input.h5'); mode=h5read(input,'/p_source_mode');
many=h5read(input,'/p_source_many'); samples=h5read(input,'/p_source_flag');
assert(mode==2 && many==1 && samples==sourceSamples,'iceind:Shallow','Invalid source HDF5.');
assert(isequal(size(data.p_max_all),n) && isequal(size(data.p_min_all),n) && ...
    isequal(size(data.p_final),n) && numel(data.p_rms)==prod(n),'iceind:Shallow','Invalid output shape.');
p_amp=max(data.p_max_all,-data.p_min_all); qp=reshape(single(double(data.p_rms).^2*g.Nt*g.dt),n);
p_final=data.p_final; clear data;
assert(all(isfinite(p_amp),'all') && all(isfinite(qp),'all') && all(isfinite(p_final),'all') ...
    && any(p_amp(:)>0),'iceind:Shallow','Invalid output values.');
x_m=g.x_vec; y_m=g.y_vec; z_m=g.z_vec-meta.source_z_kgrid_m; Nt=g.Nt; dt_s=g.dt;
note='Reduced axial domain; diagnostic only; compare 52 um with full domain before interpretation.';
save(partial,'p_amp','qp','p_final','x_m','y_m','z_m','Nt','dt_s','meta','runtime','elapsed','note','-v7.3');
[ok,msg]=movefile(partial,rawPath); assert(ok,'iceind:Shallow','Rename failed: %s',msg);
fprintf('Saved reduced domain %s in %.1f s.\n',tag,elapsed);
end
