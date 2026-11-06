function report=run_kwave_aperture_control()
%RUN_KWAVE_APERTURE_CONTROL One synthetic full64 matched-proxy-budget solve.
assert(strcmp(version('-release'),'2024b'),'iceind:MATLAB','Use R2024b.');
root=fileparts(mfilename('fullpath')); prior=path; cleanup=onCleanup(@()path(prior));
addpath(root); addpath(fullfile(root,'dependencies','k-wave-1.4.1','k-wave-toolbox-version-1.4.1'),'-begin');
old=iceind.kwave_validation_cases(); c=old(3).config;
out=fullfile(root,'results','kwave_aperture_control_2026-10-23'); c.output_dir=out;
if ~isfolder(out), mkdir(out); end
tag='full64_matched'; file=fullfile(out,[tag '.mat']);
assert(~isfile(file) && ~isfile(fullfile(out,[tag '.json'])),'iceind:NoOverwrite','Completed control exists.');
[kg,medium,source,meta,element_signals]=iceind.prepare_aperture_control(c,tag);
kg.setTime(max(kg.Nt,ceil(40e-6/kg.dt)+1),kg.dt);
[sensor,trace_meta]=iceind.offaxis_sensor(kg,meta.source_z_kgrid_m);
n=[kg.Nx kg.Ny kg.Nz]; pml=round(c.pml_m/c.dx_m); dev=gpuDevice;
rawPath=fullfile(out,[tag '.raw.mat']);
assert(~isfile(rawPath),'iceind:NoOverwrite','Raw checkpoint exists; inspect it instead of rerunning.');
assert(dev.AvailableMemory>prod(n+2*pml)*230+5e8,'iceind:Memory','Insufficient estimated GPU memory.');
fprintf('BEGIN full64_matched; gain %.9f; budget %.12g Pa^2 s m^2\n', ...
 meta.aperture_control.signal_scale,meta.aperture_control.actual_budget_pa2_s_m2);
started=tic;
data=kspaceFirstOrder3D(kg,medium,source,sensor,'PMLInside',false,'PMLSize',pml, ...
 'PlotSim',false,'DataCast','gpuArray-single','DataRecast',true);
elapsed=toc(started); x_m=kg.x_vec; y_m=kg.y_vec;
z_m=kg.z_vec-meta.source_z_kgrid_m; t_s=kg.t_array;
provenance=struct('dt_s',kg.dt,'Nt',kg.Nt,'matlab',version,'gpu',dev.Name, ...
 'source_meta',meta,'solver','kspaceFirstOrder3D','kwave_version','1.4.1');
save(rawPath,'data','trace_meta','provenance','x_m','y_m','z_m','t_s','c','elapsed','element_signals','-v7.3');
[trace_qp_pa2_s,integral_audit]=iceind.trace_integral_audit(data.p,data.p_rms,kg.dt,kg.Nt);
p_peak_pa=max(abs(data.p_max_all),abs(data.p_min_all));
metrics=iceind.pressure_focus_metrics(p_peak_pa,x_m,y_m,z_m,meta.target_m);
report=struct('tag',tag,'config',c,'source',meta,'trace_meta',trace_meta, ...
 'trace_qp_pa2_s',trace_qp_pa2_s,'integral_audit',integral_audit,'metrics',metrics, ...
 'runtime_s',elapsed,'dt_s',kg.dt,'Nt',kg.Nt,'grid_size',n,'pml_cells',pml, ...
 'matlab',version,'gpu',dev.Name,'solver','kspaceFirstOrder3D','kwave_version','1.4.1', ...
 'raw_checkpoint',rawPath,'hardware_run',false,'physical_validation','unknown', ...
 'limitations',{{'Synthetic full64 alternative, not a hardware sequence.', ...
 'Matched source pressure-square-area-time proxy, not matched power or energy.', ...
 'Element count/fill/aperture/centroid and pitch change together; no pure-pitch attribution.', ...
 'Homogeneous lossless fluid, no lens/backing/coupling/absorption/thermal/cure model.', ...
 'Sparse Qp only, finite volume/time and no offaxis fine-grid validation.'}});
save(file,'data','p_peak_pa','x_m','y_m','z_m','t_s','trace_meta','trace_qp_pa2_s','element_signals','report','-v7.3');
fid=fopen(fullfile(out,[tag '.json']),'w','n','UTF-8'); closer=onCleanup(@()fclose(fid));
fwrite(fid,jsonencode(report,'PrettyPrint',true),'char');
assert(integral_audit.rms_consistency_passed,'iceind:TraceIntegral','RMS diagnostic failed; artifacts retained.');
fprintf('FINISHED full64_matched %.1f s\n',elapsed);
end
