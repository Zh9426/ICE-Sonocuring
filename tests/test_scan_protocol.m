function tests = test_scan_protocol
tests = functiontests(localfunctions);
end

function setupOnce(~)
root=fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root,'simulation'),fullfile(root,'config'));
end

function testSingleFocusAliasAndThreeDimensionalScan(t)
c=demo_config('matrix');c.array.size=[4 3];
g=ice.make_geometry(c.array);mask=true(12,1);
a=ice.make_sequence(g,mask,c);
c.excitation.mode='single_focus';b=ice.make_sequence(g,mask,c);
verifyEqual(t,b.shots,a.shots);
verifyEqual(t,b.dwell_time_s,1);
c.excitation.mode='focal_scan';
c.excitation.regional_points_m=[-.001 .0005 .013;.001 -.0005 .017];
c.excitation.dwell_weights=[];
c.exposure.exposure_time_s=4;
c.exposure.dwell_time_s=[1;3];
s=ice.make_sequence(g,mask,c);
verifySize(t,s.shots,[1 2]);
verifyEqual(t,s.dwell_weights,[.25;.75],'AbsTol',1e-12);
verifyEqual(t,s.dwell_time_s,[1;3]);
for j=1:2
    d=vecnorm(g.positions_m-c.excitation.regional_points_m(j,:),2,2);
    phase=exp(-1i*2*pi*c.acoustics.frequency_hz*(s.shots(j).delay_s+d/c.acoustics.sound_speed_m_s));
    verifyEqual(t,phase,phase(1)*ones(12,1),'AbsTol',1e-12);
end
end

function testProtocolConsistency(t)
c=demo_config('linear');c.array.size=[4 1];
g=ice.make_geometry(c.array);mask=true(4,1);
c.excitation.mode='focal_scan';c.excitation.regional_points_m=[0 0 .014;0 0 .016];
c.exposure.exposure_time_s=4;c.exposure.dwell_time_s=[1;3];
c.excitation.dwell_weights=[.5;.5];
verifyError(t,@() ice.make_sequence(g,mask,c),'ice:Excitation');
c.excitation.dwell_weights=[];c.exposure.dwell_time_s=[1;2];
verifyError(t,@() ice.make_sequence(g,mask,c),'ice:Excitation');
c.exposure.dwell_time_s=[1;3];
c.exposure.pulse_cycles=20;c.exposure.prf_hz=25e3;
s=ice.make_sequence(g,mask,c);
verifyEqual(t,s.pulse_cycles,20);
verifyEqual(t,s.prf_hz,25e3);
c.exposure.prf_hz=20e3;
verifyError(t,@() ice.make_sequence(g,mask,c),'ice:Excitation');
end

function testSequentialSimulationBuildsIndependentSingleFocusReference(t)
c=demo_config('matrix');c.array.size=[4 3];
c.grid.x_m=linspace(-.003,.003,9);
c.grid.y_m=linspace(-.002,.002,7);
c.grid.z_m=linspace(.012,.018,7);
c.solver.patch_count=[2 2];
c.excitation.mode='focal_scan';
c.excitation.regional_points_m=[-.001 .0005 .014;.001 -.0005 .016];
c.exposure.exposure_time_s=4;
c.exposure.dwell_time_s=[1;3];
r=ice.simulate(c);
verifySize(t,r.pressure_pa,[441 2]);
verifyEqual(t,r.sequence.dwell_time_s,[1;3]);
verifyGreaterThan(t,r.reference.pressure_peak_pa,0);
end
