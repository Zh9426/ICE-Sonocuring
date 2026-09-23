function exposure = aggregate_exposure(p, dwell_weights, duty_cycle, rho, c)
%AGGREGATE_EXPOSURE Separate shots -> peak envelope Pa and equivalent W/m^2.
% p is M-by-K peak phasor Pa. Dwell weights sum 1 across the scan.
% Intensity is the plane-progressive-wave equivalent, not exact active flux.
dw=dwell_weights(:);constants=[rho,c];
if ~isnumeric(p)||isempty(p)||any(~isfinite(p(:)))|| ...
        numel(dw)~=size(p,2)||~isreal(dw)||any(~isfinite(dw))||any(dw<0)|| ...
        abs(sum(dw)-1)>1e-10||~isscalar(duty_cycle)||~isreal(duty_cycle)|| ...
        ~isfinite(duty_cycle)||duty_cycle<0||duty_cycle>1||numel(constants)~=2|| ...
        ~isreal(constants)||any(~isfinite(constants))||any(constants<=0)
    error('ice:InvalidExposure','Finite pressures, normalized nonnegative dwell, duty in [0,1], positive rho/c required.');
end
if duty_cycle==0
    peak=zeros(size(p,1),1);ipa=peak;
else
    peak=max(abs(p(:,dw>0)),[],2);
    ipa=abs(p).^2*dw/(2*rho*c);
end
exposure.pressure_peak_pa=peak;
exposure.intensity_pulse_average_w_m2=ipa;
exposure.intensity_temporal_average_w_m2=duty_cycle*ipa;
exposure.intensity_definition='plane-progressive-wave equivalent; peak phasor convention';
exposure.pressure_definition='maximum over positive-dwell shots, no coherent sum';
end
