function [seq,report]=build(cfg)
%BUILD Minimal TX-only sequence reusing the established ICE numerical backend.
% No imaging setup, computeRegions, computeTGCWaveform, VSX or hardware calls.
if ~strcmp(cfg.mode,'exposure_only') || ~strcmp(cfg.partition.layout,'exposure_only_selected')
    error('icevs:CuringOnly','This module accepts only standalone exposure_only requests.');
end
if ~strcmp(cfg.probe.type,'linear') || cfg.probe.num_elements~=64
    error('icevs:CuringOnly','Use the original working-source 64-element linear probe.');
end
% Adapt public TX-only inputs to existing validators/compiler. Imaging defaults
% here are inactive compatibility inputs, never built or exported as objects.
root=fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))));
addpath(fullfile(root,'verasonics','dual_mode'));
c=icevs.default_config(root);
for key={'vendor_root','baseline_mat','probe','identity','medium','system','exposure','runtime','hardware_limits'}
    c.(key{1})=cfg.(key{1});
end
c.mode='exposure_only'; c.partition=cfg.partition;
c.partition.layout='full64_imaging_selected_exposure';
c.sequence.num_frames=cfg.sequence.num_groups;
c.sequence.restore_imaging_profile=0;
c.imaging.voltage_v=cfg.exposure.voltage_v;
for key=fieldnames(cfg.timing)'
    c.timing.(key{1})=cfg.timing.(key{1});
end
c.timing.include_receive_recovery=0;
Trans=icevs.make_trans(c.probe,c.medium.sound_speed_m_s);
icevs.validate_config(c);
[part,~,apod]=icevs.partition_apertures(c,Trans);
part.layout=cfg.partition.layout;
part.imaging_mask(:)=false; part.imaging_active_mask(:)=false;
part.imaging_count=0; part.shared_count=0;
part.role_overlap_basis='No imaging role; only selected physical ranks transmit.';
if Trans.numelements>min(c.system.num_transmit,c.system.num_receive) || ...
        max(Trans.ConnectorES)>min(c.system.num_transmit,c.system.num_receive)
    error('icevs:Config','Probe or connector mapping exceeds configured system channels.');
end
lambda=c.medium.sound_speed_m_s/1000/Trans.frequency;
TW=struct('type','parametric','Parameters',[c.exposure.frequency_mhz, ...
    c.exposure.active_fraction,2*c.exposure.cycles,c.exposure.polarity]);
nf=size(c.exposure.foci_mm,1);
TX=repmat(struct('waveform',1,'Origin',[0 0 0],'focus',0,'Steer',[0 0], ...
    'FocalPt',[],'Apod',apod,'Delay',zeros(1,64)),1,nf);
origin=mean(Trans.ElementPos(part.exposure_mask,1:3),1);
for k=1:nf
    f=c.exposure.foci_mm(k,:)/lambda;
    TX(k).Origin=origin; TX(k).focus=norm(f-origin); TX(k).FocalPt=f;
    TX(k).Steer=[atan2(f(1)-origin(1),f(3)) 0];
    TX(k).Delay=icevs.focus_delays(Trans,f,apod);
end
maxDelay=max([TX.Delay])/Trans.frequency;
if maxDelay>45.5
    error('icevs:Config','Requested delay exceeds 45.5 us (D00163 Rev.K TX.Delay).');
end
burst=c.exposure.cycles/c.exposure.frequency_mhz;
TPC=repmat(struct('maxHighVoltage',Trans.maxHighVoltage,'xmitDuration',0), ...
    1,c.exposure.tpc_profile);
TPC(c.exposure.tpc_profile).xmitDuration=maxDelay+burst;
if ~isempty(c.exposure.voltage_v)
    for k=1:numel(TPC), TPC(k).hv=1.6; end
    TPC(c.exposure.tpc_profile).hv=c.exposure.voltage_v;
end
b=load(c.baseline_mat,'Resource');
Resource=struct('Parameters',b.Resource.Parameters);
Resource.Parameters.numTransmit=c.system.num_transmit;
Resource.Parameters.numRcvChannels=c.system.num_receive;
Resource.Parameters.speedOfSound=c.medium.sound_speed_m_s;
Resource.Parameters.speedCorrectionFactor=1;
Resource.Parameters.simulateMode=c.runtime.simulate_mode;
Resource.Parameters.freezeOnStart=double(c.runtime.freeze_on_start);
Resource.Parameters.initializeOnly=0; Resource.Parameters.startEvent=1;
meta=struct('num_angles',0,'num_foci',nf,'imaging_tx_indices',[], ...
    'exposure_tx_indices',1:nf,'receive_end_us',0, ...
    'exposure_end_us',maxDelay+burst+c.timing.waveform_guard_us, ...
    'nominal_exposure_pulse_us',burst);
[Event,SeqControl,timing]=icevs.compile_events(c,meta);
timing.num_groups=timing.num_frames; timing=rmfield(timing,'num_frames');
for k=1:numel(timing.event_rows)
    timing.event_rows(k).group=timing.event_rows(k).frame;
    Event(k).info=strrep(Event(k).info,'frame=','group=');
end
timing.event_rows=rmfield(timing.event_rows,'frame');
e=icevs.operating_envelope(c,Trans,part,timing,TX,Event);
e.imaging_burst_us=0;
seq=struct('Trans',Trans,'Resource',Resource,'TW',TW,'TX',TX, ...
    'TPC',TPC,'Event',Event,'SeqControl',SeqControl);
report=struct('schema_version',7,'mode','exposure_only', ...
    'architecture','linear64_standalone_selected_exposure', ...
    'partition',part,'wavelength_mm',lambda,'num_elements',64, ...
    'num_imaging_angles',0,'num_exposure_foci',nf,'max_exposure_delay_us',maxDelay, ...
    'operating_envelope',e,'timing',timing,'hardware_run',false, ...
    'vsx_validation','not_run','physical_validation','unknown', ...
    'startup_hv_omitted',~isfield(TPC,'hv'), ...
    'units',struct('coordinates','mm','frequency','MHz','time','us','supply_request','V'), ...
    'exposure_settings',c.exposure.provenance,'probe_settings',c.probe.provenance);
report.limitations={ ...
    'Exposure settings and charge/profile waits are assumed, not calibrated curing parameters.', ...
    'Original probe dimensions and 35 V software cap are not manufacturer burst/thermal ratings.', ...
    'No Receive object or acquisition does not mean physical receiver isolation.', ...
    'No imaging recovery wait is emitted because no imaging follows; recharge waits remain.', ...
    'Profile 5 availability and probe thermal monitoring remain unknown.', ...
    'Finite stop freezes the sequence; unfreeze can repeat it, without cross-run cumulative protection.', ...
    'VSX loading, waveform quantization, acoustic output and actual curing are not validated.'};
end
