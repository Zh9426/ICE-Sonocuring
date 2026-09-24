function m = acoustic_safety_metrics(exposure, grid, target_mask, target, threshold_metrics, sequence)
%ACOUSTIC_SAFETY_METRICS Sampled-ROI acoustic exposure screening only.
% Pre/post regions exclude the target axial slab: z<z0-rz or z>z0+rz.
% This cannot establish tissue safety or absence of peaks outside the ROI.
required={'pressure_peak_pa','intensity_temporal_average_w_m2'};
if ~isstruct(exposure) || ~all(isfield(exposure,required)) || ...
        ~isstruct(grid) || ~all(isfield(grid,{'points_m','voxel_volume_m3'})) || ...
        ~isstruct(target) || ~all(isfield(target,{'center_m','radii_m'})) || ...
        ~isstruct(threshold_metrics) || ~all(isfield(threshold_metrics, ...
        {'threshold_mask','selected_field','threshold_value_si'})) || ...
        ~isstruct(sequence) || ~isfield(sequence,'shots')
    error('ice:SafetyMetrics','Missing exposure, grid, target, threshold or sequence fields.');
end
points=grid.points_m;n=size(points,1);
p=exposure.pressure_peak_pa;ita=exposure.intensity_temporal_average_w_m2;
above=threshold_metrics.threshold_mask;
if ~isnumeric(points) || ~isreal(points) || ~isequal(size(points),[n 3]) || ...
        any(~isfinite(points(:))) || ~islogical(target_mask) || ...
        ~isequal(size(target_mask),[n 1]) || ~islogical(above) || ...
        ~isequal(size(above),[n 1]) || ...
        ~valid_field(p,n) || ~valid_field(ita,n) || ...
        ~isnumeric(grid.voxel_volume_m3) || ~isscalar(grid.voxel_volume_m3) || ...
        ~isfinite(grid.voxel_volume_m3) || grid.voxel_volume_m3<=0 || ...
        ~isnumeric(target.center_m) || ~isequal(size(target.center_m),[1 3]) || ...
        ~isnumeric(target.radii_m) || ~isequal(size(target.radii_m),[1 3]) || ...
        any(~isfinite([target.center_m,target.radii_m])) || any(target.radii_m<=0)
    error('ice:SafetyMetrics','Inconsistent finite ROI, mask or field dimensions.');
end
outside=~target_mask;
z0=target.center_m(3);rz=target.radii_m(3);
pre=outside & points(:,3)<z0-rz;
post=outside & points(:,3)>z0+rz;
m=struct();
m.off_target_max_pressure_pa=region_max(p,outside);
m.off_target_max_intensity_ta_w_m2=region_max(ita,outside);
m.prefocal_max_pressure_pa=region_max(p,pre);
m.postfocal_max_pressure_pa=region_max(p,post);
m.prefocal_max_intensity_ta_w_m2=region_max(ita,pre);
m.postfocal_max_intensity_ta_w_m2=region_max(ita,post);
m.off_target_above_threshold_volume_m3=region_volume(outside,above,grid.voxel_volume_m3);
m.prefocal_above_threshold_volume_m3=region_volume(pre,above,grid.voxel_volume_m3);
m.postfocal_above_threshold_volume_m3=region_volume(post,above,grid.voxel_volume_m3);
m.target_to_off_target_peak_pressure_ratio=NaN;
target_peak=region_max(p,target_mask);
if isfinite(target_peak) && isfinite(m.off_target_max_pressure_pa) && ...
        m.off_target_max_pressure_pa>0
    m.target_to_off_target_peak_pressure_ratio=target_peak/m.off_target_max_pressure_pa;
end
m.focus_peak_position_m=[NaN NaN NaN];
m.focus_position_error_m=NaN;
m.status=struct('off_target',region_status(outside), ...
    'prefocal',region_status(pre),'postfocal',region_status(post), ...
    'focus_position','unavailable');
if numel(sequence.shots)~=1
    m.status.focus_position='sequential_scan';
elseif ~any(target_mask)
    m.status.focus_position='empty_target';
elseif target_peak<=0
    m.status.focus_position='zero_target_field';
elseif ~isfield(sequence.shots,'focus_m') || ...
        ~isequal(size(sequence.shots.focus_m),[1 3]) || ...
        any(~isfinite(sequence.shots.focus_m))
    m.status.focus_position='no_nominal_focus';
else
    indices=find(target_mask);
    [~,local]=max(p(indices));
    m.focus_peak_position_m=points(indices(local),:);
    m.focus_position_error_m=norm(m.focus_peak_position_m-sequence.shots.focus_m);
    m.status.focus_position='sampled_target_peak';
end
m.interpretation='Acoustic exposure screening within sampled ROI; no cure or safety prediction.';
end

function tf=valid_field(v,n)
tf=isnumeric(v) && isreal(v) && isequal(size(v),[n 1]) && ...
    all(isfinite(v)) && all(v>=0);
end

function value=region_max(v,mask)
value=NaN;
if any(mask),value=max(v(mask));end
end

function value=region_volume(mask,above,volume)
value=NaN;
if any(mask),value=nnz(mask & above)*volume;end
end

function status=region_status(mask)
status='ok';
if ~any(mask),status='empty_roi';end
end
