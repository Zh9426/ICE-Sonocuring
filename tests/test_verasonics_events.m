function tests = test_verasonics_events
% Offline event-contract tests; never invokes VSX or a hardware entry point.
tests = functiontests(localfunctions);
end

function setupOnce(~)
root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root, 'verasonics', 'dual_mode'));
end

function testModesReferenceOnlyTheirOwnObjects(t)
[cfg, meta] = fixture();
modes = {'imaging_only', 'exposure_only', 'interleaved'};
for k = 1:numel(modes)
    cfg.mode = modes{k};
    [events, controls, timing] = icevs.compile_events(cfg, meta);
    imaging = find([events.rcv] > 0);
    exposure = find(ismember([events.tx], meta.exposure_tx_indices));
    if strcmp(cfg.mode, 'exposure_only')
        verifyEmpty(t, imaging);
        verifyFalse(t, any(strcmp({controls.command}, 'transferToHost')));
        verifyEqual(t, [events.recon], zeros(1, numel(events)));
        verifyEqual(t, [events.process], zeros(1, numel(events)));
    else
        verifyEqual(t, [events(imaging).rcv], 1:(cfg.sequence.num_frames * meta.num_angles));
        verifyEqual(t, [events(imaging).tx], repmat(meta.imaging_tx_indices, 1, cfg.sequence.num_frames));
        verifyEqual(t, sum(strcmp({controls.command}, 'transferToHost')), cfg.sequence.num_frames);
        verifyEqual(t, sum([events.recon] == 1), cfg.sequence.num_frames);
        verifyEqual(t, sum([events.process] == 1), cfg.sequence.num_frames);
    end
    if strcmp(cfg.mode, 'imaging_only')
        verifyEmpty(t, exposure);
        verifyEqual(t, timing.total_exposure_pulses, 0);
    else
        verifyEqual(t, numel(exposure), cfg.sequence.num_frames * meta.num_foci * cfg.exposure.pulses_per_focus);
        verifyEqual(t, [events(exposure).rcv], zeros(1, numel(exposure)));
        for n = exposure
            verifyFalse(t, any(strcmp(eventCommands(events(n), controls), 'transferToHost')));
        end
    end
    for n = 1:numel(events)
        indices = events(n).seqControl;
        verifyTrue(t, all(indices == 0 | (indices >= 1 & indices <= numel(controls) & indices == fix(indices))));
    end
    verifyFalse(t, any(ismember({controls.command}, {'jump', 'loopCnt', 'loopTst'})));
    verifyEqual(t, eventCommands(events(end), controls), {'stop'});
    verifyEqual(t, timing.event_rows(end).kind, 'stop');
    verifyEqual(t, [timing.event_rows.index], 1:numel(events));
end
end

function testProfileFiveSwitchesBothWaysWithSeparateWaits(t)
[cfg, meta] = fixture();
cfg.mode = 'interleaved';
cfg.exposure.tpc_profile = 5;
[events, controls, timing] = icevs.compile_events(cfg, meta);
switches = find(strcmp({timing.event_rows.kind}, 'profile_switch'));
verifyEqual(t, [timing.event_rows(switches).profile], [1 5 1 5 1]);
for k = 1:numel(switches)
    n = switches(k);
    verifyEqual(t, [events(n).tx events(n).rcv], [0 0]);
    control = controls(events(n).seqControl);
    verifyEqual(t, control.command, 'setTPCProfile');
    verifyEqual(t, control.condition, 'immediate');
    verifyEqual(t, [events(n+1).tx events(n+1).rcv], [0 0]);
    verifyEqual(t, eventCommands(events(n+1), controls), {'noop'});
    verifyGreaterThanOrEqual(t, timing.event_rows(n+1).requested_wait_us, cfg.timing.profile_settle_us);
