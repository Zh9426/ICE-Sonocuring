function result=reconstruct(data,cfg)
%RECONSTRUCT Coherent DAS of analytic RF for ideal normal incidence.
% No target position or reflectivity is used by this inverse operation.
validateattributes(cfg.image.x_m,{'double'},{'vector','real','finite','increasing','nonempty'});
validateattributes(cfg.image.z_m,{'double'},{'vector','real','finite','increasing','positive','nonempty'});
validateattributes(cfg.image.c_m_s,{'double'},{'scalar','real','finite','positive'});
validateattributes(cfg.image.dynamic_range_db,{'double'},{'scalar','real','finite','positive'});
validateattributes(data.rf,{'double'},{'2d','real','finite','nonempty'});
assert(size(data.rf,1)==numel(data.time_s) && ...
    size(data.rf,2)==numel(data.element_x_m),'iceind:Data','RF dimensions must match time and elements.');
validateattributes(data.time_s,{'double'},{'column','real','finite','increasing'});
% FFT analytic signal, equivalent to a Hilbert transform; base MATLAB only.
n=size(data.rf,1); h=zeros(n,1); h(1)=1;
if mod(n,2)==0
    h(2:n/2)=2; h(n/2+1)=1;
else
    h(2:(n+1)/2)=2;
end
analytic=ifft(fft(data.rf,[],1).*h,[],1);
[X,Z]=meshgrid(cfg.image.x_m,cfg.image.z_m);
beam=complex(zeros(size(X)));
for k=1:numel(data.element_x_m)
    txTime=Z/cfg.image.c_m_s;
    rxTime=hypot(X-data.element_x_m(k),Z)/cfg.image.c_m_s;
    delay=txTime+rxTime;
    assert(min(delay(:))>=data.time_s(1) && max(delay(:))<=data.time_s(end), ...
        'iceind:ImageWindow','Image query extends outside acquired time range.');
    beam=beam+interp1(data.time_s,analytic(:,k),delay,'linear');
end
envelope=abs(beam)/numel(data.element_x_m);
[peak,index]=max(envelope(:)); [iz,ix]=ind2sub(size(envelope),index);
assert(peak>0,'iceind:NoSignal','No nonzero reconstructed signal.');
db=20*log10(max(envelope/peak,10^(-cfg.image.dynamic_range_db/20)));
result=struct('envelope',envelope,'db',db,'x_m',cfg.image.x_m, ...
    'z_m',cfg.image.z_m,'peak_xz_m',[cfg.image.x_m(ix) cfg.image.z_m(iz)], ...
    'amplitude_units','arbitrary','provenance','synthetic');
end
