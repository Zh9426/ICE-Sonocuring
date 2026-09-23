function tests = test_propagation
% Independent limiting cases for the SI Rayleigh solver and exposure algebra.
tests = functiontests(localfunctions);
end

function setupOnce(t)
root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root,'simulation'), fullfile(root,'config'));
t.TestData.cfg = tiny_config();
end

function testPointPatchLimitAndDistance(t)
c=t.TestData.cfg; g=one_element(); s=one_shot();
q=[0 0 .02; 0 0 .04];
p=ice.solve_pressure(g,s,q,c);
k=2*pi*c.acoustics.frequency_hz/c.acoustics.sound_speed_m_s;
expected=1i*c.acoustics.density_kg_m3*c.acoustics.sound_speed_m_s*k/(2*pi) ...
    *c.source.velocity_m_s*g.width_m*g.height_m .* exp(-1i*k*q(:,3))./q(:,3);
verifyEqual(t,p,expected,'RelTol',1e-12);
verifyEqual(t,abs(p(1))/abs(p(2)),2,'AbsTol',1e-12);
end

function testSuperpositionAndDelaySign(t)
c=t.TestData.cfg; g=one_element(); s=one_shot();
p=ice.solve_pressure(g,s,[0 0 .02],c);
s.weights=2i; s.delay_s=1/(4*c.acoustics.frequency_hz);
q=ice.solve_pressure(g,s,[0 0 .02],c);
verifyEqual(t,q,2*p,'RelTol',1e-12);
end

function testRectangularIntegralConverges(t)
c=t.TestData.cfg; g=one_element(); g.width_m=.001; g.height_m=.002;
c.solver.patch_count=[2 4]; p1=ice.solve_pressure(g,one_shot(),[.003 .002 .015],c);
c.solver.patch_count=[8 16]; p2=ice.solve_pressure(g,one_shot(),[.003 .002 .015],c);
c.solver.patch_count=[32 64]; p3=ice.solve_pressure(g,one_shot(),[.003 .002 .015],c);
verifyLessThan(t,abs(p2-p3),abs(p1-p3));
verifyLessThan(t,abs(p2-p3)/abs(p3),.005);
end

function testRejectBackPlaneAndBadUnits(t)
c=t.TestData.cfg;
verifyError(t,@()ice.solve_pressure(one_element(),one_shot(),[0 0 0],c),'ice:InvalidPoints');
c.acoustics.sound_speed_m_s=-1;
verifyError(t,@()ice.solve_pressure(one_element(),one_shot(),[0 0 .01],c),'ice:InvalidAcoustics');
end

function testSequentialShotsDoNotCancel(t)
e=ice.aggregate_exposure([2 -2; 0 4],[.25 .75],.2,1000,1500);
verifyEqual(t,e.pressure_peak_pa,[2;4]);
verifyEqual(t,e.intensity_pulse_average_w_m2,[4;12]/3e6,'AbsTol',1e-15);
verifyEqual(t,e.intensity_temporal_average_w_m2,[4;12]*.2/3e6,'AbsTol',1e-15);
verifyError(t,@()ice.aggregate_exposure([2 -2],[1 1],.2,1000,1500),'ice:InvalidExposure');
end

function testZeroDutyAndZeroDwell(t)
e=ice.aggregate_exposure([2 100],[1 0],0,1000,1500);
verifyEqual(t,e.pressure_peak_pa,0);
verifyEqual(t,e.intensity_pulse_average_w_m2,0);
verifyEqual(t,e.intensity_temporal_average_w_m2,0);
e=ice.aggregate_exposure([2 100],[1 0],.5,1000,1500);
verifyEqual(t,e.pressure_peak_pa,2);
end

function testGridVolumeAndOrder(t)
v.x_m=[-.001 0 .001];v.y_m=[-.002 0 .002];v.z_m=[.01 .011 .012];
g=ice.make_grid(v);
verifySize(t,g.points_m,[27 3]); verifyEqual(t,g.shape,[3 3 3]);
verifyEqual(t,g.points_m(2,:),[0 -.002 .01],'AbsTol',1e-15);
verifyEqual(t,g.voxel_volume_m3,2e-9,'RelTol',1e-12);
v.x_m=[0 .001 .003];verifyError(t,@()ice.make_grid(v),'ice:InvalidGrid');
end

function testDemoAndUnknownTemplate(t)
c=demo_config('linear'); verifyEqual(t,c.provenance.kind,'synthetic');
verifyFalse(t,c.source.calibrated); ice.validate_config(c);
c=real_ice_template(); verifyError(t,@()ice.validate_config(c),'ice:UnconfirmedConfiguration');
end

function testRejectComplexGeometryAndClippedTarget(t)
c=t.TestData.cfg;g=one_element();g.positions_m(1)=1i*.001;
verifyError(t,@()ice.solve_pressure(g,one_shot(),[0 0 .01],c),'ice:InvalidGeometry');
c=demo_config('linear');c.target.center_m(1)=.006;
verifyError(t,@()ice.validate_config(c),'ice:TargetOutsideGrid');
end

function c=tiny_config()
c.acoustics=struct('frequency_hz',1e6,'sound_speed_m_s',1500,'density_kg_m3',1000);
c.source.velocity_m_s=.01;
c.solver=struct('patch_count',[1 1],'chunk_size',1000);
end
function g=one_element()
g=struct('positions_m',[0 0 0],'width_m',1e-5,'height_m',1e-5);
end
function s=one_shot()
s=struct('weights',1,'delay_s',0,'focus_m',[0 0 .02]);
end
