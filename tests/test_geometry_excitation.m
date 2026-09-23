function tests = test_geometry_excitation
tests = functiontests(localfunctions);
end

function setupOnce(~)
root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root, 'simulation'));
end

function testLinearGeometry(testCase)
a = array_config('linear', [4 1]);
g = ice.make_geometry(a);
verifyEqual(testCase, g.positions_m, [-1.5;-.5;.5;1.5] .* [a.pitch_m(1), 0, 0], 'AbsTol', 1e-15);
verifyEqual(testCase, g.grid_indices, [(1:4)', ones(4,1)]);
verifyEqual(testCase, g.width_m, repmat(a.element_width_m,4,1));
verifyEqual(testCase, g.height_m, repmat(a.element_height_m,4,1));
verifyEqual(testCase, g.normal, [0 0 1]);
verifyEqual(testCase, g.shape, [4 1]);
end

function testMatrixGeometry(testCase)
a = array_config('matrix', [3 2]);
g = ice.make_geometry(a);
verifySize(testCase, g.positions_m, [6 3]);
verifyEqual(testCase, g.grid_indices, [1 1;2 1;3 1;1 2;2 2;3 2]);
verifyEqual(testCase, mean(g.positions_m,1), zeros(1,3), 'AbsTol', 1e-15);
verifyEqual(testCase, g.positions_m(:,1), repmat([-1;0;1]*a.pitch_m(1),2,1), 'AbsTol', 1e-15);
verifyEqual(testCase, g.positions_m(:,2), [-ones(3,1);ones(3,1)]*a.pitch_m(2)/2, 'AbsTol', 1e-15);
end

function testGeometryValidation(testCase)
a = array_config('linear', [4 2]);
verifyError(testCase, @() ice.make_geometry(a), 'ice:Geometry');
a = array_config('matrix', [3.5 2]);
verifyError(testCase, @() ice.make_geometry(a), 'ice:Geometry');
a = array_config('matrix', [3 2]); a.element_height_m = 2*a.pitch_m(2);
verifyError(testCase, @() ice.make_geometry(a), 'ice:Geometry');
a = array_config('linear', [4 1]); a.element_width_m = 0;
verifyError(testCase, @() ice.make_geometry(a), 'ice:Geometry');
a.element_width_m = 2*a.pitch_m(1);
verifyError(testCase, @() ice.make_geometry(a), 'ice:Geometry');
end

function testSharedAndCustomPartition(testCase)
g = ice.make_geometry(array_config('linear',[6 1]));
a = architecture('shared', 'central_curing', .5);
p = ice.partition_elements(g,a);
verifyTrue(testCase, all(p.imaging_mask & p.curing_mask));
a.type = 'partitioned'; a.pattern = 'custom'; a.custom_curing_mask = logical([1;0;0;1;0;1]);
p = ice.partition_elements(g,a);
verifyEqual(testCase, p.curing_mask, a.custom_curing_mask);
verifyEqual(testCase, p.imaging_mask, ~p.curing_mask);
a.custom_curing_mask = true(6,1);
verifyError(testCase,@() ice.partition_elements(g,a),'ice:Partition');
end

function testGeometricPartitions(testCase)
g = ice.make_geometry(array_config('linear',[8 1]));
a = architecture('partitioned','central_curing',.5);
p = ice.partition_elements(g,a);
verifyEqual(testCase, p.curing_mask, logical([0;0;1;1;1;1;0;0]));
verifyEqual(testCase, p.imaging_mask, ~p.curing_mask);
a.pattern = 'peripheral_curing';
p = ice.partition_elements(g,a);
verifyEqual(testCase, p.curing_mask, logical([1;1;0;0;0;0;1;1]));
a.pattern = 'checkerboard';
p = ice.partition_elements(g,a);
verifyEqual(testCase, nnz(p.curing_mask),4);
verifyEqual(testCase, p.curing_mask, logical([1;0;1;0;1;0;1;0]));
end

function testRandomPartitionDoesNotChangeGlobalRng(testCase)
g = ice.make_geometry(array_config('matrix',[6 5]));
a = architecture('partitioned','random_sparse',.3);
before = rng;
p = ice.partition_elements(g,a);
verifyEqual(testCase, rng, before);
q = ice.partition_elements(g,a);
verifyEqual(testCase,p,q);
verifyEqual(testCase,nnz(p.curing_mask),9);
a.seed = 72;
r = ice.partition_elements(g,a);
verifyNotEqual(testCase,r.curing_mask,p.curing_mask);
end

function testPartitionValidation(testCase)
g = ice.make_geometry(array_config('linear',[8 1]));
a = architecture('partitioned','random_sparse',0);
verifyError(testCase,@() ice.partition_elements(g,a),'ice:Partition');
a.curing_fraction = 1;
verifyError(testCase,@() ice.partition_elements(g,a),'ice:Partition');
g = ice.make_geometry(array_config('linear',[1 1])); a.curing_fraction=.5;
verifyError(testCase,@() ice.partition_elements(g,a),'ice:Partition');
end

function testFocusedPhaseAlignment(testCase)
g = ice.make_geometry(array_config('matrix',[5 3]));
c = sequence_config('focused'); c.excitation.focus_m=[.002 -.001 .012];
s = ice.make_sequence(g,true(15,1),c);
dist = vecnorm(g.positions_m-c.excitation.focus_m,2,2);
verifyEqual(testCase,s.shots.delay_s,(max(dist)-dist)/c.acoustics.sound_speed_m_s,'AbsTol',1e-18);
omega=2*pi*c.acoustics.frequency_hz;
receivedPhase = s.shots.weights .* exp(-1i*omega*(s.shots.delay_s+dist/c.acoustics.sound_speed_m_s));
verifyEqual(testCase,receivedPhase,receivedPhase(1)*ones(15,1),'AbsTol',1e-12);
verifyEqual(testCase,s.dwell_weights,1);
end

function testBroadSteeringSign(testCase)
g = ice.make_geometry(array_config('matrix',[5 3]));
c = sequence_config('broad'); c.excitation.steering_deg=[20 -10];
s = ice.make_sequence(g,true(15,1),c);
d = [sind(20)*cosd(-10),sind(-10),cosd(20)*cosd(-10)];
projection=g.positions_m*d';
verifyEqual(testCase,s.shots.delay_s,(projection-min(projection))/c.acoustics.sound_speed_m_s,'AbsTol',1e-18);
omega=2*pi*c.acoustics.frequency_hz;
farPhase=s.shots.weights.*exp(-1i*omega*s.shots.delay_s+1i*omega/c.acoustics.sound_speed_m_s*projection);
verifyEqual(testCase,farPhase,farPhase(1)*ones(15,1),'AbsTol',1e-12);
verifyTrue(testCase,all(isnan(s.shots.focus_m)));
end

function testExpandedSeparateShotsAndDwell(testCase)
g = ice.make_geometry(array_config('linear',[8 1]));
c = sequence_config('expanded');
c.excitation.regional_points_m=[-.002 0 .01;.002 0 .01;0 0 .015];
c.excitation.dwell_weights=[.2;.3;.5];
s=ice.make_sequence(g,true(8,1),c);
verifySize(testCase,s.shots,[1 3]);
verifyEqual(testCase,s.dwell_weights,[.2;.3;.5]);
verifyEqual(testCase,s.shots(2).focus_m,[.002 0 .01]);
verifyNotEqual(testCase,s.shots(1).delay_s,s.shots(2).delay_s);
c.excitation.dwell_weights=[1;1;1];
verifyError(testCase,@() ice.make_sequence(g,true(8,1),c),'ice:Excitation');
end

function testNormalizationAndAperture(testCase)
g=ice.make_geometry(array_config('linear',[8 1]));
c=sequence_config('focused'); mask=logical([1;0;1;0;1;0;1;0]);
s=ice.make_sequence(g,mask,c);
verifyEqual(testCase,s.shots.weights(mask),ones(4,1));
verifyEqual(testCase,s.shots.weights(~mask),zeros(4,1));
c.excitation.normalization='fixed_total';
s=ice.make_sequence(g,mask,c);
area=g.width_m.*g.height_m;
verifyEqual(testCase,sum(area.*abs(s.shots.weights).^2),sum(area),'RelTol',1e-12);
verifyEqual(testCase,s.shots.weights(mask),sqrt(2)*ones(4,1),'AbsTol',1e-12);
c.excitation.normalization='fixed_element'; c.excitation.aperture_size_m=[2.1*g.positions_m(5,1),Inf];
s=ice.make_sequence(g,true(8,1),c);
verifyEqual(testCase,find(abs(s.shots.weights)>0),[4;5]);
end

function testHannAndNumericApodization(testCase)
g=ice.make_geometry(array_config('linear',[5 1]));
c=sequence_config('focused'); c.excitation.apodization='hann';
s=ice.make_sequence(g,true(5,1),c);
verifyEqual(testCase,s.shots.weights,[0;.5;1;.5;0],'AbsTol',1e-14);
c.excitation.apodization=[1;2;3;4;5];
s=ice.make_sequence(g,true(5,1),c);
verifyEqual(testCase,s.shots.weights,complex([1;2;3;4;5],zeros(5,1)));
c.excitation.apodization=zeros(5,1);
verifyError(testCase,@() ice.make_sequence(g,true(5,1),c),'ice:Excitation');
end

function testAreaWeightedNormalizationAndSpatialHann(testCase)
g=ice.make_geometry(array_config('linear',[5 1]));
g.width_m=g.width_m.*[1;.8;.6;.4;.2];
c=sequence_config('focused'); c.excitation.normalization='fixed_total';
c.excitation.apodization=[1;2;3;4;5]; mask=logical([1;0;1;0;1]);
s=ice.make_sequence(g,mask,c); area=g.width_m.*g.height_m;
verifyEqual(testCase,sum(area.*abs(s.shots.weights).^2),sum(area),'RelTol',1e-12);
c.excitation.normalization='fixed_element'; c.excitation.apodization='hann';
s=ice.make_sequence(g,mask,c);
verifyEqual(testCase,s.shots.weights,[0;0;1;0;0],'AbsTol',1e-14);
end

function testCustomDelaysAndInvalidExcitation(testCase)
g=ice.make_geometry(array_config('linear',[4 1]));
c=sequence_config('focused'); c.excitation.custom_delay_s=[0;1;2;3]*1e-8;
s=ice.make_sequence(g,true(4,1),c);
verifyEqual(testCase,s.shots.delay_s,c.excitation.custom_delay_s);
c.excitation.custom_delay_s=[0;-1;2;3];
verifyError(testCase,@() ice.make_sequence(g,true(4,1),c),'ice:Excitation');
c=sequence_config('focused');
verifyError(testCase,@() ice.make_sequence(g,false(4,1),c),'ice:Excitation');
c.excitation.focus_m=[0 0 0];
verifyError(testCase,@() ice.make_sequence(g,true(4,1),c),'ice:Excitation');
c=sequence_config('focused'); c.acoustics.frequency_hz=NaN;
verifyError(testCase,@() ice.make_sequence(g,true(4,1),c),'ice:Excitation');
end

function a=array_config(type,sz)
a=struct('type',type,'size',sz,'pitch_m',[.3e-3 .4e-3], ...
    'element_width_m',.25e-3,'element_height_m',.35e-3);
end

function a=architecture(type,pattern,fraction)
a=struct('type',type,'pattern',pattern,'curing_fraction',fraction,'seed',19,'custom_curing_mask',[]);
end

function c=sequence_config(mode)
c.acoustics=struct('frequency_hz',5e6,'sound_speed_m_s',1500);
c.excitation=struct('mode',mode,'focus_m',[0 0 .015],'regional_points_m',[], ...
    'dwell_weights',1,'aperture_size_m',[Inf Inf],'apodization','uniform', ...
    'normalization','fixed_element','steering_deg',[0 0],'custom_delay_s',[]);
end
