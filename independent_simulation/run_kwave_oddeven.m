function reports=run_kwave_oddeven(spacings)
%RUN_KWAVE_ODDEVEN Actual 3D propagation of saved physical even-element TX.
% Default coarse/fine runs preserve one physical domain and source geometry.
if nargin<1, spacings=[65 52]*1e-6; end
assert(strcmp(version('-release'),'2024b'),'iceind:MATLAB','Use MATLAB R2024b.');
root=fileparts(mfilename('fullpath')); old=path; cleanup=onCleanup(@()path(old));
addpath(root); kw=fullfile(root,'dependencies','k-wave-1.4.1','k-wave-toolbox-version-1.4.1');
addpath(kw,'-begin');
c=iceind.kwave_focus_config(); if ~isfolder(c.output_dir), mkdir(c.output_dir); end
assert(canUseGPU,'iceind:GPU','A supported GPU is required for the specified 3D grids.');
reports=struct([]);
for runIndex=1:numel(spacings)
    c.dx_m=spacings(runIndex);
    [kg,medium,source,sensor,meta,element_signals]=iceind.prepare_kwave_focus(c);
    dev=gpuDevice; pml=round(c.pml_m/c.dx_m); n=[kg.Nx kg.Ny kg.Nz];
    predictedBytes=prod(n+2*pml)*230+5e8;
    assert(dev.AvailableMemory>predictedBytes,'iceind:Memory', ...
        'Estimated requirement %.2f GB exceeds available %.2f GB; no run launched.',predictedBytes/1e9,dev.AvailableMemory/1e9);
    tag=sprintf('even32_focus20mm_dx%.0fum',c.dx_m*1e6);
    writejson(fullfile(c.output_dir,'progress.json'),struct('state','solving','tag',tag,'grid',n,'Nt',kg.Nt));
    fprintf('\nBEGIN %s | %dx%dx%d | Nt %d | GPU %s | available %.2f GB\n', ...
        tag,n,kg.Nt,dev.Name,dev.AvailableMemory/1e9);
    started=tic;
    data=kspaceFirstOrder3D(kg,medium,source,sensor,'PMLInside',false,'PMLSize',pml, ...
        'PlotSim',false,'DataCast','gpuArray-single','DataRecast',true);
    elapsed=toc(started);
    x_m=kg.x_vec; y_m=kg.y_vec; z_m=kg.z_vec-meta.source_z_kgrid_m; t_s=kg.t_array;
    p_peak_pa=max(abs(data.p_max_all),abs(data.p_min_all));
    metrics=iceind.pressure_focus_metrics(p_peak_pa,x_m,y_m,z_m,meta.target_m);
    report=struct('schema_version',1,'solver','kspaceFirstOrder3D','kwave_version','1.4.1', ...
        'matlab',version,'gpu',dev.Name,'runtime_s',elapsed,'grid_size',n, ...
        'dx_m',c.dx_m,'dt_s',kg.dt,'Nt',kg.Nt,'pml_cells',pml,'cfl',c.cfl, ...
        'config',c,'source',meta,'metrics',metrics, ...
        'pressure_units','Pa under assumed 1 Pa additive source; not calibrated physical output', ...
        'recording','Full XYZ p_max_all/p_min_all and max_t(abs(p)); sparse sensors record p(t).', ...
        'physical_validation','unknown','convergence','requires_comparison', ...
        'hardware_run',false,'setup_modified',false,'full_sequence_simulated',false, ...
        'limitations',{{'Homogeneous linear lossless fluid; no tissue, attenuation, temperature or cure.', ...
        'Flat finite rectangular sources; elevation lens, backing, matching layers and coupling omitted.', ...
        'Finite domain; unrecorded wide-angle grating lobes may leave the domain.', ...
        'Single exposure TX only; no imaging reconstruction or Verasonics runtime validation.', ...
        '0.5 mm focus threshold is a proposed numerical diagnostic, not a device specification.'}});
    sensor_coordinates_m=meta.sensor_coordinates_m;
    save(fullfile(c.output_dir,[tag '.mat']),'data','p_peak_pa','x_m','y_m','z_m','t_s', ...
        'element_signals','sensor_coordinates_m','report','-v7.3');
    writejson(fullfile(c.output_dir,[tag '.json']),report);
    render_kwave_oddeven(fullfile(c.output_dir,[tag '.mat']));
    if isempty(reports), reports=report; else, reports(end+1)=report; end %#ok<AGROW>
    fprintf('FINISHED %s: %.1f s, peak [%.3f %.3f %.3f] mm, target error %.3f mm\n', ...
        tag,elapsed,metrics.forward_peak_xyz_m*1e3,metrics.forward_peak_error_m*1e3);
    clear data p_peak_pa source sensor kg element_signals
end
if numel(spacings)==2, compare_kwave_oddeven; end
writejson(fullfile(c.output_dir,'progress.json'),struct('state','complete','completed_grids_m',spacings));
end
function writejson(file,value)
fid=fopen(file,'w','n','UTF-8'); assert(fid>=0,'iceind:Output','Cannot open output file.');
cleanup=onCleanup(@()fclose(fid)); fwrite(fid,jsonencode(value,'PrettyPrint',true),'char');
end
