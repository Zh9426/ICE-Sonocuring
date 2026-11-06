function validate_config(c)
%VALIDATE_CONFIG Check algorithm inputs, not hardware/acoustic suitability.
must(isfield(c.probe,'type') && ismember(c.probe.type,{'linear','matrix'}), ...
    'Probe type must be linear (working source) or matrix (synthetic regression).');
must(ismember(c.mode,{'imaging_only','exposure_only','interleaved'}),'Unknown mode.');
must(isfield(c.imaging,'geometry') && ...
    ismember(c.imaging.geometry,{'original_sector','plane_wave_rectangle'}), ...
    'Unknown imaging geometry; legacy plane-wave regression must be explicit.');
positive(c.medium.sound_speed_m_s,'medium.sound_speed_m_s');
integer(c.system.num_transmit,'system.num_transmit');
integer(c.system.num_receive,'system.num_receive');
integer(c.sequence.num_frames,'sequence.num_frames');
integer(c.sequence.return_every_frames,'sequence.return_every_frames');
must(c.sequence.num_frames<=1000,'num_frames exceeds offline allocation limit (1000).');
must(isequal(c.runtime.simulate_mode,1), ...
    'Probe exposure limits remain uncalibrated; only offline/simulation configuration is supported.');
must(isscalar(c.runtime.freeze_on_start) && ismember(c.runtime.freeze_on_start,[0 1]), ...
    'freeze_on_start must be scalar logical.');
must(isnumeric(c.imaging.angles_deg) && isreal(c.imaging.angles_deg) && ...
    isvector(c.imaging.angles_deg) && all(isfinite(c.imaging.angles_deg)) && ...
    all(abs(c.imaging.angles_deg)<90),'angles_deg must be finite within (-90,90).');
nonnegative(c.imaging.start_depth_wls,'imaging.start_depth_wls');
positive(c.imaging.end_depth_wls,'imaging.end_depth_wls');
must(c.imaging.end_depth_wls>c.imaging.start_depth_wls,'end depth must exceed start depth.');
must(c.imaging.end_depth_wls/c.probe.frequency_mhz>2,'end depth too short for baseline TGC.');
positive(c.imaging.demod_frequency_mhz,'imaging.demod_frequency_mhz');
% D00163 Rev.K p121 Table 15.0.1; actual clock quantization is a VSX check.
must(c.imaging.demod_frequency_mhz>=.25 && c.imaging.demod_frequency_mhz<=31.25, ...
    'NS200BW demod_frequency_mhz must be within 0.25..31.25; high-frequency hardware requires >=0.5.');
integer(c.imaging.half_cycles,'imaging.half_cycles');
integer(c.exposure.cycles,'exposure.cycles');
integer(c.exposure.pulses_per_focus,'exposure.pulses_per_focus');
integer(c.exposure.max_total_pulses,'exposure.max_total_pulses');
f = c.exposure.foci_mm;
must(isnumeric(f) && isreal(f) && ismatrix(f) && size(f,2)==3 && ...
    ~isempty(f) && all(isfinite(f),'all') && all(f(:,3)>0), ...
    'foci_mm must contain finite [x,y,z>0] rows.');
if strcmp(c.probe.type,'linear')
    must(c.probe.num_elements==64,'The current physical driver requires the working 64-element baseline.');
    must(all(f(:,2)==0),'A single-row linear array supports XZ targets only; elevation focusing is fixed.');
end
for key={'x_limits_mm','y_limits_mm'}
    bounds=c.imaging.(key{1});
    must(isnumeric(bounds) && isreal(bounds) && numel(bounds)==2 && ...
        all(isfinite(bounds)) && bounds(2)>bounds(1),'Image limits must be finite ordered pairs.');
end
step=c.imaging.voxel_size_mm;
must(isnumeric(step) && isreal(step) && numel(step)==3 && all(isfinite(step)) && all(step>0), ...
    'voxel_size_mm must contain positive [dx dy dz].');
