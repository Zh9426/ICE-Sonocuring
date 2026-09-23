function tests = test_adapters
tests = functiontests(localfunctions);
end

function setupOnce(~)
root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root,'adapters'));
end

function testHandoffRoundTripPreservesDimensionsAndUnits(t)
[g,s,c] = fixture();
filename = [tempname '.json'];
cleanup = onCleanup(@() deleteIfExists(filename));
h = iceio.export_handoff(g,s,c,filename);
r = jsondecode(fileread(filename));
verifyFalse(t, r.executable);
verifyEqual(t, r.schema_version, 'ice-handoff-1.0');
verifyEqual(t, r.geometry.positions_m, g.positions_m);
verifyEqual(t, r.units.position, 'm');
verifyEqual(t, r.units.delay, 's');
verifyEqual(t, r.units.normal_velocity, 'm/s');
verifyEqual(t, r.sequence.shots(1).delay_s, s.shots(1).delay_s);
verifyEqual(t, r.sequence.shots(1).weights_real, real(s.shots(1).weights));
verifyEqual(t, r.sequence.shots(1).weights_imag, imag(s.shots(1).weights));
verifyEqual(t, r.sequence.shots(1).normal_velocity_before_delay_imag_m_s, c.source.velocity_m_s*imag(s.shots(1).weights));
verifyEqual(t, r.sequence.dwell_weights, s.dwell_weights);
verifyEqual(t, r.sequence.mode, s.mode);
verifyEqual(t, r.exposure.duty_cycle, c.exposure.duty_cycle);
verifyFalse(t, r.source.calibrated);
verifyEqual(t, size(h.hardware.element_to_channel), [2 1]);
verifyTrue(t, all(isnan(h.hardware.element_to_channel)));
verifyEqual(t, r.hardware.tx_delay_conversion_status, 'unknown_requires_backend_documentation');
verifyEqual(t, r.source.calibration_note, c.source.calibration_note);
end

function testMismatchedElementDimensionsRejected(t)
[g,s,c] = fixture(); s.shots(1).delay_s = 0;
verifyError(t, @() iceio.export_handoff(g,s,c,''), 'iceio:InvalidSequence');
end

function testIncompleteDeviceValuesRejected(t)
[g,s,c] = fixture(); c.source.velocity_m_s = NaN;
verifyError(t, @() iceio.export_handoff(g,s,c,''), 'iceio:InvalidConfig');
end

function testKwavePreparationReportsUnimplementedRequirements(t)
[g,s,c] = fixture();
r = iceio.prepare_kwave_input(g,s,c);
verifyFalse(t, r.ready_to_run);
verifyEqual(t, r.status, 'requirements_only');
verifyTrue(t, any(strcmp(r.required_decisions, 'grid_resolution_and_pml')));
verifyTrue(t, any(strcmp(r.required_decisions, 'source_velocity_to_grid_mapping')));
verifyFalse(t, isfield(r,'pressure'));
verifyFalse(t, r.handoff.executable);
end

function [g,s,c] = fixture()
g = struct('positions_m',[-0.001 0 0;0.001 0 0], 'width_m', [0.0008;0.0008], ...
    'height_m',[0.003;0.003], 'grid_indices',[1 1;2 1], 'shape',[2 1], 'normal',[0 0 1]);
shot = struct('weights',[1;1i],'delay_s',[0;1e-7],'focus_m',[0 0 0.01]);
s = struct('shots',[shot shot],'dwell_weights',[0.25;0.75],'mode','expanded_focus');
c = struct('source',struct('velocity_m_s',0.01,'calibrated',false,'calibration_note','Synthetic example'), ...
    'acoustics',struct('frequency_hz',5e6,'sound_speed_m_s',1500,'density_kg_m3',1000), ...
    'exposure',struct('duty_cycle',0.1,'exposure_time_s',1));
end

function deleteIfExists(filename)
if isfile(filename), delete(filename); end
end
