function [signals,meta]=kw_waveform(q,dt,duration,amplitude)
%KW_WAVEFORM Nominal PWM shape -> assumed bandpass -> normalized pressure.
% Not a hardware clock quantizer or calibrated probe transfer function.
fs=500e6; t=(0:ceil(q.duration_s*fs))/fs;
halfPhase=mod(t*q.frequency_hz*2,1);
halfIndex=floor(t*q.frequency_hz*2);
active=halfPhase>=(1-q.active_fraction)/2 & ...
    halfPhase<(1+q.active_fraction)/2 & t<q.duration_s;
drive=q.polarity*(-1).^halfIndex.*active;
sigma=sqrt(2*log(2))/(pi*q.bandwidth_hz);
th=(-ceil(6*sigma*fs):ceil(6*sigma*fs))/fs;
h=exp(-.5*(th/sigma).^2).*cos(2*pi*q.acoustic_center_hz*th);
acoustic=conv(drive,h); acoustic=amplitude*acoustic/max(abs(acoustic));
ta=(0:numel(acoustic)-1)/fs;
time=0:dt:duration;
signals=zeros(numel(q.delay_s),numel(time),'single');
for k=1:numel(q.delay_s)
    signals(k,:)=single(q.apod(k)*interp1(ta,acoustic,time-q.delay_s(k),'linear',0));
end
meta=struct('half_cycles',q.half_cycles,'active_fraction',q.active_fraction, ...
    'frequency_hz',q.frequency_hz,'nominal_drive_duration_s',q.duration_s, ...
    'assumed_filter_group_delay_s',-th(1),'acoustic_duration_s',ta(end), ...
    'assumed_reference_source_pa',amplitude,'calibration','assumed_not_voltage_calibrated', ...
    'waveform_model','nominal_centered_PWM_assumed_Gaussian_bandpass_normalized');
end
