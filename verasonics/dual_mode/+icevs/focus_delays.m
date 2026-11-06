function delays = focus_delays(Trans,target_wls,apod)
%FOCUS_DELAYS Equal-arrival 3D geometric delays at an explicit target.
if ~isnumeric(target_wls) || ~isreal(target_wls) || numel(target_wls)~=3 || ...
        any(~isfinite(target_wls)) || target_wls(3)<=0 || ...
        numel(apod)~=Trans.numelements || any(~isfinite(apod)) || ...
        any(apod<0 | apod>1) || ~any(apod>0)
    error('icevs:Delays','Finite forward 3D focus and nonempty element apodization required.');
end
d=vecnorm(Trans.ElementPos(:,1:3)-reshape(target_wls,1,3),2,2)';
active=apod(:)'>0; delays=zeros(1,Trans.numelements);
delays(active)=max(d(active))-d(active);
end
