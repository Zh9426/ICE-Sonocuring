function tests=test_kwave_singlepoint_validation
tests=functiontests(localfunctions);
end
function setupOnce(t)
root=fileparts(fileparts(mfilename('fullpath'))); addpath(root);
addpath(fullfile(root,'dependencies','k-wave-1.4.1','k-wave-toolbox-version-1.4.1'));
t.TestData.root=root;
end
function testCasesChangeOnePhysicalControl(t)
cases=iceind.kwave_validation_cases();
verifyEqual(t,{cases.tag},{'baseline65','pml65','wide65','long65','fine52'});
a=cases(1).config;
verifyEqual(t,cases(2).config.domain_m,a.domain_m);
verifyGreaterThan(t,cases(2).config.pml_m,a.pml_m);
verifyEqual(t,cases(3).config.domain_m(3),a.domain_m(3));
verifyEqual(t,cases(4).config.domain_m(1:2),a.domain_m(1:2));
verifyEqual(t,cases(5).config.domain_m,a.domain_m);
verifyEqual(t,cases(5).config.dx_m,52e-6,'AbsTol',1e-15);
verifyEqual(t,[cases.minimum_end_time_s],repmat(40e-6,1,5));
for k=1:numel(cases)
 verifyEqual(t,cases(k).config.input_mat,a.input_mat);
 verifyEqual(t,cases(k).config.source_amplitude_pa,a.source_amplitude_pa);
 verifyEqual(t,cases(k).config.cfl,a.cfl);
end
end
function testKnownExposurePartitionAndOutsidePeak(t)
x=(-2:2)*1e-3; y=x; z=(18:22)*1e-3;
qp=ones(5,5,5); qp(3,3,3)=4; qp(1,3,3)=8;
p=sqrt(qp); roi=[-2 2;-2 2;18 22]*1e-3;
m=iceind.pressure_exposure_metrics(qp,p,x,y,z,[0 0 .02],[.4 .4 .4]*1e-3,roi);
verifyEqual(t,m.target_voxels,1);
verifyEqual(t,m.material_voxels,125);
verifyEqual(t,m.target_qp_integral_pa2_s_m3,4e-9,'AbsTol',1e-20);
verifyEqual(t,m.target_qp_fraction_of_material,4/135,'AbsTol',1e-12);
verifyEqual(t,m.outside_over_target_max_qp,2);
verifyEqual(t,m.outside_max_xyz_m,[-.002 0 .02],'AbsTol',1e-15);
verifyFalse(t,m.target_clipped); verifyFalse(t,m.material_clipped);
verifyEqual(t,m.target_relative_halfmax_coverage,1);
end
function testClippedTargetIsReported(t)
x=(-2:2)*1e-3; z=(18:22)*1e-3; q=ones(5,5,5);
m=iceind.pressure_exposure_metrics(q,q,x,x,z,[0 0 .02],[3 1 1]*1e-3, ...
 [-2 2;-2 2;18 22]*1e-3);
verifyTrue(t,m.target_clipped);
verifyFalse(t,m.material_clipped);
verifyError(t,@()iceind.pressure_exposure_metrics(q,q,x,x,z,[0 0 .05],[1 1 1]*1e-3, ...
 [-2 2;-2 2;18 22]*1e-3),'iceind:ExposureROI');
end
function testRejectNonphysicalProxy(t)
x=(-2:2)*1e-3; z=(18:22)*1e-3; q=ones(5,5,5); q(1)=-1;
verifyError(t,@()iceind.pressure_exposure_metrics(q,abs(q),x,x,z,[0 0 .02], ...
 [1 1 1]*1e-3,[-2 2;-2 2;18 22]*1e-3),'iceind:ExposureField');
end
function testUnilluminatedTargetCannotReportFullCoverage(t)
x=(-2:2)*1e-3; z=(18:22)*1e-3; q=zeros(5,5,5);
roi=[-2 2;-2 2;18 22]*1e-3;
verifyError(t,@()iceind.pressure_exposure_metrics(q,q,x,x,z,[0 0 .02], ...
 [.4 .4 .4]*1e-3,roi),'iceind:ExposureField');
q(:)=1; q(3,3,3)=0;
verifyError(t,@()iceind.pressure_exposure_metrics(q,sqrt(q),x,x,z,[0 0 .02], ...
 [.4 .4 .4]*1e-3,roi),'iceind:ExposureField');
end
function testRmsIntegralAgreesWithTimeSamples(t)
% Independent k-Wave check of Qp conversion and all-mask linear indexing.
kg=kWaveGrid(12,1e-4,10,1e-4,16,1e-4); kg.setTime(85,1e-8);
medium=struct('sound_speed',1500,'density',1000);
source.p_mask=false(12,10,16); source.p_mask(6,5,4)=true;
source.p=single(sin(2*pi*1e6*(0:19)*kg.dt));
sensor.mask=true(12,10,16); sensor.record={'p','p_rms','p_max_all','p_min_all'};
d=kspaceFirstOrder3D(kg,medium,source,sensor,'PMLInside',false,'PMLSize',4, ...
 'PlotSim',false,'DataCast','single');
qp=iceind.rms_to_qp(d.p_rms,kg.dt,kg.Nt);
direct=sum(double(d.p).^2,2)*kg.dt;
verifyLessThan(t,norm(qp-direct)/norm(direct),2e-6);
verifyEqual(t,reshape(max(abs(d.p),[],2),12,10,16), ...
 max(abs(d.p_max_all),abs(d.p_min_all)),'AbsTol',single(1e-6));
verifyError(t,@()iceind.rms_to_qp(d.p_rms,kg.dt,0),'iceind:ExposureTime');
end
