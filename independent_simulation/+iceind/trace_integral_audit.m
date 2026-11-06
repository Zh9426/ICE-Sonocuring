function [qp,a]=trace_integral_audit(p,pRms,dt,nSamples)
%TRACE_INTEGRAL_AUDIT Double direct integral is primary; RMS is a diagnostic.
assert(ismatrix(p) && size(p,2)==nSamples && size(p,1)==numel(pRms) && ...
 isreal(p) && all(isfinite(p),'all'),'iceind:TraceShape','Expected sensor-by-time finite traces.');
rmsQp=iceind.rms_to_qp(pRms(:),dt,nSamples);
qp=sum(double(p).^2,2)*dt;
if norm(qp)>0, relative=norm(qp-rmsQp)/norm(qp);
elseif norm(rmsQp)==0, relative=0;
else, relative=Inf;
end
tolerance=1e-3;
a=struct('rms_direct_relative_l2',relative,'rms_consistency_tolerance_relative',tolerance, ...
 'rms_consistency_passed',relative<=tolerance, ...
 'primary','Double direct dt*sum(p^2) over saved time samples.', ...
 'tolerance_basis','Proposed 0.1 percent diagnostic, informed by 4740-step GPU single replay (0.0119 percent RMS-Qp drift); not a physical sensitivity criterion.');
end
