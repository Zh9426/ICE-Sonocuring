function tests=test_verasonics_matrix
tests=functiontests(localfunctions);
end
function setupOnce(t)
t.TestData.root=fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(t.TestData.root,'verasonics','dual_mode'));
end
function testGeometryMatchesExistingP0MatrixConvention(t)
c=matrix_config(t.TestData.root);
tr=icevs.make_trans(c.probe,c.medium.sound_speed_m_s);
lambda=c.medium.sound_speed_m_s/1000/tr.frequency;
xyz=tr.ElementPos(:,1:3)*lambda;
verifyEqual(t,xyz(1:12,2),repmat(-3.5*.3,12,1),'AbsTol',1e-12);
verifyEqual(t,xyz(1:12,1),(-5.5:5.5)'*.3,'AbsTol',1e-12);
verifyEqual(t,xyz(13,1:2),[-5.5 -2.5]*.3,'AbsTol',1e-12);
[p,ia,ea]=icevs.partition_apertures(c,tr);
verifyEqual(t,find(ia),(reshape((1:6)'+(0:7)*12,1,[])));
verifyEqual(t,sum(ea),48);
verifyTrue(t,all(p.imaging_mask|p.exposure_mask));
verifyEqual(t,tr.ElementPos(:,3:5),zeros(96,3));
verifyFalse(t,isfield(tr,'elevationFocusMm'));
end
function testPermutedElementListDoesNotBecomeFirst48Split(t)
c=matrix_config(t.TestData.root);
tr=icevs.make_trans(c.probe,c.medium.sound_speed_m_s);
order=[2:2:96 1:2:95];
lambda=c.medium.sound_speed_m_s/1000/tr.frequency;
c.probe.positions_mm=tr.ElementPos(order,1:3)*lambda+[2 3 0];
c.probe.connector_es=c.probe.connector_es(order);
[s,r]=icevs.build(c);
verifyEqual(t,r.partition.imaging_mask,c.probe.positions_mm(:,1)<2);
verifyEqual(t,s.Trans.ConnectorES,c.probe.connector_es);
verifyEqual(t,s.Receive(1).Apod,double(r.partition.imaging_mask'));
verifyEqual(t,s.TX(end).Apod,double(r.partition.exposure_mask'));
end
function testMatrixDelaysAgainstVendorUtility(t)
c=matrix_config(t.TestData.root); c.sequence.num_frames=1;
c.exposure.foci_mm=[-1 2 20;3 -2 30];
[s,~]=icevs.build(c);
oldPath=path; restorePath=onCleanup(@()path(oldPath));
addpath(fullfile(c.vendor_root,'Utilities'));
names={'Trans','Resource'};
saved=cell(1,2); existed=false(1,2);
for k=1:2
    existed(k)=evalin('base',['exist(''' names{k} ''',''var'')~=0']);
    if existed(k), saved{k}=evalin('base',names{k}); end
end
restoreBase=onCleanup(@()restore(names,saved,existed));
assignin('base','Trans',s.Trans); assignin('base','Resource',s.Resource);
for k=1:numel(s.TX)
    reference=computeTXDelays(s.TX(k));
    verifyEqual(t,s.TX(k).Delay,reference,'AbsTol',1e-11);
end
% Elevation steering plane-wave utility uses both x and y coordinates.
tx=s.TX(1); tx.Steer=[.1 -.2];
actual=icevs.tx_delays(s.Trans,0,tx.Steer,tx.Apod,tx.Origin);
verifyEqual(t,actual,computeTXDelays(tx),'AbsTol',1e-11);
end
function testReceiveRangeContainsThreeDimensionalGrid(t)
c=matrix_config(t.TestData.root); c.sequence.num_frames=1;
[s,~]=icevs.build(c);
pd=s.PData;
[x,y,z]=ndgrid(pd.Origin(1)+[0 (pd.Size(2)-1)*pd.PDelta(1)], ...
    pd.Origin(2)-[0 (pd.Size(1)-1)*pd.PDelta(2)], ...
    pd.Origin(3)+[0 (pd.Size(3)-1)*pd.PDelta(3)]);
for k=1:numel(x)
    distances=vecnorm(s.Trans.ElementPos(s.Receive(1).Apod>0,1:3)-[x(k) y(k) z(k)],2,2);
    verifyGreaterThanOrEqual(t,s.Receive(1).endDepth,max(distances));
end
end
function testInvalidMatrixAndOverlappingElementsRejected(t)
c=matrix_config(t.TestData.root); c.probe.shape=[8 8];
verifyError(t,@()icevs.build(c),'icevs:Probe');
c=matrix_config(t.TestData.root); c.probe.height_mm=1;
verifyError(t,@()icevs.build(c),'icevs:Probe');
c=matrix_config(t.TestData.root); c.probe.connector_es=ones(96,1);
verifyError(t,@()icevs.build(c),'icevs:Probe');
end
function restore(names,values,existed)
for k=1:numel(names)
    if existed(k), assignin('base',names{k},values{k});
    else, evalin('base',['clear ' names{k}]); end
end
end
function c=matrix_config(root)
% Explicit synthetic regression fixture, never the current physical default.
c=icevs.default_config(root);
c.imaging.geometry='plane_wave_rectangle'; % Explicit historical synthetic model.
c.partition.layout='left_imaging_right_exposure'; % Explicit synthetic fixture.
c.probe.type='matrix'; c.probe.name='Synthetic_Matrix12x8';
c.probe.shape=[12 8]; c.probe.num_elements=96;
c.probe.pitch_mm=[.3 .3]; c.probe.width_mm=.25; c.probe.height_mm=.25;
c.probe.connector_es=(1:96)'; c.probe.provenance='synthetic';
end
