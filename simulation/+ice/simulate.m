function result = simulate(cfg, reference)
%SIMULATE Complete 3-D acoustic screening run. All physical data are SI.
% reference is a common scalar reference struct from a shared-focused run.
% Without it a baseline with this geometry/source/grid is computed once.
ice.validate_config(cfg);
if strcmp(cfg.array.type,'dual_array')
    geom=ice.make_probe_geometry(cfg.probe);
else
    geom=ice.make_geometry(cfg.array);
end
grid=ice.make_grid(cfg.grid);
partition=ice.partition_elements(geom,cfg.architecture);
sequence=ice.make_sequence(geom,partition.curing_mask,cfg);
p=ice.solve_pressure(geom,sequence.shots,grid.points_m,cfg);
exposure=ice.aggregate_exposure(p,sequence.dwell_weights,cfg.exposure.duty_cycle, ...
    cfg.acoustics.density_kg_m3,cfg.acoustics.sound_speed_m_s);
if nargin<2||isempty(reference)
    baseline=cfg;baseline.architecture.type='shared';
    baseline.excitation.mode='focused';baseline.excitation.dwell_weights=[];
    baseline.excitation.custom_delay_s=[];
    if isfield(baseline.exposure,'dwell_time_s')
        baseline.exposure.dwell_time_s=[];
    end
    bseq=ice.make_sequence(geom,true(size(geom.positions_m,1),1),baseline);
    if isequal(sequence,bseq)
        bexp=exposure;
    else
        bp=ice.solve_pressure(geom,bseq.shots,grid.points_m,baseline);
        bexp=ice.aggregate_exposure(bp,1,cfg.exposure.duty_cycle, ...
            cfg.acoustics.density_kg_m3,cfg.acoustics.sound_speed_m_s);
    end
    reference=struct('pressure_peak_pa',max(bexp.pressure_peak_pa), ...
        'intensity_pulse_average_w_m2',max(bexp.intensity_pulse_average_w_m2), ...
        'intensity_temporal_average_w_m2',max(bexp.intensity_temporal_average_w_m2));
end
target=sum(((grid.points_m-cfg.target.center_m)./cfg.target.radii_m).^2,2)<=1;
if ~any(target)
    error('ice:UnresolvedTarget','No voxel centers resolve the target; refine the grid.');
end
metrics=ice.evaluate_threshold(exposure,target,grid.voxel_volume_m3,cfg.threshold,cfg.source,reference);
safety=ice.acoustic_safety_metrics(exposure,grid,target,cfg.target,metrics,sequence);
field=reshape(exposure.pressure_peak_pa,grid.shape);
[~,ix]=min(abs(grid.x_m-cfg.target.center_m(1)));
[~,iy]=min(abs(grid.y_m-cfg.target.center_m(2)));
[~,iz]=min(abs(grid.z_m-cfg.target.center_m(3)));
cuts.x=ice.beam_metrics(grid.x_m,squeeze(field(:,iy,iz)),cfg.target.center_m(1));
cuts.y=ice.beam_metrics(grid.y_m,squeeze(field(ix,:,iz)),cfg.target.center_m(2));
cuts.z=ice.beam_metrics(grid.z_m,squeeze(field(ix,iy,:)),cfg.target.center_m(3));
cuts.sampled_center_m=[grid.x_m(ix),grid.y_m(iy),grid.z_m(iz)];
w=abs(sequence.shots(1).weights);area=geom.width_m.*geom.height_m;
drive=struct('active_elements',nnz(w),'active_area_m2',sum(area(w>0)), ...
    'max_weight',max(w),'squared_velocity_area_m4_s2',sum(area.*w.^2)*cfg.source.velocity_m_s^2, ...
    'normalization',cfg.excitation.normalization);
feasibility=ice.check_drive_limits(cfg,geom,sequence);
solver_info=struct('name','planar_rayleigh_midpoint', ...
    'version','p0-2026-09-24','medium','homogeneous_lossless_linear', ...
    'boundary','infinite_rigid_baffle_z0', ...
    'grid_spacing_m',grid.spacing_m,'patch_count',cfg.solver.patch_count, ...
    'patches_per_wavelength',cfg.solver.patches_per_wavelength);
result=struct('cfg',cfg,'geometry',geom,'grid',grid,'partition',partition, ...
    'sequence',sequence,'pressure_pa',p,'exposure',exposure,'target_mask',target, ...
    'metrics',metrics,'safety',safety,'beam',cuts,'reference',reference, ...
    'drive',drive,'feasibility',feasibility,'solver_info',solver_info);
end
