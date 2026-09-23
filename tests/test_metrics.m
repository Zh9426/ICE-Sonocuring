function tests = test_metrics
tests = functiontests(localfunctions);
end

function setupOnce(~)
root = fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root, 'simulation'));
end

function testVolumeWeightedCoverageAndPopulationCV(t)
[e, th, src, ref] = fixture();
v = [1; 3; 2; 4] * 1e-9;
m = ice.evaluate_threshold(e, logical([1;1;0;0]), v, th, src, ref);
verifyEqual(t, m.target_coverage, 0.75, 'AbsTol', 1e-12);
verifyEqual(t, m.off_target_exposure, 2/3, 'AbsTol', 1e-12);
verifyEqual(t, m.target_uniformity_cv, sqrt(0.75)/2.5, 'AbsTol', 1e-12);
verifyEqual(t, m.target_mean, 2.5, 'AbsTol', 1e-12);
verifyEqual(t, m.target_volume_m3, 4e-9, 'AbsTol', 1e-20);
verifyEqual(t, m.off_target_volume_m3, 6e-9, 'AbsTol', 1e-20);
verifyEqual(t, m.above_threshold_volume_m3, 7e-9, 'AbsTol', 1e-20);
verifyEqual(t, m.threshold_value_si, 2);
verifyEqual(t, m.threshold_units, 'Pa');
verifyEqual(t, m.threshold_mask, logical([0;1;0;1]));
verifyEqual(t, m.status.target_coverage, 'ok');
end

function testReferenceIsNotPerFieldRenormalized(t)
[e, th, src, ref] = fixture();
ref.pressure_peak_pa = 20;
m = ice.evaluate_threshold(e, true(4,1), 1, th, src, ref);
verifyEqual(t, m.target_coverage, 0);
verifyEqual(t, m.threshold_value_si, 10);
end

function testIntensityBasisIsExplicitAndUsesOwnReference(t)
[e, th, src, ref] = fixture();
th.type = 'intensity'; th.intensity_basis = 'temporal_average';
m = ice.evaluate_threshold(e, true(4,1), 1, th, src, ref);
verifyEqual(t, m.threshold_value_si, 0.2, 'AbsTol', 1e-14);
verifyEqual(t, m.target_mean, mean(e.intensity_temporal_average_w_m2), 'AbsTol', 1e-14);
verifyEqual(t, m.threshold_units, 'W/m^2');
th = rmfield(th, 'intensity_basis');
verifyError(t, @() ice.evaluate_threshold(e, true(4,1), 1, th, src, ref), 'ice:InvalidThreshold');
end

function testAbsoluteRequiresCalibrationAndProvenance(t)
[e, th, src, ref] = fixture(); th.scale = 'absolute';
verifyError(t, @() ice.evaluate_threshold(e, true(4,1), 1, th, src, ref), 'ice:UncalibratedAbsoluteThreshold');
src.calibrated = true; src.calibration_note = ' ';
verifyError(t, @() ice.evaluate_threshold(e, true(4,1), 1, th, src, ref), 'ice:UncalibratedAbsoluteThreshold');
src.calibration_note = 'Synthetic calibrated fixture, not a device measurement';
m = ice.evaluate_threshold(e, true(4,1), 1, th, src, struct());
verifyEqual(t, m.threshold_value_si, th.value);
end

function testEmptyRegionsAndZeroField(t)
[e, th, src, ref] = fixture();
m = ice.evaluate_threshold(e, false(4,1), 1, th, src, ref);
verifyTrue(t, isnan(m.target_coverage));
verifyTrue(t, isnan(m.target_uniformity_cv));
verifyEqual(t, m.status.target_coverage, 'empty_target');
m = ice.evaluate_threshold(e, true(4,1), 1, th, src, ref);
verifyTrue(t, isnan(m.off_target_exposure));
verifyEqual(t, m.status.off_target_exposure, 'empty_off_target');
e.pressure_peak_pa(:) = 0;
m = ice.evaluate_threshold(e, true(4,1), 1, th, src, ref);
verifyEqual(t, m.target_coverage, 0);
verifyTrue(t, isnan(m.target_uniformity_cv));
verifyEqual(t, m.status.target_uniformity_cv, 'zero_target_mean');
th.value = 0;
m = ice.evaluate_threshold(e, true(4,1), 1, th, src, ref);
verifyEqual(t, m.target_coverage, 1);
end

