function Trans = make_trans(probe, sound_speed_m_s)
%MAKE_TRANS Working-source linear geometry; synthetic matrix dispatch retained.
% Dimensions supplied in mm are converted to wavelengths of frequency_mhz.
% Existing-code parameters are unverified; this function does not identify a
% physical probe, resolve UTA wiring, or calibrate acoustic output.
%
% Reference: D00163 Rev. K, p.22 and section 13.1, pp.107-111;
% VantageNXT-2.3.2-p2/Utilities/computeTrans.m (P9-4ULts and ElementSens).
% ConnectorES is explicitly supplied, never inferred from element count.

if isfield(probe,'type') && strcmp(probe.type,'matrix')
    Trans=icevs.matrix_trans(probe,sound_speed_m_s);
    return
end
required = {'name','num_elements','frequency_mhz','bandwidth_mhz', ...
    'pitch_mm','width_mm','elevation_aperture_mm','elevation_focus_mm', ...
    'positions_mm','connector_es','conn_type','impedance_ohm', ...
    'max_high_voltage_v','lens_correction_mm','id','provenance'};
if ~isstruct(probe) || ~isscalar(probe) || ~all(isfield(probe,required))
    error('icevs:Probe','probe must be a scalar structure containing every required probe field.');
end
if ~nonempty_text(probe.name) || ~nonempty_text(probe.provenance)
    error('icevs:Probe','name and provenance must be nonempty text scalars.');
end
positiveFields = {'num_elements','frequency_mhz','pitch_mm','width_mm', ...
    'elevation_aperture_mm','elevation_focus_mm','impedance_ohm','max_high_voltage_v'};
for k = 1:numel(positiveFields)
    value = probe.(positiveFields{k});
    if ~finite_scalar(value) || value <= 0
        error('icevs:Probe','%s must be a finite positive real scalar.',positiveFields{k});
    end
end
if probe.num_elements ~= fix(probe.num_elements)
    error('icevs:Probe','num_elements must be a positive integer.');
end
if probe.width_mm > probe.pitch_mm
    error('icevs:Probe','width_mm must not exceed pitch_mm.');
end
if ~finite_scalar(sound_speed_m_s) || sound_speed_m_s <= 0
    error('icevs:Probe','sound_speed_m_s must be a finite positive real scalar.');
end
bandwidth = probe.bandwidth_mhz;
if ~finite_real(bandwidth) || ~isvector(bandwidth) || numel(bandwidth) ~= 2 || ...
        bandwidth(1) <= 0 || bandwidth(2) <= bandwidth(1) || ...
        probe.frequency_mhz < bandwidth(1) || probe.frequency_mhz > bandwidth(2)
    error('icevs:Probe','bandwidth_mhz must be [low high] > 0 and contain frequency_mhz.');
end
if ~finite_scalar(probe.conn_type) || probe.conn_type < 1 || probe.conn_type ~= fix(probe.conn_type)
    error('icevs:Probe','conn_type must be an explicitly supplied positive integer.');
end
if ~finite_scalar(probe.id) || probe.id < -1 || probe.id ~= fix(probe.id)
    error('icevs:Probe','id must be -1 or a nonnegative integer; -1 skips identification.');
end
if ~finite_scalar(probe.lens_correction_mm) || probe.lens_correction_mm < 0
    error('icevs:Probe','lens_correction_mm must be finite and nonnegative.');
end

n = double(probe.num_elements);
mapping = probe.connector_es;
if ~finite_real(mapping) || ~isvector(mapping) || numel(mapping) ~= n || ...
        any(mapping(:) <= 0) || any(mapping(:) ~= fix(mapping(:))) || numel(unique(mapping)) ~= n
    error('icevs:Probe','connector_es must provide one unique positive integer signal number per element.');
end
positions = probe.positions_mm;
if isempty(positions)
    positions = [((-((n-1)/2):((n-1)/2))' * double(probe.pitch_mm)), zeros(n,2)];
elseif ~finite_real(positions) || ~isequal(size(positions),[n 3]) || ...
        any(any(positions(:,2:3) ~= 0))
    error('icevs:Probe','positions_mm must be a finite N-by-3 linear array with y=z=0.');
end
if numel(unique(positions(:,1))) ~= n
    error('icevs:Probe','Each linear-array element must have a distinct x coordinate.');
end

scaleToWvl = double(probe.frequency_mhz) / (double(sound_speed_m_s)/1000);
if ~isfinite(scaleToWvl) || scaleToWvl <= 0
    error('icevs:Probe','The frequency/sound-speed conversion must be finite and positive.');
end
Trans = struct();
Trans.name = char(probe.name);
Trans.numelements = n;
Trans.frequency = double(probe.frequency_mhz);
Trans.Bandwidth = double(reshape(bandwidth,1,2));
Trans.type = 0;
Trans.units = 'wavelengths';
Trans.connType = double(probe.conn_type);
Trans.ConnectorES = double(mapping(:));
Trans.elementWidth = double(probe.width_mm) * scaleToWvl;
Trans.spacingMm = double(probe.pitch_mm);
Trans.spacing = Trans.spacingMm * scaleToWvl;
Trans.elevationApertureMm = double(probe.elevation_aperture_mm);
Trans.elevationFocusMm = double(probe.elevation_focus_mm);
Trans.ElementPos = [double(positions) * scaleToWvl, zeros(n,2)];
Trans.lensCorrection = double(probe.lens_correction_mm) * scaleToWvl;
Trans.impedance = double(probe.impedance_ohm);
Trans.maxHighVoltage = double(probe.max_high_voltage_v);
Trans.id = double(probe.id);
if ~all(isfinite([Trans.elementWidth,Trans.spacing,Trans.lensCorrection,Trans.ElementPos(:)']))
    error('icevs:Probe','Converted probe dimensions must remain finite.');
end

% Analytic bar-element directivity assumption, not a measured sensitivity.
theta = -pi/2:pi/100:pi/2;
theta(51) = 1e-7;
if Trans.elementWidth < .01
    Trans.ElementSens = abs(cos(theta));
else
    argument = Trans.elementWidth * pi * sin(theta);
    Trans.ElementSens = abs(cos(theta) .* sin(argument) ./ argument);
end
end

function yes = finite_real(value)
yes = isnumeric(value) && isreal(value) && all(isfinite(value(:)));
end

function yes = finite_scalar(value)
yes = finite_real(value) && isscalar(value);
end

function yes = nonempty_text(value)
yes = (ischar(value) && isrow(value) && ~isempty(strtrim(value))) || ...
    (isstring(value) && isscalar(value) && ~ismissing(value) && strlength(strtrim(value)) > 0);
end
