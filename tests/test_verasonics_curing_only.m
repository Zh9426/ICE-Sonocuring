function tests=test_verasonics_curing_only
tests=functiontests(localfunctions);
end
function setupOnce(t)
t.TestData.root=fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(t.TestData.root,'verasonics','dual_mode'));
addpath(fullfile(t.TestData.root,'verasonics','curing_mode'));
end
function testMinimalContainsNoImagingOrReceiveObjects(t)
c=icec.default_config(t.TestData.root); c.sequence.num_groups=2;
[s,r]=icec.build(c);
for field={'Receive','Recon','ReconInfo','PData','P','TGC','Process','UI','Media'}
    verifyFalse(t,isfield(s,field{1}));
end
verifyEqual(t,fieldnames(s.Resource),{'Parameters'});
verifyFalse(t,isfield(c,'imaging'));
verifyEqual(t,numel(s.TW),1); verifyEqual(t,[s.TX.waveform],1);
verifyEqual(t,r.timing.total_imaging_acquisitions,0);
verifyFalse(t,r.hardware_run); verifyEqual(t,r.vsx_validation,'not_run');
end
function testFourVariantsUseCentralPhysicalRanks(t)
c=icec.default_config(t.TestData.root); c.sequence.num_groups=1;
groups=icec.variants(); counts=[64 48 32 16];
verifyEqual(t,numel(groups),4);
for k=1:4
    verifyEqual(t,groups(k).ranks,(65-counts(k))/2+(0:counts(k)-1)+.5);
    c.partition.exposure_ranks=groups(k).ranks; [s,r]=icec.build(c);
    verifyEqual(t,sum(s.TX.Apod>0),counts(k));
    verifyEqual(t,r.partition.imaging_count,0);
    verifyEqual(t,r.partition.shared_count,0);
end
end
function testFocusAndProbeMatchExistingExposureBackend(t)
c=icec.default_config(t.TestData.root); c.sequence.num_groups=2;
c.partition.exposure_ranks=17:48; [s,r]=icec.build(c);
old=icevs.default_config(t.TestData.root); old.mode='exposure_only';
old.partition.exposure_ranks=c.partition.exposure_ranks;
old.sequence.num_frames=c.sequence.num_groups;
[baseline,~]=icevs.build(old);
verifyEqual(t,s.Trans,baseline.Trans);
verifyEqual(t,s.TX.Delay,baseline.TX(end).Delay,'AbsTol',1e-11);
verifyEqual(t,s.TW.Parameters,baseline.TW(2).Parameters);
verifyEqual(t,r.operating_envelope.per_element.exposure_on_time_us(17:48), ...
    repmat(20*20/6,32,1),'AbsTol',1e-12);
verifyEqual(t,r.operating_envelope.per_element.maximum_adjacent_burst_ratio(17:48), ...
    repmat((20/6)/1000,32,1),'AbsTol',1e-12);
end
function testOnlyFiniteTransmitAndRecharge(t)
c=icec.default_config(t.TestData.root); c.sequence.num_groups=2;
c.exposure.pulses_per_focus=3; [s,r]=icec.build(c);
verifyEqual(t,sum([s.Event.tx]>0),6);
verifyTrue(t,all([s.Event.rcv]==0 & [s.Event.recon]==0 & [s.Event.process]==0));
verifyFalse(t,any(ismember({s.SeqControl.command},{'transferToHost','returnToMatlab','jump'})));
verifyEqual(t,s.SeqControl(s.Event(end).seqControl).command,'stop');
verifyFalse(t,any(strcmp({r.timing.event_rows.kind},'receive_recovery')));
verifyEqual(t,sum(strcmp({r.timing.event_rows.kind},'recharge')),2);
verifyEqual(t,r.timing.num_groups,2);
verifyFalse(t,isfield(s.TPC,'hv'));
end
function testCustomRanksAndInvalidRequests(t)
c=icec.default_config(t.TestData.root); c.sequence.num_groups=1;
c.partition.exposure_ranks=[1 20 64]; s=icec.build(c);
verifyEqual(t,find(s.TX.Apod),[1 20 64]);
c.partition.exposure_ranks=[1 1]; verifyError(t,@()icec.build(c),'icevs:Partition');
c=icec.default_config(t.TestData.root); c.mode='interleaved';
verifyError(t,@()icec.build(c),'icevs:CuringOnly');
c=icec.default_config(t.TestData.root); c.runtime.simulate_mode=0;
verifyError(t,@()icec.build(c),'icevs:Config');
c=icec.default_config(t.TestData.root); c.hardware_limits.max_burst_us=1;
verifyError(t,@()icec.build(c),'icevs:Limits');
end
function testFourEntryPointsSaveOnlyMinimalPayload(t)
c=icec.default_config(t.TestData.root); c.sequence.num_groups=1;
out=fullfile(t.TestData.root,'results','curing_only_2026-11-03','test_exports');
groups=icec.variants(); paths=cell(1,4);
for k=1:4
    [s,r,used]=feval(groups(k).entry,c,out);
    verifyEqual(t,used.partition.exposure_ranks,groups(k).ranks);
    paths{k}=r.output_paths.mat; saved=load(paths{k});
    verifyEqual(t,saved.TX,s.TX);
    verifyFalse(t,isfield(saved,'Receive')); verifyFalse(t,isfield(saved,'PData'));
    verifyEqual(t,saved.ICEConfig.mode,'exposure_only');
    verifyFalse(t,isfield(saved.ICEConfig,'imaging'));
end
verifyEqual(t,numel(unique(paths)),4);
end
function testStandaloneKeepsItsOwnProfileAtStop(t)
c=icec.default_config(t.TestData.root); c.sequence.num_groups=1;
c.exposure.tpc_profile=2; c.exposure.voltage_v=2;
[s,r]=icec.build(c);
switches=strcmp({s.SeqControl.command},'setTPCProfile');
verifyEqual(t,[s.SeqControl(switches).argument],2);
verifyEqual(t,s.TPC(2).hv,2); verifyEqual(t,r.timing.shutdown_us,0);
end
function testImagingCannotDisableRecoveryWithStandaloneFlags(t)
c=icevs.default_config(t.TestData.root); c.sequence.num_frames=1;
c.timing.include_receive_recovery=0;
verifyError(t,@()icevs.build(c),'icevs:Config');
c=icevs.default_config(t.TestData.root); c.sequence.restore_imaging_profile=0;
verifyError(t,@()icevs.build(c),'icevs:Config');
end
