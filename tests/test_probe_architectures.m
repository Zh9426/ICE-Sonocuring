function tests = test_probe_architectures
tests = functiontests(localfunctions);
end

function setupOnce(~)
root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root,'simulation'),fullfile(root,'config'));
end

function testIndependentArraysAndMasks(t)
c = small_dual();
g = ice.make_probe_geometry(c.probe);
verifySize(t,g.positions_m,[12 3]);
verifyEqual(t,nnz(g.imaging_mask),6);
verifyEqual(t,nnz(g.curing_mask),6);
verifyFalse(t,any(g.imaging_mask & g.curing_mask));
verifyEqual(t,unique(g.subarray_id),[1;2]);
verifyEqual(t,mean(g.positions_m(g.imaging_mask,1)),-.002,'AbsTol',1e-15);
verifyEqual(t,mean(g.positions_m(g.curing_mask,1)),.002,'AbsTol',1e-15);
p = ice.partition_elements(g,c.architecture);
verifyEqual(t,p.imaging_mask,g.imaging_mask);
verifyEqual(t,p.curing_mask,g.curing_mask);
end

function testDualRejectsOverlapAndOutOfPlane(t)
c = small_dual();
c.probe.curing.offset_m=[-.002 0 0];
verifyError(t,@() ice.make_probe_geometry(c.probe),'ice:ProbeGeometry');
c = small_dual();c.probe.curing.offset_m=[.002 0 .001];
verifyError(t,@() ice.make_probe_geometry(c.probe),'ice:ProbeGeometry');
end

function testContinuousHalfPlanePartitions(t)
a = demo_config('matrix');a.array.size=[4 2];g=ice.make_geometry(a.array);
a.architecture.type='partitioned';a.architecture.curing_fraction=.5;
cases={'left_curing','right_curing','lower_curing','upper_curing'};
for i=1:numel(cases)
    a.architecture.pattern=cases{i};
    p=ice.partition_elements(g,a.architecture);
    verifyEqual(t,nnz(p.curing_mask),4);
    verifyFalse(t,any(p.curing_mask & p.imaging_mask));
    verifyTrue(t,all(p.curing_mask | p.imaging_mask));
    q=ice.partition_elements(g,a.architecture);
    verifyEqual(t,p,q);
end

a.architecture.pattern='left_curing';p=ice.partition_elements(g,a.architecture);
verifyTrue(t,all(g.positions_m(p.curing_mask,1)<0));
a.architecture.pattern='right_curing';p=ice.partition_elements(g,a.architecture);
verifyTrue(t,all(g.positions_m(p.curing_mask,1)>0));
a.architecture.pattern='lower_curing';p=ice.partition_elements(g,a.architecture);
verifyTrue(t,all(g.positions_m(p.curing_mask,2)<0));
a.architecture.pattern='upper_curing';p=ice.partition_elements(g,a.architecture);
verifyTrue(t,all(g.positions_m(p.curing_mask,2)>0));
end

function testDualEndToEndPreservesCuringApertureAndProvenance(t)
c=small_dual();
c.grid.x_m=linspace(-.003,.003,9);
c.grid.y_m=linspace(-.002,.002,7);
c.grid.z_m=linspace(.012,.018,7);
c.solver.patch_count=[2 2];
r=ice.simulate(c);
verifyEqual(t,r.drive.active_elements,6);
verifyEqual(t,nnz(r.partition.imaging_mask),6);
verifyEqual(t,r.solver_info.name,'planar_rayleigh_midpoint');
verifyEqual(t,r.solver_info.grid_spacing_m,r.grid.spacing_m);
verifyGreaterThan(t,r.reference.pressure_peak_pa,0);
verifyEqual(t,r.feasibility.status,'unknown');
end

function c = small_dual()
c = demo_config('matrix');
a=c.array;a.size=[3 2];
c.probe=struct('kind','dual_array', ...
    'imaging',struct('array',a,'offset_m',[-.002 0 0]), ...
    'curing',struct('array',a,'offset_m',[.002 0 0]));
c.array=struct('type','dual_array');
c.architecture.type='dual_array';
end
