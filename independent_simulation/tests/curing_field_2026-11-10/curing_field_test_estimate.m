function tests=curing_field_test_estimate
tests=functiontests(localfunctions);
end
function setupOnce(t)
td=fileparts(mfilename('fullpath')); root=fileparts(fileparts(td));
addpath(root); addpath(td); t.TestData.root=root;
end
function testUnmeasuredEstimateDoesNotClaimTime(t)
c=iceind.curing_field_cases();
e=iceind.curing_field_estimate(c(1));
verifyEqual(t,e.grid_size,[240 160 480]);
verifyEqual(t,e.grid_with_pml,[272 192 512]);
verifyEqual(t,e.pml_cells,16);
verifyTrue(t,isnan(e.projected_s));
verifyTrue(t,isnan(e.memory_bytes));
verifyEqual(t,e.gate,'unmeasured');
verifyGreaterThanOrEqual(t,e.t_end_s,40e-6);
end
function testFineGridSizesAndPointSteps(t)
c=iceind.curing_field_cases();
e=iceind.curing_field_estimate(c(3));
verifyEqual(t,e.grid_size,[300 200 600]);
verifyEqual(t,e.grid_with_pml,[340 240 640]);
verifyEqual(t,e.voxels,36e6);
dt=0.2*52e-6/1540;
verifyEqual(t,e.dt_s,dt,'RelTol',1e-12);
verifyEqual(t,e.Nt,ceil(40e-6/dt)+1);
verifyEqual(t,e.point_steps,36e6*e.Nt);
end
function testMeasuredProjectionScalesWithRate(t)
c=iceind.curing_field_cases();
a=iceind.curing_field_estimate(c(1),1e6,120);
b=iceind.curing_field_estimate(c(1),2e6,120);
verifyEqual(t,a.projected_s/a.point_steps,1e-6,'RelTol',1e-12);
verifyEqual(t,a.projected_s/b.projected_s,2,'RelTol',1e-12);
verifyEqual(t,a.memory_bytes,120*prod(a.grid_with_pml));
verifyEqual(t,a.gate,'measured_projection');
end
