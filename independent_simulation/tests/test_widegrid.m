function tests=test_widegrid
tests=functiontests(localfunctions);
end
function setupOnce(t)
root=fileparts(fileparts(mfilename('fullpath'))); addpath(root);
addpath(fullfile(root,'dependencies','k-wave-1.4.1','k-wave-toolbox-version-1.4.1'));
t.TestData.root=root;
end
function testFineGridPreservesPhysicalDomainAndPML(t)
a=iceind.widegrid_cases(); old=iceind.kwave_validation_cases();
verifyEqual(t,{a.kind},{'even32','full64_matched'});
for j=1:2
 verifyEqual(t,a(j).config.domain_m,old(3).config.domain_m);
 verifyEqual(t,a(j).config.pml_m,old(3).config.pml_m);
 verifyEqual(t,a(j).config.dx_m,52e-6);
 verifyEqual(t,round(a(j).config.domain_m/a(j).config.dx_m),[300 200 600]);
 verifyEqual(t,a(j).reference_budget_pa2_s_m2,1.1509677686634e-11,'RelTol',1e-10);
end
end
function testFineSourcesMatchCoarseBudgetAndCoverGeometry(t)
a=iceind.widegrid_cases();
for j=1:2
 [kg,~,src,m,w]=iceind.prepare_widegrid(a(j));
 actual=m.element_area_m2*kg.dt*sum(double(w).^2,'all');
 verifyLessThan(t,abs(actual/a(j).reference_budget_pa2_s_m2-1),1e-6);
 verifyLessThan(t,m.area_error_m2,1e-12);
 verifyLessThan(t,m.active_center_arrival_spread_s,1e-12);
 verifyEqual(t,numel(m.active_elements),32*j);
 verifyEqual(t,size(src.p,1),nnz(src.p_mask));
 [~,tm]=iceind.offaxis_sensor(kg,m.source_z_kgrid_m);
 verifyLessThanOrEqual(t,max(abs(tm.actual_xyz_m-tm.requested_xyz_m),[],'all'),26e-6+1e-12);
end
end
function testProbeGateAcceptsJSONVectorOrientation(t)
p=struct('grid_with_pml',[340 240 640],'gpu','testGPU', ...
 'available_gpu_bytes_before',7e9,'Nt',128,'solver','kspaceFirstOrder3D');
p=jsondecode(jsonencode(p));
verifyTrue(t,iceind.widegrid_probe_matches(p,[300 200 600],20,'testGPU',7e9));
end
function testProbeGateRejectsChangedMemoryOrGrid(t)
p=struct('grid_with_pml',[340 240 640],'gpu','testGPU', ...
 'available_gpu_bytes_before',7e9,'Nt',128,'solver','kspaceFirstOrder3D');
verifyFalse(t,iceind.widegrid_probe_matches(p,[300 200 600],20,'otherGPU',7e9));
verifyFalse(t,iceind.widegrid_probe_matches(p,[300 200 600],20,'testGPU',6e9));
verifyFalse(t,iceind.widegrid_probe_matches(p,[301 200 600],20,'testGPU',7e9));
end
