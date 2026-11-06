function reports=run_kwave_singlepoint_validation(caseTags)
%RUN_KWAVE_SINGLEPOINT_VALIDATION Controlled standalone solves; no VSX.
% Existing complete artifacts are refused, not silently overwritten.
assert(strcmp(version('-release'),'2024b'),'iceind:MATLAB','Use MATLAB R2024b.');
root=fileparts(mfilename('fullpath')); prior=path; cleanup=onCleanup(@()path(prior));
addpath(root); addpath(fullfile(root,'dependencies','k-wave-1.4.1','k-wave-toolbox-version-1.4.1'),'-begin');
cases=iceind.kwave_validation_cases();
if nargin>0
 selected=ismember({cases.tag},cellstr(caseTags));
 assert(any(selected),'iceind:Case','No known case selected.'); cases=cases(selected);
end
out=cases(1).config.output_dir; if ~isfolder(out), mkdir(out); end
assert(canUseGPU,'iceind:GPU','Supported GPU required.');
for k=1:numel(cases)
 assert(~isfile(fullfile(out,[cases(k).tag '.mat'])) && ~isfile(fullfile(out,[cases(k).tag '.json'])), ...
  'iceind:NoOverwrite','Case %s already exists; select only unfinished cases.',cases(k).tag);
end
reports=struct([]);
for k=1:numel(cases)
 c=cases(k).config; tag=cases(k).tag;
 [kg,medium,source,sparseSensor,meta,element_signals]=iceind.prepare_kwave_focus(c);
 assert(meta.active_center_arrival_spread_s<1e-12,'iceind:Delay','Centre arrivals disagree.');
 n=[kg.Nx kg.Ny kg.Nz]; pml=round(c.pml_m/c.dx_m);
 kg.setTime(max(kg.Nt,ceil(cases(k).minimum_end_time_s/kg.dt)+1),kg.dt);
 sensor=struct('mask',true(n),'record',{{'p_rms','p_max_all','p_min_all'}},'record_start_index',1);
 dev=gpuDevice; predictedBytes=prod(n+2*pml)*230+5e8;
 assert(dev.AvailableMemory>predictedBytes,'iceind:Memory', ...
  'Estimated %.2f GB exceeds available %.2f GB.',predictedBytes/1e9,dev.AvailableMemory/1e9);
 writejson(fullfile(out,'progress.json'),struct('state','solving','tag',tag,'grid',n,'Nt',kg.Nt));
 fprintf('\nBEGIN %s | grid %dx%dx%d | Nt=%d | available GPU %.2f GB\n',tag,n,kg.Nt,dev.AvailableMemory/1e9);
 started=tic;
 data=kspaceFirstOrder3D(kg,medium,source,sensor,'PMLInside',false,'PMLSize',pml, ...
  'PlotSim',false,'DataCast','gpuArray-single','DataRecast',true);
 elapsed=toc(started);
 x_m=kg.x_vec; y_m=kg.y_vec; z_m=kg.z_vec-meta.source_z_kgrid_m; t_s=kg.t_array;
 p_peak_pa=max(abs(data.p_max_all),abs(data.p_min_all));
 qp_pa2_s=reshape(iceind.rms_to_qp(data.p_rms,kg.dt,kg.Nt),n);
 metrics=iceind.pressure_focus_metrics(p_peak_pa,x_m,y_m,z_m,meta.target_m);
 material=[-4 4;-2 2;10 28]*1e-3;
 halfwidths=[.5 .5 .5;.5 1 .5;1 1 1;.5 1 2]*1e-3;
 exposure=struct([]);
 for j=1:size(halfwidths,1)
  m=iceind.pressure_exposure_metrics(qp_pa2_s,p_peak_pa,x_m,y_m,z_m,meta.target_m,halfwidths(j,:),material);
  if isempty(exposure), exposure=m; else, exposure(end+1)=m; end %#ok<AGROW>
 end
 sample_indices=find(sparseSensor.mask); sample_qp_pa2_s=qp_pa2_s(sample_indices);
 forward=qp_pa2_s(:,:,z_m>=2e-3);
 report=struct('schema_version',1,'tag',tag,'controlled_change',cases(k).change, ...
  'solver','kspaceFirstOrder3D','kwave_version','1.4.1','matlab',version,'gpu',dev.Name, ...
  'runtime_s',elapsed,'grid_size',n,'dx_m',c.dx_m,'dt_s',kg.dt,'Nt',kg.Nt, ...
  'record_start_index',1,'record_window_end_s',kg.t_array(end),'pml_cells',pml,'config',c,'source',meta, ...
  'metrics',metrics,'exposure',exposure, ...
  'observed_forward_qp_integral_pa2_s_m3',sum(forward,'all')*c.dx_m^3, ...
  'qp_definition','dt * Nt * p_rms^2 = discrete sum_t(p^2)*dt, Pa^2 s; record starts at step 1.', ...
  'recording','Full-volume RMS and time extrema only; no full-domain time histories.', ...
  'target_provenance','synthetic','material_provenance','assumed_box_not_actual_sample', ...
  'absolute_pressure_calibration','unknown','physical_validation','unknown', ...
  'hardware_run',false,'setup_modified',false,'full_sequence_simulated',false, ...
  'limitations',{{'Homogeneous linear lossless fluid and assumed 1 Pa source; no measured electric-to-acoustic transfer.', ...
  'Elevation lens, matching/backing layers, interelement coupling, container walls and absorption omitted.', ...
  'Qp volume fractions are pressure-squared-time proxies, not acoustic energy, heat, cure or safety.', ...
  'Finite domain and 40 us recording window; all-space/all-time convergence not established.', ...
  'Box sizes and 5 percent/0.13 mm numerical sensitivity criteria are proposed, not material/device specifications.'}});
 save(fullfile(out,[tag '.mat']),'data','p_peak_pa','qp_pa2_s','x_m','y_m','z_m','t_s', ...
  'sample_indices','sample_qp_pa2_s','element_signals','report','-v7.3');
 writejson(fullfile(out,[tag '.json']),report);
 if isempty(reports), reports=report; else, reports(end+1)=report; end %#ok<AGROW>
 fprintf('FINISHED %s: %.1f s; peak z %.3f mm; target error %.3f mm\n', ...
  tag,elapsed,metrics.forward_peak_xyz_m(3)*1e3,metrics.forward_peak_error_m*1e3);
 clear data p_peak_pa qp_pa2_s forward kg source sensor sparseSensor element_signals
end
writejson(fullfile(out,'progress.json'),struct('state','complete_selected_cases','tags',{{cases.tag}}));
end
function writejson(file,value)
fid=fopen(file,'w','n','UTF-8'); assert(fid>=0,'iceind:Output','Cannot write report.');
cleanup=onCleanup(@()fclose(fid)); fwrite(fid,jsonencode(value,'PrettyPrint',true),'char');
end
