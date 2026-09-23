function sequence = make_sequence(geom, mask, cfg)
%MAKE_SEQUENCE Numerical focused, broad, or sequential expanded excitation.
%   weights are dimensionless amplitudes; delay_s is applied by propagation as
%   exp(-1i*omega*delay_s) under the exp(+1i*omega*t) time convention.
%   fixed_total preserves the area-weighted squared-weight norm of the whole
%   unmasked uniform aperture. It can require extra per-element amplitude and
%   is a source-drive proxy, not a guarantee of radiated power or hardware fit.
validate_geometry(geom);
positions = double(geom.positions_m);
n = size(positions,1);
if ~(islogical(mask) || isnumeric(mask)) || ~isreal(mask) || ...
        ~isequal(size(mask),[n 1]) || any(mask(:)~=0 & mask(:)~=1)
    error('ice:Excitation','mask must be a binary N-by-1 column vector.');
end
if ~isstruct(cfg) || ~isscalar(cfg) || ~all(isfield(cfg,{'acoustics','excitation'})) || ...
        ~isstruct(cfg.acoustics) || ~isscalar(cfg.acoustics) || ...
        ~isstruct(cfg.excitation) || ~isscalar(cfg.excitation)
    error('ice:Excitation','cfg must contain acoustics and excitation structures.');
end
if ~all(isfield(cfg.acoustics,{'frequency_hz','sound_speed_m_s'})) || ...
        ~positive_scalar(cfg.acoustics.frequency_hz) || ...
        ~positive_scalar(cfg.acoustics.sound_speed_m_s)
    error('ice:Excitation','Frequency and sound speed must be positive finite scalars.');
end
c = double(cfg.acoustics.sound_speed_m_s);
exc = cfg.excitation;
if ~all(isfield(exc,{'mode','aperture_size_m','apodization','normalization'}))
    error('ice:Excitation','Excitation requires mode, aperture_size_m, apodization, normalization.');
end
mode = enum_text(exc.mode,{'focused','broad','expanded'});
normalization = enum_text(exc.normalization,{'fixed_element','fixed_total'});
aperture = exc.aperture_size_m;
if ~isnumeric(aperture) || ~isreal(aperture) || numel(aperture)~=2 || ...
        any(isnan(aperture(:))) || any(aperture(:)<=0)
    error('ice:Excitation','aperture_size_m must contain two positive lengths or Inf.');
end
aperture = double(reshape(aperture,1,2));
inside = all(abs(positions(:,1:2))<=aperture/2,2);
amplitude = apodization_weights(exc.apodization,positions,inside,n);
amplitude(~inside | ~logical(mask)) = 0;
active = amplitude>0;
if ~any(active)
    error('ice:Excitation','Mask, aperture and apodization leave no effective excitation.');
end
if strcmp(normalization,'fixed_total')
    area = double(geom.width_m).*double(geom.height_m);
    amplitude = amplitude*sqrt(sum(area)/sum(area.*amplitude.^2));
end
if any(~isfinite(amplitude))
    error('ice:Excitation','Amplitude normalization must remain finite.');
end
switch mode
    case 'focused'
        if ~isfield(exc,'focus_m')
            error('ice:Excitation','Focused mode requires focus_m.');
        end
        points = focal_points(exc.focus_m,1);
    case 'expanded'
        if ~isfield(exc,'regional_points_m')
            error('ice:Excitation','Expanded mode requires regional_points_m.');
        end
        points = focal_points(exc.regional_points_m,[]);
    case 'broad'
        points = nan(1,3);
end
k = size(points,1);
if ~isfield(exc,'dwell_weights') || isempty(exc.dwell_weights)
    dwell = ones(k,1)/k;
else
    dwell = exc.dwell_weights;
    if ~isnumeric(dwell) || ~isreal(dwell) || ~isequal(size(dwell),[k 1]) || ...
            any(~isfinite(dwell)) || any(dwell<0) || abs(sum(dwell)-1)>1e-12
        error('ice:Excitation','dwell_weights must be a nonnegative K-by-1 column summing to one.');
    end
    dwell = double(dwell);
