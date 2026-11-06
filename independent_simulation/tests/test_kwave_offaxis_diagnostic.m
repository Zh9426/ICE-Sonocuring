function tests=test_kwave_offaxis_diagnostic
tests=functiontests(localfunctions);
end
function setupOnce(t)
root=fileparts(fileparts(mfilename('fullpath'))); addpath(root);
addpath(fullfile(root,'dependencies','k-wave-1.4.1','k-wave-toolbox-version-1.4.1'));
t.TestData.root=root;
end
function testControlledBoundaryChanges(t)
cases=iceind.kwave_offaxis_cases(); old=iceind.kwave_validation_cases(); old=old(3).config;
verifyEqual(t,{cases.tag},{'wide_pml20','wider_x256'});
verifyEqual(t,cases(1).config.domain_m,old.domain_m);
verifyEqual(t,cases(1).config.pml_m,1.30e-3,'AbsTol',1e-15);
verifyEqual(t,cases(2).config.domain_m,[16.64 10.4 31.2]*1e-3,'AbsTol',1e-15);
verifyEqual(t,cases(2).config.pml_m,old.pml_m);
for j=1:2
 c=cases(j).config;
 verifyEqual(t,c.dx_m,old.dx_m); verifyEqual(t,c.input_mat,old.input_mat);
 verifyEqual(t,c.source_offset_m,old.source_offset_m);
 verifyEqual(t,c.source_amplitude_pa,old.source_amplitude_pa);
 verifyEqual(t,c.cfl,old.cfl); verifyEqual(t,cases(j).minimum_end_time_s,40e-6);
end
end
function testTraceRowsHavePhysicalCoordinateMapping(t)
kg=kWaveGrid(240,65e-6,160,65e-6,480,65e-6);
sourceZ=kg.z_vec(9); [sensor,m]=iceind.offaxis_sensor(kg,sourceZ);
verifyEqual(t,nnz(sensor.mask),12);
verifyEqual(t,size(m.actual_xyz_m),[12 3]);
verifyLessThanOrEqual(t,max(abs(m.actual_xyz_m-m.requested_xyz_m),[],'all'),65e-6/2+1e-14);
ids=find(sensor.mask); [x,y,z]=ind2sub(size(sensor.mask),ids(m.trace_row));
verifyEqual(t,[kg.x_vec(x),kg.y_vec(y),kg.z_vec(z)-sourceZ],m.actual_xyz_m,'AbsTol',1e-14);
verifyEqual(t,m.actual_xyz_m(strcmp(m.labels,'offaxis_pos'),:),[6.37 0 2.015]*1e-3,'AbsTol',1e-14);
verifyEqual(t,sensor.record,{'p','p_rms','p_max_all','p_min_all'});
end
function testBoundaryChangesPreserveSourceAndTraceLocations(t)
cases=iceind.kwave_offaxis_cases();
[kg,~,source,~,meta]=iceind.prepare_kwave_focus(cases(1).config);
[~,a]=iceind.offaxis_sensor(kg,meta.source_z_kgrid_m);
[kg2,~,source2,~,meta2]=iceind.prepare_kwave_focus(cases(2).config);
[~,b]=iceind.offaxis_sensor(kg2,meta2.source_z_kgrid_m);
verifyEqual(t,source.p,source2.p); verifyEqual(t,meta.input_sha256,meta2.input_sha256);
verifyEqual(t,meta.active_elements,meta2.active_elements);
verifyEqual(t,a.actual_xyz_m,b.actual_xyz_m,'AbsTol',1e-14);
end
function testDirectIntegralPrimaryAndRmsDiagnostic(t)
p=[1 2 0;0 -3 4]; dt=1e-8;
expected=[5;25]*dt; rms=sqrt(expected/(3*dt));
[q,a]=iceind.trace_integral_audit(p,rms'*(1-6e-5),dt,3);
verifyEqual(t,q,expected,'AbsTol',1e-20);
verifyTrue(t,a.rms_consistency_passed);
verifyLessThan(t,a.rms_direct_relative_l2,1e-3);
[q,a]=iceind.trace_integral_audit(p,rms*1.01,dt,3);
verifyEqual(t,q,expected,'AbsTol',1e-20);
verifyFalse(t,a.rms_consistency_passed);
end
