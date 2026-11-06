function tests=test_kwave_oddeven
tests=functiontests(localfunctions);
end
function setupOnce(t)
t.TestData.root=fileparts(fileparts(mfilename('fullpath')));
addpath(t.TestData.root);
addpath(fullfile(t.TestData.root,'dependencies','k-wave-1.4.1','k-wave-toolbox-version-1.4.1'));
end
function testSavedOddEvenSourceAndArrivalTimes(t)
c=iceind.kwave_focus_config();
[kg,~,src,~,meta]=iceind.prepare_kwave_focus(c);
verifyEqual(t,meta.active_elements,2:2:64);
verifyEqual(t,meta.target_m,[0 0 .02],'AbsTol',1e-14);
verifyEqual(t,meta.input_partition,'odd_imaging_even_exposure');
verifyEqual(t,meta.num_elements,64);
verifyLessThan(t,meta.area_error_m2,1e-12);
verifyLessThan(t,meta.active_center_arrival_spread_s,1e-12);
verifyEqual(t,size(src.p,1),nnz(src.p_mask));
verifyGreaterThan(t,kg.Nt,size(src.p,2));
verifyEqual(t,meta.source_model,'assumed_flat_rectangular_additive_pressure_no_lens');
end
function testRefinementKeepsDomainAndPhysicalSource(t)
c=iceind.kwave_focus_config();
[a,~,~,~,ma]=iceind.prepare_kwave_focus(c);
c.dx_m=52e-6;
[b,~,~,~,mb]=iceind.prepare_kwave_focus(c);
verifyEqual(t,[a.Nx a.Ny a.Nz]*a.dx,[b.Nx b.Ny b.Nz]*b.dx,'AbsTol',1e-12);
verifyEqual(t,ma.source_z_offset_m,mb.source_z_offset_m,'AbsTol',1e-12);
verifyEqual(t,ma.element_area_m2,mb.element_area_m2,'AbsTol',1e-12);
verifyLessThan(t,mb.area_error_m2,1e-12);
end
function testShiftedPeakIsNotCalledPrecise(t)
x=(-2:.1:2)*1e-3; y=x; z=(10:.1:30)*1e-3;
[xx,yy,zz]=ndgrid(x,y,z);
p=exp(-((xx-.3e-3)/.6e-3).^2-(yy/.8e-3).^2-((zz-.018)/.003).^2);
m=iceind.pressure_focus_metrics(p,x,y,z,[0 0 .020]);
verifyEqual(t,m.forward_peak_xyz_m,[.3e-3 0 .018],'AbsTol',1e-12);
verifyEqual(t,m.forward_peak_error_m,norm([.3e-3 0 -.002]),'AbsTol',1e-12);
verifyFalse(t,m.within_proposed_0p5mm_tolerance);
verifyEqual(t,m.width_at_forward_peak_m(1),2*.6e-3*sqrt(log(2)),'AbsTol',1e-5);
verifyFalse(t,any(m.width_clipped));
end
function testBoundaryPeakAndUnclosedWidthFlagged(t)
x=(-1:.1:1)*1e-3; y=x; z=(2:.1:4)*1e-3;
p=ones(numel(x),numel(y),numel(z));
m=iceind.pressure_focus_metrics(p,x,y,z,[0 0 .003]);
verifyTrue(t,m.forward_peak_on_boundary);
verifyTrue(t,all(m.width_clipped));
verifyTrue(t,all(isnan(m.width_at_forward_peak_m)));
end
function testEmptyTargetNeighborhoodRejected(t)
verifyError(t,@()iceind.pressure_focus_metrics(ones(3,3,3),[-1 0 1],[-1 0 1],[2 3 4],[0 0 .02]), ...
    'iceind:FocusROI');
end
