function tests=test_verasonics_linear64
tests=functiontests(localfunctions);
end
function setupOnce(t)
t.TestData.root=fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(t.TestData.root,'verasonics','dual_mode'));
end
function testPhysicalOrderAndOrigin(t)
c=icevs.default_config(t.TestData.root); c.sequence.num_frames=1;
c.partition.layout='left_imaging_right_exposure'; % Legacy regression only.
order=[2:2:64 1:2:63]; xyz=[(-31.5:31.5)'*.13,zeros(64,2)];
c.probe.positions_mm=xyz(order,:); c.probe.connector_es=order';
[s,r]=icevs.build(c);
verifyEqual(t,r.partition.imaging_mask,xyz(order,1)<0);
verifyEqual(t,s.TX(1).Origin,[0 0 0]); % Preserve original virtual-apex coordinates.
verifyEqual(t,s.TX(end).Origin*r.wavelength_mm,[2.08 0 0],'AbsTol',1e-12);
verifyEqual(t,r.operating_envelope.exposure_aperture_width_mm,4.14,'AbsTol',1e-12);
end
function testOffPlaneAndNonlinearConfigsRejected(t)
c=icevs.default_config(t.TestData.root); c.exposure.foci_mm=[0 1 20];
verifyError(t,@()icevs.build(c),'icevs:Config');
c=icevs.default_config(t.TestData.root); c.probe.type='unexpected';
verifyError(t,@()icevs.build(c),'icevs:Config');
end
function testEnvelopeAndUnknownLimits(t)
c=icevs.default_config(t.TestData.root); c.sequence.num_frames=2;
[~,r]=icevs.build(c); e=r.operating_envelope;
verifyEqual(t,e.exposure_burst_us,20/6,'AbsTol',1e-12);
verifyEqual(t,e.exposure_local_duty_cycle,(20/6)/1000,'AbsTol',1e-12);
verifyEqual(t,e.exposure_total_on_time_us,20*20/6,'AbsTol',1e-12);
verifyEqual(t,e.hardware_limits_status,'unknown');
verifyFalse(t,e.hardware_qualified);
c.mode='imaging_only'; [~,r]=icevs.build(c);
verifyEqual(t,r.operating_envelope.exposure_total_on_time_us,0);
end
function testDeclaredLimitsEnforced(t)
c=icevs.default_config(t.TestData.root);
c.hardware_limits.max_burst_us=1;
verifyError(t,@()icevs.build(c),'icevs:Limits');
c=icevs.default_config(t.TestData.root); c.hardware_limits.max_local_duty_cycle=.001;
verifyError(t,@()icevs.build(c),'icevs:Limits');
c=icevs.default_config(t.TestData.root); c.hardware_limits.max_total_on_time_us=1;
verifyError(t,@()icevs.build(c),'icevs:Limits');
c=icevs.default_config(t.TestData.root); c.hardware_limits.max_voltage_v=1.5;
verifyError(t,@()icevs.build(c),'icevs:Limits');
c=icevs.default_config(t.TestData.root); c.hardware_limits.max_local_duty_cycle=1.1;
verifyError(t,@()icevs.build(c),'icevs:Config');
end
function testLinearTransmitMetadataAndDelaysAgainstVendor(t)
c=icevs.default_config(t.TestData.root); c.sequence.num_frames=1;
c.exposure.foci_mm=[-1 0 20;3 0 25];
c.exposure.tpc_profile=2; c.exposure.voltage_v=6;
[s,~]=icevs.build(c);
oldPath=path; restorePath=onCleanup(@()path(oldPath));
addpath(fullfile(c.vendor_root,'Utilities'));
names={'Trans','Resource'}; values=cell(1,2); existed=false(1,2);
for k=1:2
    existed(k)=evalin('base',['exist(''' names{k} ''',''var'')~=0']);
    if existed(k), values{k}=evalin('base',names{k}); end
end
restoreBase=onCleanup(@()restore(names,values,existed));
assignin('base','Trans',s.Trans); assignin('base','Resource',s.Resource);
for k=1:numel(s.TX)
    verifyEqual(t,s.TX(k).Delay,computeTXDelays(s.TX(k)),'AbsTol',1e-11);
end
verifyEqual(t,[s.TPC.hv],[1.6 6]);
verifyGreaterThanOrEqual(t,s.TPC(2).xmitDuration,20/6);
% SectorFT is not its bounding rectangle: sample the outer sector arc.
angles=linspace(-pi/4,pi/4,101);
x=(s.P.radius+c.imaging.end_depth_wls)*sin(angles);
z=(s.P.radius+c.imaging.end_depth_wls)*cos(angles)-s.P.radius;
for k=1:numel(x)
    d=vecnorm(s.Trans.ElementPos(s.Receive(1).Apod>0,1:3)-[x(k) 0 z(k)],2,2);
    verifyGreaterThanOrEqual(t,s.Receive(1).endDepth,max(d));
end
end
function testPassingDeclaredLimitsDoNotQualifyHardware(t)
c=icevs.default_config(t.TestData.root); c.sequence.num_frames=1;
c.hardware_limits=struct('max_burst_us',10,'max_local_duty_cycle',.01, ...
    'max_total_on_time_us',1000,'max_voltage_v',5,'provenance','synthetic_test_limits');
[~,r]=icevs.build(c);
verifyEqual(t,r.operating_envelope.hardware_limits_status,'declared_limits_passed_not_qualified');
verifyFalse(t,r.operating_envelope.hardware_qualified);
verifyTrue(t,all(strcmp({r.operating_envelope.limit_checks.status},'declared_comparison_passed')));
end
function testSinglePulseGroupsCannotHideDutyBehindUnusedPRI(t)
c=icevs.default_config(t.TestData.root); c.mode='exposure_only';
c.sequence.num_frames=2; c.exposure.pulses_per_focus=1;
c.exposure.pri_us=1e6;
c.hardware_limits.max_local_duty_cycle=1e-4;
verifyError(t,@()icevs.build(c),'icevs:Limits');
c.hardware_limits.max_local_duty_cycle=NaN;
[~,r]=icevs.build(c);
verifyGreaterThan(t,r.operating_envelope.exposure_local_duty_cycle,1e-4);
verifyLessThan(t,r.operating_envelope.exposure_min_scheduled_start_interval_us,13000);
end
function restore(names,values,existed)
for k=1:2
    if existed(k), assignin('base',names{k},values{k});
    else, evalin('base',['clear ' names{k}]); end
end
end
