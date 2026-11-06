function [Event, SeqControl, timing] = compile_events(cfg, meta)
%COMPILE_EVENTS Compile a finite, offline imaging/exposure event sequence.
% This function neither calls VSX nor configures or activates any hardware.
% All wait settings are assumed until measured on the actual installation.
%
% References: D00163 Rev. K, section 12.1 pp.96-97, appendix pp.A103,
% A107, A109-A110 (PDF pp.242,246,248-249). Cross-checked against bundled
% D00163 Rev. L, pp.A104,A108,A110-A111 (PDF pp.247,251,253-254).
% noop has 200 ns ticks; timeToNextAcq (TTNA) uses microseconds. Profile
% switches use immediate in non-acquisition events, followed by a noop.
% Profile 5 requests do not demonstrate an installed option or license.
% The standalone TX-only adapter can omit receive recovery and final imaging
% profile restoration. Imaging modes reject those omissions.
%
% Within a group, TTNA measures transmit-start to transmit-start and already
% overlaps acquisition time. The final transmit has no TTNA, so its following
% completion/recovery/recharge noops are not hidden inside a pending PRI.
% Completion noops deliberately add the full supplied effective duration
% after the acquisition event. Timing accounts for that explicit wait but
% does not additionally count the final acquisition's own execution time.
% Consequently timing values are scheduled lower bounds, not hardware-exact
% periods. DMA, host processing, hardware transition and command execution
% can lengthen them. The nominal duty ratio is not an acoustic measurement.

if ~isstruct(cfg) || ~isscalar(cfg) || ~isstruct(meta) || ~isscalar(meta)
    error('icevs:Config', 'cfg and meta must be scalar structs.');
end
if ~isfield(cfg, 'mode') || ~(ischar(cfg.mode) || (isstring(cfg.mode) && isscalar(cfg.mode)))
    error('icevs:Config', 'mode must be imaging_only, exposure_only, or interleaved.');
end
mode = char(cfg.mode);
if ~ismember(mode, {'imaging_only', 'exposure_only', 'interleaved'})
    error('icevs:Config', 'Unsupported sequence mode.');
end
has_imaging = ~strcmp(mode, 'exposure_only');
has_exposure = ~strcmp(mode, 'imaging_only');

% Finite compilation bounds are local allocation policy, not hardware limits.
max_events = 1000000;
max_noop_ticks = 2^25 - 1; % Manual-documented noop argument limit.
max_wait_us = floor(max_noop_ticks / 5);
nf = option(cfg, 'sequence', 'num_frames', 30, 1, 10000);
return_every = option(cfg, 'sequence', 'return_every_frames', 3, 1, 10000);
im_pri = option(cfg, 'imaging', 'pri_us', 400, 1, max_wait_us);
frame_period = option(cfg, 'imaging', 'frame_period_us', 20000, 1, max_wait_us);
im_profile = option(cfg, 'imaging', 'tpc_profile', 1, 1, 4);
ex_pri = option(cfg, 'exposure', 'pri_us', 1000, 1, max_wait_us);
np = option(cfg, 'exposure', 'pulses_per_focus', 10, 1, 100000);
ex_profile = option(cfg, 'exposure', 'tpc_profile', 1, 1, 5);
initial_settle = option(cfg, 'timing', 'initial_settle_us', 5000, 1, max_wait_us);
profile_settle = option(cfg, 'timing', 'profile_settle_us', 5000, 1, max_wait_us);
receive_recovery = option(cfg, 'timing', 'receive_recovery_us', 2000, 1, max_wait_us);
include_recovery = option(cfg, 'timing', 'include_receive_recovery', 1, 0, 1);
restore_imaging_profile = option(cfg, 'sequence', 'restore_imaging_profile', 1, 0, 1);
if has_imaging && (~include_recovery || ~restore_imaging_profile)
    error('icevs:Config','Imaging sequences must retain receive/profile recovery behavior.');
end
recharge = option(cfg, 'timing', 'recharge_us', 10000, 1, max_wait_us);

na = metadataNumber(meta, 'num_angles', 0, 10000, true);
nfocus = metadataNumber(meta, 'num_foci', 0, 10000, true);
im_tx = metadataIndices(meta, 'imaging_tx_indices', na);
ex_tx = metadataIndices(meta, 'exposure_tx_indices', nfocus);
receive_end = metadataNumber(meta, 'receive_end_us', 0, max_wait_us, false);
exposure_end = metadataNumber(meta, 'exposure_end_us', 0, max_wait_us, false);
nominal_pulse = metadataNumber(meta, 'nominal_exposure_pulse_us', 0, max_wait_us, false);
if (has_imaging && (na < 1 || receive_end <= 0)) || ...
        (has_exposure && (nfocus < 1 || exposure_end <= 0 || nominal_pulse <= 0))
    error('icevs:Metadata', 'Active modes require positive counts and effective durations.');
