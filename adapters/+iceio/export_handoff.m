function handoff = export_handoff(geom, sequence, cfg, filename)
%EXPORT_HANDOFF Validate and export backend-neutral, non-executable JSON.
% Physical delay_s is NOT converted into any hardware-specific TX.Delay.
% Complex peak velocity is split into real/imaginary parts before delays.
% Use filename='' (or omit it) to return the structure without writing.

if nargin < 4, filename = ''; end
validateGeometry(geom);
n = size(geom.positions_m,1);
validateConfig(cfg);
if ~isstruct(sequence) || ~all(isfield(sequence, {'shots','dwell_weights','mode'})) || ...
        ~isstruct(sequence.shots) || isempty(sequence.shots) || ~isTextScalar(sequence.mode)
    error('iceio:InvalidSequence', 'Sequence requires shots, dwell_weights and a text mode.');
end
shot_count = numel(sequence.shots);
dwell = sequence.dwell_weights(:);
if ~isnumeric(dwell) || ~isreal(dwell) || numel(dwell) ~= shot_count || ...
        any(~isfinite(dwell)) || any(dwell < 0) || abs(sum(dwell)-1) > 1e-10
    error('iceio:InvalidSequence', 'One finite nonnegative dwell weight per shot must sum to 1.');
end
shots = repmat(struct('weights_real',[], 'weights_imag',[], 'delay_s',[], ...
    'normal_velocity_before_delay_real_m_s',[], 'normal_velocity_before_delay_imag_m_s',[], ...
    'focus_m',[]), shot_count, 1);
for k = 1:shot_count
    shot = sequence.shots(k);
    if ~all(isfield(shot, {'weights','delay_s','focus_m'})) || ...
            ~isnumeric(shot.weights) || ~isequal(size(shot.weights),[n 1]) || any(~isfinite(shot.weights)) || ...
            ~isnumeric(shot.delay_s) || ~isreal(shot.delay_s) || ~isequal(size(shot.delay_s),[n 1]) || ...
            any(~isfinite(shot.delay_s)) || any(shot.delay_s < 0) || ...
            ~isnumeric(shot.focus_m) || ~isreal(shot.focus_m) || numel(shot.focus_m) ~= 3 || ...
            ~(all(isfinite(shot.focus_m)) || all(isnan(shot.focus_m)))
        error('iceio:InvalidSequence', 'Each shot requires N-by-1 weights/delays and a finite or all-NaN focus.');
    end
    velocity = cfg.source.velocity_m_s * shot.weights;
    shots(k) = struct('weights_real',real(shot.weights), 'weights_imag',imag(shot.weights), ...
        'delay_s',shot.delay_s, 'normal_velocity_before_delay_real_m_s',real(velocity), ...
        'normal_velocity_before_delay_imag_m_s',imag(velocity), 'focus_m',reshape(shot.focus_m,1,3));
end
handoff = struct();
handoff.schema_version = 'ice-handoff-1.0';
handoff.executable = false;
handoff.purpose = 'Inspectable physics inputs only; not a hardware program or a complete k-Wave simulation.';
handoff.units = struct('position','m', 'element_size','m', 'delay','s', ...
    'normal_velocity','m/s', 'frequency','Hz', 'sound_speed','m/s', ...
    'density','kg/m^3', 'exposure_time','s', 'weights','dimensionless', ...
    'dwell_weights','dimensionless', 'duty_cycle','dimensionless');
handoff.conventions = struct('coordinates','Array in x-y plane; x along linear array; positive z outward.', ...
    'phasor','Peak amplitude: real(v*exp(+i*omega*t)); delay multiplies exp(-i*omega*delay_s).', ...
    'intensity','Plane-progressive-wave equivalent |p|^2/(2*rho*c), not exact active near-field flux.', ...
    'shot_combination','Sequential shots: dwell-weighted intensities; never coherent pressure summation.');
