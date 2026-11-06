function tests=test_verasonics_oddeven
tests=functiontests(localfunctions);
end
function setupOnce(t)
t.TestData.root=fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(t.TestData.root,'verasonics','dual_mode'));
end
function testExplicitOddEvenMasksAcrossAllModes(t)
c=icevs.default_config(t.TestData.root); c.sequence.num_frames=2;
c.partition.layout='odd_imaging_even_exposure';
verifyEqual(t,c.partition.layout,'odd_imaging_even_exposure');
odd=mod(1:64,2)==1; even=~odd;
for mode={'imaging_only','exposure_only','interleaved'}
    c.mode=mode{1}; [s,r]=icevs.build(c);
    verifyEqual(t,r.partition.imaging_mask,odd');
    verifyEqual(t,r.partition.exposure_mask,even');
    verifyEqual(t,[r.partition.imaging_count r.partition.exposure_count],[32 32]);
    verifyEqual(t,vertcat(s.Receive.Apod),repmat(double(odd),numel(s.Receive),1));
    na=numel(c.imaging.angles_deg);
    verifyEqual(t,vertcat(s.TX(1:na).Apod),repmat(double(odd),na,1));
    verifyEqual(t,s.TX(end).Apod,double(even));
    verifyEqual(t,s.TX(end).Delay(odd),zeros(1,32));
    verifyEqual(t,s.TX(1).Delay(even),zeros(1,32));
    exposureEvents=[s.Event.tx]>na;
    verifyTrue(t,all([s.Event(exposureEvents).rcv]==0));
    verifyEqual(t,s.SeqControl(s.Event(end).seqControl).command,'stop');
end
end
function testPhysicalRankIndependentOfListAndConnectorOrder(t)
c=icevs.default_config(t.TestData.root); c.sequence.num_frames=1;
c.partition.layout='odd_imaging_even_exposure';
order=[2:2:64 1:2:63]; xyz=[(-31.5:31.5)'*.13,zeros(64,2)];
c.probe.positions_mm=xyz(order,:); c.probe.connector_es=(64:-1:1)';
[s,r]=icevs.build(c);
verifyEqual(t,r.partition.imaging_mask,mod(order',2)==1);
verifyEqual(t,s.Trans.ConnectorES,(64:-1:1)');
verifyEqual(t,s.TX(1).Origin,[0 0 0]);
verifyEqual(t,s.TX(end).Origin*r.wavelength_mm,[.065 0 0],'AbsTol',1e-12);
verifyEqual(t,r.operating_envelope.exposure_aperture_width_mm,8.17,'AbsTol',1e-12);
verifyEqual(t,r.operating_envelope.imaging_aperture_width_mm,8.17,'AbsTol',1e-12);
end
function testReversedRolesAndWeightedApodization(t)
c=icevs.default_config(t.TestData.root); c.sequence.num_frames=1;
c.partition.layout='even_imaging_odd_exposure';
c.imaging.apod=zeros(1,64); c.imaging.apod(2:2:64)=linspace(.2,1,32);
c.exposure.apod=zeros(1,64); c.exposure.apod(1:2:63)=linspace(1,.2,32);
[s,r]=icevs.build(c);
verifyEqual(t,s.TX(1).Apod,c.imaging.apod);
verifyEqual(t,s.TX(end).Apod,c.exposure.apod);
verifyEqual(t,s.Receive(1).Apod,double(mod(1:64,2)==0));
verifyEqual(t,r.partition.imaging_mask,mod((1:64)',2)==0);
c.imaging.apod(1)=.1;
verifyError(t,@()icevs.build(c),'icevs:Partition');
end
function testOddEvenExportMatchesSavedSequence(t)
c=icevs.default_config(t.TestData.root); c.sequence.num_frames=1;
c.partition.layout='odd_imaging_even_exposure';
[s,r]=icevs.build(c);
out=tempname; mkdir(out); cleanup=onCleanup(@()rmdir(out,'s'));
p=icevs.save_sequence(s,r,c,out);
verifyTrue(t,contains(p.mat,'ICE_Linear64OddEven_'));
saved=load(p.mat); j=jsondecode(fileread(p.json)); e=readtable(p.elements_csv);
verifyEqual(t,saved.ICEConfig.partition.layout,'odd_imaging_even_exposure');
verifyEqual(t,j.report.partition.imaging_mask,mod((1:64)',2)==1);
verifyEqual(t,logical(e.imaging),mod((1:64)',2)==1);
verifyEqual(t,logical(e.exposure),mod((1:64)',2)==0);
verifyEqual(t,e.connector_signal_assumed,(1:64)');
verifyEqual(t,saved.TX,s.TX);
verifyTrue(t,isnan(r.partition.boundary_x_wls));
end
function testUnsupportedPartitionRejected(t)
c=icevs.default_config(t.TestData.root); c.partition.layout='typo';
verifyError(t,@()icevs.build(c),'icevs:Partition');
c.partition.layout='odd_imaging_even_exposure';
tr=icevs.make_trans(c.probe,c.medium.sound_speed_m_s); tr.type=2;
verifyError(t,@()icevs.partition_apertures(c,tr),'icevs:Partition');
end