end
if ~isempty(im_tx) && ~isempty(ex_tx) && min(ex_tx) <= max(im_tx)
    error('icevs:Metadata', 'Exposure TX entries must follow the imaging TX entries.');
end
if nominal_pulse > exposure_end
    error('icevs:Metadata', 'Nominal exposure pulse cannot exceed its effective end time.');
end
if (has_imaging && im_pri < receive_end) || (has_exposure && ex_pri < exposure_end)
    error('icevs:Timing', 'PRI is shorter than the effective acquisition/transmit duration.');
end
imaging_span = (na - 1) * im_pri + ceil(receive_end * 5) / 5;
if has_imaging && frame_period < imaging_span
    error('icevs:Timing', 'Imaging frame period is shorter than the compiled angle group.');
end
event_bound = 5 + nf * (has_imaging * (na + 5) + ...
    has_exposure * (nfocus * (np + 2) + 5));
if event_bound > max_events
    error('icevs:Config', 'Sequence exceeds the offline compiler policy of %d events.', max_events);
end

Event = struct('info', {}, 'tx', {}, 'rcv', {}, 'recon', {}, 'process', {}, 'seqControl', {});
SeqControl = struct('command', {}, 'argument', {}, 'condition', {});
rows = struct('index', {}, 'kind', {}, 'frame', {}, 'focus', {}, ...
    'requested_wait_us', {}, 'scheduled_wait_us', {}, 'profile', {}, ...
    'scheduled_start_lower_bound_us', {});
clock_us = 0;
cycle_us = zeros(1, nf);
if has_imaging
    current_profile = im_profile;
else
    current_profile = ex_profile;
end
selectProfile(current_profile, 0, initial_settle, 'initial_settle');
initialization_us = clock_us;

for frame = 1:nf
    cycle_start = clock_us;
    if has_imaging
        for angle = 1:na
            scheduled_pri = 0;
            if angle < na
                controls = addControl('timeToNextAcq', im_pri, []);
                scheduled_pri = im_pri;
            else
                % A distinct DMA command is required for every receive frame.
                controls = addControl('transferToHost', [], []);
            end
            addEvent('imaging_acquire', frame, 0, im_tx(angle), ...
                na * (frame - 1) + angle, 0, 0, controls, scheduled_pri, scheduled_pri);
        end
        addWait('imaging_complete', frame, 0, receive_end);
        controls = 0;
        if mod(frame, return_every) == 0
            controls = addControl('returnToMatlab', [], []);
        end
        addEvent('reconstruct', frame, 0, 0, 0, 1, 1, controls, 0, 0);
        % This explicit idle completes the scheduled imaging portion, even
        % when exposure is the next group. It is not another acquisition PRI.
        idle = frame_period - imaging_span;
        if idle > 0
            addWait('frame_idle', frame, 0, idle);
        end
    end

    if has_exposure
        if current_profile ~= ex_profile
            selectProfile(ex_profile, frame, profile_settle, 'profile_settle');
        end
        for focus = 1:nfocus
            for pulse = 1:np
                controls = 0;
                scheduled_pri = 0;
                if pulse < np
                    controls = addControl('timeToNextAcq', ex_pri, []);
                    scheduled_pri = ex_pri;
                end
                addEvent('exposure_transmit', frame, focus, ex_tx(focus), ...
                    0, 0, 0, controls, scheduled_pri, scheduled_pri);
            end
            addWait('exposure_complete', frame, focus, exposure_end);
            % One recharge after every focus, including the final focus.
            % These assumed waits do not certify stored-energy recovery.
            addWait('recharge', frame, focus, recharge);
        end
        if include_recovery
            addWait('receive_recovery', frame, 0, receive_recovery);
        end
        if has_imaging && current_profile ~= im_profile
            selectProfile(im_profile, frame, profile_settle, 'profile_settle');
        end
    end
    cycle_us(frame) = clock_us - cycle_start;
end

% An exposure-only request may finish on profile 5 (or another profile).
% Restore the configured imaging profile before freezing the finite sequence.
shutdown_start = clock_us;
if restore_imaging_profile && current_profile ~= im_profile
    selectProfile(im_profile, nf, profile_settle, 'profile_settle');
end
shutdown_us = clock_us - shutdown_start;
addEvent('stop', nf, 0, 0, 0, 0, 0, addControl('stop', [], []), 0, 0);

