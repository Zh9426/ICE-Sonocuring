function tests=curing_field_test_metrics
tests=functiontests(localfunctions);
end
function setupOnce(t)
td=fileparts(mfilename('fullpath')); root=fileparts(fileparts(td));
addpath(root); addpath(td); t.TestData.root=root;
end
function testGaussianFocusMetricsAndExplicitSixDb(t)
x=(-4:0.1:4)*1e-3; y=(-3:0.1:3)*1e-3; z=(0:0.1:30)*1e-3;
[X,Y,Z]=ndgrid(x,y,z); sig=1e-3;
p=exp(-(X.^2+Y.^2+(Z-20e-3).^2)/(2*sig^2));
p=p+0.8*exp(-(X.^2+Y.^2+(Z-0.5e-3).^2)/(2*(0.4e-3)^2));
p=p+0.3*exp(-((X-3e-3).^2+Y.^2+(Z-10e-3).^2)/(2*(0.8e-3)^2));
m=iceind.curing_field_metrics(p,x,y,z,[0 0 20]*1e-3,0.1e-3);
verifyEqual(t,m.six_db_threshold_db,-6,'AbsTol',1e-12);
verifyEqual(t,m.six_db_threshold_pa,10^(-6/20)*m.forward_peak_pa_assumed,'AbsTol',1e-12);
verifyEqual(t,m.target_peak_xyz_m,[0 0 20e-3],'AbsTol',0.2e-3);
verifyEqual(t,m.outside_target_peak_xyz_m,[3e-3 0 10e-3],'AbsTol',0.2e-3);
verifyLessThan(t,norm(m.forward_peak_xyz_m-[0 0 20e-3]),0.2e-3);
verifyTrue(t,~m.forward_peak_on_boundary);
verifyEqual(t,m.six_db_widths_m(1),2.3548e-3,'AbsTol',0.15e-3);
verifyEqual(t,m.six_db_widths_m(3),2.3548e-3,'AbsTol',0.15e-3);
verifyTrue(t,all(~m.six_db_width_clipped));
analytic=4/3*pi*(sqrt(2*log(2))*1e-3)^3;
verifyEqual(t,m.six_db_volume_m3,analytic,'RelTol',0.2);
verifyGreaterThan(t,m.six_db_fraction_inside_target_box,0.95);
verifyEqual(t,m.shallow_0_2mm_over_forward_peak,0.8,'AbsTol',0.05);
verifyLessThan(t,m.shallow_2_5mm_over_forward_peak,0.02);
verifyEqual(t,m.outside_over_target_peak,0.3,'AbsTol',0.05);
verifyEqual(t,m.axis_peak_z_m,20e-3,'AbsTol',0.2e-3);
verifyEqual(t,m.target_plane_peak_xy_m,[0 0],'AbsTol',1e-12);
verifyTrue(t,contains(m.six_db_definition,'-6 dB'));
verifyTrue(t,contains(m.not_acoustic_energy,'not deposited energy'));
end
function testPeakOnForwardRoiBoundaryIsFlaggedAndClipped(t)
x=(-4:0.1:4)*1e-3; y=(-3:0.1:3)*1e-3; z=(0:0.1:30)*1e-3;
[X,Y,Z]=ndgrid(x,y,z);
p=exp(-(X.^2+Y.^2+(Z-2e-3).^2)/(2*(0.5e-3)^2));
m=iceind.curing_field_metrics(p,x,y,z,[0 0 20]*1e-3,0.1e-3);
verifyTrue(t,m.forward_peak_on_boundary);
verifyTrue(t,m.six_db_region_touches_forward_boundary);
verifyTrue(t,isnan(m.six_db_widths_m(3)));
end
function testTargetPeakIsDistinctFromHigherOffTargetPeak(t)
x=(-5:0.2:5)*1e-3; y=(-3:0.2:3)*1e-3; z=(0:0.2:30)*1e-3;
[X,Y,Z]=ndgrid(x,y,z);
p=exp(-(X.^2+Y.^2+(Z-20e-3).^2)/(2*(.6e-3)^2));
p=p+2*exp(-((X-3e-3).^2+Y.^2+(Z-10e-3).^2)/(2*(.4e-3)^2));
m=iceind.curing_field_metrics(p,x,y,z,[0 0 20]*1e-3,.2e-3);
verifyEqual(t,m.target_peak_xyz_m,[0 0 20e-3],'AbsTol',.2e-3);
verifyEqual(t,m.outside_target_peak_xyz_m,[3e-3 0 10e-3],'AbsTol',.2e-3);
verifyLessThan(t,m.target_peak_error_to_target_m,.2e-3);
verifyTrue(t,all(isfinite(m.target_peak_widths_m)));
verifyEqual(t,m.target_point_over_target_peak,1,'AbsTol',1e-10);
end
function testZeroTargetAndZeroOutsideHaveUndefinedPeakLocation(t)
x=(-4:1:4)*1e-3;y=(-3:1:3)*1e-3;z=(0:1:30)*1e-3;
p=zeros(numel(x),numel(y),numel(z));
p(x==3e-3,y==0,z==10e-3)=1;
m=iceind.curing_field_metrics(p,x,y,z,[0 0 20]*1e-3,1e-3);
verifyTrue(t,m.target_peak_is_zero);verifyTrue(t,all(isnan(m.target_peak_xyz_m)));
verifyTrue(t,isnan(m.outside_over_target_peak));verifyTrue(t,isnan(m.target_point_over_target_peak));
p(:)=0;p(x==0,y==0,z==20e-3)=1;
m=iceind.curing_field_metrics(p,x,y,z,[0 0 20]*1e-3,1e-3);
verifyTrue(t,m.outside_peak_is_zero);verifyTrue(t,all(isnan(m.outside_target_peak_xyz_m)));
end
function testRejectsNegativeOrNonFiniteField(t)
x=(-2:0.1:2)*1e-3; y=0; z=(0:0.1:30)*1e-3;
p=zeros(numel(x),1,numel(z)); p(1)= -1;
verifyError(t,@()iceind.curing_field_metrics(p,x,y,z,[0 0 20]*1e-3,0.1e-3), ...
    'iceind:CuringField');
p(1)=NaN;
verifyError(t,@()iceind.curing_field_metrics(p,x,y,z,[0 0 20]*1e-3,0.1e-3), ...
    'iceind:CuringField');
end
function testRejectsZeroForwardField(t)
x=(-2:1:2)*1e-3; y=(-2:1:2)*1e-3; z=(0:1:30)*1e-3;
p=zeros(numel(x),numel(y),numel(z));
verifyError(t,@()iceind.curing_field_metrics(p,x,y,z,[0 0 20]*1e-3,1e-3), ...
    'iceind:CuringField');
end
