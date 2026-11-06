function [seq, report] = build(cfg)
%BUILD Construct finite ICE imaging/exposure sequence without activating VSX.
% Only the vendor's numerical region and TGC utilities are used. No SetUp
% script, activation, VSX entry, voltage control, or acquisition is executed.
Trans = icevs.make_trans(cfg.probe,cfg.medium.sound_speed_m_s);
icevs.validate_config(cfg);
[partition,imageApod,exposureApod]=icevs.partition_apertures(cfg,Trans);
if Trans.numelements>min(cfg.system.num_transmit,cfg.system.num_receive)
    error('icevs:Config','This non-multiplexed model needs a channel for every element.');
end
if max(Trans.ConnectorES)>min(cfg.system.num_transmit,cfg.system.num_receive)
    error('icevs:Config','Connector map exceeds configured channel count; UTA routing is unknown.');
end
b = load(cfg.baseline_mat,'Resource','Media','Process','UI','P','PData');
oldPath = path; restorePath = onCleanup(@()path(oldPath));
addpath(fullfile(cfg.vendor_root,'Utilities'),'-begin');
na = numel(cfg.imaging.angles_deg); nf = size(cfg.exposure.foci_mm,1);
frames = cfg.sequence.num_frames; n = Trans.numelements;
% D00163 Rev.K A101: receive buffers contain 1 frame or an even count.
bufferFrames = frames;
if frames>1, bufferFrames=2*ceil(frames/2); end
wavelengthMm = cfg.medium.sound_speed_m_s/1000/Trans.frequency;
P = struct('startDepth',cfg.imaging.start_depth_wls,'endDepth',cfg.imaging.end_depth_wls);
originalSector=Trans.type==0 && strcmp(cfg.imaging.geometry,'original_sector');
if originalSector
    % Original SetUp formulas; the full physical aperture defines the virtual
    % apex even with sparse imaging apodization. Do not recenter on the mask.
    P.theta=-pi/4; P.rayDelta=2*(-P.theta);
    P.aperture=64*Trans.spacing; P.radius=(P.aperture/2)/tan(-P.theta);
    PData.PDelta=[Trans.spacing 0 .5];
    PData.Size=[10+ceil((P.endDepth-P.startDepth)/.5), ...
        10+ceil(2*(P.endDepth+P.radius)*sin(-P.theta)/Trans.spacing),1];
    PData.Origin=[-(PData.Size(2)/2)*PData.PDelta(1),0,P.startDepth];
    PData.Region.Shape=struct('Name','SectorFT','Position',[0 0 0], ...
        'z',P.startDepth,'r',P.radius+P.endDepth,'angle',P.rayDelta,'steer',0);
elseif Trans.type==0
    dx=cfg.imaging.voxel_size_mm(1)/wavelengthMm;
    dz=cfg.imaging.voxel_size_mm(3)/wavelengthMm;
    xl=cfg.imaging.x_limits_mm/wavelengthMm;
    PData.PDelta=[dx 0 dz];
    PData.Size=[1+ceil((P.endDepth-P.startDepth)/dz),1+ceil(diff(xl)/dx),1];
    PData.Origin=[xl(1) 0 P.startDepth];
    PData.Region.Shape=struct('Name','Rectangle', ...
        'Position',[mean(xl) 0 P.startDepth],'width',diff(xl), ...
        'height',P.endDepth-P.startDepth);
else
% Type-2 volume layout follows SetUpM3dVFlash: Size=[Ny Nx Nz],
% Origin=[xmin ymax zmin], positive PDelta=[dx dy dz]. Reconstruct one XZ slice.
PData.PDelta = cfg.imaging.voxel_size_mm/wavelengthMm;
xl=cfg.imaging.x_limits_mm/wavelengthMm; yl=cfg.imaging.y_limits_mm/wavelengthMm;
PData.Size = [1+ceil(diff(yl)/PData.PDelta(2)),1+ceil(diff(xl)/PData.PDelta(1)), ...
    1+ceil((P.endDepth-P.startDepth)/PData.PDelta(3))];
if prod(PData.Size)>1e7
    error('icevs:Config','Requested PData exceeds the offline allocation bound of 10 million voxels.');
end
PData.Origin=[xl(1),yl(2),P.startDepth];
PData.Region.Shape = struct('Name','Slice','Orientation','xz', ...
    'oPAIntersect',cfg.imaging.slice_y_mm/wavelengthMm);
