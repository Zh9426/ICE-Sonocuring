function response = angular_response(geom, shot, angles_deg, plane, cfg)
%ANGULAR_RESPONSE Far-field rectangular-piston angular factor (not Pa).
% This is independent of finite-distance solve_pressure. Its sinc factors
% must never be applied again to the Rayleigh-integral field.
% plane='xz' or 'yz', angles in degrees from +z; output vectors are columns.
% Amplitude denominator=sum(area*abs(weights)); it is not radiated power.
validateattributes(angles_deg,{'numeric'},{'real','finite','vector','>=',-90,'<=',90});
theta=angles_deg(:);z=zeros(size(theta));
switch char(plane)
    case 'xz',direction=[sind(theta),z,cosd(theta)];
    case 'yz',direction=[z,sind(theta),cosd(theta)];
    otherwise,error('ice:InvalidPlane','Use xz or yz.');
end
% Reuse physical input validation on one point. No angular result uses it.
ice.solve_pressure(geom,shot,[0 0 1],cfg);
if numel(shot)~=1,error('ice:InvalidExcitation','Angular diagnostics require one shot.');end
k=2*pi*cfg.acoustics.frequency_hz/cfg.acoustics.sound_speed_m_s;
omega=2*pi*cfg.acoustics.frequency_hz;
area=geom.width_m(:).*geom.height_m(:);weights=shot.weights(:);
denominator=sum(area.*abs(weights));
if denominator==0,error('ice:InvalidExcitation','Angular normalization requires a nonzero drive.');end
directivity=sinc_unscaled(k/2*direction(:,1)*geom.width_m(:).').* ...
    sinc_unscaled(k/2*direction(:,2)*geom.height_m(:).');
phase=exp(1i*k*(direction*geom.positions_m.'));
factor=(directivity.*phase)*(area.*weights.*exp(-1i*omega*shot.delay_s(:)));
response=struct('angles_deg',theta,'complex_area_factor_m2',factor, ...
    'coherent_area_reference_m2',denominator,'amplitude',abs(factor)/denominator, ...
    'plane',char(plane),'interpretation','Far-field angular shape, normalized by summed absolute surface drive.');
end
function y=sinc_unscaled(x)
y=ones(size(x));nz=x~=0;y(nz)=sin(x(nz))./x(nz);
end
