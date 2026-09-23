function cfg = demo_config(array_type)
%DEMO_CONFIG Synthetic examples only. Every length is m; frequency is Hz.
% No values in this file describe a measured or manufacturer-specified ICE.
if nargin==0, array_type='linear'; end
cfg.provenance=struct('kind','synthetic','description', ...
    'Illustrative planar piston array; not a real ICE probe or material.');
cfg.array.type=char(array_type);
switch cfg.array.type
    case 'linear'
        cfg.array.size=[32 1];
        cfg.array.element_height_m=1.5e-3;
    case 'matrix'
        cfg.array.size=[12 8];
        cfg.array.element_height_m=.25e-3;
    otherwise
        error('ice:InvalidArrayType','Use linear or matrix.');
end
cfg.array.pitch_m=[.3 .3]*1e-3;
cfg.array.element_width_m=.25e-3;
cfg.acoustics=struct('frequency_hz',2.5e6,'sound_speed_m_s',1500,'density_kg_m3',1000);
cfg.source=struct('velocity_m_s',.01,'calibrated',false,'calibration_note','');
cfg.architecture=struct('type','shared','pattern','central_curing', ...
    'curing_fraction',.5,'seed',17,'custom_curing_mask',[]);
cfg.excitation=struct('mode','focused','focus_m',[0 0 .015], ...
    'regional_points_m',[-.0015 0 .015;0 0 .015;.0015 0 .015], ...
    'dwell_weights',[],'aperture_size_m',[Inf Inf], ...
    'apodization','uniform','normalization','fixed_element', ...
    'steering_deg',[0 0],'custom_delay_s',[]);
cfg.exposure=struct('duty_cycle',.2,'exposure_time_s',1);
% Uniform finite-volume cell centers. The sampled ROI extends half a cell
% beyond the first/last coordinate; these are not boundary-node quadratures.
cfg.grid=struct('x_m',linspace(-.006,.006,41), ...
    'y_m',linspace(-.004,.004,25),'z_m',linspace(.008,.022,45));
cfg.target=struct('center_m',[0 0 .015],'radii_m',[.002 .0015 .002]);
cfg.threshold=struct('type','pressure','scale','relative','value',.5, ...
    'intensity_basis','temporal_average');
% Empty patch_count chooses patches no larger than wavelength/4.
cfg.solver=struct('patch_count',[],'patches_per_wavelength',4,'chunk_size',4096);
cfg.output=struct('db_floor',-40,'visible','off');
end