end
if prod(PData.Size)>1e7
    error('icevs:Config','Requested PData exceeds the offline allocation bound of 10 million pixels/voxels.');
end
PData.Region = computeRegions(PData);
TW(1) = struct('type','parametric','Parameters',[cfg.imaging.frequency_mhz, ...
    cfg.imaging.active_fraction,cfg.imaging.half_cycles,cfg.imaging.polarity]);
TW(2) = struct('type','parametric','Parameters',[cfg.exposure.frequency_mhz, ...
    cfg.exposure.active_fraction,2*cfg.exposure.cycles,cfg.exposure.polarity]);
TX = repmat(struct('waveform',1,'Origin',[0 0 0],'focus',0, ...
    'Steer',[0 0],'FocalPt',[],'Apod',zeros(1,n),'Delay',zeros(1,n)),1,na+nf);
imageOrigin=mean(Trans.ElementPos(partition.imaging_mask,1:3),1);
exposureOrigin=mean(Trans.ElementPos(partition.exposure_mask,1:3),1);
imageFocus=0;
if originalSector, imageOrigin=[0 0 0]; imageFocus=-P.radius; end
for k=1:na
    TX(k).Origin=imageOrigin;
    TX(k).focus=imageFocus;
    TX(k).Steer = [cfg.imaging.angles_deg(k)*pi/180 0];
    TX(k).Apod = imageApod;
    TX(k).Delay = icevs.tx_delays(Trans,imageFocus,TX(k).Steer,TX(k).Apod,imageOrigin);
end
for k=1:nf
    f = cfg.exposure.foci_mm(k,:)/wavelengthMm;
    TX(na+k).waveform = 2;
    TX(na+k).Origin=exposureOrigin;
    TX(na+k).focus = norm(f-exposureOrigin);
    TX(na+k).FocalPt=f; % explicit point avoids azimuth/elevation convention ambiguity
    if Trans.type==0
        TX(na+k).Steer=[atan2(f(1)-exposureOrigin(1),f(3)) 0];
    end
    TX(na+k).Apod = exposureApod;
    TX(na+k).Delay = icevs.focus_delays(Trans,f,exposureApod);
end
if max([TX.Delay])/Trans.frequency>45.5
    error('icevs:Config','Requested delay exceeds 45.5 us (D00163 Rev.K TX.Delay).');
end
% Bound every active imaging element to every corner of the actual 3D grid.
% Twice the maximum one-way range conservatively covers transmit plus receive.
xBounds=PData.Origin(1)+[0 (PData.Size(2)-1)*PData.PDelta(1)];
if Trans.type==0
    yBounds=[0 0];
    zBounds=PData.Origin(3)+[0 (PData.Size(1)-1)*PData.PDelta(3)];
else
    yBounds=PData.Origin(2)-[0 (PData.Size(1)-1)*PData.PDelta(2)];
    zBounds=PData.Origin(3)+[0 (PData.Size(3)-1)*PData.PDelta(3)];
end
[cx,cy,cz]=ndgrid(xBounds,yBounds,zBounds); corners=[cx(:),cy(:),cz(:)];
rangeMax=0;
for k=1:size(corners,1)
    rangeMax=max(rangeMax,max(vecnorm(Trans.ElementPos(imageApod>0,1:3)-corners(k,:),2,2)));
end
receiveEndWls=16*ceil(rangeMax/16);
if originalSector
    % Original sector acquisition window, not the enclosing rectangle.
    maxAcqLength=ceil(sqrt(P.aperture^2+P.endDepth^2- ...
        2*P.aperture*P.endDepth*cos(P.theta-pi/2))-P.startDepth);
    receiveEndWls=P.startDepth+16*ceil(maxAcqLength/16);
end
sampleRateMHz = 4*cfg.imaging.demod_frequency_mhz;
imagingPulseUs = cfg.imaging.half_cycles/(2*cfg.imaging.frequency_mhz);
exposurePulseUs = cfg.exposure.cycles/cfg.exposure.frequency_mhz;
imageDelayUs = max([TX(1:na).Delay])/Trans.frequency;
exposureDelayUs = max([TX(na+1:end).Delay])/Trans.frequency;
receiveEndUs = 2*receiveEndWls/Trans.frequency+imageDelayUs+imagingPulseUs+cfg.timing.waveform_guard_us;
estimatedSamples = ceil(receiveEndUs*sampleRateMHz);
rowsPerAcq = max(8192,128*ceil((estimatedSamples+128)/128));
Resource = b.Resource;
Resource.Parameters.numTransmit = cfg.system.num_transmit;
Resource.Parameters.numRcvChannels = cfg.system.num_receive;
Resource.Parameters.speedOfSound = cfg.medium.sound_speed_m_s;
Resource.Parameters.speedCorrectionFactor = 1;
Resource.Parameters.simulateMode = cfg.runtime.simulate_mode;
Resource.Parameters.freezeOnStart = double(cfg.runtime.freeze_on_start);
Resource.Parameters.initializeOnly = 0;
Resource.Parameters.startEvent = 1;
Resource.RcvBuffer = struct('datatype','int16','rowsPerFrame',na*rowsPerAcq, ...
    'colsPerFrame',cfg.system.num_receive,'numFrames',bufferFrames);
