function tests = test_curing_gpu_validation_20261111
%TEST_CURING_GPU_VALIDATION_20261111 Unit tests for the additive BLI setup.
% These tests do not run kspaceFirstOrder3D, kspaceFirstOrder3DG, VSX or any
% hardware. They verify the small additive BLI problem, the multi-source
% delays, the non-cubic grid, the record-field policy, and that a missing GPU
% binary fails instead of silently falling back to a CPU result.
tests = functiontests(localfunctions);
end

function setupOnce(t)
td = fileparts(mfilename('fullpath'));
root = fileparts(td);
addpath(root);
kw = fullfile(root, 'dependencies', 'k-wave-1.4.1', 'k-Wave');
assert(isfolder(kw), 'Test requires the bundled k-Wave toolbox.');
addpath(kw);
t.TestData.root = root;
end

function testPrepareOnlyAdditiveBliDelays(t)
out = curing_gpu_validation_20261111(struct('prepare_only', true));
p = out.prepare;

verifyEqual(t, out.mode, 'prepare_only');
verifyEqual(t, out.source_mode, 'additive');
verifyEqual(t, p.source_mode, 'additive');
verifyEqual(t, p.num_elements, 3);
verifyGreaterThanOrEqual(t, p.num_elements, 2);
verifyEqual(t, p.n, [30 24 20]);
verifyGreaterThan(t, numel(unique(p.n)), 1);
verifyEqual(t, p.delay_samples, [0 16 32]);
verifyEqual(t, numel(unique(p.delay_samples)), p.num_elements);
verifyEqual(t, p.delays_s, p.delay_samples * p.dt_s, 'AbsTol', 1e-18);

verifyEqual(t, p.bli.type, 'sinc');
verifyEqual(t, p.bli.tolerance, 0.05);
verifyEqual(t, p.bli.upsampling_rate, 10);
verifyTrue(t, p.bli.single_precision);
verifyGreaterThan(t, p.bli.mask_nonzero_points, 0);
verifyLessThanOrEqual(t, p.bli.max_weight_sum_error, 0.10);

verifyFalse(t, p.support.touches_boundary);
verifyGreaterThanOrEqual(t, p.support.min_margin_cells, 1);
verifyGreaterThan(t, p.support_margin_m.x_lo, 0);
verifyGreaterThan(t, p.support_margin_m.x_hi, 0);
verifyGreaterThan(t, p.support_margin_m.y_lo, 0);
verifyGreaterThan(t, p.support_margin_m.y_hi, 0);
verifyGreaterThan(t, p.support_margin_m.z_lo, 0);
verifyGreaterThan(t, p.support_margin_m.z_hi, 0);

verifyTrue(t, p.distributed_source.mask_rows_match);
verifyGreaterThan(t, p.distributed_source.rows, 0);
verifyEqual(t, p.distributed_source.columns, p.signal_samples);
verifyEqual(t, p.distributed_source.class, 'single');
verifyLessThanOrEqual(t, p.distributed_source.max_direct_sum_relative_error, 1e-5);

verifyEqual(t, p.record_fields_requested, {'p'});
verifyTrue(t, any(strcmp(p.record_fields_not_requested, 'p_rms')));
verifyTrue(t, any(strcmp(p.record_fields_not_requested, 'p_max_all')));
verifyFalse(t, isempty(strfind(p.record_field_policy, 'no CPU'))); % policy text
verifyFalse(t, isempty(strfind(p.source_mode_definition, 'Dirichlet')));

verifyLessThanOrEqual(t, p.signal_samples, p.time_window.Nt);
verifyGreaterThanOrEqual(t, p.time_window.t_end_s, p.time_window.required_end_s);
verifyGreaterThan(t, p.time_window.one_way_bound_s, 0);
verifyLessThanOrEqual(t, p.onset_max_error_s, 2*p.dt_s + 1e-12);
end

function testMissingGpuBinaryFailsWithoutCpuFallback(t)
missingDir = fullfile(t.TestData.root, 'dependencies', ...
    sprintf('iceind_missing_cuda_%d', randi(1e9)));
verifyError(t, @() curing_gpu_validation_20261111(struct( ...
    'binary_path', missingDir, ...
    'binary_name', 'kspaceFirstOrder-CUDA-windows.exe')), ...
    'iceind:GPUNotDeployed');
end

function testPrepareOnlyDoesNotCreateOutputDirectory(t)
outRoot = fullfile(tempdir, sprintf('iceind_prepare_only_%d', randi(1e9)));
out = curing_gpu_validation_20261111(struct( ...
    'prepare_only', true, 'output_root', outRoot));
verifyEqual(t, out.mode, 'prepare_only');
verifyFalse(t, isfolder(outRoot));
end

function testWindowIndicesAreConfigured(t)
out = curing_gpu_validation_20261111(struct('prepare_only', true));
verifyEqual(t, out.prepare.start_indices, [1 37]);
end

function testCustomStartIndicesAcceptedForPrepareOnly(t)
out = curing_gpu_validation_20261111(struct( ...
    'prepare_only', true, 'start_indices', [1]));
verifyEqual(t, out.prepare.start_indices, 1);
end

function testUntrustedOutputRootRejected(t)
verifyError(t, @() curing_gpu_validation_20261111(struct( ...
    'output_root', tempdir)), 'iceind:GPUPathUntrusted');
end

function testShellUnsafeOutputRootRejected(t)
badRoot = fullfile(t.TestData.root, 'results', 'curing_gpu_bad&dir');
verifyError(t, @() curing_gpu_validation_20261111(struct( ...
    'output_root', badRoot)), 'iceind:GPUPathUntrusted');
end

function testHdf5SourceIndexAndAdditiveScale(t)
out = curing_gpu_validation_20261111(struct('prepare_only', true));
p = out.prepare;
h = p.hdf5_source_check;
n = p.n;
pml = p.pml_cells;

% PMLInside=false: the saved index is in the expanded grid, not the original.
maskIndex = find(p.mask);
[ix, iy, iz] = ind2sub(n, maskIndex);
expectedIndex = sub2ind(n + 2*pml, ix + pml, iy + pml, iz + pml);
verifyEqual(t, h.original_mask_index, maskIndex);
verifyEqual(t, h.expected_source_index, expectedIndex);
verifyGreaterThan(t, numel(expectedIndex), 0);
verifyFalse(t, isequal(h.expected_source_index, maskIndex));
k = maskIndex(1);
[a, b, c] = ind2sub(n, k);
verifyEqual(t, h.expected_source_index(1), ...
    sub2ind(n + 2*pml, a + pml, b + pml, c + pml));

% Additive p_source_input is scaled by 2*dt/(3*c0*dx) before saving.
factor = 2*p.dt_s/(3*p.medium.sound_speed*p.dx_m);
verifyEqual(t, h.source_scale_factor, factor, 'RelTol', 1e-14);
verifyNotEqual(t, h.source_scale_factor, 1);
verifyNotEqual(t, h.source_scale_factor, ...
    2*p.dt_s/(p.medium.sound_speed*p.dx_m));       % missing /3
verifyNotEqual(t, h.source_scale_factor, ...
    p.dt_s/(3*p.medium.sound_speed*p.dx_m));       % missing factor 2
end
