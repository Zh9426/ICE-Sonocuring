function qp=rms_to_qp(pRms,dt,nSamples)
%RMS_TO_QP Discrete sum(p.^2)*dt; record_start_index must be one.
% This is a pressure-squared-time proxy (Pa^2 s), not heat or acoustic energy.
assert(isscalar(dt) && isfinite(dt) && dt>0 && isscalar(nSamples) && ...
 isfinite(nSamples) && nSamples>=1 && nSamples==fix(nSamples), ...
 'iceind:ExposureTime','Positive dt and integer recorded sample count required.');
assert(isreal(pRms) && all(isfinite(pRms),'all') && all(pRms>=0,'all'), ...
 'iceind:ExposureField','RMS pressure must be finite and nonnegative.');
qp=double(pRms).^2*(dt*nSamples);
end