end
custom = [];
if isfield(exc,'custom_delay_s') && ~isempty(exc.custom_delay_s)
    custom = exc.custom_delay_s;
    if ~isnumeric(custom) || ~isreal(custom) || ~isequal(size(custom),[n 1]) || ...
            any(~isfinite(custom)) || any(custom<0)
        error('ice:Excitation','custom_delay_s must be a nonnegative finite N-by-1 column.');
    end
    custom = double(custom);
end
if strcmp(mode,'broad')
    steering = [0 0];
    if isfield(exc,'steering_deg') && ~isempty(exc.steering_deg)
        steering = exc.steering_deg;
    end
    if ~isnumeric(steering) || ~isreal(steering) || numel(steering)~=2 || ...
            any(~isfinite(steering(:))) || any(abs(steering(:))>=90)
        error('ice:Excitation','steering_deg must contain two finite forward angles in (-90,90).');
    end
    az = double(steering(1)); el = double(steering(2));
    direction = [sind(az)*cosd(el),sind(el),cosd(az)*cosd(el)];
    projection = positions*direction';
end
shot = struct('weights',complex(amplitude,zeros(n,1)), ...
    'delay_s',zeros(n,1),'focus_m',nan(1,3));
shots = repmat(shot,1,k);
for j=1:k
    delays = zeros(n,1);
    if ~isempty(custom)
        delays = custom;
    elseif strcmp(mode,'broad')
        delays(active) = (projection(active)-min(projection(active)))/c;
    else
        distances = vecnorm(positions(active,:)-points(j,:),2,2);
        delays(active) = (max(distances)-distances)/c;
    end
    shots(j).delay_s = delays;
    shots(j).focus_m = points(j,:);
end
sequence = struct('shots',shots,'dwell_weights',dwell,'mode',mode);
end

function validate_geometry(geom)
if ~isstruct(geom) || ~isscalar(geom) || ...
        ~all(isfield(geom,{'positions_m','width_m','height_m'}))
    error('ice:Excitation','Geometry must include positions and element dimensions.');
end
p = geom.positions_m;
if ~isnumeric(p) || ~isreal(p) || isempty(p) || size(p,2)~=3 || any(~isfinite(p(:)))
    error('ice:Excitation','Geometry positions must be finite N-by-3 values.');
end
n = size(p,1);
for name={'width_m','height_m'}
    value = geom.(name{1});
    if ~isnumeric(value) || ~isreal(value) || ~isequal(size(value),[n 1]) || ...
            any(~isfinite(value)) || any(value<=0)
        error('ice:Excitation','Geometry dimensions must be positive finite N-by-1 columns.');
    end
end
end

function weights = apodization_weights(apodization,positions,inside,n)
if isnumeric(apodization)
    if ~isreal(apodization) || ~isequal(size(apodization),[n 1]) || ...
            any(~isfinite(apodization)) || any(apodization<0)
        error('ice:Excitation','Numeric apodization must be a nonnegative finite N-by-1 column.');
    end
    weights = double(apodization);
    return
end
kind = enum_text(apodization,{'uniform','hann'});
weights = ones(n,1);
if strcmp(kind,'hann')
    for axis=1:2
        coordinates = unique(positions(inside,axis));
        m = numel(coordinates);
        axis_weights = ones(n,1);
        if m>1
            [present,index] = ismember(positions(:,axis),coordinates);
            window = .5-.5*cos(2*pi*(0:m-1)'/(m-1));
            axis_weights(present) = window(index(present));
        end
        weights = weights.*axis_weights;
    end
end
end

function points = focal_points(points, count)
if ~isnumeric(points) || ~isreal(points) || isempty(points) || size(points,2)~=3 || ...
        any(~isfinite(points(:))) || any(points(:,3)<=0) || ...
        (~isempty(count) && size(points,1)~=count)
    error('ice:Excitation','Focal positions must be finite K-by-3 rows with positive z.');
end
points = double(points);
end

function tf = positive_scalar(value)
tf = isnumeric(value) && isreal(value) && isscalar(value) && isfinite(value) && value>0;
end

function value = enum_text(value, choices)
if isstring(value) && isscalar(value)
    value = char(value);
end
if ~ischar(value) || ~isrow(value) || ~any(strcmp(value,choices))
    error('ice:Excitation','Unsupported mode, normalization, or apodization name.');
end
end
