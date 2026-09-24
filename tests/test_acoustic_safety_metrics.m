function tests = test_acoustic_safety_metrics
tests = functiontests(localfunctions);
end

function setupOnce(~)
root=fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root,'simulation'));
end

function testPrePostAndOffTargetVolumes(t)
g=ice.make_grid(struct('x_m',[-1 1]*1e-3,'y_m',[-1 1]*1e-3, ...
    'z_m',[10 12 14 16 18]*1e-3));
n=size(g.points_m,1);z=g.points_m(:,3);target=abs(z-.014)<1e-10;
p=4*ones(n,1);p(abs(z-.010)<1e-10)=5;
p(abs(z-.012)<1e-10)=5;
p(abs(z-.014)<1e-10)=20;
p(abs(z-.016)<1e-10)=10;
p(abs(z-.018)<1e-10)=10;
e=struct('pressure_peak_pa',p,'intensity_temporal_average_w_m2',p.^2);
th=struct('threshold_mask',p>=8,'selected_field','pressure_peak_pa','threshold_value_si',8);
goal=struct('center_m',[0 0 .014],'radii_m',[.002 .002 .0005]);
seq=struct('shots',struct('focus_m',[0 0 .014]));
m=ice.acoustic_safety_metrics(e,g,target,goal,th,seq);
verifyEqual(t,m.off_target_max_pressure_pa,10);
verifyEqual(t,m.prefocal_max_pressure_pa,5);
verifyEqual(t,m.postfocal_max_pressure_pa,10);
verifyEqual(t,m.off_target_max_intensity_ta_w_m2,100);
verifyEqual(t,m.target_to_off_target_peak_pressure_ratio,2);
verifyEqual(t,m.prefocal_above_threshold_volume_m3,0);
verifyEqual(t,m.postfocal_above_threshold_volume_m3,8*g.voxel_volume_m3);
verifyEqual(t,m.off_target_above_threshold_volume_m3,8*g.voxel_volume_m3);
verifyEqual(t,m.focus_position_error_m,sqrt(2)*1e-3,'AbsTol',1e-12);
end

function testEmptyRegionAndSequentialFocusUnavailable(t)
g=ice.make_grid(struct('x_m',[-1 1]*1e-3,'y_m',[-1 1]*1e-3, ...
    'z_m',[14 16 18]*1e-3));
n=size(g.points_m,1);target=abs(g.points_m(:,3)-.014)<1e-10;
e=struct('pressure_peak_pa',ones(n,1),'intensity_temporal_average_w_m2',ones(n,1));
th=struct('threshold_mask',false(n,1),'selected_field','pressure_peak_pa','threshold_value_si',2);
goal=struct('center_m',[0 0 .014],'radii_m',[.002 .002 .0005]);
seq=struct('shots',repmat(struct('focus_m',[0 0 .014]),1,2));
m=ice.acoustic_safety_metrics(e,g,target,goal,th,seq);
verifyTrue(t,isnan(m.prefocal_max_pressure_pa));
verifyEqual(t,m.status.prefocal,'empty_roi');
verifyTrue(t,isnan(m.focus_position_error_m));
verifyEqual(t,m.status.focus_position,'sequential_scan');
end
