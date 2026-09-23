function p = solve_pressure(geom, shots, points_m, cfg)
%SOLVE_PRESSURE Baffled rectangular piston Rayleigh integral, peak phasor Pa.
% geom: N-by-3 centers [m], N-by-1 width/height [m], in z=0 plane.
% shots: struct array with N-by-1 weights and delays [s].
% points_m: M-by-3, z>0 [m]. p: M-by-K complex peak pressure [Pa].
% Time convention exp(+i omega t). Uniform peak normal velocity [m/s].
% Homogeneous lossless linear medium. No empirical voltage conversion.
a=cfg.acoustics; values=[a.frequency_hz,a.sound_speed_m_s,a.density_kg_m3];
if numel(values)~=3||~isreal(values)||any(~isfinite(values))||any(values<=0)
    error('ice:InvalidAcoustics','Frequency [Hz], speed [m/s], density [kg/m^3] must be positive finite scalars.');
end
if ~isnumeric(points_m)||~isreal(points_m)||size(points_m,2)~=3|| ...
        any(~isfinite(points_m(:)))||any(points_m(:,3)<=0)
    error('ice:InvalidPoints','Observation points must be finite M-by-3, strictly z>0.');
end
n=size(geom.positions_m,1); w=geom.width_m(:); h=geom.height_m(:);
if ~isnumeric(geom.positions_m)||~isreal(geom.positions_m)||n<1|| ...
        ~isnumeric(w)||~isreal(w)||~isnumeric(h)||~isreal(h)|| ...
        size(geom.positions_m,2)~=3||any(~isfinite(geom.positions_m(:)))|| ...
        any(geom.positions_m(:,3)~=0)||numel(w)~=n||numel(h)~=n|| ...
        any(~isfinite([w;h]))||any([w;h]<=0)
    error('ice:InvalidGeometry','Expected planar z=0 finite rectangles with positive dimensions.');
end
v=cfg.source.velocity_m_s;
if ~isnumeric(v)||~isreal(v)||~isscalar(v)||~isfinite(v)||v<0
    error('ice:InvalidSource','Peak surface velocity must be a nonnegative finite scalar [m/s].');
end
k=2*pi*a.frequency_hz/a.sound_speed_m_s;omega=2*pi*a.frequency_hz;
ns=numel(shots);if ns<1,error('ice:InvalidExcitation','At least one shot is required.');end
drive=complex(zeros(n,ns));
for s=1:ns
    weights=shots(s).weights(:);delays=shots(s).delay_s(:);
    if numel(weights)~=n||numel(delays)~=n||any(~isfinite(weights))|| ...
            ~isreal(delays)||any(~isfinite(delays))||any(delays<0)
        error('ice:InvalidExcitation','Weights and nonnegative finite delays must match the elements.');
    end
    drive(:,s)=v*weights.*exp(-1i*omega*delays);
end
patch=cfg.solver.patch_count;
if isempty(patch)
    ppw=cfg.solver.patches_per_wavelength;
    if ~isscalar(ppw)||~isreal(ppw)||~isfinite(ppw)||ppw<1
        error('ice:InvalidSolver','patches_per_wavelength must be finite and >=1.');
    end
    lambda=a.sound_speed_m_s/a.frequency_hz;
    counts=max(1,ceil([w,h]/(lambda/ppw)));
else
    if numel(patch)~=2||~isreal(patch)||any(~isfinite(patch))||any(patch<1)||any(mod(patch,1)~=0)
        error('ice:InvalidSolver','patch_count must contain two positive integers.');
    end
    counts=repmat(reshape(patch,1,2),n,1);
end
chunk=cfg.solver.chunk_size;
if ~isscalar(chunk)||~isfinite(chunk)||chunk<1||mod(chunk,1)~=0
    error('ice:InvalidSolver','chunk_size must be a positive integer.');
end
active=find(any(drive~=0,2));
p=complex(zeros(size(points_m,1),ns));
for first=1:chunk:size(points_m,1)
    idx=first:min(first+chunk-1,size(points_m,1));q=points_m(idx,:);
    transfer=complex(zeros(numel(idx),numel(active)));
    for j=1:numel(active)
        e=active(j);nx=counts(e,1);ny=counts(e,2);
        sx=geom.positions_m(e,1)+(((1:nx)-.5)/nx-.5)*w(e);
        sy=geom.positions_m(e,2)+(((1:ny)-.5)/ny-.5)*h(e);
        [sx,sy]=ndgrid(sx,sy);
        r=sqrt((q(:,1)-sx(:).').^2+(q(:,2)-sy(:).').^2+q(:,3).^2);
        transfer(:,j)=sum(exp(-1i*k*r)./r,2)*(w(e)*h(e)/(nx*ny));
    end
    p(idx,:)=1i*a.density_kg_m3*a.sound_speed_m_s*k/(2*pi)*(transfer*drive(active,:));
end
end