end
verifyFalse(t, any(strcmp({controls.command}, 'timeToNextEB')));
verifyEqual(t, sum(strcmp({timing.event_rows.kind}, 'receive_recovery')), cfg.sequence.num_frames);
verifyEqual(t, sum(strcmp({timing.event_rows.kind}, 'recharge')), cfg.sequence.num_frames * meta.num_foci);
end

function testNoopUsesTwoHundredNanosecondsAndRoundsUp(t)
[cfg, meta] = fixture();
cfg.mode = 'interleaved';
meta.receive_end_us = 100.04;
meta.exposure_end_us = 8.03;
[events, controls, timing] = icevs.compile_events(cfg, meta);
waits = find([timing.event_rows.requested_wait_us] > 0 & [events.tx] == 0);
for n = waits
    sc = controls(events(n).seqControl);
    verifyEqual(t, sc.command, 'noop');
    verifyEqual(t, sc.argument, ceil(timing.event_rows(n).requested_wait_us * 5));
    verifyGreaterThanOrEqual(t, sc.argument / 5, timing.event_rows(n).requested_wait_us);
    verifyLessThan(t, sc.argument / 5 - timing.event_rows(n).requested_wait_us, 0.2 + 1e-9);
end
completion = find(strcmp({timing.event_rows.kind}, 'exposure_complete'), 1);
verifyEqual(t, controls(events(completion).seqControl).argument, 41);
verifyEqual(t, controls(events(2).seqControl).argument, cfg.timing.initial_settle_us * 5);
end

function testExposureOnlyRestoresImagingProfileBeforeStop(t)
[cfg, meta] = fixture();
cfg.mode = 'exposure_only';
cfg.exposure.tpc_profile = 5;
[events, controls, timing] = icevs.compile_events(cfg, meta);
switches = find(strcmp({timing.event_rows.kind}, 'profile_switch'));
verifyEqual(t, [timing.event_rows(switches).profile], [5 1]);
verifyEqual(t, eventCommands(events(end-1), controls), {'noop'});
verifyEqual(t, eventCommands(events(end), controls), {'stop'});
verifyEqual(t, timing.shutdown_us, cfg.timing.profile_settle_us);
verifyEqual(t, timing.scheduled_total_us, timing.initialization_us + ...
    cfg.sequence.num_frames * timing.scheduled_cycle_us + timing.shutdown_us, 'AbsTol', 1e-9);
end

function testPulseAccountingAndTimingAreExplicitLowerBounds(t)
[cfg, meta] = fixture();
cfg.mode = 'interleaved';
[events, controls, timing] = icevs.compile_events(cfg, meta);
expectedPerCycle = meta.num_foci * cfg.exposure.pulses_per_focus;
verifyEqual(t, timing.total_exposure_pulses, cfg.sequence.num_frames * expectedPerCycle);
verifyEqual(t, timing.nominal_exposure_on_time_us, expectedPerCycle * meta.nominal_exposure_pulse_us);
verifyEqual(t, timing.nominal_exposure_duty_cycle, timing.nominal_exposure_on_time_us / timing.scheduled_cycle_us, 'AbsTol', 1e-12);
verifyTrue(t, timing.is_lower_bound);
verifyEqual(t, timing.parameter_status, 'assumed');
verifyNotEmpty(t, strfind(lower(timing.description), 'lower bound'));
verifyEqual(t, timing.scheduled_total_us, cfg.timing.initial_settle_us + cfg.sequence.num_frames * timing.scheduled_cycle_us, 'AbsTol', 1e-9);
verifyGreaterThanOrEqual(t, timing.scheduled_cycle_us, cfg.imaging.frame_period_us + cfg.timing.receive_recovery_us + meta.num_foci * cfg.timing.recharge_us);
% A final group transmit never leaves a pending PRI timer across a switch.
for n = 2:numel(events)
    if ismember(timing.event_rows(n).kind, {'imaging_complete', 'exposure_complete'})
        verifyFalse(t, any(strcmp(eventCommands(events(n-1), controls), 'timeToNextAcq')));
    end
end
end

