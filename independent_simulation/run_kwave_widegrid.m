function report=run_kwave_widegrid(kind)
%RUN_KWAVE_WIDEGRID One fine-grid case or a short full-grid memory probe.
assert(strcmp(version('-release'),'2024b'),'iceind:MATLAB','Use R2024b.');
assert(ismember(kind,{'probe','even32','full64_matched'}),'iceind:Case','Unknown case.');
root=fileparts(mfilename('fullpath')); prior=path; cleanup=onCleanup(@()path(prior));
addpath(root); addpath(fullfile(root,'dependencies','k-wave-1.4.1','k-wave-toolbox-version-1.4.1'),'-begin');
cases=iceind.widegrid_cases(); probe=strcmp(kind,'probe');
if probe, item=cases(2); else, item=cases(strcmp({cases.kind},kind)); end
c=item.config; out=c.output_dir;
if ~isfolder(out), mkdir(out); end
if probe, tag='memory_probe_128steps'; else, tag=item.tag; end
file=fullfile(out,[tag '.mat']); jsonPath=fullfile(out,[tag '.json']);
rawPath=fullfile(out,[tag '.raw.mat']);
assert(~isfile(file) && ~isfile(jsonPath) && ~isfile(rawPath), ...
 'iceind:NoOverwrite','Artifact exists for %s; inspect it instead of rerunning.',tag);
if ~probe
 assert(isfile(fullfile(out,'memory_probe_128steps.json')),'iceind:Probe','Complete the full-grid memory probe first.');
end
[kg,medium,source,meta,element_signals]=iceind.prepare_widegrid(item);
[sensor,trace_meta]=iceind.offaxis_sensor(kg,meta.source_z_kgrid_m);
n=[kg.Nx kg.Ny kg.Nz]; pml=round(c.pml_m/c.dx_m); dev=gpuDevice;
% Historical same-solver wide65: 3.3921 GiB / 26.74M voxels (~136 B/voxel).
% The short full-grid probe verifies this extrapolation before full solves.
estimatedBytes=prod(n+2*pml)*140+5e8;
availableBefore=dev.AvailableMemory;
if probe
 % The conservative extrapolation is not a measurement. Permit the bounded
 % probe above a lower allocation floor; an actual CUDA OOM aborts the probe.
 assert(availableBefore>prod(n+2*pml)*100+5e8,'iceind:Memory','Insufficient memory even for the allocation probe.');
 kg.setTime(128,kg.dt); source.p=source.p(:,1:min(128,size(source.p,2)));
else
 probeReport=jsondecode(fileread(fullfile(out,'memory_probe_128steps.json')));
 assert(iceind.widegrid_probe_matches(probeReport,n,pml,dev.Name,availableBefore), ...
  'iceind:Memory','Memory availability or grid differs from the successful probe.');
end
fprintf('BEGIN %s | grid %dx%dx%d | Nt=%d | available GPU %.3f GB\n',tag,n,kg.Nt,availableBefore/1e9);
started=tic;
data=kspaceFirstOrder3D(kg,medium,source,sensor,'PMLInside',false,'PMLSize',pml, ...
 'PlotSim',false,'DataCast','gpuArray-single','DataRecast',true);
elapsed=toc(started); x_m=kg.x_vec; y_m=kg.y_vec;
z_m=kg.z_vec-meta.source_z_kgrid_m; t_s=kg.t_array;
if probe
 report=struct('tag',tag,'purpose','Resource probe only; truncated source and time, not a physical field result.', ...
  'grid_size',n,'grid_with_pml',n+2*pml,'Nt',kg.Nt,'runtime_s',elapsed, ...
  'available_gpu_bytes_before',availableBefore,'estimated_bytes',estimatedBytes, ...
  'matlab',version,'gpu',dev.Name,'solver','kspaceFirstOrder3D','kwave_version','1.4.1');
 writejson(jsonPath,report); fprintf('PROBE COMPLETE %.1f s\n',elapsed); return
end
provenance=struct('dt_s',kg.dt,'Nt',kg.Nt,'matlab',version,'gpu',dev.Name, ...
 'source_meta',meta,'solver','kspaceFirstOrder3D','kwave_version','1.4.1');
save(rawPath,'data','trace_meta','provenance','x_m','y_m','z_m','t_s','c','elapsed','element_signals','-v7.3');
fprintf('RAW CHECKPOINT SAVED %s\n',tag);
[trace_qp_pa2_s,integral_audit]=iceind.trace_integral_audit(data.p,data.p_rms,kg.dt,kg.Nt);
p_peak_pa=max(abs(data.p_max_all),abs(data.p_min_all));
metrics=iceind.pressure_focus_metrics(p_peak_pa,x_m,y_m,z_m,meta.target_m);
report=struct('tag',tag,'kind',kind,'config',c,'source',meta,'trace_meta',trace_meta, ...
 'trace_qp_pa2_s',trace_qp_pa2_s,'integral_audit',integral_audit,'metrics',metrics, ...
 'runtime_s',elapsed,'dt_s',kg.dt,'Nt',kg.Nt,'grid_size',n,'pml_cells',pml, ...
 'matlab',version,'gpu',dev.Name,'solver','kspaceFirstOrder3D','kwave_version','1.4.1', ...
 'raw_checkpoint',rawPath,'hardware_run',false,'physical_validation','unknown','material_model','none', ...
 'limitations',{{'Assumed lossless fluid and flat uncalibrated pressure source; finite domain/PML/time.', ...
 'Source proxy budget matched across grids, not actual power or energy.', ...
 'Source rasterization and waveform sampling change with dx; sparse nearest-voxel trace coordinates differ.', ...
 'Synthetic full64 changes count/pitch/fill/aperture/centroid together; not a hardware sequence.', ...
 'No elevation lens, coupling, backing, container, absorption, heat or SonoInk cure.'}});
save(file,'data','p_peak_pa','x_m','y_m','z_m','t_s','trace_meta','trace_qp_pa2_s','element_signals','report','-v7.3');
writejson(jsonPath,report);
assert(integral_audit.rms_consistency_passed,'iceind:TraceIntegral','RMS diagnostic failed; artifacts retained.');
fprintf('FINISHED %s %.1f s; main peak z %.3f mm\n',tag,elapsed,metrics.forward_peak_xyz_m(3)*1e3);
end
function writejson(file,value)
fid=fopen(file,'w','n','UTF-8'); assert(fid>=0,'iceind:Output','Cannot write report.');
cleanup=onCleanup(@()fclose(fid)); fwrite(fid,jsonencode(value,'PrettyPrint',true),'char');
end