pulses_per_cycle = has_exposure * nfocus * np;
timing = struct();
timing.mode = mode;
timing.num_frames = nf;
timing.scheduled_cycle_us = cycle_us(1);
timing.scheduled_cycles_us = cycle_us;
timing.scheduled_total_us = clock_us;
timing.initialization_us = initialization_us;
timing.shutdown_us = shutdown_us;
timing.nominal_exposure_on_time_us = pulses_per_cycle * nominal_pulse;
timing.nominal_total_exposure_on_time_us = nf * timing.nominal_exposure_on_time_us;
timing.nominal_exposure_duty_cycle = timing.nominal_exposure_on_time_us / timing.scheduled_cycle_us;
timing.total_exposure_pulses = nf * pulses_per_cycle;
timing.total_imaging_acquisitions = has_imaging * nf * na;
timing.is_lower_bound = true;
timing.parameter_status = 'assumed';
timing.profile5_requested = has_exposure && ex_profile == 5;
timing.profile5_hardware_support = 'unknown';
timing.description = ['Scheduled lower bound, not an exact hardware period. ' ...
    'Within-group TTNA includes acquisition time; only group-final explicit noops ' ...
    'are added, with no pending TTNA at group boundaries. Final-acquisition execution, ' ...
    'DMA, processing, command overhead and profile transitions may add time. ' ...
    'Completion noops add the full effective duration after the acquisition event. ' ...
    'All settle, recovery and recharge values are assumed; 5000 us cannot guarantee ' ...
    'profile completion (D00163 Rev. K/L section 12.1 reports up to 6-8 ms).'];
timing.duty_cycle_basis = ['Per-supercycle nominal pulse time divided by the scheduled ' ...
    'cycle lower bound; an upper estimate for that nominal timing model, not measured ' ...
    'acoustic exposure, successful curing, or a clinical safety conclusion.'];
timing.manual_references = {'D00163 Rev. K: section 12.1 pp.96-97; A103,A107,A109-A110', ...
    'D00163 Rev. L: section 12.1 pp.96-97; A104,A108,A110-A111'};
timing.event_rows = rows;

    function index = addControl(command, argument, condition)
        index = numel(SeqControl) + 1;
        SeqControl(index) = struct('command', command, 'argument', argument, 'condition', condition);
    end

    function addEvent(kind, frame_id, focus_id, tx, rcv, recon, process, control, requested, scheduled)
        index = numel(Event) + 1;
        Event(index) = struct('info', sprintf('%s frame=%d focus=%d', kind, frame_id, focus_id), ...
            'tx', tx, 'rcv', rcv, 'recon', recon, 'process', process, 'seqControl', control);
        rows(index) = struct('index', index, 'kind', kind, 'frame', frame_id, 'focus', focus_id, ...
            'requested_wait_us', requested, 'scheduled_wait_us', scheduled, ...
            'profile', current_profile, 'scheduled_start_lower_bound_us', clock_us);
        clock_us = clock_us + scheduled;
    end

    function addWait(kind, frame_id, focus_id, requested)
        ticks = ceil(requested * 5);
        if ticks < 1 || ticks > max_noop_ticks
            error('icevs:Timing', 'Explicit noop must fit the 1 to 2^25-1 tick range.');
        end
        control = addControl('noop', ticks, []);
        addEvent(kind, frame_id, focus_id, 0, 0, 0, 0, control, requested, ticks / 5);
    end

    function selectProfile(profile, frame_id, settle, kind)
        current_profile = profile;
        control = addControl('setTPCProfile', profile, 'immediate');
        addEvent('profile_switch', frame_id, 0, 0, 0, 0, 0, control, 0, 0);
        addWait(kind, frame_id, 0, settle);
    end
end

function value = option(cfg, section, field, default, minimum, maximum)
value = default;
if isfield(cfg, section)
    if ~isstruct(cfg.(section)) || ~isscalar(cfg.(section))
        error('icevs:Config', '%s must be a scalar struct.', section);
    end
    if isfield(cfg.(section), field)
        value = cfg.(section).(field);
    end
end
if ~isnumeric(value) || ~isreal(value) || ~isscalar(value) || ~isfinite(value) || ...
        value ~= fix(value) || value < minimum || value > maximum
    error('icevs:Config', '%s.%s must be an integer in [%g,%g].', section, field, minimum, maximum);
end
value = double(value);
end

function value = metadataNumber(meta, field, minimum, maximum, integer_only)
if ~isfield(meta, field)
    error('icevs:Metadata', 'Missing metadata field %s.', field);
end
value = meta.(field);
if ~isnumeric(value) || ~isreal(value) || ~isscalar(value) || ~isfinite(value) || ...
        value < minimum || value > maximum || (integer_only && value ~= fix(value))
    error('icevs:Metadata', 'Invalid metadata field %s.', field);
end
value = double(value);
end

function indices = metadataIndices(meta, field, count)
if ~isfield(meta, field)
    error('icevs:Metadata', 'Missing metadata field %s.', field);
end
indices = meta.(field);
if ~isnumeric(indices) || ~isreal(indices) || numel(indices) ~= count || ...
        (~isempty(indices) && ~isvector(indices)) || any(~isfinite(indices(:))) || ...
        any(indices(:) < 1 | indices(:) > 1000000 | indices(:) ~= fix(indices(:))) || ...
        numel(unique(indices)) ~= count
    error('icevs:Metadata', '%s must contain one unique positive TX index per entry.', field);
end
indices = double(indices(:).');
end
