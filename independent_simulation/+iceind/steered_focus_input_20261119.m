function [s,target]=steered_focus_input_20261119(base,angle_deg)
%STEERED_FOCUS_INPUT_20261119 Synthetic R20 steering; offline simulation only.
% Geometry, waveform, and apodisation are retained from the saved export.
validateattributes(angle_deg,{'numeric'},{'real','finite','scalar'});
assert(ismember(angle_deg,[0 10 -10 20 -20 30 -30]), ...
    'iceind:SteeredFocusAngle','Supported synthetic angles are 0, +/-10, +/-20, +/-30 deg.');
s=base;
b=iceind.compile_kwave(base);
assert(numel(b.tx)==1 && numel(b.tx.apod)==64 && all(b.tx.apod==1), ...
    'iceind:SteeredFocusInput','Expected the unchanged All64 equal-amplitude export.');
target=[sind(double(angle_deg)) 0 cosd(double(angle_deg))]*0.02;
distance=vecnorm(b.geometry.positions_m-target,2,2);
delay=(max(distance)-distance)/b.sound_speed_m_s;
frequency_hz=double(base.Trans.frequency)*1e6;
s.TX.Delay=reshape(delay,size(base.TX.Delay))*frequency_hz;
s.ICEConfig.exposure.foci_mm=target*1e3;
s.TX.FocalPt=target*frequency_hz/b.sound_speed_m_s;
s.TX.focus=norm(target)*frequency_hz/b.sound_speed_m_s;
s.TX.Steer=[double(angle_deg)*pi/180 0];
s.synthetic_target_m=target;
s.synthetic_angle_deg=double(angle_deg);
end
