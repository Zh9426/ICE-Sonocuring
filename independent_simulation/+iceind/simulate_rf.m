function data=simulate_rf(cfg)
%SIMULATE_RF Ideal +z plane-wave echo from one stationary point scatterer.
% Arrival = z/c + sqrt((x-x_element)^2+z^2)/c.
% Gaussian pulse centered at arrival. Amplitude has assumed 1/r receive
% spreading only; no finite transmit aperture, element directivity or Pa.
validateattributes(cfg.probe.element_x_m,{'double'},{'vector','real','finite','nonempty'});
validateattributes(cfg.target.xz_m,{'double'},{'size',[1 2],'real','finite'});
validateattributes(cfg.target.reflectivity,{'double'},{'scalar','real','finite','positive'});
validateattributes(cfg.medium.c_m_s,{'double'},{'scalar','real','finite','positive'});
validateattributes(cfg.pulse.fc_hz,{'double'},{'scalar','real','finite','positive'});
validateattributes(cfg.pulse.sigma_s,{'double'},{'scalar','real','finite','positive'});
validateattributes(cfg.sampling.fs_hz,{'double'},{'scalar','real','finite','positive'});
validateattributes(cfg.sampling.duration_s,{'double'},{'scalar','real','finite','positive'});
validateattributes(cfg.model.reference_distance_m,{'double'},{'scalar','real','finite','positive'});
assert(strcmp(cfg.transmit.model,'ideal_normal_plane_wave'), ...
    'iceind:Model','Only the ideal normal plane-wave benchmark is supported.');
assert(cfg.target.xz_m(2)>0,'iceind:Target','Target must be in z>0.');
assert(cfg.sampling.fs_hz>=4*cfg.pulse.fc_hz && ...
    cfg.pulse.sigma_s>=1/cfg.pulse.fc_hz,'iceind:Sampling', ...
    'Benchmark requires fs>=4fc and Gaussian sigma>=1/fc.');
x=cfg.probe.element_x_m(:)';
r=hypot(cfg.target.xz_m(1)-x,cfg.target.xz_m(2));
arrival=(cfg.target.xz_m(2)+r)/cfg.medium.c_m_s;
time=(0:floor(cfg.sampling.duration_s*cfg.sampling.fs_hz))'/cfg.sampling.fs_hz;
assert(min(arrival)-4*cfg.pulse.sigma_s>=time(1) && ...
    max(arrival)+4*cfg.pulse.sigma_s<=time(end),'iceind:Acquisition', ...
    'Acquisition must contain every pulse center plus/minus four sigma.');
dt=time-arrival;
rf=exp(-.5*(dt/cfg.pulse.sigma_s).^2).*cos(2*pi*cfg.pulse.fc_hz*dt);
rf=rf.*(cfg.target.reflectivity*cfg.model.reference_distance_m./r);
data=struct('rf',rf,'time_s',time,'element_x_m',x, ...
    'amplitude_units','arbitrary','provenance','synthetic', ...
    'model',cfg.model.name);
end