must(isnumeric(c.imaging.slice_y_mm) && isscalar(c.imaging.slice_y_mm) && ...
    isfinite(c.imaging.slice_y_mm) && c.imaging.slice_y_mm>=c.imaging.y_limits_mm(1) && ...
    c.imaging.slice_y_mm<=c.imaging.y_limits_mm(2),'XZ slice must lie inside the image y limits.');
for name = {'imaging','exposure'}
    s = c.(name{1});
    positive(s.frequency_mhz,[name{1} '.frequency_mhz']);
    must(s.frequency_mhz>=c.probe.bandwidth_mhz(1) && s.frequency_mhz<=c.probe.bandwidth_mhz(2), ...
        'Waveform frequency outside configured probe bandwidth.');
    positive(s.pri_us,[name{1} '.pri_us']);
    voltage=icevs.requested_voltage(s);
    positive(voltage,[name{1} '.voltage_v']);
    must(voltage<=c.probe.max_high_voltage_v,'Supply request exceeds configured maxHighVoltage.');
    must(isscalar(s.active_fraction) && isfinite(s.active_fraction) && s.active_fraction>0 && ...
        s.active_fraction<=1,'active_fraction must be in (0,1].');
    must(isscalar(s.polarity) && ismember(s.polarity,[-1 1]),'polarity must be +1 or -1.');
    must(isscalar(s.tpc_profile) && ismember(s.tpc_profile,1:5),'TPC profile must be integer 1..5.');
    if ~isempty(s.apod)
        must(isnumeric(s.apod) && isreal(s.apod) && isvector(s.apod) && ...
            numel(s.apod)==c.probe.num_elements && all(isfinite(s.apod)) && ...
            all(s.apod>=0 & s.apod<=1) && any(s.apod>0),'Apod must match probe, in [0,1], nonzero.');
    end
end
must(c.imaging.tpc_profile<5,'Imaging uses profiles 1..4; profile 5 is exposure-only.');
if c.imaging.tpc_profile==c.exposure.tpc_profile
    must(icevs.requested_voltage(c.imaging)==icevs.requested_voltage(c.exposure), ...
        'One TPC profile cannot request two voltages.');
end
positive(c.imaging.frame_period_us,'imaging.frame_period_us');
must(isscalar(c.imaging.senscutoff) && isfinite(c.imaging.senscutoff) && ...
    c.imaging.senscutoff>=0 && c.imaging.senscutoff<=1,'senscutoff must be in [0,1].');
for name = {'initial_settle_us','profile_settle_us','receive_recovery_us','recharge_us','waveform_guard_us'}
    positive(c.timing.(name{1}),['timing.' name{1}]);
end
if ~strcmp(c.mode,'imaging_only')
    n=c.sequence.num_frames*size(f,1)*c.exposure.pulses_per_focus;
    must(n<=c.exposure.max_total_pulses,'Total exposure pulses exceed configured finite-session cap.');
end
if isfield(c,'hardware_limits')
    limits=c.hardware_limits;
    for key={'max_burst_us','max_local_duty_cycle','max_total_on_time_us','max_voltage_v'}
        value=limits.(key{1});
        must(isnumeric(value) && isreal(value) && isscalar(value) && ...
            (isnan(value) || (isfinite(value) && value>0)), ...
            'Hardware limits must be NaN (unknown) or finite positive values.');
    end
    must(isnan(limits.max_local_duty_cycle) || limits.max_local_duty_cycle<=1, ...
        'max_local_duty_cycle must not exceed 1.');
    must(isfield(limits,'provenance') && ~isempty(limits.provenance),'Limit provenance is required.');
end
must(isfile(c.baseline_mat),'Saved baseline MAT is missing.');
must(isfolder(fullfile(c.vendor_root,'Utilities')),'Vendor Utilities directory is missing.');
end

function positive(x,name)
must(isnumeric(x) && isreal(x) && isscalar(x) && isfinite(x) && x>0,[name ' must be finite positive.']);
end
function nonnegative(x,name)
must(isnumeric(x) && isreal(x) && isscalar(x) && isfinite(x) && x>=0,[name ' must be finite nonnegative.']);
end
function integer(x,name)
positive(x,name); must(x==fix(x),[name ' must be integer.']);
end
function must(ok,message)
if ~ok, error('icevs:Config','%s',message); end
end
