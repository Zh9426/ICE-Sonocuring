function tests=test_verasonics_shared_aperture
tests=functiontests(localfunctions);
end
function setupOnce(t)
t.TestData.root=fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(t.TestData.root,'verasonics','dual_mode'));
end
function testDefaultFullImagingAndSelectedExposure(t)
c=icevs.default_config(t.TestData.root); c.sequence.num_frames=2;
verifyEqual(t,c.partition.layout,'full64_imaging_selected_exposure');
verifyEqual(t,c.partition.exposure_ranks,2:2:64);
b=load(c.baseline_mat); [s,r]=icevs.build(c);
verifyEqual(t,r.partition.imaging_count,64);
verifyEqual(t,r.partition.exposure_count,32);
verifyEqual(t,r.partition.shared_count,32);
verifyEqual(t,s.Receive,b.Receive(1:30));
verifyEqual(t,s.PData,b.PData);
for k=1:15
    verifyEqual(t,s.TX(k).Apod,b.TX(k).Apod);
    verifyEqual(t,s.TX(k).Delay,b.TX(k).Delay,'AbsTol',1e-11);
end
verifyEqual(t,s.TX(end).Apod,double(mod(1:64,2)==0));
end
function testAnyNonemptySubsetIncludingAll64(t)
c=icevs.default_config(t.TestData.root); c.sequence.num_frames=1;
for ranks={1,[1 17 32 64],1:64}
    c.partition.exposure_ranks=ranks{1}; [s,r]=icevs.build(c);
    verifyEqual(t,s.TX(end).Apod,double(ismember(1:64,ranks{1})));
    verifyEqual(t,s.Receive(1).Apod,ones(1,64));
    verifyEqual(t,r.partition.exposure_count,numel(ranks{1}));
    verifyEqual(t,s.TX(end).Delay(~s.TX(end).Apod),zeros(1,64-numel(ranks{1})));
end
end
function testInvalidSubsetsRejected(t)
c=icevs.default_config(t.TestData.root);
for ranks={[],[1 1],0,65,1.5,NaN,[1 Inf],ones(2)}
    c.partition.exposure_ranks=ranks{1};
    verifyError(t,@()icevs.build(c),'icevs:Partition');
