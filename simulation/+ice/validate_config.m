function validate_config(cfg)
%VALIDATE_CONFIG Validate physical scalars and prevent unknown-device fallback.
if ~isfield(cfg,'provenance')||strcmp(cfg.provenance.kind,'unconfirmed')
    error('ice:UnconfirmedConfiguration','Complete and document real_ice_template before running.');
end
a=cfg.acoustics;v=[a.frequency_hz,a.sound_speed_m_s,a.density_kg_m3];
if numel(v)~=3||~isreal(v)||any(~isfinite(v))||any(v<=0)
    error('ice:InvalidAcoustics','Use positive finite SI acoustic scalars.');
end
validateattributes(cfg.source.velocity_m_s,{'numeric'},{'real','finite','scalar','nonnegative'});
validateattributes(cfg.exposure.duty_cycle,{'numeric'},{'real','finite','scalar','>=',0,'<=',1});
validateattributes(cfg.exposure.exposure_time_s,{'numeric'},{'real','finite','scalar','positive'});
validateattributes(cfg.target.center_m,{'numeric'},{'real','finite','size',[1 3]});
validateattributes(cfg.target.radii_m,{'numeric'},{'real','finite','size',[1 3],'positive'});
if cfg.target.center_m(3)-cfg.target.radii_m(3)<=0
    error('ice:InvalidTarget','Target must lie strictly in front of the aperture.');
end
grid=ice.make_grid(cfg.grid);
if strcmp(cfg.array.type,'dual_array')
    if ~isfield(cfg,'probe')
        error('ice:ProbeGeometry','Dual array configuration requires probe geometry.');
    end
    ice.make_probe_geometry(cfg.probe);
else
    ice.make_geometry(cfg.array);
end
low=[grid.x_m(1),grid.y_m(1),grid.z_m(1)]-grid.spacing_m/2;
high=[grid.x_m(end),grid.y_m(end),grid.z_m(end)]+grid.spacing_m/2;
if any(cfg.target.center_m-cfg.target.radii_m<low)||any(cfg.target.center_m+cfg.target.radii_m>high)
    error('ice:TargetOutsideGrid','The complete target must fit within the voxel ROI; enlarge the grid.');
end
end
