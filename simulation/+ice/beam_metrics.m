function metrics = beam_metrics(axis_m, amplitude, main_center_m)
%BEAM_METRICS Connected -6 dB amplitude width and scoped secondary peaks.
% The local maximum nearest main_center_m defines the selected main peak.
% Width is interpolated in linear amplitude at 10^(-6/20) of that peak.
% Secondary peak is the maximum sampled amplitude outside the nearest
% interior minima bracketing the main peak. Without both minima it is NaN.
% A secondary peak alone is not evidence of a grating lobe.

if ~isnumeric(axis_m) || ~isreal(axis_m) || ~isvector(axis_m) || ...
        numel(axis_m) < 2 || any(~isfinite(axis_m)) || ...
        ~isnumeric(amplitude) || ~isreal(amplitude) || ~isvector(amplitude) || ...
        numel(amplitude) ~= numel(axis_m) || any(~isfinite(amplitude)) || any(amplitude < 0) || ...
        ~isnumeric(main_center_m) || ~isreal(main_center_m) || ~isscalar(main_center_m) || ~isfinite(main_center_m)
    error('ice:InvalidBeamProfile', 'Provide finite matching vectors, nonnegative amplitude, and a finite scalar center.');
end
x = double(axis_m(:)); a = double(amplitude(:));
if any(diff(x) <= 0)
    error('ice:InvalidBeamProfile', 'Profile coordinates must be strictly increasing.');
end
metrics = struct('width_6db_m',NaN, 'main_peak',max(a), 'main_peak_position_m',NaN, ...
    'secondary_peak_db',NaN, 'secondary_peak_available',false, ...
    'secondary_peak_status','unbracketed_main_lobe', 'secondary_peak_at_boundary',false, ...
    'left_boundary_truncated',false, 'right_boundary_truncated',false, ...
    'main_lobe_bounds_m',[NaN NaN], 'crossings_6db_m',[NaN NaN], 'status','ok');
if max(a) == 0
    metrics.status = 'zero_field';
    metrics.secondary_peak_status = 'zero_field';
    return;
end
[maxima, minima] = extrema(a);
if isempty(maxima)
    maxima = find(a == max(a));
end
[~, nearest] = min(abs(x(maxima) - main_center_m));
peak_index = maxima(nearest);
metrics.main_peak = a(peak_index);
metrics.main_peak_position_m = x(peak_index);
level = a(peak_index) * 10^(-6/20);
left = find(a(1:peak_index) <= level, 1, 'last');
right_relative = find(a(peak_index:end) <= level, 1, 'first');
if isempty(left)
    metrics.left_boundary_truncated = true;
else
    metrics.crossings_6db_m(1) = interpolate(x(left), a(left), x(left+1), a(left+1), level);
end
if isempty(right_relative)
    metrics.right_boundary_truncated = true;
else
    right = peak_index + right_relative - 1;
    metrics.crossings_6db_m(2) = interpolate(x(right-1), a(right-1), x(right), a(right), level);
end
if ~metrics.left_boundary_truncated && ~metrics.right_boundary_truncated
    metrics.width_6db_m = diff(metrics.crossings_6db_m);
else
    metrics.status = 'width_truncated';
end
left_minimum = minima(find(minima < peak_index, 1, 'last'));
right_minimum = minima(find(minima > peak_index, 1, 'first'));
if ~isempty(left_minimum) && ~isempty(right_minimum)
    metrics.main_lobe_bounds_m = [x(left_minimum) x(right_minimum)];
    outside = [1:left_minimum-1, right_minimum+1:numel(a)];
    [secondary, i] = max(a(outside));
    metrics.secondary_peak_db = 20*log10(secondary / a(peak_index));
    metrics.secondary_peak_available = true;
    metrics.secondary_peak_status = 'ok';
    metrics.secondary_peak_at_boundary = ismember(outside(i), [1 numel(a)]);
    if metrics.secondary_peak_at_boundary
        metrics.secondary_peak_db = NaN;
        metrics.secondary_peak_available = false;
        metrics.secondary_peak_status = 'secondary_peak_truncated';
    end
end
end

function [maxima, minima] = extrema(a)
% Treat a flat run as one extremum at its central sample. Endpoints may be
% maxima, but never bracketing minima because the field beyond is unknown.
run_starts = [1; find(diff(a) ~= 0) + 1];
run_ends = [run_starts(2:end)-1; numel(a)];
maxima = zeros(0,1); minima = zeros(0,1);
for k = 1:numel(run_starts)
    first = run_starts(k); last = run_ends(k);
    mid = floor((first+last)/2);
    left_lower = first == 1 || a(first-1) < a(first);
    right_lower = last == numel(a) || a(last+1) < a(last);
    if left_lower && right_lower
        maxima(end+1,1) = mid; %#ok<AGROW>
    elseif first > 1 && last < numel(a) && a(first-1) > a(first) && a(last+1) > a(last)
        minima(end+1,1) = mid; %#ok<AGROW>
    end
end
end

function x_cross = interpolate(x1,a1,x2,a2,level)
x_cross = x1 + (level-a1)*(x2-x1)/(a2-a1);
end
