function e=operating_envelope(c,tr,part,timing,TX,Event)
%OPERATING_ENVELOPE Nominal burst-envelope accounting, not acoustic dosimetry.
% Unknown declared limits remain unknown; a comparison never qualifies hardware.
hasImage=~strcmp(c.mode,'exposure_only');
hasExposure=~strcmp(c.mode,'imaging_only');
imBurst=c.imaging.half_cycles/(2*c.imaging.frequency_mhz);
exBurst=c.exposure.cycles/c.exposure.frequency_mhz;
imDuty=hasImage*imBurst/c.imaging.pri_us;
exDuty=hasExposure*exBurst/c.exposure.pri_us;
% PRI is emitted only inside a group. At focus/frame boundaries, explicit
% waits may be shorter than the requested PRI. Use the denser bound too.
[imDuty,imInterval]=scheduledDuty(timing,'imaging_acquire',imBurst,imDuty);
[exDuty,exInterval]=scheduledDuty(timing,'exposure_transmit',exBurst,exDuty);
imTime=timing.total_imaging_acquisitions*imBurst;
exTime=timing.total_exposure_pulses*exBurst;
lambda=c.medium.sound_speed_m_s/1000/tr.frequency;
x=tr.ElementPos(:,1)*lambda;
e=struct('imaging_burst_us',imBurst,'exposure_burst_us',exBurst, ...
    'imaging_local_duty_cycle',imDuty,'exposure_local_duty_cycle',exDuty, ...
    'imaging_min_scheduled_start_interval_us',imInterval, ...
    'exposure_min_scheduled_start_interval_us',exInterval, ...
    'imaging_total_on_time_us',imTime,'exposure_total_on_time_us',exTime, ...
    'total_on_time_us',imTime+exTime, ...
    'nominal_session_duty_upper_estimate',(imTime+exTime)/timing.scheduled_total_us, ...
    'imaging_aperture_width_mm',range(x(part.imaging_mask))+c.probe.width_mm, ...
    'exposure_aperture_width_mm',range(x(part.exposure_mask))+c.probe.width_mm, ...
    'hardware_limits_status','unknown','hardware_qualified',false, ...
    'basis','Nominal burst envelope; not voltage high-state time, acoustic energy, temperature or cure.');
if ~any(part.imaging_mask), e.imaging_aperture_width_mm=0; end
% A reused element accumulates both roles. Apod amplitude is not an energy
% calibration: any positive weight counts the complete nominal burst envelope.
imageActive=part.imaging_active_mask;
exposureActive=part.exposure_active_mask;
elementImageTime=double(imageActive)*imTime;
elementExposureTime=double(exposureActive)*exTime;
elementTime=elementImageTime+elementExposureTime;
e.per_element=struct('imaging_acquisitions',double(imageActive)*timing.total_imaging_acquisitions, ...
    'exposure_pulses',double(exposureActive)*timing.total_exposure_pulses, ...
    'imaging_on_time_us',elementImageTime,'exposure_on_time_us',elementExposureTime, ...
    'total_on_time_us',elementTime, ...
    'nominal_session_duty_upper_estimate',elementTime/timing.scheduled_total_us);
e.total_element_on_time_us=sum(elementTime);
e.max_element_total_on_time_us=max(elementTime);
e.element_load_basis='Nominal per-element burst envelope; aggregate is element-us, not acoustic or electrical energy.';
e.acoustic_power_status='unknown_requires_calibration';
[elementDuty,elementInterval,adjacentRatio]=sharedDuty(TX,Event,timing,tr.frequency, ...
    imBurst,exBurst,imageActive,exposureActive,imDuty,exDuty,c.mode);
e.per_element.local_duty_upper_estimate=elementDuty;
e.per_element.minimum_start_interval_us=elementInterval;
e.per_element.maximum_adjacent_burst_ratio=adjacentRatio;
keys={'max_burst_us','max_local_duty_cycle','max_total_on_time_us','max_voltage_v'};
requested=[max(hasImage*imBurst,hasExposure*exBurst),max([imDuty;exDuty;elementDuty]), ...
    imTime+exTime,max(hasImage*icevs.requested_voltage(c.imaging), ...
    hasExposure*icevs.requested_voltage(c.exposure))];
checks=struct('quantity',{},'requested',{},'limit',{},'status',{});
for k=1:numel(keys)
    limit=NaN;
    if isfield(c,'hardware_limits'), limit=c.hardware_limits.(keys{k}); end
    status='unknown';
    if ~isnan(limit)
        if requested(k)>limit
            error('icevs:Limits','%s request %.9g exceeds declared limit %.9g.',keys{k},requested(k),limit);
        end
        status='declared_comparison_passed';
    end
    checks(k)=struct('quantity',keys{k},'requested',requested(k),'limit',limit,'status',status);
end
e.limit_checks=checks;
if all(~isnan([checks.limit])), e.hardware_limits_status='declared_limits_passed_not_qualified'; end
e.waveform_quantization='unknown_until_VSX_validation';
e.probe_thermal_monitoring='unknown';
e.profile5_installed=c.system.profile5_available;
e.local_duty_basis=['Maximum of configured burst/PRI and burst/shortest compiled same-role ' ...
    'start interval lower bound, plus each physical element previous-burst/next-start ratio ' ...
    'across both roles, including configured TX.Delay. With fewer than two starts, only ' ...
    'configured ratios are available. Scheduled nominal estimates, not measured output.'];
end
function [duty,interval,adjacent]=sharedDuty(TX,Event,timing,frequency, ...
        imBurst,exBurst,imageActive,exposureActive,imDuty,exDuty,mode)
n=numel(imageActive);
duty=max([double(imageActive)*imDuty,double(exposureActive)*exDuty],[],2);
interval=NaN(n,1); adjacent=zeros(n,1);
indices=find([Event.tx]>0); txIndices=[Event(indices).tx];
rows=timing.event_rows(indices); starts=[rows.scheduled_start_lower_bound_us];
waveforms=[TX(txIndices).waveform];
bursts=imBurst*(waveforms==1)+exBurst*(waveforms==2);
% Single-role modules may use waveform 1 for their only transmit waveform.
if strcmp(mode,'exposure_only'), bursts(:)=exBurst; end
if strcmp(mode,'imaging_only'), bursts(:)=imBurst; end
delays=vertcat(TX.Delay)/frequency; apods=vertcat(TX.Apod)>0;
for element=1:n
    active=apods(txIndices,element)';
    if sum(active)<2, continue; end
    times=starts(active)+delays(txIndices(active),element)';
    spacing=diff(times);
    if any(spacing<=0)
        error('icevs:Timing','Per-element transmit starts must remain ordered and separated.');
    end
    widths=bursts(active);
    interval(element)=min(spacing);
    adjacent(element)=max(widths(1:end-1)./spacing);
    duty(element)=max(duty(element),adjacent(element));
end
end
function [duty,interval]=scheduledDuty(timing,kind,burst,duty)
rows=timing.event_rows;
starts=[rows(strcmp({rows.kind},kind)).scheduled_start_lower_bound_us];
interval=NaN;
if numel(starts)>=2
    interval=min(diff(starts));
    if interval<=0, error('icevs:Timing','Repeated TX starts must have positive scheduled separation.'); end
    duty=max(duty,burst/interval);
end
end
