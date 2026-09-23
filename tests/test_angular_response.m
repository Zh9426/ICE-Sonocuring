function tests=test_angular_response
tests=functiontests(localfunctions);
end
function setupOnce(~)
root=fileparts(fileparts(mfilename('fullpath')));addpath(root);startup_ice();
end
function testSingleRectangularPistonNull(t)
c=demo_config('linear');c.array.size=[1 1];c.array.pitch_m=[.002 .002];
c.array.element_width_m=.0012;c.excitation.mode='broad';
g=ice.make_geometry(c.array);s=ice.make_sequence(g,true,c);
r=ice.angular_response(g,s.shots,[0 30],'xz',c);
verifyEqual(t,r.amplitude(1),1,'AbsTol',1e-14);
verifyLessThan(t,r.amplitude(2),1e-12);
end
function testSteeringAndThinnedGratingLobe(t)
c=demo_config('linear');c.excitation.mode='broad';c.excitation.steering_deg=[20 0];
g=ice.make_geometry(c.array);mask=mod((1:32)',2)==0;
s=ice.make_sequence(g,mask,c);theta=asind(sind(20)-1);
r=ice.angular_response(g,s.shots,[theta -20 20],'xz',c);
verifyGreaterThan(t,r.amplitude(1),.8);verifyGreaterThan(t,r.amplitude(3),.9);
verifyLessThan(t,r.amplitude(2),.15);
end
function testElevationSymmetryAndFiniteDistanceLimit(t)
c=demo_config('linear');g=ice.make_geometry(c.array);s=ice.make_sequence(g,true(32,1),c);
r=ice.angular_response(g,s.shots,[-20 0 20],'yz',c);
verifyEqual(t,r.amplitude(1),r.amplitude(3),'AbsTol',1e-12);
c.excitation.mode='broad';s=ice.make_sequence(g,true(32,1),c);
theta=[-10;0;10];direction=[sind(theta),zeros(3,1),cosd(theta)];
c.solver.patch_count=[4 40];p=ice.solve_pressure(g,s.shots,direction*100,c);
r=ice.angular_response(g,s.shots,theta,'xz',c);
verifyEqual(t,abs(p)/abs(p(2)),r.amplitude,'AbsTol',1e-4);
end