function testReturnCadenceAndImagingFrameBounds(t)
[cfg, meta] = fixture();
cfg.mode = 'imaging_only';
cfg.sequence.num_frames = 5;
cfg.sequence.return_every_frames = 2;
[events, controls, timing] = icevs.compile_events(cfg, meta);
returns = [];
for n = 1:numel(events)
    if any(strcmp(eventCommands(events(n), controls), 'returnToMatlab'))
        verifyEqual(t, [events(n).recon events(n).process], [1 1]);
        returns(end+1) = timing.event_rows(n).frame; %#ok<AGROW>
    end
end
verifyEqual(t, returns, [2 4]);
verifyGreaterThanOrEqual(t, timing.scheduled_cycle_us, cfg.imaging.frame_period_us);
end

function testDefaultsProduceThirtyFiniteFrames(t)
[~, meta] = fixture();
[events, controls, timing] = icevs.compile_events(struct('mode', 'imaging_only'), meta);
verifyEqual(t, sum([events.rcv] > 0), 30 * meta.num_angles);
verifyEqual(t, timing.num_frames, 30);
verifyEqual(t, timing.scheduled_cycle_us, 20000);
verifyEqual(t, timing.initialization_us, 5000);
verifyEqual(t, sum(arrayfun(@(e) any(strcmp(eventCommands(e, controls), ...
    'returnToMatlab')), events)), 10);
verifyEqual(t, eventCommands(events(end), controls), {'stop'});
end

function testShortPriAndInvalidConfigurationRejected(t)
[cfg, meta] = fixture();
cfg.mode = 'interleaved';
bad = cfg; bad.imaging.pri_us = 99;
verifyError(t, @() icevs.compile_events(bad, meta), 'icevs:Timing');
bad = cfg; bad.exposure.pri_us = 7;
verifyError(t, @() icevs.compile_events(bad, meta), 'icevs:Timing');
bad = cfg; bad.imaging.frame_period_us = 800;
verifyError(t, @() icevs.compile_events(bad, meta), 'icevs:Timing');
bad = cfg; bad.sequence.num_frames = Inf;
verifyError(t, @() icevs.compile_events(bad, meta), 'icevs:Config');
bad = cfg; bad.exposure.pulses_per_focus = 1.5;
verifyError(t, @() icevs.compile_events(bad, meta), 'icevs:Config');
bad = cfg; bad.timing.profile_settle_us = -1;
verifyError(t, @() icevs.compile_events(bad, meta), 'icevs:Config');
bad = cfg; bad.imaging.pri_us = NaN;
verifyError(t, @() icevs.compile_events(bad, meta), 'icevs:Config');
bad = cfg; bad.exposure.tpc_profile = 6;
verifyError(t, @() icevs.compile_events(bad, meta), 'icevs:Config');
badmeta = meta; badmeta.exposure_tx_indices = 1;
verifyError(t, @() icevs.compile_events(cfg, badmeta), 'icevs:Metadata');
end

function commands = eventCommands(event, controls)
indices = event.seqControl;
indices = indices(indices > 0);
commands = {controls(indices).command};
end

function [cfg, meta] = fixture()
cfg.mode = 'interleaved';
cfg.sequence = struct('num_frames', 2, 'return_every_frames', 1);
cfg.imaging = struct('pri_us', 400, 'frame_period_us', 20000, 'tpc_profile', 1);
cfg.exposure = struct('pri_us', 1000, 'pulses_per_focus', 4, 'tpc_profile', 1);
cfg.timing = struct('initial_settle_us', 5000, 'profile_settle_us', 5000, ...
    'receive_recovery_us', 2000, 'recharge_us', 10000);
meta = struct('num_angles', 3, 'num_foci', 2, 'imaging_tx_indices', 1:3, ...
    'exposure_tx_indices', 4:5, 'receive_end_us', 100, ...
    'exposure_end_us', 8, 'nominal_exposure_pulse_us', 5);
end
