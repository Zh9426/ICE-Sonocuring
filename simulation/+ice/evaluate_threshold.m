function metrics = evaluate_threshold(exposure, target_mask, voxel_volume_m3, threshold, source, reference)
%EVALUATE_THRESHOLD Volume-weighted exposure screening, not a cure model.
% Relative thresholds require an externally supplied common reference. The
% intensity fields are plane-progressive-wave equivalent intensities, not
% measured active energy flux in a general interference/near field.
% Pressure coverage uses the maximum shot magnitude, so it reports whether
% the level occurs in any positive-dwell shot, not how long it is sustained.

if ~islogical(target_mask) || ~iscolumn(target_mask)
    error('ice:InvalidTargetMask', 'target_mask must be an M-by-1 logical vector.');
end
n = numel(target_mask);
if ~isstruct(threshold) || ~all(isfield(threshold, {'type','scale','value'}))
    error('ice:InvalidThreshold', 'Threshold requires type, scale and value.');
end
type = textOption(threshold.type, {'pressure','intensity'}, 'ice:InvalidThreshold');
scale = textOption(threshold.scale, {'relative','absolute'}, 'ice:InvalidThreshold');
if ~validScalar(threshold.value, false)
    error('ice:InvalidThreshold', 'Threshold value must be finite, real and nonnegative.');
end
if strcmp(type, 'pressure')
    field = 'pressure_peak_pa'; units = 'Pa';
else
    if ~isfield(threshold, 'intensity_basis')
        error('ice:InvalidThreshold', 'Intensity threshold requires an explicit intensity_basis.');
    end
    basis = textOption(threshold.intensity_basis, {'pulse_average','temporal_average'}, 'ice:InvalidThreshold');
    field = ['intensity_' basis '_w_m2']; units = 'W/m^2';
end
if ~isstruct(exposure) || ~isfield(exposure,field)
    error('ice:InvalidExposure', 'Exposure is missing selected physical field %s.', field);
end
values = exposure.(field);
if ~isnumeric(values) || ~isreal(values) || ~isequal(size(values),[n 1]) || ...
        any(~isfinite(values)) || any(values < 0)
    error('ice:InvalidExposure', 'Selected exposure field must be finite, nonnegative and M-by-1.');
end
if ~isnumeric(voxel_volume_m3) || ~isreal(voxel_volume_m3) || ...
        ~(isscalar(voxel_volume_m3) || isequal(size(voxel_volume_m3), [n 1])) || ...
        any(~isfinite(voxel_volume_m3)) || any(voxel_volume_m3 <= 0)
    error('ice:InvalidVoxelVolume', 'Voxel volumes must be positive finite scalar or M-by-1 values.');
end
if isscalar(voxel_volume_m3)
    volumes = repmat(double(voxel_volume_m3), n, 1);
else
    volumes = double(voxel_volume_m3);
end
if strcmp(scale, 'relative')
    if nargin < 6 || ~isstruct(reference) || ~isfield(reference,field) || ~validScalar(reference.(field),true)
        error('ice:InvalidReference', 'Relative thresholds need a positive common reference for %s.', field);
    end
    cutoff = double(threshold.value) * double(reference.(field));
else
    if ~isstruct(source) || ~all(isfield(source, {'calibrated','calibration_note'})) || ...
            ~islogical(source.calibrated) || ~isscalar(source.calibrated) || ~source.calibrated || ...
            ~isTextScalar(source.calibration_note) || strlength(strtrim(string(source.calibration_note))) == 0
        error('ice:UncalibratedAbsoluteThreshold', ...
            'Absolute thresholds require calibrated=true and a nonempty calibration_note.');
    end
    cutoff = double(threshold.value);
end
if ~isfinite(cutoff)
    error('ice:InvalidThreshold', 'Threshold multiplication overflowed its physical units.');
end
above = values >= cutoff;
target_volume = sum(volumes(target_mask));
outside = ~target_mask;
outside_volume = sum(volumes(outside));
metrics = struct('target_coverage',NaN, 'off_target_exposure',NaN, ...
    'target_uniformity_cv',NaN, 'target_mean',NaN, ...
    'target_volume_m3',target_volume, 'off_target_volume_m3',outside_volume, ...
    'above_threshold_volume_m3',sum(volumes(above)), 'threshold_value_si',cutoff, ...
    'threshold_units',units, 'threshold_mask',above, 'selected_field',field);
metrics.status = struct('target_coverage','empty_target', ...
    'off_target_exposure','empty_off_target', 'target_uniformity_cv','empty_target', ...
    'target_mean','empty_target');
if target_volume > 0
    metrics.target_coverage = sum(volumes(target_mask & above)) / target_volume;
    metrics.status.target_coverage = 'ok';
    weights = volumes(target_mask) / target_volume;
    target_values = double(values(target_mask));
    mu = sum(weights .* target_values);
    metrics.target_mean = mu;
    metrics.status.target_mean = 'ok';
    if mu > 0
        % Scale before squaring to avoid unnecessary overflow in physical units.
        metrics.target_uniformity_cv = sqrt(sum(weights .* (target_values / mu - 1).^2));
        metrics.status.target_uniformity_cv = 'ok';
    else
        metrics.status.target_uniformity_cv = 'zero_target_mean';
    end
end
if outside_volume > 0
    metrics.off_target_exposure = sum(volumes(outside & above)) / outside_volume;
    metrics.status.off_target_exposure = 'ok';
end
metrics.interpretation = 'Threshold crossing is an exposure-screening proxy and does not establish cure.';
end

function tf = validScalar(value, positive)
tf = isnumeric(value) && isreal(value) && isscalar(value) && isfinite(value);
if tf
    if positive, tf = value > 0; else, tf = value >= 0; end
end
end

function tf = isTextScalar(value)
tf = (ischar(value) && (isrow(value) || isempty(value))) || (isstring(value) && isscalar(value) && ~ismissing(value));
end

function value = textOption(raw, allowed, id)
if ~isTextScalar(raw) || ~any(strcmp(char(raw), allowed))
    error(id, 'Expected one of: %s.', strjoin(allowed, ', '));
end
value = char(raw);
end
