function reports=run_kwave_offaxis_diagnostic(caseTags)
%RUN_KWAVE_OFFAXIS_DIAGNOSTIC Sparse histories and full-volume peak controls.
assert(strcmp(version('-release'),'2024b'),'iceind:MATLAB','Use MATLAB R2024b.');
root=fileparts(mfilename('fullpath')); prior=path; cleanup=onCleanup(@()path(prior));
addpath(root); addpath(fullfile(root,'dependencies','k-wave-1.4.1','k-wave-toolbox-version-1.4.1'),'-begin');
cases=iceind.kwave_offaxis_cases();
if nargin>0
 names=cellstr(caseTags); assert(all(ismember(names,{cases.tag})),'iceind:Case','Unknown case.');
 cases=cases(ismember({cases.tag},names)); assert(~isempty(cases),'iceind:Case','No cases.');
end
out=cases(1).config.output_dir; if ~isfolder(out), mkdir(out); end
assert(canUseGPU,'iceind:GPU','Supported GPU required.');
for k=1:numel(cases)
 assert(~isfile(fullfile(out,[cases(k).tag '.mat'])) && ~isfile(fullfile(out,[cases(k).tag '.json'])), ...
  'iceind:NoOverwrite','Case %s exists; select unfinished cases only.',cases(k).tag);
end
reports=struct([]);
for k=1:numel(cases)
 c=cases(k).config; tag=cases(k).tag;
 [kg,medium,source,~,meta,element_signals]=iceind.prepare_kwave_focus(c);
 assert(meta.active_center_arrival_spread_s<1e-12,'iceind:Delay','Centre arrivals disagree.');
 kg.setTime(max(kg.Nt,ceil(cases(k).minimum_end_time_s/kg.dt)+1),kg.dt);
 [sensor,trace_meta]=iceind.offaxis_sensor(kg,meta.source_z_kgrid_m);
 n=[kg.Nx kg.Ny kg.Nz]; pml=round(c.pml_m/c.dx_m); dev=gpuDevice;
 rawPath=fullfile(out,[tag '.raw.mat']); resumed=isfile(rawPath);
 if resumed
  raw=load(rawPath);
  assert(isequaln(raw.c,c) && isequaln(raw.trace_meta,trace_meta) && ...
   strcmp(raw.meta.input_sha256,meta.input_sha256),'iceind:Checkpoint','Raw checkpoint configuration differs.');
  data=raw.data; elapsed=raw.elapsed; clear raw
 else
  predictedBytes=prod(n+2*pml)*230+5e8;
  assert(dev.AvailableMemory>predictedBytes,'iceind:Memory', ...
   'Estimated %.2f GB exceeds available %.2f GB.',predictedBytes/1e9,dev.AvailableMemory/1e9);
  writejson(fullfile(out,'progress.json'),struct('state','solving','tag',tag,'grid',n,'Nt',kg.Nt));
  fprintf('\nBEGIN %s | grid %dx%dx%d | Nt=%d | available GPU %.2f GB\n',tag,n,kg.Nt,dev.AvailableMemory/1e9);
  started=tic;
  data=kspaceFirstOrder3D(kg,medium,source,sensor,'PMLInside',false,'PMLSize',pml, ...
   'PlotSim',false,'DataCast','gpuArray-single','DataRecast',true);
  elapsed=toc(started);
  save(rawPath,'data','trace_meta','meta','c','elapsed','-v7.3');
  fprintf('RAW CHECKPOINT SAVED %s before postprocessing checks\n',tag);
 end
 x_m=kg.x_vec; y_m=kg.y_vec;
 z_m=kg.z_vec-meta.source_z_kgrid_m; t_s=kg.t_array;
 p_peak_pa=max(abs(data.p_max_all),abs(data.p_min_all));
 [trace_qp_pa2_s,integral_audit]=iceind.trace_integral_audit(data.p,data.p_rms,kg.dt,kg.Nt);
 rms_relative_error=integral_audit.rms_direct_relative_l2;
 metrics=iceind.pressure_focus_metrics(p_peak_pa,x_m,y_m,z_m,meta.target_m);
 report=struct('schema_version',1,'tag',tag,'controlled_change',cases(k).change, ...
  'reference_tag','wide65','solver','kspaceFirstOrder3D','kwave_version','1.4.1','matlab',version, ...
  'gpu',dev.Name,'runtime_s',elapsed,'grid_size',n,'dx_m',c.dx_m,'dt_s',kg.dt,'Nt',kg.Nt, ...
  'record_start_index',1,'record_window_end_s',t_s(end),'pml_cells',pml,'config',c,'source',meta, ...
  'trace_meta',trace_meta,'trace_qp_pa2_s',trace_qp_pa2_s,'rms_direct_relative_l2',rms_relative_error, ...
  'integral_audit',integral_audit,'raw_checkpoint',rawPath,'resumed_raw_checkpoint',resumed, ...
  'metrics',metrics,'recording','Sparse p(t)/RMS and full-volume positive/negative extrema; no full-volume Qp.', ...
  'qp_definition','dt*sum(p(t_n)^2), Pa^2 s; not deposited energy, heat or cure.', ...
  'absolute_pressure_calibration','unknown','material_model','none','physical_validation','unknown', ...
  'hardware_run',false,'setup_modified',false, ...
  'limitations',{{'Assumed 1 Pa flat additive pressure source and homogeneous linear lossless fluid.', ...
  'No elevation lens, matching/backing layers, coupling, container, absorption, heat or cure.', ...
  'Only X extent and PML controlled; finite Y/Z extent and time window remain.', ...
  'Peak pressure and Qp have different temporal meanings; no absolute calibration.'}});
 save(fullfile(out,[tag '.mat']),'data','p_peak_pa','x_m','y_m','z_m','t_s', ...
  'trace_meta','trace_qp_pa2_s','element_signals','report','-v7.3');
 writejson(fullfile(out,[tag '.json']),report);
 assert(integral_audit.rms_consistency_passed,'iceind:TraceIntegral', ...
  'RMS/direct relative error %.6g exceeds %.6g; raw and processed artifacts retained.', ...
  rms_relative_error,integral_audit.rms_consistency_tolerance_relative);
 if isempty(reports), reports=report; else, reports(end+1)=report; end %#ok<AGROW>
 fprintf('FINISHED %s: %.1f s; peak=(%.3f, %.3f, %.3f) mm; RMS integral error=%.3g\n', ...
  tag,elapsed,metrics.forward_peak_xyz_m*1e3,rms_relative_error);
 clear data p_peak_pa kg source sensor element_signals
end
writejson(fullfile(out,'progress.json'),struct('state','complete_selected_cases','tags',{{cases.tag}}));
end
function writejson(file,value)
fid=fopen(file,'w','n','UTF-8'); assert(fid>=0,'iceind:Output','Cannot write report.');
cleanup=onCleanup(@()fclose(fid)); fwrite(fid,jsonencode(value,'PrettyPrint',true),'char');
end
