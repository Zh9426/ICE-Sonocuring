function tests=test_verasonics_original_baseline
tests=functiontests(localfunctions);
end
function setupOnce(t)
t.TestData.root=fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(t.TestData.root,'verasonics','dual_mode'));
end
function testDefaultRestoresOriginalImagingGeometry(t)
c=icevs.default_config(t.TestData.root); c.sequence.num_frames=2;
b=load(c.baseline_mat); [s,r]=icevs.build(c);
verifyEqual(t,c.imaging.angles_deg,-22.5+(0:14)*90/14,'AbsTol',1e-12);
verifyEqual(t,s.P,b.P);
verifyEqual(t,s.PData,b.PData);
verifyEqual(t,s.TGC,b.TGC);
verifyEqual(t,s.Process,b.Process);
verifyEqual(t,s.Resource.DisplayWindow,b.Resource.DisplayWindow);
verifyEqual(t,s.Receive(1).endDepth,b.Receive(1).endDepth);
verifyEqual(t,s.TW(1),b.TW);
for k=1:15
    verifyEqual(t,s.TX(k).Origin,b.TX(k).Origin);
    verifyEqual(t,s.TX(k).focus,b.TX(k).focus);
    verifyEqual(t,s.TX(k).Steer,b.TX(k).Steer,'AbsTol',1e-12);
end
verifyFalse(t,isfield(s.TPC,'hv'));
verifyEqual(t,r.operating_envelope.limit_checks(4).requested,1.6);
verifyEqual(t,s.SeqControl(s.Event(end).seqControl).command,'stop');
end
function testFull64ControlMatchesOriginalTransmitAndReceive(t)
c=icevs.default_config(t.TestData.root); c.mode='imaging_only';
c.partition.layout='full64_imaging_control'; c.sequence.num_frames=2;
b=load(c.baseline_mat); [s,r]=icevs.build(c);
for k=1:15
    verifyEqual(t,s.TX(k).Apod,b.TX(k).Apod);
    verifyEqual(t,s.TX(k).Delay,b.TX(k).Delay,'AbsTol',1e-11);
end
verifyEqual(t,s.Receive,b.Receive(1:30));
verifyEqual(t,s.Media,b.Media);
verifyEqual(t,r.timing.total_exposure_pulses,0);
c.mode='interleaved';
verifyError(t,@()icevs.build(c),'icevs:Partition');
end
function testExplicitVoltageAndSharedProfileConflict(t)
c=icevs.default_config(t.TestData.root); c.sequence.num_frames=1;
c.imaging.voltage_v=2; c.exposure.voltage_v=2;
s=icevs.build(c); verifyEqual(t,s.TPC.hv,2);
c.exposure.voltage_v=3;
verifyError(t,@()icevs.build(c),'icevs:Config');
end
function testOriginalSparseDelaysAgainstOriginalFullAperture(t)
c=icevs.default_config(t.TestData.root); c.sequence.num_frames=1;
c.partition.layout='odd_imaging_even_exposure';
b=load(c.baseline_mat); s=icevs.build(c); odd=1:2:64;
for k=1:15
    expected=b.TX(k).Delay(odd); expected=expected-min(expected);
    verifyEqual(t,s.TX(k).Delay(odd),expected,'AbsTol',1e-11);
    verifyEqual(t,s.TX(k).Delay(2:2:64),zeros(1,32));
end
end
function testMixedDefaultAndExplicitProfileVoltages(t)
c=icevs.default_config(t.TestData.root); c.sequence.num_frames=1;
c.exposure.tpc_profile=2; c.exposure.voltage_v=2;
s=icevs.build(c); verifyEqual(t,[s.TPC.hv],[1.6 2]);
c=icevs.default_config(t.TestData.root); c.imaging.voltage_v=1.6;
c.sequence.num_frames=1; s=icevs.build(c); verifyEqual(t,s.TPC.hv,1.6);
end
