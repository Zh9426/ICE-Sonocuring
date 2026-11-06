function tests=test_aperture_control
tests=functiontests(localfunctions);
end
function setupOnce(t)
root=fileparts(fileparts(mfilename('fullpath'))); addpath(root);
addpath(fullfile(root,'dependencies','k-wave-1.4.1','k-wave-toolbox-version-1.4.1'));
t.TestData.root=root;
end
function testEvenControlExactlyPreservesSavedSource(t)
old=iceind.kwave_validation_cases(); c=old(3).config;
[kg,~,s,~,m,w]=iceind.prepare_kwave_focus(c);
[kg2,~,s2,m2,w2]=iceind.prepare_aperture_control(c,'even32');
verifyEqual(t,s,s2); verifyEqual(t,w,w2); verifyEqual(t,kg.dt,kg2.dt);
verifyEqual(t,m.active_elements,m2.active_elements);
end
function testFullArrayHasAlignedArrivalsAndEqualSourceBudget(t)
old=iceind.kwave_validation_cases(); c=old(3).config;
[~,~,s,m,w]=iceind.prepare_aperture_control(c,'full64_matched');
verifyEqual(t,m.active_elements,1:64);
verifyLessThan(t,m.active_center_arrival_spread_s,1e-12);
verifyLessThan(t,abs(m.aperture_control.actual_budget_pa2_s_m2 / ...
 m.aperture_control.reference_budget_pa2_s_m2-1),1e-6);
verifyGreaterThan(t,m.aperture_control.signal_scale,0.6);
verifyLessThan(t,m.aperture_control.signal_scale,0.8);
verifyLessThan(t,m.area_error_m2,1e-12);
verifyEqual(t,size(s.p,1),nnz(s.p_mask)); verifyEqual(t,size(w,1),64);
verifyEqual(t,m.target_m,[0 0 .02],'AbsTol',1e-15);
end
