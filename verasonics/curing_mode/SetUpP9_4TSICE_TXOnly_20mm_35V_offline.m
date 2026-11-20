% Offline TX-only adaptation of XJD/SetUpP9_4TSICE_FlashAngles.m.
% Not a hardware-safe or maximum-power prescription. Probe ratings unknown.
% Run only in an isolated MATLAB workspace: vendor utilities use base variables.
% This script constructs objects only. It does not save, run VSX, or transmit.

root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
addpath(fullfile(root,'VantageNXT-2.3.2-p2','Utilities'), ...
    fullfile(root,'VantageNXT-2.3.2-p2','System'), ...
    fullfile(root,'VantageNXT-2.3.2-p2','System','P_Files'));

% Original system/probe definitions. Runtime remains simulation-only.
Resource = struct();
Resource.Parameters.numTransmit = 128;
Resource.Parameters.numRcvChannels = 128;
Resource.Parameters.speedOfSound = 1540;
Resource.Parameters.speedCorrectionFactor = 1.0;
Resource.Parameters.verbose = 2;
Resource.Parameters.initializeOnly = 0;
Resource.Parameters.simulateMode = 1;
Trans = struct('name','P9-4ULts','units','wavelengths');
Trans = computeTrans(Trans);
Trans.maxHighVoltage = 35; % Existing software cap; probe rating is unknown.
Trans.id = -1;
TPC = struct('hv',35); % Offline supply request, not a measured output.

% Original waveform and all-64 apodization; a single 20 mm on-axis focus.
TW = struct('type','parametric','Parameters',[6,.67,2,1]);
TX = struct('waveform',1,'Origin',[0,0,0], ...
    'focus',20/(Resource.Parameters.speedOfSound/1000/Trans.frequency), ...
    'Steer',[0,0],'Apod',ones(1,64),'Delay',zeros(1,64));
TX.Delay = computeTXDelays(TX);

% Preserve original 15 transmissions per group and original start intervals.
% Replace receive/transfer/reconstruction and indefinite jump with finite stop.
SeqControl = struct('command',{'timeToNextAcq','timeToNextAcq','stop'}, ...
    'argument',{400,14400,[]});
Event = repmat(struct('info','TX only','tx',1,'rcv',0,'recon',0, ...
    'process',0,'seqControl',1),1,451);
for group = 1:30
    Event(group*15).seqControl = 2;
end
Event(end) = struct('info','stop','tx',0,'rcv',0,'recon',0, ...
    'process',0,'seqControl',3);
