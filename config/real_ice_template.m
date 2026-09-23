function cfg = real_ice_template()
%REAL_ICE_TEMPLATE Deliberately non-runnable until measured data are entered.
% See docs/parameter_dictionary.md. Never interpret the unknown "400" here.
cfg=demo_config('linear');
cfg.provenance.kind='unconfirmed';
cfg.provenance.description='Enter probe model, source document and calibration date.';
cfg.array.type=''; cfg.array.size=[NaN NaN]; cfg.array.pitch_m=[NaN NaN];
cfg.array.element_width_m=NaN; cfg.array.element_height_m=NaN;
cfg.acoustics.frequency_hz=NaN; cfg.acoustics.sound_speed_m_s=NaN;
cfg.acoustics.density_kg_m3=NaN;
cfg.source.velocity_m_s=NaN; cfg.source.calibrated=false;
cfg.excitation.focus_m=[NaN NaN NaN]; cfg.excitation.regional_points_m=nan(1,3);
cfg.excitation.dwell_weights=1;
cfg.exposure.duty_cycle=NaN; cfg.exposure.exposure_time_s=NaN;
cfg.threshold.scale='absolute'; cfg.threshold.type=''; cfg.threshold.value=NaN;
cfg.threshold.intensity_basis='';
cfg.grid.x_m=NaN;cfg.grid.y_m=NaN;cfg.grid.z_m=NaN;
cfg.target.center_m=[NaN NaN NaN];cfg.target.radii_m=[NaN NaN NaN];
cfg.hardware=struct('probe_model','','connector_map',[], ...
    'voltage_limit_v',NaN,'frequency_limits_hz',[NaN NaN], ...
    'max_duty_cycle',NaN,'max_exposure_time_s',NaN);
cfg.material=struct('reported_value',400,'reported_unit','UNKNOWN', ...
    'threshold_definition','UNKNOWN','required_exposure_time_s',NaN);
end
