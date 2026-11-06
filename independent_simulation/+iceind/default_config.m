function cfg=default_config()
%DEFAULT_CONFIG SI inputs for a synthetic analytic imaging benchmark.
% Software reference only: ../verasonics/dual_mode/+icevs/default_config.m.
% This function does not load or execute any vendor or other project code.
cfg.probe=struct('element_x_m',((0:63)-31.5)*.13e-3, ...
    'provenance','existing_code_unverified');
cfg.medium=struct('c_m_s',1540,'provenance','assumed');
cfg.pulse=struct('fc_hz',6e6,'sigma_s',1/6e6, ...
    'provenance','frequency_existing_code_unverified_envelope_assumed');
cfg.transmit=struct('model','ideal_normal_plane_wave','provenance','assumed');
cfg.target=struct('xz_m',[.00083 .02003],'reflectivity',1,'provenance','synthetic');
cfg.sampling=struct('fs_hz',48e6,'duration_s',45e-6,'provenance','assumed');
cfg.image=struct('x_m',(-3:.025:3)*1e-3,'z_m',(17:.025:23)*1e-3, ...
    'c_m_s',1540,'dynamic_range_db',40,'provenance','assumed');
cfg.model=struct('name','analytic_plane_wave_point_scatterer_v1', ...
    'amplitude_units','arbitrary','reference_distance_m',.02, ...
    'physical_validation','unknown','vendor_runtime_required',false);
end