end
end
function testPhysicalRanksIndependentOfListAndConnectorOrder(t)
c=icevs.default_config(t.TestData.root); c.sequence.num_frames=1;
order=[2:2:64 1:2:63]; xyz=[(-31.5:31.5)'*.13,zeros(64,2)];
c.probe.positions_mm=xyz(order,:); c.probe.connector_es=(64:-1:1)';
c.partition.exposure_ranks=[1 8 64]; [s,r]=icevs.build(c);
verifyEqual(t,r.partition.exposure_mask,ismember(order',[1 8 64]));
verifyEqual(t,s.Receive(1).Apod,ones(1,64));
verifyEqual(t,s.Trans.ConnectorES,(64:-1:1)');
end
function testModesKeepTransmitReceiveSeparateAndRecovery(t)
c=icevs.default_config(t.TestData.root); c.sequence.num_frames=2;
for mode={'imaging_only','exposure_only','interleaved'}
    c.mode=mode{1}; [s,r]=icevs.build(c); na=numel(c.imaging.angles_deg);
    isExposure=[s.Event.tx]>na; verifyTrue(t,all([s.Event(isExposure).rcv]==0));
    verifyEqual(t,s.SeqControl(s.Event(end).seqControl).command,'stop');
    rows=r.timing.event_rows;
    if strcmp(c.mode,'interleaved')
        recovery=find(strcmp({rows.kind},'receive_recovery') & [rows.frame]==1);
        nextImage=find(strcmp({rows.kind},'imaging_acquire') & [rows.frame]==2,1);
        verifyGreaterThan(t,nextImage,recovery);
        verifyGreaterThanOrEqual(t,rows(nextImage).scheduled_start_lower_bound_us, ...
            rows(recovery).scheduled_start_lower_bound_us+c.timing.receive_recovery_us);
    end
    if strcmp(c.mode,'imaging_only'), verifyFalse(t,any(isExposure)); end
    if strcmp(c.mode,'exposure_only'), verifyTrue(t,all([s.Event.rcv]==0)); end
end
end
function testElementLoadCountsBothRolesAndNoEnergyClaim(t)
c=icevs.default_config(t.TestData.root); c.sequence.num_frames=2;
[~,r]=icevs.build(c); e=r.operating_envelope; even=2:2:64;
verifyEqual(t,e.per_element.imaging_on_time_us,repmat(5,64,1),'AbsTol',1e-12);
expected=repmat(5,64,1); expected(even)=5+20*20/6;
verifyEqual(t,e.per_element.total_on_time_us,expected,'AbsTol',1e-12);
verifyEqual(t,e.total_element_on_time_us,sum(expected),'AbsTol',1e-10);
verifyEqual(t,e.acoustic_power_status,'unknown_requires_calibration');
verifyFalse(t,e.hardware_qualified);
c.mode='exposure_only'; [~,r]=icevs.build(c);
verifyEqual(t,r.operating_envelope.per_element.total_on_time_us(1:2:64),zeros(32,1));
end
function testApodizationRespectsSelectionAndFullImaging(t)
c=icevs.default_config(t.TestData.root); c.sequence.num_frames=1;
c.exposure.apod=ones(1,64); verifyError(t,@()icevs.build(c),'icevs:Partition');
c=icevs.default_config(t.TestData.root); c.imaging.apod=ones(1,64); c.imaging.apod(1)=0;
verifyError(t,@()icevs.build(c),'icevs:Partition');
end
function testSavedMasksAndDistinctSubsetNames(t)
c=icevs.default_config(t.TestData.root); c.sequence.num_frames=1;
out=fullfile(t.TestData.root,'results','shared_aperture_test_exports');
[s,r]=icevs.build(c); p=icevs.save_sequence(s,r,c,out);
saved=load(p.mat); elements=readtable(p.elements_csv);
verifyEqual(t,saved.Receive,s.Receive);
verifyTrue(t,all(elements.imaging));
verifyEqual(t,logical(elements.exposure),mod((1:64)',2)==0);
c.partition.exposure_ranks=1:2:64;
[s,r]=icevs.build(c); q=icevs.save_sequence(s,r,c,out);
verifyNotEqual(t,p.mat,q.mat);
end
function testZeroExposureWeightsAreNotCountedAsFiring(t)
c=icevs.default_config(t.TestData.root); c.sequence.num_frames=1;
c.exposure.apod=zeros(1,64); c.exposure.apod(4:4:64)=.5;
[~,r]=icevs.build(c); e=r.operating_envelope;
verifyEqual(t,r.partition.exposure_count,32); % Assigned candidate set.
verifyEqual(t,sum(r.partition.exposure_active_mask),16); % Actual TX weights.
expected=zeros(64,1); expected(4:4:64)=10*20/6;
verifyEqual(t,e.per_element.exposure_on_time_us,expected,'AbsTol',1e-12);
end
function testSharedRoleBoundaryCannotHideShortTransmitSpacing(t)
% Synthetic timing only: never a recommendation for physical receive recovery.
c=icevs.default_config(t.TestData.root); c.sequence.num_frames=2;
c.exposure.pulses_per_focus=1; c.exposure.pri_us=1e6;
c.timing.recharge_us=1; c.timing.receive_recovery_us=1;
c.timing.provenance='synthetic_short_boundary_regression_only';
c.hardware_limits.max_local_duty_cycle=.01;
verifyError(t,@()icevs.build(c),'icevs:Limits');
% Different physical channels do not accumulate this cross-role TX boundary.
c.partition.layout='odd_imaging_even_exposure';
[~,r]=icevs.build(c); verifyFalse(t,r.operating_envelope.hardware_qualified);
end
