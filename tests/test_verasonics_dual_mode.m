function tests = test_verasonics_dual_mode
tests = functiontests(localfunctions);
end

function setupOnce(t)
root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root,'verasonics','dual_mode'));
t.TestData.root = root;
end

function testDefaultUsesWorkingLinear64AndSharedExposureSubset(t)
c = icevs.default_config(t.TestData.root);
[s,r] = icevs.build(c);
verifyEqual(t,s.Trans.type,0);
verifySize(t,s.Trans.ElementPos,[64 5]);
verifyEqual(t,s.Trans.spacingMm,.13);
verifyEqual(t,s.Trans.ConnectorES,(1:64)');
left=true(64,1); right=mod((1:64)',2)==0;
verifyEqual(t,[sum(left) sum(right)],[64 32]);
for k=1:numel(c.imaging.angles_deg)
    verifyEqual(t,s.TX(k).Apod,double(left'));
    verifyEqual(t,s.TX(k).focus,-s.P.radius);
end
verifyEqual(t,s.TX(end).Apod,double(right'));
verifyTrue(t,all(vertcat(s.Receive.Apod)==double(left'),'all'));
verifyEqual(t,sum(r.partition.imaging_mask & r.partition.exposure_mask),32);
verifyEqual(t,s.PData.Region.Shape.Name,'SectorFT');
verifyEqual(t,s.PData.Size(3),1);
verifyFalse(t,any(strcmp(s.Process.Parameters,'intensity3D')));
verifyEqual(t,s.TW(1).Parameters,[6 .67 2 1]);
verifyEqual(t,s.Receive(1).demodFrequency,12);
verifyEqual(t,s.Resource.Parameters.simulateMode,1);
verifyEqual(t,s.Resource.Parameters.freezeOnStart,1);
verifyEqual(t,r.physical_validation,'unknown');
verifyEqual(t,mod(s.Resource.RcvBuffer.rowsPerFrame,128),0);
verifyEqual(t,numel(s.UI),1); % Range changes must rebuild buffer/timing together.
end

function testFocusArrivalTimesAndFiniteExposure(t)
c = icevs.default_config(t.TestData.root);
c.sequence.num_frames = 2;
c.exposure.foci_mm = [-1 0 20; 1 0 25];
c.exposure.pulses_per_focus = 3;
[s,r] = icevs.build(c);
for k=1:2
    tx=s.TX(15+k);
    xyz=s.Trans.ElementPos(:,1:3)/s.Trans.frequency*c.medium.sound_speed_m_s/1000;
    d=vecnorm(xyz-c.exposure.foci_mm(k,:),2,2)/1000;
    active=tx.Apod(:)>0;
    arrival=tx.Delay(active)'/(s.Trans.frequency*1e6)+d(active)/c.medium.sound_speed_m_s;
    verifyLessThan(t,max(arrival)-min(arrival),1e-12);
end
verifyEqual(t,r.timing.total_exposure_pulses,12);
verifyEqual(t,s.TW(2).Parameters(3),2*c.exposure.cycles);
last=s.Event(end).seqControl;
verifyEqual(t,s.SeqControl(last).command,'stop');
end

function testTopologyAndMappingMustMatch(t)
c = icevs.default_config(t.TestData.root);
c.probe.num_elements = 96;
verifyError(t,@()icevs.build(c),'icevs:Probe');
c = icevs.default_config(t.TestData.root);
c.probe.connector_es = (64:-1:1)';
[s,~] = icevs.build(c);
verifySize(t,s.Trans.ElementPos,[64 5]);
verifySize(t,s.TX(1).Apod,[1 64]);
verifySize(t,s.TX(end).Delay,[1 64]);
verifySize(t,s.Receive(1).Apod,[1 64]);
verifyEqual(t,s.TX(1).Apod,ones(1,64));
verifyEqual(t,s.Trans.ConnectorES,(64:-1:1)');
end

function testInvalidProtocolRejected(t)
c = icevs.default_config(t.TestData.root);
c.exposure.cycles = 0;
verifyError(t,@()icevs.build(c),'icevs:Config');
c = icevs.default_config(t.TestData.root);
c.exposure.voltage_v = c.probe.max_high_voltage_v + 1;
verifyError(t,@()icevs.build(c),'icevs:Config');
c = icevs.default_config(t.TestData.root);
c.exposure.voltage_v = 2.6; % default 1.6 V imaging profile conflicts
verifyError(t,@()icevs.build(c),'icevs:Config');
c = icevs.default_config(t.TestData.root);
c.exposure.foci_mm = [0 1 -20];
verifyError(t,@()icevs.build(c),'icevs:Config');
c = icevs.default_config(t.TestData.root);
c.exposure.max_total_pulses = 1;
verifyError(t,@()icevs.build(c),'icevs:Config');
c = icevs.default_config(t.TestData.root);
c.imaging.demod_frequency_mhz = 32; % exceeds NS200BW maximum in Table 15.0.1
verifyError(t,@()icevs.build(c),'icevs:Config');
end

function testOfflineExportAndModeIsolation(t)
c = icevs.default_config(t.TestData.root);
c.mode = 'exposure_only';
c.sequence.num_frames = 1;
[s,r] = icevs.build(c);
verifyTrue(t,all([s.Event.rcv]==0));
verifyFalse(t,any(strcmp({s.SeqControl.command},'transferToHost')));
out = tempname; mkdir(out);
cleanup = onCleanup(@()rmdir(out,'s'));
paths = icevs.save_sequence(s,r,c,out);
saved = load(paths.mat);
verifyEqual(t,saved.TX,s.TX);
verifyEqual(t,saved.ICEConfig,c);
verifyEqual(t,saved.ICEReport.physical_validation,'unknown');
verifyTrue(t,isfile(paths.json));
verifyTrue(t,isfile(paths.events_csv));
c.mode = 'imaging_only';
[s,r] = icevs.build(c);
verifyEqual(t,r.timing.total_exposure_pulses,0);
verifyFalse(t,any([s.Event.tx]>numel(c.imaging.angles_deg)));
end

function testExplicitGeometryAndDeepReceiveAllocation(t)
c = icevs.default_config(t.TestData.root);
c.sequence.num_frames = 1;
c.imaging.end_depth_wls = 1000;
[s,r] = icevs.build(c);
verifyGreaterThan(t,s.Receive(1).endDepth,c.imaging.end_depth_wls);
verifyGreaterThan(t,r.reserved_rows_per_acquisition,8192);
verifyGreaterThan(t,r.reserved_rows_per_acquisition,r.estimated_samples_per_acquisition);
c.imaging.pri_us = 50;
verifyError(t,@()icevs.build(c),'icevs:Timing');
end

function testApertureOverridesCannotLeakAcrossPhysicalSplit(t)
c=icevs.default_config(t.TestData.root);
c.imaging.apod=ones(1,64); c.imaging.apod(1)=0;
verifyError(t,@()icevs.build(c),'icevs:Partition');
c=icevs.default_config(t.TestData.root);
c.exposure.apod=ones(1,64);
verifyError(t,@()icevs.build(c),'icevs:Partition');
c=icevs.default_config(t.TestData.root);
c.runtime.simulate_mode=0;
verifyError(t,@()icevs.build(c),'icevs:Config');
end

function testOddSessionUsesEvenBufferWithoutExtraExposure(t)
c = icevs.default_config(t.TestData.root);
c.sequence.num_frames = 3;
[s,r] = icevs.build(c);
verifyEqual(t,s.Resource.RcvBuffer.numFrames,4);
verifyEqual(t,numel(s.Receive),3*numel(c.imaging.angles_deg));
verifyEqual(t,r.timing.total_exposure_pulses,3*c.exposure.pulses_per_focus);
verifyEqual(t,r.reserved_receive_buffer_mib, ...
    2*s.Resource.RcvBuffer.rowsPerFrame*c.system.num_receive*4/2^20);
end