Resource.DisplayWindow.Title = ['ICE: ' strrep(cfg.partition.layout,'_',' ') ' - XZ'];
if Trans.type==0
    displayHeight=PData.Size(1)*PData.PDelta(3);
else
    displayHeight=PData.Size(3)*PData.PDelta(3);
end
Resource.DisplayWindow.Position(3:4) = ceil([PData.Size(2)*PData.PDelta(1), ...
    displayHeight]/Resource.DisplayWindow.pdelta);
Resource.DisplayWindow.Orientation='xz';
Resource.DisplayWindow.ReferencePt = PData.Origin;
if Trans.type==2, Resource.DisplayWindow.ReferencePt(2)=cfg.imaging.slice_y_mm/wavelengthMm; end
if originalSector
    Resource.DisplayWindow=b.Resource.DisplayWindow;
    Resource.DisplayWindow.ReferencePt=PData.Origin;
    Resource.DisplayWindow.Position(3:4)=ceil([PData.Size(2)*PData.PDelta(1), ...
        PData.Size(1)*PData.PDelta(3)]/Resource.DisplayWindow.pdelta);
end
Receive = repmat(struct('Apod',double(partition.imaging_mask'),'startDepth',P.startDepth, ...
    'endDepth',receiveEndWls,'TGC',1,'bufnum',1,'framenum',1,'acqNum',1, ...
    'sampleMode','NS200BW','demodFrequency',cfg.imaging.demod_frequency_mhz, ...
    'mode',0,'callMediaFunc',0),1,na*frames);
for k=1:numel(Receive)
    Receive(k).framenum = ceil(k/na);
    Receive(k).acqNum = mod(k-1,na)+1;
    Receive(k).callMediaFunc = double(mod(k-1,na)==0);
end
TGC = struct('CntrlPts',[0 431 450 603 637 749 921 944],'rangeMax',P.endDepth);
TGC.Waveform = computeTGCWaveform(TGC);
Recon = struct('senscutoff',cfg.imaging.senscutoff,'pdatanum',1,'rcvBufFrame',-1, ...
    'IntBufDest',[1 1],'ImgBufDest',[1 -1],'RINums',1:na);
ReconInfo = repmat(struct('mode','accumIQ','txnum',1,'rcvnum',1,'regionnum',1),1,na);
for k=1:na
    ReconInfo(k).txnum=k; ReconInfo(k).rcvnum=k;
end
ReconInfo(1).mode='replaceIQ'; ReconInfo(end).mode='accumIQ_replaceIntensity';
if na==1, ReconInfo.mode='replaceIntensity'; end
TPC = repmat(struct('hv',icevs.requested_voltage(cfg.imaging),'maxHighVoltage',Trans.maxHighVoltage,'xmitDuration',0), ...
    1,max(cfg.imaging.tpc_profile,cfg.exposure.tpc_profile));
TPC(cfg.exposure.tpc_profile).hv=icevs.requested_voltage(cfg.exposure);
% Include delay plus burst in profile transition timing (D00163 Rev.K p96).
TPC(cfg.imaging.tpc_profile).xmitDuration=imageDelayUs+imagingPulseUs;
TPC(cfg.exposure.tpc_profile).xmitDuration=max(TPC(cfg.exposure.tpc_profile).xmitDuration, ...
    exposureDelayUs+exposurePulseUs);
if isempty(cfg.imaging.voltage_v) && isempty(cfg.exposure.voltage_v)
    TPC=rmfield(TPC,'hv'); % Preserve original unspecified startup voltage.
end
meta = struct('num_angles',na,'num_foci',nf,'imaging_tx_indices',1:na, ...
    'exposure_tx_indices',na+(1:nf),'receive_end_us',receiveEndUs, ...
    'exposure_end_us',exposureDelayUs+exposurePulseUs+cfg.timing.waveform_guard_us, ...
    'nominal_exposure_pulse_us',exposurePulseUs);
[Event,SeqControl,timing] = icevs.compile_events(cfg,meta);
envelope=icevs.operating_envelope(cfg,Trans,partition,timing,TX,Event);
UI = b.UI(1);
idx=find(strcmp(UI.Control,'SliderMinMaxVal'),1);
UI.Control{idx+1}=[0 1 cfg.imaging.senscutoff];
Process=b.Process;
if Trans.type==2, Process.Parameters=[Process.Parameters,{'srcData','intensity3D'}]; end
Media=struct('MP',[[-2 0 10;0 0 20;2 0 30]/wavelengthMm,ones(3,1)], ...
    'numPoints',3,'attenuation',-.5);
% Synthetic stationary point targets; no inherited line-array motion callback.
for k=1:numel(Receive), Receive(k).callMediaFunc=0; end
if originalSector
    Media=b.Media; % Original synthetic targets and movePoints callback.
    for k=1:numel(Receive), Receive(k).callMediaFunc=double(mod(k-1,na)==0); end
end
seq = struct('P',P,'Trans',Trans,'Resource',Resource,'PData',PData, ...
    'Media',Media,'TW',TW,'TX',TX,'Receive',Receive,'TGC',TGC, ...
    'Recon',Recon,'ReconInfo',ReconInfo,'Process',Process,'TPC',TPC, ...
    'Event',Event,'SeqControl',SeqControl,'UI',UI, ...
    'frameRateFactor',cfg.sequence.return_every_frames);
architecture='linear64_fixed_physical_partition';
if Trans.type==2, architecture='synthetic_matrix_fixed_physical_partition'; end
if strcmp(cfg.partition.layout,'full64_imaging_selected_exposure')
    architecture='linear64_full_imaging_selected_exposure';
end
report = struct('schema_version',6,'mode',cfg.mode,'architecture',architecture, ...
    'imaging_geometry',cfg.imaging.geometry, ...
    'original_sector_restored',originalSector, ...
    'exposure_events_enabled',~strcmp(cfg.mode,'imaging_only'), ...
    'startup_hv_omitted',~isfield(TPC,'hv'), ...
    'partition',partition,'array_shape',cfg.probe.shape, ...
    'physical_validation','unknown','exposure_settings',cfg.exposure.provenance, ...
    'simulation_media','synthetic','probe_settings',cfg.probe.provenance, ...
    'units',struct('coordinates','mm','frequency','MHz','time','us','supply_request','V'), ...
    'num_elements',n,'num_imaging_angles',na,'num_exposure_foci',nf, ...
    'wavelength_mm',wavelengthMm,'receive_end_wls',receiveEndWls, ...
    'requested_sampling_rate_mhz',sampleRateMHz,'estimated_samples_per_acquisition',estimatedSamples, ...
    'reserved_rows_per_acquisition',rowsPerAcq, ...
    'reserved_receive_buffer_frames',bufferFrames, ...
    'reserved_receive_buffer_mib',2*na*rowsPerAcq*cfg.system.num_receive*bufferFrames/2^20, ...
    'max_imaging_delay_us',imageDelayUs,'max_exposure_delay_us',exposureDelayUs, ...
    'operating_envelope',envelope, ...
    'timing',timing,'hardware_run',false,'vsx_validation','not_run');
report.limitations = { ...
    'The current 64-linear baseline is user-reported working; dimensions/electrical limits are source-derived, not calibrated.', ...
    'TINGSN Sonic Eyes 10F exact model suffix is unknown; P9-4ULts is a software alias.', ...
    'Exposure parameters and profile settling/recovery times are assumed, not measured.', ...
    'Profile 5 availability is unknown; no p5ena flag is forced.', ...
    'Waveform/sampling quantization and buffer fit must be validated by VSX.', ...
    'Finite software sequence does not measure acoustic energy, temperature or material cure.', ...
    'Linear reconstruction and electronic focusing are limited to XZ; elevation lens behavior is not calibrated.', ...
    'Synthetic matrix mode is retained for regression only and does not describe the current physical probe.', ...
    'Odd/even means ascending physical x rank, not connector parity; sparse-aperture sidelobes/grating lobes are not validated.', ...
    'Declared limits do not establish hardware qualification or measured acoustic/thermal safety.'};
end