handoff.dimensions = struct('element_count',n, 'shot_count',shot_count, 'coordinates_per_element',3);
handoff.geometry = geom;
handoff.sequence = struct('mode',char(sequence.mode), 'shots',shots, 'dwell_weights',dwell);
handoff.acoustics = cfg.acoustics;
handoff.source = cfg.source;
handoff.exposure = cfg.exposure;
handoff.hardware = struct('device_identity','unknown', 'element_to_channel',NaN(n,1), ...
    'voltage_to_normal_velocity_m_s_per_v',NaN, 'delay_clock_hz',NaN, ...
    'tx_delay_conversion_status','unknown_requires_backend_documentation', ...
    'pulse_cycles',NaN, 'transmit_voltage_v',NaN, ...
    'operating_limits_status','not_established');
if ~isTextScalar(filename)
    error('iceio:InvalidFilename', 'filename must be a scalar string or character row.');
end
if strlength(string(filename)) > 0
    encoded = jsonencode(handoff, 'PrettyPrint', true);
    [fid,message] = fopen(filename, 'w', 'n', 'UTF-8');
    if fid < 0
        error('iceio:WriteFailed', 'Cannot write handoff: %s', message);
    end
    cleanup = onCleanup(@() fclose(fid));
    count = fprintf(fid, '%s\n', encoded);
    if count < numel(encoded)
        error('iceio:WriteFailed', 'Incomplete handoff write.');
    end
end
end

function validateGeometry(g)
if ~isstruct(g) || ~all(isfield(g, {'positions_m','width_m','height_m','normal'})) || ...
        ~isnumeric(g.positions_m) || ~isreal(g.positions_m) || size(g.positions_m,2) ~= 3 || ...
        isempty(g.positions_m) || any(~isfinite(g.positions_m(:)))
    error('iceio:InvalidGeometry', 'Geometry requires finite N-by-3 positions and dimensions.');
end
n = size(g.positions_m,1);
for name = {'width_m','height_m'}
    v = g.(name{1});
    if ~isnumeric(v) || ~isreal(v) || ~(isscalar(v) || isequal(size(v),[n 1])) || ...
            any(~isfinite(v)) || any(v <= 0)
        error('iceio:InvalidGeometry', 'Element sizes must be positive finite scalar or N-by-1.');
    end
end
if ~isnumeric(g.normal) || ~isreal(g.normal) || numel(g.normal) ~= 3 || ...
        any(~isfinite(g.normal)) || abs(norm(g.normal)-1) > 1e-10
    error('iceio:InvalidGeometry', 'Geometry normal must be a finite unit vector.');
end
end

function validateConfig(c)
required = struct('source',{{'velocity_m_s','calibrated','calibration_note'}}, ...
    'acoustics',{{'frequency_hz','sound_speed_m_s','density_kg_m3'}}, ...
    'exposure',{{'duty_cycle','exposure_time_s'}});
for name = {'source','acoustics','exposure'}
    group = name{1};
    if ~isstruct(c) || ~isfield(c,group) || ~isstruct(c.(group)) || ~all(isfield(c.(group),required.(group)))
        error('iceio:InvalidConfig', 'Configuration is missing required %s fields.', group);
    end
end
for name = required.acoustics
    if ~validScalar(c.acoustics.(name{1})) || c.acoustics.(name{1}) <= 0
        error('iceio:InvalidConfig', 'Acoustic constants must be positive finite scalars.');
    end
end
if ~validScalar(c.source.velocity_m_s) || c.source.velocity_m_s < 0 || ...
        ~islogical(c.source.calibrated) || ~isscalar(c.source.calibrated) || ...
        ~isTextScalar(c.source.calibration_note) || ...
        (c.source.calibrated && strlength(strtrim(string(c.source.calibration_note))) == 0) || ...
        ~validScalar(c.exposure.duty_cycle) || c.exposure.duty_cycle < 0 || c.exposure.duty_cycle > 1 || ...
        ~validScalar(c.exposure.exposure_time_s) || c.exposure.exposure_time_s <= 0
    error('iceio:InvalidConfig', 'Source/calibration, duty cycle or exposure time is invalid.');
end
end

function tf = validScalar(value)
tf = isnumeric(value) && isreal(value) && isscalar(value) && isfinite(value);
end

function tf = isTextScalar(value)
tf = (ischar(value) && (isrow(value) || isempty(value))) || (isstring(value) && isscalar(value) && ~ismissing(value));
end