function testMetricInputValidation(t)
[e, th, src, ref] = fixture();
verifyError(t, @() ice.evaluate_threshold(e, [1;1;0;0], 1, th, src, ref), 'ice:InvalidTargetMask');
verifyError(t, @() ice.evaluate_threshold(e, true(4,1), [1;0;1;1], th, src, ref), 'ice:InvalidVoxelVolume');
ref.pressure_peak_pa = 0;
verifyError(t, @() ice.evaluate_threshold(e, true(4,1), 1, th, src, ref), 'ice:InvalidReference');
end

function testInterpolatedMinusSixDbWidth(t)
x = (-2:2)'; a = [0;0.5;1;0.5;0];
b = ice.beam_metrics(x,a,0);
verifyEqual(t, b.width_6db_m, 4*(1-10^(-6/20)), 'AbsTol', 1e-12);
verifyEqual(t, b.main_peak_position_m, 0);
verifyFalse(t, b.left_boundary_truncated);
verifyFalse(t, b.right_boundary_truncated);
verifyFalse(t, b.secondary_peak_available);
verifyTrue(t, isnan(b.secondary_peak_db));
end

function testNearestLocalPeakDefinesConnectedMainLobe(t)
x = (0:8)'; a = [0;0.4;0.1;0.8;1;0.8;0.1;0.3;0];
b = ice.beam_metrics(x,a,0.9);
verifyEqual(t, b.main_peak_position_m, 1);
verifyEqual(t, b.main_peak, 0.4);
verifyLessThan(t, b.width_6db_m, 2);
b = ice.beam_metrics(x,a,4);
verifyTrue(t, b.secondary_peak_available);
verifyEqual(t, b.secondary_peak_db, 20*log10(0.4), 'AbsTol', 1e-12);
verifyEqual(t, b.main_lobe_bounds_m, [2 6]);
end

function testUnbracketedTailIsNotSecondaryPeak(t)
x = (-2:2)'; a = [0.3;0.8;1;0.8;0.3];
b = ice.beam_metrics(x,a,0);
verifyFalse(t, b.secondary_peak_available);
verifyEqual(t, b.secondary_peak_status, 'unbracketed_main_lobe');
verifyTrue(t, isnan(b.secondary_peak_db));
end

function testBoundaryTruncatedWidthIsUnavailable(t)
b = ice.beam_metrics((0:3)', [1;0.9;0.8;0.7], 0);
verifyTrue(t, isnan(b.width_6db_m));
verifyTrue(t, b.left_boundary_truncated);
verifyTrue(t, b.right_boundary_truncated);
end

function testZeroProfileAndValidation(t)
b = ice.beam_metrics((0:3)', zeros(4,1), 1.5);
verifyTrue(t, isnan(b.width_6db_m));
verifyTrue(t, isnan(b.secondary_peak_db));
verifyEqual(t, b.status, 'zero_field');
verifyError(t, @() ice.beam_metrics([0;2;1], [1;2;1], 1), 'ice:InvalidBeamProfile');
end

function testPlateauMainPeakHasFiniteConnectedWidth(t)
b = ice.beam_metrics((0:8)', [0;0.1;0.5;1;1;1;0.5;0.1;0], 4);
verifyEqual(t, b.main_peak_position_m, 4);
verifyEqual(t, b.main_peak, 1);
verifyEqual(t, b.width_6db_m, 6-4*10^(-6/20), 'AbsTol', 1e-12);
end

function testProfileBoundaryCannotCertifySecondaryMaximum(t)
b = ice.beam_metrics((0:8)', [0.7;0.5;0.1;0.8;1;0.8;0.1;0.2;0.4], 4);
verifyFalse(t, b.secondary_peak_available);
verifyTrue(t, b.secondary_peak_at_boundary);
verifyTrue(t, isnan(b.secondary_peak_db));
verifyEqual(t, b.secondary_peak_status, 'secondary_peak_truncated');
end

function [e, th, src, ref] = fixture()
e = struct('pressure_peak_pa', [1;3;0;4], ...
    'intensity_pulse_average_w_m2', [0.1;0.9;0;1.6], ...
    'intensity_temporal_average_w_m2', [0.01;0.09;0;0.16]);
th = struct('type','pressure','scale','relative','value',0.5);
src = struct('calibrated',false,'calibration_note','');
ref = struct('pressure_peak_pa',4, 'intensity_pulse_average_w_m2',4, ...
    'intensity_temporal_average_w_m2',0.4);
end
