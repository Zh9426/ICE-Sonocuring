function out = curing_gpu_validation_20261111(opts)
%CURING_GPU_VALIDATION_20261111 Minimal auditable CPU/CUDA numerical comparison.
%
% Purpose
%   Build ONE small, non-cubic 3-D k-Wave problem with a band-limited (BLI)
%   finite-rectangle source array (three elements, distinct integer-sample
%   delays) in the same additive source mode used by the curing driver
%   (source.p_mode = 'additive'; the source is NOT converted to a Dirichlet
%   boundary condition). The same kgrid/medium/source/sensor inputs are then
%   run with:
%       CPU  : MATLAB kspaceFirstOrder3D
%       GPU  : kspaceFirstOrder3DG (kspaceFirstOrder3DC wrapper) pointed at
%              dependencies/kwave-cuda-unified-v1.4.2/
%              kspaceFirstOrder-CUDA-windows.exe
%
%   For every requested record_start_index (default 1 and 37) the complete
%   recorded pressure time series p(t) is stored for both solvers, and peaks,
%   per-point Qp = dt * sum_t p(t).^2, coordinates, runtimes, versions and
%   relative errors are written to a new, timestamped directory below
%   independent_simulation/results/curing_gpu_validation_20261111/.
%
% GPU proof (no silent CPU substitution)
%   kspaceFirstOrder3DC (and therefore 3DG) calls the executable with
%   system(...) but does NOT expose the child process exit code. To check the
%   real exit code and the real executable output, this function additionally
%   invokes the SAME CUDA executable directly on the SAME input HDF5 file that
%   the 3DG wrapper just wrote (a "direct audit" run). The direct run's exit
%   code, console log, GPU/CUDA marker and output are recorded; its /p dataset
%   must agree with the wrapper's /p within the declared tolerance (not a
%   byte-identical claim). If the direct run fails, if the executable is
%   absent, if the console does not identify CUDA/GPU, or if the two outputs
%   differ beyond tolerance, the function fails loudly. It never falls back to
%   a MATLAB CPU result and never labels a CPU run as GPU. The additive input
%   HDF5 is also checked for PML-expanded source indices, source-point count,
%   source time length, and the 2*dt/(3*c0*dx) saveToDisk scaling, not merely
%   p_source_many=1.
%
%   Only the raw field 'p' is requested from both solvers. Peaks and Qp are
%   computed from that complete series on both sides. Binary accumulator fields
%   (p_rms, p_max_all, p_min_all) are deliberately NOT requested and are NOT
%   substituted for a missing field; if '/p' is absent from the GPU output the
%   run fails with the available dataset names in the error message.
%
% Path scope
%   Custom output_root and binary_path are resolved to absolute canonical paths
%   and must stay inside the project root. Windows shell metacharacters are
%   rejected. A new timestamp directory is created only if it is empty; existing
%   files are never deleted. The direct CUDA output is hashed before deletion,
%   or kept when opts.keep_direct_output is true.
%
% Record fields and semantics
%   CPU and GPU both request: sensor.record = {'p'} and the same
%   sensor.record_start_index. A requested field that is missing from the GPU
%   output is a hard error. Qp from a start index > 1 is a Qp over the recorded
%   window only; it is labelled qp_recorded_* and qp_scope='recorded_window',
%   never described as the full-time Qp.
%
% Scope / status
%   Small synthetic/assumed consistency problem only. Homogeneous lossless
%   fluid, flat rectangular pressure sources, 1 Pa assumed per element. This is
%   not a calibrated transducer, not acoustic power or energy, not heating,
%   dose, safety or cure, and not a hardware/VSX test. Runtimes include HDF5
%   I/O and process launch; they are not a benchmark.
%
% Usage
%   curing_gpu_validation_20261111                 % full CPU/CUDA comparison
%   out = curing_gpu_validation_20261111();        % summary + per-start data
%   out = curing_gpu_validation_20261111(struct('prepare_only',true));
%       % build/verify the additive BLI source only; no solver, no GPU, no
%       % result directory. Used by the unit test.
%
% Optional opts fields (defaults in local_options)
%   prepare_only, keep_direct_output, output_root, binary_path, binary_name,
%   device_num, verbose_level, start_indices, pml_cells, cfl, time_margin_s,
%   geometry.n, geometry.dx_m, medium.*, source.*, bli.*, tolerances.*
%
% See also kspaceFirstOrder3D, kspaceFirstOrder3DG, kspaceFirstOrder3DC,
%          kWaveArray, curing_qp_rms_probe_20261110, iceind.curing_bli_prepare.

if nargin < 1 || isempty(opts)
    opts = struct();
end
opts = local_options(opts);

root = fileparts(mfilename('fullpath'));
oldPath = path;
cleanupPath = onCleanup(@() path(oldPath)); %#ok<NASGU>
kwPath = fullfile(root, 'dependencies', 'k-wave-1.4.1', 'k-Wave');
assert(isfolder(kwPath), 'iceind:KWaveMissing', ...
    sprintf('k-Wave toolbox folder not found: %s', kwPath));
addpath(kwPath);

if isempty(opts.output_root)
    opts.output_root = fullfile(root, 'results', 'curing_gpu_validation_20261111');
end
if isempty(opts.binary_path)
    opts.binary_path = fullfile(root, 'dependencies', 'kwave-cuda-unified-v1.4.2');
end

projectRoot = fileparts(root);
opts.output_root = local_resolve_path(opts.output_root, root);
opts.binary_path = local_resolve_path(opts.binary_path, root);
if ~opts.prepare_only
    assert(local_is_within(opts.output_root, projectRoot), ...
        'iceind:GPUPathUntrusted', ...
        sprintf(['output_root must stay inside the project root %s; got %s. ' ...
        'Custom output paths outside the project are refused.'], ...
        projectRoot, opts.output_root));
    assert(local_is_within(opts.binary_path, projectRoot), ...
        'iceind:GPUPathUntrusted', ...
        sprintf(['binary_path must stay inside the project root %s; got %s. ' ...
        'Custom binary paths outside the project are refused.'], ...
        projectRoot, opts.binary_path));
    local_assert_shell_safe_path(opts.output_root, 'output_root');
    local_assert_shell_safe_path(opts.binary_path, 'binary_path');
    assert(isempty(strfind(opts.binary_name, '/')) && ...
        isempty(strfind(opts.binary_name, char(92))), ...
        'iceind:GPUPathUntrusted', ...
        sprintf(['binary_name must be a bare filename without path separators: ' ...
        '%s'], opts.binary_name));
end

fprintf('\n=== curing_gpu_validation_20261111 ===\n');
fprintf('k-Wave path : %s\n', kwPath);
fprintf('MATLAB      : %s (%s)\n', version(), version('-release'));

% ------------------------------------------------------------------
% Prepare-only mode: build and verify the additive BLI source.
% No solver is called and no output directory is created.
% ------------------------------------------------------------------
if opts.prepare_only
    t0 = tic;
    [kg, medium, source, sensor, prep] = local_prepare(opts);
    prep.prepare_runtime_s = toc(t0); %#ok<NASGU>
    out = local_prepare_output(kg, source, prep);
    fprintf('prepare_only: elements=%d, delays (samples)=%s, mask points=%d, Nt=%d\n', ...
        prep.num_elements, mat2str(prep.delay_samples), ...
        prep.source_mask_nonzero_points, kg.Nt);
    if nargout == 0
        disp(out);
    end
    return
end

% ------------------------------------------------------------------
% GPU preflight BEFORE any simulation: do not assume deployment.
% ------------------------------------------------------------------
gpuInfo = local_gpu_preflight(opts);

tPrepare = tic;
[kg, medium, source, sensor, prep] = local_prepare(opts);
prepareRuntime = toc(tPrepare);
assert(all(opts.start_indices <= kg.Nt), 'iceind:GPUValidationInput', ...
    sprintf('start_indices %s exceed Nt=%d.', mat2str(opts.start_indices), kg.Nt));

outDir = local_make_output_dir(opts.output_root);
dataDir = fullfile(outDir, 'hdf5');
local_make_empty_dir(dataDir);
logFile = fullfile(outDir, 'matlab_console.log');
local_require_absent(logFile);
diary(logFile);
cleanupDiary = onCleanup(@() diary('off')); %#ok<NASGU>

summary = local_empty_summary(opts, gpuInfo, prep);
tTotal = tic;

try
    cfg = local_config(opts, kg, source, prep, gpuInfo, kwPath, outDir);
    runConfigFile = fullfile(outDir, 'run_config.json');
    local_require_absent(runConfigFile);
    local_write_json(runConfigFile, cfg);

    prepJsonFile = fullfile(outDir, 'prepare.json');
    prepMatFile = fullfile(outDir, 'prepare.mat');
    local_require_absent(prepJsonFile);
    local_require_absent(prepMatFile);
    prepForJson = local_prepare_json(prep);
    local_write_json(prepJsonFile, prepForJson);
    save(prepMatFile, 'kg', 'medium', 'source', 'sensor', 'prep', '-v7');

    results = struct([]);
    for si = 1:numel(opts.start_indices)
        startIndex = opts.start_indices(si);
        fprintf('\n--- record_start_index = %d ---\n', startIndex);

        cpu = local_run_cpu(kg, medium, source, sensor, startIndex, opts);
        gpu = local_run_gpu(kg, medium, source, sensor, startIndex, opts, ...
            gpuInfo, prep, outDir, dataDir);

        met = local_metrics(double(cpu.traces), double(gpu.traces), kg.dt, ...
            startIndex, opts.tolerances, cpu.sensor_xyz_m);
        met.cpu_runtime_s = cpu.runtime_s;
        met.gpu_wrapper_runtime_s = gpu.wrapper_runtime_s;
        met.gpu_direct_runtime_s = gpu.direct_runtime_s;
        met.gpu_direct_exit_code = gpu.direct_exit_code;
        met.gpu_wrapper_exit_code = 'not_exposed_by_kspaceFirstOrder3DC';
        met.gpu_evidence_ok = gpu.evidence_ok;
        met.gpu_console_gpu_marker = gpu.console_gpu_marker;
        met.gpu_console_version_line = gpu.console_version_line;
        met.gpu_console_log = gpu.console_log;
        met.gpu_wrapper_vs_direct_max_abs_pa = gpu.wrapper_vs_direct_max_abs_pa;
        met.gpu_wrapper_vs_direct_rel = gpu.wrapper_vs_direct_rel;
        met.gpu_wrapper_vs_direct_relation = gpu.wrapper_vs_direct_relation;
        met.direct_output_sha256 = gpu.direct_output_sha256;
        met.direct_output_bytes = gpu.direct_output_bytes;
        met.direct_output_kept = gpu.direct_output_kept;
        met.direct_output_h5 = gpu.direct_output_h5;
        met.source_points_in_input = gpu.source_points_in_input;
        met.source_samples_in_input = gpu.source_samples_in_input;
        met.source_matrix_orientation = gpu.source_matrix_orientation;
        met.source_matrix_max_rel_error = gpu.source_matrix_max_rel_error;
        met.source_scale_factor = gpu.source_scale_factor;
        met.input_h5 = gpu.input_h5;
        met.input_h5_sha256 = gpu.input_h5_sha256;
        met.wrapper_output_h5 = gpu.wrapper_output_h5;
        met.wrapper_output_sha256 = gpu.wrapper_output_sha256;
        met.source_mode_in_input = gpu.source_mode_in_input;
        met.cpu_mat = fullfile(outDir, sprintf('cpu_start%d.mat', startIndex));
        met.gpu_mat = fullfile(outDir, sprintf('gpu_start%d.mat', startIndex));
        met.point_qp_csv = fullfile(outDir, sprintf('point_qp_start%d.csv', startIndex));
        local_require_absent(met.cpu_mat);
        local_require_absent(met.gpu_mat);
        local_require_absent(met.point_qp_csv);
        met = local_status(met, opts.tolerances);

        results(si).start = startIndex; %#ok<AGROW>
        results(si).cpu = cpu; %#ok<AGROW>
        results(si).gpu = gpu; %#ok<AGROW>
        results(si).metrics = met; %#ok<AGROW>

        local_save_run(met.cpu_mat, cpu, kg, startIndex);
        local_save_run(met.gpu_mat, gpu, kg, startIndex);
        writetable(met.point_qp, met.point_qp_csv);

        fprintf(['CPU start=%d: samples=%d points=%d runtime=%.3f s | ' ...
            'GPU wrapper=%.3f s direct=%.3f s | time relL2=%.3g ' ...
            'Qp relL2=%.3g -> %s\n'], ...
            startIndex, met.recorded_samples, met.sensor_points, ...
            met.cpu_runtime_s, met.gpu_wrapper_runtime_s, ...
            met.gpu_direct_runtime_s, met.time_rel_l2, met.qp_rel_l2, ...
            met.status);
    end

    metTable = local_metrics_table(results);
    comparisonCsv = fullfile(outDir, 'comparison_metrics.csv');
    local_require_absent(comparisonCsv);
    writetable(metTable, comparisonCsv);

    wc = local_window_consistency(results, opts.tolerances);
    if ~isempty(wc.table) && ~isempty(wc.table.Properties.VariableNames)
        windowCsv = fullfile(outDir, 'window_consistency.csv');
        local_require_absent(windowCsv);
        writetable(wc.table, windowCsv);
    end

    % The executable must not change during the run.
    assert(strcmp(local_sha256(gpuInfo.binary_file), gpuInfo.sha256), ...
        'iceind:GPUBinaryChanged', ...
        ['The CUDA executable changed (or its hash became unreadable) during ' ...
        'the validation run.']);

    summary = local_summary(summary, results, metTable, wc, opts, kg, ...
        prepareRuntime, toc(tTotal));
    local_write_json(fullfile(outDir, 'validation_summary.json'), summary);

    out = summary;
    out.output_dir = outDir;
    out.results = results;

    fprintf('\n=== validation %s: %s ===\n', summary.overall_status, outDir);
    if ~summary.overall_pass
        error('iceind:GPUValidationTolerance', ...
            sprintf(['CPU/CUDA comparison did not meet the declared ' ...
            'tolerances or consistency criteria. See %s'], ...
            fullfile(outDir, 'validation_summary.json')));
    end
catch ME
    if ~isfield(summary, 'overall_status') || ~strcmp(summary.overall_status, 'FAIL')
        summary.overall_status = 'ERROR';
    end
    summary.overall_pass = false;
    summary.error_identifier = ME.identifier;
    summary.error_message = ME.message;
    summary.output_dir = outDir;
    try
        local_write_json(fullfile(outDir, 'validation_summary.json'), summary);
    catch
        % Do not mask the original error if the failure report cannot be written.
    end
    rethrow(ME);
end
end

% =========================================================================
% Problem construction
% =========================================================================
function [kg, medium, source, sensor, prep] = local_prepare(opts)
n = double(opts.geometry.n(:)');
dx = double(opts.geometry.dx_m);
c0 = double(opts.medium.sound_speed_m_s);
rho0 = double(opts.medium.density_kg_m3);
pml = double(opts.pml_cells);

kg = kWaveGrid(n(1), dx, n(2), dx, n(3), dx);
domain = n * dx;
dt = opts.cfl * dx / c0;          % k-Wave CFL definition for uniform dx

x = double(opts.source.element_x_m(:)');
y = double(opts.source.element_y_m(:)');
z = double(opts.source.element_z_m(:)');
if isscalar(y)
    y = repmat(y, 1, numel(x));
end
if isscalar(z)
    z = repmat(z, 1, numel(x));
end
assert(numel(y) == numel(x) && numel(z) == numel(x), ...
    'iceind:GPUValidationInput', 'Element coordinate vectors must match.');
width = double(opts.source.width_m);
height = double(opts.source.height_m);
f0 = double(opts.source.f0_hz);
cycles = double(opts.source.cycles);
delaySamples = double(opts.source.delay_samples(:)');

% ---- band-limited tone burst, delayed by whole grid samples ----
burstSamples = round(cycles / f0 / dt);
assert(burstSamples >= 8, 'iceind:GPUValidationInput', ...
    'The tone burst has fewer than 8 samples; increase f0 or cycles.');
tBurst = (0:burstSamples-1) * dt;
win = 0.5 * (1 - cos(2*pi*(0:burstSamples-1)/max(burstSamples-1, 1)));
wave = double(opts.source.amplitude_pa) * sin(2*pi*f0*tBurst) .* win;
nSamples = burstSamples + max(delaySamples);
sig = zeros(numel(x), nSamples, 'single');
for e = 1:numel(x)
    sig(e, delaySamples(e) + (1:burstSamples)) = single(wave);
end
assert(max(abs(sig(:))) > 0, 'iceind:GPUValidationSource', ...
    'The source signal is identically zero.');

% ---- finite rectangular elements represented with BLI ----
supportRadiusCells = ceil(1/(pi*opts.bli.tolerance));
supportRadius = supportRadiusCells * dx;
a = kWaveArray('BLITolerance', opts.bli.tolerance, ...
    'UpsamplingRate', opts.bli.upsampling_rate, ...
    'BLIType', opts.bli.type, ...
    'SinglePrecision', opts.bli.single_precision);
for e = 1:numel(x)
    a.addRectElement([x(e), y(e), z(e)], width, height, [0 0 0]);
end
assert(a.number_elements == numel(x), 'iceind:GPUValidationSource', ...
    'kWaveArray element count does not match the source geometry.');

mask = a.getArrayBinaryMask(kg);
assert(any(mask(:)) && nnz(mask) < prod(n), 'iceind:GPUValidationSource', ...
    'The band-limited source mask is empty or fills the whole domain.');
assert(~any(mask(1,:,:), 'all') && ~any(mask(end,:,:), 'all') && ...
    ~any(mask(:,1,:), 'all') && ~any(mask(:,end,:), 'all') && ...
    ~any(mask(:,:,1), 'all') && ~any(mask(:,:,end), 'all'), ...
    'iceind:GPUValidationBoundary', ...
    'The band-limited source support touches a physical-domain face.');

support = local_support(kg, mask);
assert(~support.touches_boundary, 'iceind:GPUValidationBoundary', ...
    'The band-limited source support touches the physical-domain boundary.');

% Geometric margins of the nominal rectangles and of the BLI support. Use the
% actual kWaveGrid coordinate limits: for an even N the coordinates are
% (-N/2:N/2-1)*dx, so the physical span is not symmetric about zero.
xLo = min(kg.x_vec); xHi = max(kg.x_vec);
yLo = min(kg.y_vec); yHi = max(kg.y_vec);
zLo = min(kg.z_vec); zHi = max(kg.z_vec);

geomMargin = struct();
geomMargin.x_lo = min(x) - width/2 - xLo;
geomMargin.x_hi = xHi - (max(x) + width/2);
geomMargin.y_lo = min(y) - height/2 - yLo;
geomMargin.y_hi = yHi - (max(y) + height/2);
geomMargin.z_lo = min(z) - zLo;
geomMargin.z_hi = zHi - max(z);
assert(all(cell2mat(struct2cell(geomMargin)) > 0), ...
    'iceind:GPUValidationBoundary', ...
    'A nominal source rectangle crosses a physical-domain face.');

supportMargin = struct();
supportMargin.x_lo = min(x) - width/2 - supportRadius - xLo;
supportMargin.x_hi = xHi - (max(x) + width/2 + supportRadius);
supportMargin.y_lo = min(y) - height/2 - supportRadius - yLo;
supportMargin.y_hi = yHi - (max(y) + height/2 + supportRadius);
supportMargin.z_lo = min(z) - supportRadius - zLo;
supportMargin.z_hi = zHi - (max(z) + supportRadius);
assert(all(cell2mat(struct2cell(supportMargin)) > 0), ...
    'iceind:GPUValidationBoundary', ...
    ['The conservative BLI support margin is not positive. Move the source ' ...
    'or enlarge the domain.']);

% Per-element weight sum: detects silent clipping even if no face is touched.
expectedWeightSum = width*height/dx^2;
weightError = zeros(1, numel(x));
for e = 1:numel(x)
    wt = a.getElementGridWeights(kg, e);
    total = double(sum(wt, 'all'));
    weightError(e) = (total - expectedWeightSum) / expectedWeightSum;
end
assert(max(abs(weightError)) <= 0.10, 'iceind:GPUValidationSource', ...
    sprintf(['The per-element BLI weight sum differs from area/dx^2 by up to ' ...
    '%.3g; this is far beyond the 5%% BLI truncation tolerance and suggests ' ...
    'clipping.'], max(abs(weightError))));

dist = a.getDistributedSourceSignal(kg, sig);
assert(isa(dist, 'single'), 'iceind:GPUValidationSource', ...
    'The distributed source is not single precision.');
assert(size(dist,1) == nnz(mask) && size(dist,2) == nSamples, ...
    'iceind:GPUValidationSource', ...
    'Distributed-source dimensions do not match mask points and signal samples.');
assert(all(isfinite(dist(:))), 'iceind:GPUValidationSource', ...
    'The distributed source contains non-finite values.');

% Direct weighted delayed-sum check at first, peak and last samples.
mag = max(abs(sig), [], 1);
first = find(mag > 0, 1, 'first');
[~, peakIndex] = max(mag);
checkColumns = unique([first, peakIndex, size(sig,2)]);
direct = zeros(nnz(mask), numel(checkColumns), 'single');
for e = 1:numel(x)
    wt = a.getElementGridWeights(kg, e);
    direct = direct + cast(wt(mask), 'single') * cast(sig(e, checkColumns), 'single');
end
directRelError = max(abs(direct - dist(:, checkColumns)), [], 'all') / ...
    max(1, max(abs(dist(:, checkColumns)), [], 'all'));
assert(directRelError <= 1e-5, 'iceind:GPUValidationSource', ...
    sprintf(['The distributed source does not equal the weighted delayed sum ' ...
    '(%.3g > 1e-5).'], directRelError));

% Onset/delay check with a common 1%-of-peak threshold.
onset = zeros(1, numel(x));
for e = 1:numel(x)
    peak = max(abs(sig(e,:)));
    idx = find(abs(sig(e,:)) > single(0.01*peak), 1, 'first');
    assert(~isempty(idx), 'iceind:GPUValidationSource', ...
        'A delayed element signal has no 1%-of-peak onset.');
    onset(e) = double(idx - 1) * dt;
end
[~, refElement] = min(delaySamples);
relativeOnset = onset - onset(refElement);
expectedRelativeDelay = (delaySamples - delaySamples(refElement)) * dt;
onsetError = max(abs(relativeOnset - expectedRelativeDelay));
assert(onsetError <= 2*dt + 1e-12, 'iceind:GPUValidationSource', ...
    'Per-element delays were not applied in element order.');

% ---- expected saved-HDF5 source index and additive scaling ----
% PMLInside=false embeds the original mask in the expanded PML grid before
% saveToDisk, so p_source_index is a 1-based column-major index in
% size(mask)+2*PMLSize, not in the original mask. The additive pressure
% source is also multiplied by 2*dt/(N*c0*dx) (N=3) by
% kspaceFirstOrder_scaleSourceTerms before it is written as p_source_input.
assert(kg.dim == 3, 'iceind:GPUValidationSource', ...
    'This check assumes a 3-D grid.');
assert(isscalar(c0) && kg.dx == kg.dy && kg.dy == kg.dz, ...
    'iceind:GPUValidationSource', ...
    'The saved-source scaling formula assumes a uniform isotropic grid.');
[ixMask, iyMask, izMask] = ind2sub(size(mask), find(mask));
pmlSize = [pml, pml, pml];
expandedSize = size(mask) + 2*pmlSize;
expectedSourceIndex = sub2ind(expandedSize, ...
    ixMask + pmlSize(1), iyMask + pmlSize(2), izMask + pmlSize(3));
sourceScaleFactor = 2*dt / (kg.dim * c0 * dx);
assert(max(abs(sourceScaleFactor)) > 0, 'iceind:GPUValidationSource', ...
    'The additive source scale factor is zero.');

% ---- conservative time window ----
% The farthest distance from any point of the BLI source support to any
% physical-domain corner. The actual grid limits are used (not domain/2), so
% an even N with asymmetric coordinates remains conservative.
sx = max(abs(x)) + width/2 + supportRadius;
sy = max(abs(y)) + height/2 + supportRadius;
xReach = max(abs([xLo, xHi])) + sx;
yReach = max(abs([yLo, yHi])) + sy;
zReach = max(abs([zLo, zHi])) + max(abs(z)) + supportRadius;
maxDistance = sqrt(xReach^2 + yReach^2 + zReach^2);
oneWay = maxDistance / c0;
sourceTailEnd = (nSamples - 1) * dt;
requiredEnd = sourceTailEnd + oneWay + opts.time_margin_s;
Nt = ceil(requiredEnd/dt) + 1;
kg.setTime(Nt, dt);
assert(nSamples <= kg.Nt, 'iceind:GPUValidationTime', ...
    'The source signal is longer than the simulation time axis.');
assert(kg.t_array(end) >= requiredEnd - 1e-12, 'iceind:GPUValidationTime', ...
    'The simulation time window is shorter than the conservative bound.');

medium = struct('sound_speed', c0, 'density', rho0);
sensor = struct();
sensor.mask = true(n);
sensor.record = {'p'};
sensor.record_start_index = 1;

source = struct();
source.p_mask = mask;
source.p = dist;
source.p_mode = 'additive';

prep = struct();
prep.schema_version = 1;
prep.case_tag = 'curing_gpu_validation_20261111';
prep.model_status = 'synthetic_assumed';
prep.n = n;
prep.dx_m = dx;
prep.domain_m = domain;
prep.pml_cells = pml;
prep.cfl = opts.cfl;
prep.dt_s = dt;
prep.medium = medium;
prep.source_mode = source.p_mode;
prep.source_mode_definition = ['additive mass source; the same mode as ' ...
    'iceind.curing_bli_prepare, not converted to Dirichlet'];
prep.source_model = 'band_limited_finite_rectangles_additive_no_lens';
prep.num_elements = numel(x);
prep.element_positions_m = [x(:), y(:), z(:)];
prep.element_width_m = width;
prep.element_height_m = height;
prep.delay_samples = delaySamples;
prep.delays_s = delaySamples * dt;
prep.source_signal = sig;
prep.mask = mask;
prep.source_mask_nonzero_points = nnz(mask);
prep.waveform = struct( ...
    'f0_hz', f0, ...
    'cycles', cycles, ...
    'amplitude_pa', double(opts.source.amplitude_pa), ...
    'amplitude_definition', 'assumed equal reference pressure per element; not voltage calibrated', ...
    'burst_samples', burstSamples, ...
    'signal_samples', nSamples, ...
    'dt_s', dt, ...
    'shape', 'Hann-windowed sine burst, whole-sample delays');
prep.signal_samples = nSamples;
prep.signal_peak_pa = max(abs(sig), [], 2)';
prep.signal_onset_s = onset;
prep.relative_onset_s = relativeOnset;
prep.expected_relative_delay_s = expectedRelativeDelay;
prep.onset_max_error_s = onsetError;
prep.bli = struct( ...
    'type', opts.bli.type, ...
    'tolerance', opts.bli.tolerance, ...
    'upsampling_rate', opts.bli.upsampling_rate, ...
    'single_precision', opts.bli.single_precision, ...
    'support_radius_cells', supportRadiusCells, ...
    'support_radius_m', supportRadius, ...
    'mask_nonzero_points', nnz(mask), ...
    'expected_weight_sum_area_over_dx2', expectedWeightSum, ...
    'per_element_weight_sum_error', weightError, ...
    'max_weight_sum_error', max(abs(weightError)));
prep.support = support;
prep.hdf5_source_check = struct( ...
    'pml_cells', pml, ...
    'expanded_size', expandedSize, ...
    'original_mask_index', find(mask), ...
    'expected_source_index', expectedSourceIndex, ...
    'source_scale_factor', sourceScaleFactor, ...
    'index_definition', ['PMLInside=false: sub2ind(size(mask)+2*PMLSize, ' ...
    'ix+PMLSize, iy+PMLSize, iz+PMLSize) in original find(mask) order'], ...
    'scale_definition', ['additive p_source_input uses 2*dt/(kgrid.dim*c0*dx) ' ...
    'from kspaceFirstOrder_scaleSourceTerms on a uniform isotropic grid']);
prep.grid_limits_m = struct('x_m', [xLo xHi], 'y_m', [yLo yHi], ...
    'z_m', [zLo zHi]);
prep.support_margin_m = supportMargin;
prep.geometry_margin_m = geomMargin;
prep.time_window = struct( ...
    'source_tail_end_s', sourceTailEnd, ...
    'one_way_bound_s', oneWay, ...
    'one_way_bound_definition', ['maximum distance from the BLI source support ' ...
    '(element half-size plus truncated-BLI support radius) to a physical-domain corner'], ...
    'margin_s', opts.time_margin_s, ...
    'required_end_s', requiredEnd, ...
    't_end_s', kg.t_array(end), ...
    'Nt', kg.Nt, ...
    'dt_s', dt);
prep.distributed_source = struct( ...
    'rows', size(dist,1), ...
    'columns', size(dist,2), ...
    'class', class(dist), ...
    'mask_rows_match', size(dist,1) == nnz(mask), ...
    'max_direct_sum_relative_error', directRelError, ...
    'direct_check_columns', checkColumns, ...
    'direct_check_definition', ['weighted delayed sum of all elements at the first, ' ...
    'peak and last signal samples']);
prep.record_fields_requested = {'p'};
prep.record_fields_not_requested = {'p_rms','p_max_all','p_min_all','p_final','u'};
prep.record_field_policy = ['Only raw p is requested from CPU and GPU. ' ...
    'Peaks and Qp are computed from the complete p(t) series on both sides. ' ...
    'If /p is missing from the GPU output, the run fails; no CPU result and ' ...
    'no alternative GPU accumulator field is substituted.'];
prep.start_indices = opts.start_indices;
prep.sensor_mask_definition = ['sensor.mask is all true on the n-cell physical ' ...
    'grid; PMLInside=false and PMLSize=pml keep the absorbing layer outside it'];
prep.assumptions = { ...
    'Homogeneous lossless fluid; no absorption, nonlinearity, lens, backing, coupling layer, container or SonoInk reaction.'; ...
    'Flat rectangular pressure sources with an assumed 1 Pa reference per element; not voltage calibrated.'; ...
    'Three elements with distinct whole-sample delays; the additive source signal is the BLI weighted delayed sum.'; ...
    'Pressure peaks and Qp are numerical proxies, not acoustic power, energy, heating, dose or cure.'};
end

function out = local_prepare_output(kg, source, prep)
out = struct();
out.mode = 'prepare_only';
out.prepare = prep;
out.source_mode = source.p_mode;
out.num_elements = prep.num_elements;
out.grid_size = prep.n;
out.dx_m = prep.dx_m;
out.dt_s = kg.dt;
out.Nt = kg.Nt;
out.delays_s = prep.delays_s;
out.delay_samples = prep.delay_samples;
out.record_fields_requested = prep.record_fields_requested;
out.record_fields_not_requested = prep.record_fields_not_requested;
out.note = ['prepare_only builds and verifies the additive BLI source; it does ' ...
    'not run kspaceFirstOrder3D or kspaceFirstOrder3DG and makes no numerical ' ...
    'comparison.'];
end

% =========================================================================
% CPU run
% =========================================================================
function r = local_run_cpu(kg, medium, source, sensor, startIndex, opts)
s = sensor;
s.record = {'p'};
s.record_start_index = startIndex;

t0 = tic;
data = kspaceFirstOrder3D(kg, medium, source, s, ...
    'PMLInside', false, ...
    'PMLSize', opts.pml_cells, ...
    'PlotSim', false, ...
    'DataCast', 'single', ...
    'DataRecast', false);
runtime = toc(t0);

assert(isstruct(data) && isfield(data, 'p'), 'iceind:CPUOutput', ...
    'kspaceFirstOrder3D did not return the requested p field.');
traces = double(data.p);
% k-Wave documents binary-mask sensor_data as
% sensor_data(sensor_point_index, time_index), i.e. [points x samples].
assert(size(traces,1) == prod([kg.Nx, kg.Ny, kg.Nz]), 'iceind:CPUOutput', ...
    'CPU sensor point count does not match the full grid.');
assert(size(traces,2) == kg.Nt - startIndex + 1, 'iceind:CPUOutput', ...
    sprintf('CPU recorded %d samples; expected %d.', ...
    size(traces,2), kg.Nt - startIndex + 1));
assert(all(isfinite(traces(:))), 'iceind:CPUOutput', ...
    'CPU output contains non-finite values.');

[sensorXYZ, sensorIndex] = local_sensor_coords(kg, s.mask);
r = struct();
r.solver = 'kspaceFirstOrder3D';
r.device = 'cpu';
r.start_index = startIndex;
r.runtime_s = runtime;
r.traces = single(traces.');   % normalized to [time_samples x sensor_points]
r.trace_orientation = '[time_samples x sensor_points]';
r.native_trace_orientation = '[sensor_points x time_samples]';
r.time_s = kg.t_array(startIndex:end);
r.sensor_xyz_m = sensorXYZ;
r.sensor_index = sensorIndex;
end

% =========================================================================
% GPU run: 3DG wrapper + direct audit of the same executable/input
% =========================================================================
function r = local_run_gpu(kg, medium, source, sensor, startIndex, opts, ...
    gpuInfo, prep, outDir, dataDir)
assert(isfolder(dataDir), 'iceind:OutputDirectory', ...
    sprintf('The GPU working directory does not exist: %s', dataDir));

prefix = sprintf('gpu_wrapper_start%d', startIndex);
inFile = fullfile(dataDir, [prefix '_input.h5']);
outFile = fullfile(dataDir, [prefix '_output.h5']);
local_require_absent(inFile);
local_require_absent(outFile);

s = sensor;
s.record = {'p'};
s.record_start_index = startIndex;

t0 = tic;
try
    data = kspaceFirstOrder3DG(kg, medium, source, s, ...
        'PMLInside', false, ...
        'PMLSize', opts.pml_cells, ...
        'PlotSim', false, ...
        'DataCast', 'single', ...
        'DataRecast', false, ...
        'BinaryName', gpuInfo.binary_name, ...
        'BinaryPath', gpuInfo.binary_path, ...
        'DataPath', dataDir, ...
        'DataName', prefix, ...
        'DeleteData', false, ...
        'DeviceNum', opts.device_num, ...
        'VerboseLevel', opts.verbose_level);
catch ME
    % The wrapper does not expose the child exit code. If it left an input
    % file, run the same CUDA executable directly to obtain the real code and
    % console output, then fail with that evidence.
    if isfile(inFile)
        audit = local_run_gpu_direct(inFile, startIndex, opts, gpuInfo, ...
            outDir, false);
        if audit.direct_exit_code == 0 && isfile(audit.outFile)
            error('iceind:GPUWrapperFailed', ...
                sprintf(['kspaceFirstOrder3DG failed (%s). A direct CUDA run ' ...
                'on the same input exited 0 and wrote output, so the wrapper/' ...
                'format bridge failed, not the GPU executable. See %s'], ...
                ME.message, audit.console_log));
        end
        error('iceind:GPUWrapperFailed', ...
            sprintf(['kspaceFirstOrder3DG failed (%s). Direct CUDA executable ' ...
            'exit code %d; console log: %s'], ...
            ME.message, audit.direct_exit_code, audit.console_log));
    end
    rethrow(ME);
end
wrapperRuntime = toc(t0);

assert(isfile(inFile), 'iceind:GPUInputMissing', ...
    sprintf('The 3DG wrapper did not leave the input HDF5 file: %s', inFile));
assert(isfile(outFile), 'iceind:GPUOutputMissing', ...
    sprintf('The 3DG wrapper did not leave the output HDF5 file: %s', outFile));

% The HDF5 input must actually contain additive mode (2), not Dirichlet.
assert(local_h5_has(inFile, 'p_source_mode'), 'iceind:GPUInputMissing', ...
    sprintf('The 3DG input HDF5 lacks /p_source_mode: %s', inFile));
assert(local_h5_has(inFile, 'p_source_many'), 'iceind:GPUInputMissing', ...
    sprintf('The 3DG input HDF5 lacks /p_source_many: %s', inFile));
sourceMode = double(h5read(inFile, '/p_source_mode'));
assert(sourceMode == 2, 'iceind:GPUSourceMode', ...
    sprintf(['The saved GPU input has p_source_mode=%g, expected 2 (additive). ' ...
    'The source was not allowed to change mode.'], sourceMode));
sourceMany = double(h5read(inFile, '/p_source_many'));
assert(sourceMany == 1, 'iceind:GPUSourceMode', ...
    ['The saved GPU input is not a 2-D source matrix (p_source_many=1). ' ...
    'p_source_many=1 alone is necessary but not sufficient; the source point ' ...
    'and time dimensions are checked next.']);
assert(local_h5_has(inFile, 'p_source_index') && ...
    local_h5_has(inFile, 'p_source_input'), 'iceind:GPUInputMissing', ...
    sprintf(['The 3DG input HDF5 lacks /p_source_index or /p_source_input: %s'], ...
    inFile));
sourceIndex = double(h5read(inFile, '/p_source_index'));
sourceInput = double(h5read(inFile, '/p_source_input'));
nSourcePoints = nnz(source.p_mask);
nSourceSamples = size(source.p, 2);
assert(nSourcePoints > 0 && nSourceSamples > 0, 'iceind:GPUSourceMode', ...
    'The source mask or source time series is empty.');
assert(numel(sourceIndex) == nSourcePoints, 'iceind:GPUSourceMode', ...
    sprintf(['The input /p_source_index has %d entries; the source mask has ' ...
    '%d points.'], numel(sourceIndex), nSourcePoints));
assert(isfield(prep, 'hdf5_source_check'), 'iceind:GPUValidationSource', ...
    'The prepared source metadata lacks hdf5_source_check.');
expectedSourceIndex = prep.hdf5_source_check.expected_source_index;
assert(numel(expectedSourceIndex) == nSourcePoints, ...
    'iceind:GPUValidationSource', ...
    'The prepared expanded source index count does not match the source mask.');
assert(isequal(sourceIndex(:), expectedSourceIndex(:)), ...
    'iceind:GPUSourceMode', ...
    ['The input /p_source_index does not match the PML-expanded ' ...
    'sub2ind(size(mask)+2*PMLSize, ix+PMLSize, iy+PMLSize, iz+PMLSize) ' ...
    'expectation in original find(mask) order.']);
sourceSize = size(sourceInput);
assert(numel(sourceSize) == 2, 'iceind:GPUSourceMode', ...
    'The input /p_source_input is not a 2-D matrix.');
if sourceSize(1) == nSourcePoints && sourceSize(2) == nSourceSamples
    sourceH5 = sourceInput;
    sourceOrientation = '[source_points x time_samples]';
elseif sourceSize(2) == nSourcePoints && sourceSize(1) == nSourceSamples
    sourceH5 = sourceInput.';
    sourceOrientation = '[time_samples x source_points]';
else
    error('iceind:GPUSourceMode', ...
        sprintf(['The input /p_source_input size is %s; expected %d source ' ...
        'points by %d time samples (either orientation).'], ...
        mat2str(sourceSize), nSourcePoints, nSourceSamples));
end
sourceScaleFactor = prep.hdf5_source_check.source_scale_factor;
assert(isfinite(sourceScaleFactor) && sourceScaleFactor > 0, ...
    'iceind:GPUValidationSource', ...
    'The prepared additive source scale factor is not positive finite.');
expectedSourceInput = double(source.p) * sourceScaleFactor;
sourceScale = max(abs(expectedSourceInput(:)));
if ~isfinite(sourceScale) || sourceScale <= 0
    sourceScale = 1;
end
sourceMatrixError = max(abs(sourceH5(:) - expectedSourceInput(:))) / sourceScale;
assert(sourceMatrixError <= 1e-6, 'iceind:GPUSourceMode', ...
    sprintf(['The input /p_source_input does not match source.p scaled by ' ...
    '2*dt/(kgrid.dim*c0*dx) = %.9g (max relative error %.3g > 1e-6).'], ...
    sourceScaleFactor, sourceMatrixError));
assert(max(abs(sourceH5(:))) > 0, 'iceind:GPUSourceMode', ...
    'The input /p_source_input is identically zero.');

if ~local_h5_has(outFile, 'p')
    ds = local_h5_datasets(outFile);
    error('iceind:GPUFieldUnsupported', ...
        sprintf(['The GPU output does not contain the requested /p dataset. ' ...
        'No CPU fallback and no alternative GPU field is substituted. ' ...
        'Available datasets: %s'], strjoin(ds, ', ')));
end
pWrapper = double(h5read(outFile, '/p'));
% kspaceFirstOrder3DC loads /p directly; the k-Wave binary sensor layout is
% [sensor_points x time_samples], matching kspaceFirstOrder3D's documented
% sensor_data(sensor_point_index, time_index).
expectedSize = [prod([kg.Nx, kg.Ny, kg.Nz]), kg.Nt - startIndex + 1];
assert(isequal(size(pWrapper), expectedSize), 'iceind:GPUOutputSize', ...
    sprintf('GPU /p size is %s; expected %s ([points x samples]).', ...
    mat2str(size(pWrapper)), mat2str(expectedSize)));
assert(all(isfinite(pWrapper(:))), 'iceind:GPUOutput', ...
    'GPU /p contains non-finite values.');

assert(isstruct(data) && isfield(data, 'p'), 'iceind:GPUOutput', ...
    'kspaceFirstOrder3DG did not return the requested p field.');
assert(isequal(size(data.p), size(pWrapper)), 'iceind:GPUOutput', ...
    'The 3DG return value does not match its own HDF5 /p size.');
returnedFileError = max(abs(double(data.p(:)) - pWrapper(:)));
assert(returnedFileError == 0 || ...
    returnedFileError <= 1e-6*max(abs(pWrapper(:))), ...
    'iceind:GPUOutput', ...
    'The 3DG return value differs from its own HDF5 /p dataset.');

inputHash = local_sha256(inFile);
assert(~strcmp(inputHash, 'unavailable'), 'iceind:GPUInputMissing', ...
    'Could not compute the input HDF5 SHA-256; audited provenance is incomplete.');
audit = local_run_gpu_direct(inFile, startIndex, opts, gpuInfo, outDir, true);

assert(isequal(size(audit.p), size(pWrapper)), 'iceind:GPUDirectOutput', ...
    'The direct CUDA output size differs from the 3DG wrapper output size.');
assert(all(isfinite(audit.p(:))), 'iceind:GPUDirectOutput', ...
    'The direct CUDA output contains non-finite values.');
wrapperVsDirect = max(abs(audit.p(:) - pWrapper(:)));
wrapperVsDirectRel = wrapperVsDirect / max(max(abs(pWrapper(:))), realmin);
assert(wrapperVsDirectRel <= opts.tolerances.wrapper_vs_direct_rel, ...
    'iceind:GPUWrapperMismatch', ...
    sprintf(['The 3DG wrapper output and the direct CUDA output differ ' ...
    '(max abs %.3g Pa, rel %.3g > %.3g).'], ...
    wrapperVsDirect, wrapperVsDirectRel, opts.tolerances.wrapper_vs_direct_rel));

assert(strcmp(local_sha256(inFile), inputHash), 'iceind:GPUInputChanged', ...
    'The input HDF5 file changed while the direct CUDA audit was running.');
if wrapperVsDirect == 0
    wrapperVsDirectRelation = 'exact';
else
    wrapperVsDirectRelation = 'within_tolerance';
end

directHash = audit.outFileSha256;
directBytes = audit.outFileBytes;
assert(~strcmp(directHash, 'unavailable'), 'iceind:GPUDirectOutput', ...
    'Could not hash the direct CUDA output before deciding whether to keep it.');
if opts.keep_direct_output
    directKeep = fullfile(outDir, sprintf('gpu_start%d_direct_output.h5', startIndex));
    local_require_absent(directKeep);
    local_move_new(audit.outFile, directKeep);
    directKept = true;
else
    directKeep = '';
    assert(strcmp(local_sha256(audit.outFile), directHash), ...
        'iceind:OutputFile', ...
        'The direct CUDA output changed before deletion; refusing to delete it.');
    delete(audit.outFile);
    directKept = false;
end

% Keep the raw input and the wrapper output as evidence. Never delete an
% existing file in this timestamp directory; refuse instead.
keepInput = fullfile(outDir, sprintf('gpu_start%d_input.h5', startIndex));
keepOutput = fullfile(outDir, sprintf('gpu_start%d_output.h5', startIndex));
local_require_absent(keepInput);
local_require_absent(keepOutput);
tmpInput = [keepInput '.copying'];
local_require_absent(tmpInput);
[ok, msg] = copyfile(inFile, tmpInput);
assert(ok, 'iceind:OutputFile', sprintf('Could not copy %s to %s: %s', ...
    inFile, tmpInput, msg));
local_move_new(tmpInput, keepInput);
local_move_new(outFile, keepOutput);
assert(strcmp(local_sha256(keepInput), inputHash), 'iceind:OutputFile', ...
    'The kept input HDF5 hash does not match the audited input hash.');

outputHash = local_sha256(keepOutput);
[sensorXYZ, sensorIndex] = local_sensor_coords(kg, s.mask);

r = struct();
r.solver = 'kspaceFirstOrder3DG';
r.device = 'cuda';
r.start_index = startIndex;
r.runtime_s = wrapperRuntime;
r.wrapper_runtime_s = wrapperRuntime;
r.direct_runtime_s = audit.runtime_s;
r.direct_exit_code = audit.direct_exit_code;
r.console_log = audit.console_log;
r.console_gpu_marker = audit.console_gpu_marker;
r.console_version_line = audit.console_version_line;
r.evidence_ok = true;
r.wrapper_vs_direct_max_abs_pa = wrapperVsDirect;
r.wrapper_vs_direct_rel = wrapperVsDirectRel;
r.wrapper_vs_direct_relation = wrapperVsDirectRelation;
r.direct_output_sha256 = directHash;
r.direct_output_bytes = directBytes;
r.direct_output_kept = directKept;
r.direct_output_h5 = directKeep;
r.source_points_in_input = nSourcePoints;
r.source_samples_in_input = nSourceSamples;
r.source_matrix_orientation = sourceOrientation;
r.source_matrix_max_rel_error = sourceMatrixError;
r.source_scale_factor = sourceScaleFactor;
r.input_h5 = keepInput;
r.input_h5_sha256 = inputHash;
r.wrapper_output_h5 = keepOutput;
r.wrapper_output_sha256 = outputHash;
r.source_mode_in_input = sourceMode;
r.traces = single(pWrapper.');   % normalized to [time_samples x sensor_points]
r.trace_orientation = '[time_samples x sensor_points]';
r.native_trace_orientation = '[sensor_points x time_samples]';
r.time_s = kg.t_array(startIndex:end);
r.sensor_xyz_m = sensorXYZ;
r.sensor_index = sensorIndex;
r.gpu_evidence = struct( ...
    'binary_name', gpuInfo.binary_name, ...
    'binary_path', gpuInfo.binary_path, ...
    'binary_sha256', gpuInfo.sha256, ...
    'direct_exit_code', audit.direct_exit_code, ...
    'console_gpu_marker', audit.console_gpu_marker, ...
    'console_version_line', audit.console_version_line, ...
    'console_log', audit.console_log, ...
    'console_head', audit.console_head, ...
    'wrapper_exit_code', 'not_exposed_by_kspaceFirstOrder3DC', ...
    'wrapper_output_present', true, ...
    'wrapper_output_relation', wrapperVsDirectRelation, ...
    'wrapper_vs_direct_max_abs_pa', wrapperVsDirect, ...
    'wrapper_vs_direct_rel', wrapperVsDirectRel, ...
    'direct_output_sha256', directHash, ...
    'direct_output_bytes', directBytes, ...
    'direct_output_kept', directKept, ...
    'direct_output_h5', directKeep, ...
    'input_source_mode_in_hdf5', sourceMode, ...
    'input_source_points', nSourcePoints, ...
    'input_source_samples', nSourceSamples, ...
    'input_source_matrix_orientation', sourceOrientation, ...
    'input_source_matrix_max_rel_error', sourceMatrixError, ...
    'input_source_scale_factor', sourceScaleFactor, ...
    'input_h5_sha256', inputHash, ...
    'wrapper_output_sha256', outputHash, ...
    'hdf5_p_orientation', '[sensor_points x time_samples]', ...
    'mat_trace_orientation', '[time_samples x sensor_points]', ...
    'note', ['The 3DG wrapper does not expose its child exit code. The direct ' ...
    'invocation of the same CUDA executable on the same input HDF5 is the ' ...
    'exit-code check; its /p agrees with the wrapper /p within the declared ' ...
    'tolerance, not a byte-identical claim.']);
end

function a = local_run_gpu_direct(inFile, startIndex, opts, gpuInfo, outDir, mustPass)
dataDir = fileparts(inFile);
prefix = sprintf('gpu_direct_start%d', startIndex);
outFile = fullfile(dataDir, [prefix '_output.h5']);
local_require_absent(outFile);

cmd = sprintf(['cd /d "%s" && "%s" -i "%s" -o "%s" -g %d ' ...
    '--p_raw -s %d --verbose %d 2>&1'], ...
    gpuInfo.binary_path, gpuInfo.binary_file, inFile, outFile, ...
    opts.device_num, startIndex, opts.verbose_level);

t0 = tic;
[status, console] = system(cmd);
runtime = toc(t0);
logFile = fullfile(outDir, sprintf('gpu_start%d_console.log', startIndex));
local_require_absent(logFile);
local_write_text(logFile, console);

a = struct();
a.direct_exit_code = double(status);
a.console = console;
a.console_log = logFile;
a.console_head = local_head(console, 2000);
a.console_gpu_marker = '';
a.console_version_line = '';
a.runtime_s = runtime;
a.outFile = outFile;
a.outFileSha256 = '';
a.outFileBytes = -1;
a.p = [];

if ~mustPass
    if isfile(outFile)
        a.outFileSha256 = local_sha256(outFile);
        d = dir(outFile);
        a.outFileBytes = d.bytes;
    end
    if status == 0 && isfile(outFile) && local_h5_has(outFile, 'p')
        a.p = double(h5read(outFile, '/p'));
    end
    return
end

assert(status == 0, 'iceind:GPUExitCode', ...
    sprintf(['The CUDA executable returned exit code %d. This is the actual ' ...
    'process exit code, not the MATLAB CPU solver. See %s'], status, logFile));
assert(isfile(outFile), 'iceind:GPUOutputMissing', ...
    sprintf('The CUDA executable exited 0 but wrote no output file: %s', outFile));
if ~local_h5_has(outFile, 'p')
    ds = local_h5_datasets(outFile);
    error('iceind:GPUFieldUnsupported', ...
        sprintf(['The CUDA output does not contain the requested /p dataset. ' ...
        'No CPU fallback and no alternative field is substituted. ' ...
        'Available datasets: %s'], strjoin(ds, ', ')));
end

marker = local_gpu_marker_line(console);
assert(~isempty(marker), 'iceind:GPUNotProven', ...
    sprintf(['The executable exited 0 and wrote output, but its console did ' ...
    'not identify CUDA/GPU/device. Refusing to label this run as GPU. ' ...
    'See %s'], logFile));
a.console_gpu_marker = marker;
a.console_version_line = regexp(console, ...
    '(?i)[^\r\n]*k-?wave[^\r\n]*', 'match', 'once');
a.outFileSha256 = local_sha256(outFile);
d = dir(outFile);
a.outFileBytes = d.bytes;
a.p = double(h5read(outFile, '/p'));
end

function line = local_gpu_marker_line(console)
% Pick a console line that identifies CUDA/a device, avoiding file paths
% (the run directory deliberately contains the token "gpu").
line = '';
try
    lines = regexp(console, '\r\n|\n|\r', 'split');
    for k = 1:numel(lines)
        s = lines{k};
        low = lower(s);
        if ~isempty(strfind(low, '.h5')) || ~isempty(strfind(low, 'input')) || ...
                ~isempty(strfind(low, 'output')) || ~isempty(strfind(low, 'file')) || ...
                ~isempty(strfind(low, char(92))) || ~isempty(strfind(low, '/'))
            continue
        end
        if ~isempty(regexp(low, '(cuda|device|\bgpu\b)', 'once'))
            line = s;
            return
        end
    end
catch
end
end

% =========================================================================
% GPU preflight
% =========================================================================
function g = local_gpu_preflight(opts)
g = struct();
g.binary_path = char(opts.binary_path);
g.binary_name = char(opts.binary_name);
g.binary_file = fullfile(g.binary_path, g.binary_name);
g.device_num = opts.device_num;
g.verbose_level = opts.verbose_level;

assert(isfolder(g.binary_path), 'iceind:GPUNotDeployed', ...
    sprintf(['CUDA dependency folder not found: %s. The coordinator may still ' ...
    'be downloading it. Do not assume deployment; no CPU fallback is used.'], ...
    g.binary_path));
assert(isfile(g.binary_file), 'iceind:GPUNotDeployed', ...
    sprintf(['CUDA executable not found: %s. The coordinator may still be ' ...
    'downloading it. Do not assume deployment; no CPU fallback is used.'], ...
    g.binary_file));
assert(~isempty(strfind(lower(g.binary_name), 'cuda')), ...
    'iceind:GPUNotDeployed', ...
    sprintf(['The configured executable name "%s" does not identify a CUDA ' ...
    'binary. Refusing to run a CPU-named binary as the GPU comparison.'], ...
    g.binary_name));
assert(isempty(strfind(g.binary_name, '/')) && ...
    isempty(strfind(g.binary_name, char(92))), ...
    'iceind:GPUPathUntrusted', ...
    sprintf('binary_name must be a bare filename: %s', g.binary_name));

d = dir(g.binary_file);
g.bytes = d.bytes;
g.modified = d.date;
g.sha256 = local_sha256(g.binary_file);
assert(~strcmp(g.sha256, 'unavailable'), 'iceind:GPUNotDeployed', ...
    ['Could not compute the executable SHA-256 (Java or file read ' ...
    'unavailable). Refusing to claim audited GPU identity.']);
g.file_version = local_file_version(g.binary_file);

dllNames = {'cudart64_13.dll','cudart64_12.dll','hdf5.dll','hdf5_hl.dll', ...
    'msvcp140.dll','concrt140.dll','aec.dll'};
g.runtime_dlls = struct('name', {}, 'present', {}, 'bytes', {}, 'sha256', {});
for k = 1:numel(dllNames)
    f = fullfile(g.binary_path, dllNames{k});
    if isfile(f)
        dd = dir(f);
        g.runtime_dlls(end+1) = struct('name', dllNames{k}, 'present', true, ...
            'bytes', dd.bytes, 'sha256', local_sha256(f)); %#ok<AGROW>
    else
        g.runtime_dlls(end+1) = struct('name', dllNames{k}, 'present', false, ...
            'bytes', -1, 'sha256', ''); %#ok<AGROW>
    end
end
end

% =========================================================================
% Metrics
% =========================================================================
function m = local_metrics(cpuTraces, gpuTraces, dt, startIndex, tol, sensorXYZ)
assert(isequal(size(cpuTraces), size(gpuTraces)), 'iceind:MetricInput', ...
    'CPU and GPU trace matrices must have the same size.');
assert(size(sensorXYZ,1) == size(cpuTraces,2), 'iceind:MetricInput', ...
    'Coordinate count does not match sensor points.');

nSamples = size(cpuTraces,1);
nPoints = size(cpuTraces,2);
difference = gpuTraces - cpuTraces;
cpuScale = max(abs(cpuTraces), [], 'all');
if ~isfinite(cpuScale) || cpuScale <= 0
    cpuScale = 1;
end

m = struct();
m.record_start_index = startIndex;
m.recorded_samples = nSamples;
m.sensor_points = nPoints;
m.dt_s = dt;
m.recorded_window_duration_s = max(0, (nSamples - 1)) * dt;
m.qp_scope = 'recorded_window';
if startIndex == 1
    m.qp_scope = 'full_time';
end

m.time_rel_l2 = local_ratio(norm(difference, 'fro'), norm(cpuTraces, 'fro'));
m.time_max_abs_pa = max(abs(difference), [], 'all');
m.time_max_abs_over_peak = m.time_max_abs_pa / cpuScale;
m.time_point_floor_pa = tol.time_point_floor_fraction * cpuScale;
maskTime = abs(cpuTraces) > m.time_point_floor_pa;
if any(maskTime(:))
    m.time_point_rel_max_above_floor = ...
        max(abs(difference(maskTime)) ./ abs(cpuTraces(maskTime)));
else
    m.time_point_rel_max_above_floor = 0;
end
m.time_points_above_floor = nnz(maskTime);

qpCpu = dt * sum(cpuTraces.^2, 1);
qpGpu = dt * sum(gpuTraces.^2, 1);
m.qp_cpu_total_pa2_s = sum(qpCpu);
m.qp_gpu_total_pa2_s = sum(qpGpu);
m.qp_total_rel_error = local_ratio(abs(m.qp_gpu_total_pa2_s - m.qp_cpu_total_pa2_s), ...
    abs(m.qp_cpu_total_pa2_s));
m.qp_rel_l2 = local_ratio(norm(qpGpu - qpCpu), norm(qpCpu));
m.qp_max_abs_pa2_s = max(abs(qpGpu - qpCpu));
m.qp_floor_pa2_s = tol.qp_floor_fraction * max(qpCpu);
if ~isfinite(m.qp_floor_pa2_s) || m.qp_floor_pa2_s <= 0
    m.qp_floor_pa2_s = realmin;
end
maskQp = qpCpu > m.qp_floor_pa2_s;
if any(maskQp)
    m.qp_max_rel_above_floor = ...
        max(abs(qpGpu(maskQp) - qpCpu(maskQp)) ./ qpCpu(maskQp));
else
    m.qp_max_rel_above_floor = 0;
end
m.qp_points_above_floor = nnz(maskQp);

pmaxCpu = max(cpuTraces, [], 1);
pminCpu = min(cpuTraces, [], 1);
pmaxGpu = max(gpuTraces, [], 1);
pminGpu = min(gpuTraces, [], 1);
m.peak_cpu_pa = max(abs([pmaxCpu, pminCpu]), [], 'all');
m.peak_gpu_pa = max(abs([pmaxGpu, pminGpu]), [], 'all');
m.peak_rel_error = local_ratio(abs(m.peak_gpu_pa - m.peak_cpu_pa), ...
    m.peak_cpu_pa);
m.pmax_max_abs_diff_pa = max(abs(pmaxGpu - pmaxCpu));
m.pmin_max_abs_diff_pa = max(abs(pminGpu - pminCpu));
m.peak_abs_over_peak = max(m.pmax_max_abs_diff_pa, m.pmin_max_abs_diff_pa) / ...
    max(m.peak_cpu_pa, realmin);

nTail = min(tol.tail_samples, nSamples);
m.tail_sample_count = nTail;
m.tail_sample_ratio_cpu = max(abs(cpuTraces(end-nTail+1:end,:)), [], 'all') / cpuScale;
m.tail_sample_ratio_gpu = max(abs(gpuTraces(end-nTail+1:end,:)), [], 'all') / cpuScale;
m.tail_sample_ratio_max = max(m.tail_sample_ratio_cpu, m.tail_sample_ratio_gpu);
m.tail_sample_check_pass = m.tail_sample_ratio_max <= tol.tail_sample_ratio;

qpRel = abs(qpGpu - qpCpu) ./ max(qpCpu, m.qp_floor_pa2_s);
m.point_qp = table( ...
    repmat(startIndex, nPoints, 1), ...
    repmat({m.qp_scope}, nPoints, 1), ...
    (1:nPoints)', ...
    sensorXYZ(:,1), sensorXYZ(:,2), sensorXYZ(:,3), ...
    qpCpu', qpGpu', abs(qpGpu - qpCpu)', qpRel', maskQp', ...
    pmaxCpu', pmaxGpu', pminCpu', pminGpu', ...
    'VariableNames', { ...
    'record_start_index', 'qp_scope', 'index', 'x_m', 'y_m', 'z_m', ...
    'qp_recorded_cpu_pa2_s', 'qp_recorded_gpu_pa2_s', ...
    'qp_abs_diff_pa2_s', 'qp_rel_diff_to_floor', 'qp_above_floor', ...
    'pmax_cpu_pa', 'pmax_gpu_pa', 'pmin_cpu_pa', 'pmin_gpu_pa'});
end

function m = local_status(m, tol)
c = struct();
c.time_rel_l2 = m.time_rel_l2 <= tol.time_rel_l2;
c.time_max_abs_over_peak = m.time_max_abs_over_peak <= tol.time_max_abs_over_peak;
c.time_point_rel_max_above_floor = ...
    m.time_point_rel_max_above_floor <= tol.time_point_rel_max_above_floor;
c.qp_rel_l2 = m.qp_rel_l2 <= tol.qp_rel_l2;
c.qp_total_rel_error = m.qp_total_rel_error <= tol.qp_total_rel_error;
c.qp_max_rel_above_floor = ...
    m.qp_max_rel_above_floor <= tol.qp_max_rel_above_floor;
c.peak_rel_error = m.peak_rel_error <= tol.peak_rel_error;
c.peak_abs_over_peak = m.peak_abs_over_peak <= tol.peak_abs_over_peak;
c.nonzero_signal = m.peak_cpu_pa > 0 && m.peak_gpu_pa > 0 && ...
    m.qp_cpu_total_pa2_s > 0 && m.qp_gpu_total_pa2_s > 0;
c.tail_sample_check_pass = logical(m.tail_sample_check_pass);
c.source_matrix_checked = m.source_points_in_input > 0 && ...
    m.source_samples_in_input > 0 && ...
    m.source_matrix_max_rel_error <= 1e-6;
c.gpu_evidence = logical(m.gpu_evidence_ok) && ...
    m.gpu_direct_exit_code == 0 && ...
    m.source_mode_in_input == 2 && ...
    c.source_matrix_checked && ...
    m.gpu_wrapper_vs_direct_rel <= tol.wrapper_vs_direct_rel;

reasons = {};
if ~c.time_rel_l2
    reasons{end+1} = sprintf('time_rel_l2=%.3g > %.3g', ...
        m.time_rel_l2, tol.time_rel_l2); %#ok<AGROW>
end
if ~c.time_max_abs_over_peak
    reasons{end+1} = sprintf('time_max_abs_over_peak=%.3g > %.3g', ...
        m.time_max_abs_over_peak, tol.time_max_abs_over_peak); %#ok<AGROW>
end
if ~c.time_point_rel_max_above_floor
    reasons{end+1} = sprintf('time_point_rel_max_above_floor=%.3g > %.3g', ...
        m.time_point_rel_max_above_floor, ...
        tol.time_point_rel_max_above_floor); %#ok<AGROW>
end
if ~c.qp_rel_l2
    reasons{end+1} = sprintf('qp_rel_l2=%.3g > %.3g', ...
        m.qp_rel_l2, tol.qp_rel_l2); %#ok<AGROW>
end
if ~c.qp_total_rel_error
    reasons{end+1} = sprintf('qp_total_rel_error=%.3g > %.3g', ...
        m.qp_total_rel_error, tol.qp_total_rel_error); %#ok<AGROW>
end
if ~c.qp_max_rel_above_floor
    reasons{end+1} = sprintf('qp_max_rel_above_floor=%.3g > %.3g', ...
        m.qp_max_rel_above_floor, tol.qp_max_rel_above_floor); %#ok<AGROW>
end
if ~c.peak_rel_error
    reasons{end+1} = sprintf('peak_rel_error=%.3g > %.3g', ...
        m.peak_rel_error, tol.peak_rel_error); %#ok<AGROW>
end
if ~c.peak_abs_over_peak
    reasons{end+1} = sprintf('peak_abs_over_peak=%.3g > %.3g', ...
        m.peak_abs_over_peak, tol.peak_abs_over_peak); %#ok<AGROW>
end
if ~c.nonzero_signal
    reasons{end+1} = ['CPU or GPU pressure/Qp is identically zero; a zero ' ...
        'field cannot validate the solvers']; %#ok<AGROW>
end
if ~c.tail_sample_check_pass
    reasons{end+1} = sprintf(['tail_sample_ratio_max=%.3g > %.3g; the last %d ' ...
        'samples still carry this fraction of the peak. This is a tail-sampling ' ...
        'check only, not proof that the window captured all energy.'], ...
        m.tail_sample_ratio_max, tol.tail_sample_ratio, ...
        m.tail_sample_count); %#ok<AGROW>
end
if ~c.gpu_evidence
    reasons{end+1} = ['GPU evidence check failed: direct exit code, additive ' ...
        'source mode, source point/time matrix, or wrapper/direct output ' ...
        'agreement within tolerance']; %#ok<AGROW>
end

m.criteria = c;
m.failure_reasons = strjoin(reasons, '; ');
if isempty(reasons)
    m.status = 'PASS';
else
    m.status = 'FAIL';
end
end

function t = local_metrics_table(results)
n = numel(results);
rows = cell(n,1);
for k = 1:n
    r = results(k);
    m = r.metrics;
    rows{k} = struct( ...
        'start_index', m.record_start_index, ...
        'qp_scope', m.qp_scope, ...
        'recorded_samples', m.recorded_samples, ...
        'sensor_points', m.sensor_points, ...
        'recorded_window_duration_s', m.recorded_window_duration_s, ...
        'cpu_runtime_s', m.cpu_runtime_s, ...
        'gpu_wrapper_runtime_s', m.gpu_wrapper_runtime_s, ...
        'gpu_direct_runtime_s', m.gpu_direct_runtime_s, ...
        'gpu_direct_exit_code', m.gpu_direct_exit_code, ...
        'gpu_wrapper_exit_code', m.gpu_wrapper_exit_code, ...
        'source_mode_in_input', m.source_mode_in_input, ...
        'source_points_in_input', m.source_points_in_input, ...
        'source_samples_in_input', m.source_samples_in_input, ...
        'source_matrix_orientation', m.source_matrix_orientation, ...
        'source_matrix_max_rel_error', m.source_matrix_max_rel_error, ...
        'source_scale_factor', m.source_scale_factor, ...
        'gpu_wrapper_vs_direct_max_abs_pa', m.gpu_wrapper_vs_direct_max_abs_pa, ...
        'gpu_wrapper_vs_direct_rel', m.gpu_wrapper_vs_direct_rel, ...
        'gpu_wrapper_vs_direct_relation', m.gpu_wrapper_vs_direct_relation, ...
        'time_rel_l2', m.time_rel_l2, ...
        'time_max_abs_pa', m.time_max_abs_pa, ...
        'time_max_abs_over_peak', m.time_max_abs_over_peak, ...
        'time_point_rel_max_above_floor', m.time_point_rel_max_above_floor, ...
        'time_point_floor_pa', m.time_point_floor_pa, ...
        'time_points_above_floor', m.time_points_above_floor, ...
        'qp_cpu_total_pa2_s', m.qp_cpu_total_pa2_s, ...
        'qp_gpu_total_pa2_s', m.qp_gpu_total_pa2_s, ...
        'qp_total_rel_error', m.qp_total_rel_error, ...
        'qp_rel_l2', m.qp_rel_l2, ...
        'qp_max_abs_pa2_s', m.qp_max_abs_pa2_s, ...
        'qp_max_rel_above_floor', m.qp_max_rel_above_floor, ...
        'qp_floor_pa2_s', m.qp_floor_pa2_s, ...
        'qp_points_above_floor', m.qp_points_above_floor, ...
        'peak_cpu_pa', m.peak_cpu_pa, ...
        'peak_gpu_pa', m.peak_gpu_pa, ...
        'peak_rel_error', m.peak_rel_error, ...
        'peak_abs_over_peak', m.peak_abs_over_peak, ...
        'pmax_max_abs_diff_pa', m.pmax_max_abs_diff_pa, ...
        'pmin_max_abs_diff_pa', m.pmin_max_abs_diff_pa, ...
        'tail_sample_count', m.tail_sample_count, ...
        'tail_sample_ratio_cpu', m.tail_sample_ratio_cpu, ...
        'tail_sample_ratio_gpu', m.tail_sample_ratio_gpu, ...
        'tail_sample_ratio_max', m.tail_sample_ratio_max, ...
        'tail_sample_check_pass', m.tail_sample_check_pass, ...
        'gpu_console_log', m.gpu_console_log, ...
        'gpu_console_gpu_marker', m.gpu_console_gpu_marker, ...
        'gpu_console_version_line', m.gpu_console_version_line, ...
        'input_h5', m.input_h5, ...
        'input_h5_sha256', m.input_h5_sha256, ...
        'wrapper_output_h5', m.wrapper_output_h5, ...
        'wrapper_output_sha256', m.wrapper_output_sha256, ...
        'direct_output_sha256', m.direct_output_sha256, ...
        'direct_output_bytes', m.direct_output_bytes, ...
        'direct_output_kept', m.direct_output_kept, ...
        'direct_output_h5', m.direct_output_h5, ...
        'cpu_mat', m.cpu_mat, ...
        'gpu_mat', m.gpu_mat, ...
        'point_qp_csv', m.point_qp_csv, ...
        'status', m.status, ...
        'failure_reasons', m.failure_reasons);
end
t = struct2table([rows{:}]);
end

% =========================================================================
% start=1 vs start=37 window consistency (same solver)
% =========================================================================
function wc = local_window_consistency(results, tol)
wc = struct();
wc.applicable = false;
wc.pass = true;
wc.status = 'not_applicable';
wc.table = table();
starts = [results.start];
if ~any(starts == 1) || ~any(starts == 37)
    wc.note = ['start indices 1 and 37 are not both present; the window ' ...
        'consistency comparison is not_applicable, not a failure.'];
    return
end
wc.applicable = true;
wc.status = 'PASS';
iFull = find(starts == 1, 1, 'first');
iWindow = find(starts == 37, 1, 'first');
rows = cell(2,1);
solverNames = {'cpu','gpu'};
for k = 1:2
    solver = solverNames{k};
    fullData = results(iFull).(solver);
    windowData = results(iWindow).(solver);
    fullTrace = double(fullData.traces);
    windowTrace = double(windowData.traces);
    assert(size(fullTrace,1) >= 37, 'iceind:WindowConsistency', ...
        'The start=1 trace has fewer than 37 samples.');
    tail = fullTrace(37:end, :);
    assert(isequal(size(tail), size(windowTrace)), 'iceind:WindowConsistency', ...
        sprintf(['%s start=37 trace size %s does not match the start=1 tail ' ...
        'size %s.'], upper(solver), mat2str(size(windowTrace)), ...
        mat2str(size(tail))));
    maxAbs = max(abs(windowTrace - tail), [], 'all');
    scale = max(abs(fullTrace), [], 'all');
    rel = maxAbs / max(scale, realmin);
    status = 'PASS';
    if rel > tol.window_consistency_rel
        status = 'FAIL';
        wc.pass = false;
        wc.status = 'FAIL';
    end
    rows{k} = struct('solver', solver, 'full_start_index', 1, ...
        'window_start_index', 37, 'full_samples', size(fullTrace,1), ...
        'window_samples', size(windowTrace,1), 'max_abs_pa', maxAbs, ...
        'max_abs_over_peak', rel, ...
        'tolerance_rel', tol.window_consistency_rel, 'status', status);
end
wc.table = struct2table([rows{:}]);
wc.note = ['The start=37 recording must agree with the start=1 tail for the ' ...
    'same solver because record_start_index only changes recording, not ' ...
    'propagation.'];
end

% =========================================================================
% Summary / configuration
% =========================================================================
function s = local_empty_summary(opts, gpuInfo, prep)
s = struct();
s.schema_version = 1;
s.case_tag = 'curing_gpu_validation_20261111';
s.created = datestr(now, 31);
s.output_dir = '';
s.overall_status = 'RUNNING';
s.overall_pass = false;
s.prepare_only = logical(opts.prepare_only);
s.environment = local_environment();
s.gpu = gpuInfo;
s.record_field_policy = local_record_policy();
s.grid = struct('n', prep.n, 'dx_m', prep.dx_m, 'domain_m', prep.domain_m, ...
    'pml_cells', prep.pml_cells, 'Nt', prep.time_window.Nt, ...
    'dt_s', prep.dt_s, 't_end_s', prep.time_window.t_end_s);
s.error_identifier = '';
s.error_message = '';
s.limitations = local_limitations();
end

function s = local_summary(s, results, metTable, wc, opts, kg, prepareRuntime, totalRuntime)
gpuRuns = [results.gpu];
windowOk = ~wc.applicable || wc.pass;
s.overall_pass = all(strcmp(metTable.status, 'PASS')) && windowOk;
if s.overall_pass
    s.overall_status = 'PASS';
else
    s.overall_status = 'FAIL';
end
s.output_dir = fileparts(gpuRuns(1).wrapper_output_h5);
s.environment = local_environment();
s.prepare_runtime_s = prepareRuntime;
s.total_runtime_s = totalRuntime;
s.per_start = table2struct(metTable);
if wc.applicable && ~isempty(wc.table) && ~isempty(wc.table.Properties.VariableNames)
    s.window_consistency = table2struct(wc.table);
else
    s.window_consistency = [];
end
s.window_consistency_applicable = wc.applicable;
s.window_consistency_pass = wc.pass;
s.window_consistency_ok = windowOk;
s.window_consistency_status = wc.status;
s.window_consistency_note = wc.note;
gpuOk = true;
for k = 1:numel(gpuRuns)
    gpuOk = gpuOk && logical(gpuRuns(k).evidence_ok);
end
s.criteria = struct( ...
    'all_numerical_pass', all(strcmp(metTable.status, 'PASS')), ...
    'window_consistency_applicable', wc.applicable, ...
    'window_consistency_pass', wc.pass, ...
    'window_consistency_ok', windowOk, ...
    'gpu_evidence_pass', gpuOk, ...
    'direct_exit_code_zero', all([gpuRuns.direct_exit_code] == 0), ...
    'source_mode_additive_in_hdf5', all([gpuRuns.source_mode_in_input] == 2), ...
    'source_matrix_checked', all([gpuRuns.source_matrix_max_rel_error] <= 1e-6), ...
    'tail_sample_check_pass', all([metTable.tail_sample_check_pass]));
s.tolerances = opts.tolerances;
s.start_indices = opts.start_indices;
s.record_field_policy = local_record_policy();
s.limitations = local_limitations();
s.notes = { ...
    'Both solvers use single precision; differences at the float32 level are expected.'; ...
    'MAT traces are stored as [time_samples x sensor_points]; raw GPU HDF5 /p is [sensor_points x time_samples].'; ...
    'Qp for start_index > 1 is dt*sum over the recorded window only.'; ...
    'The 3DG wrapper does not expose the child process exit code; the direct CUDA invocation on the same input HDF5 is the exit-code check.'; ...
    'The wrapper and direct outputs are compared within a declared tolerance; no byte-identical claim is made.'; ...
    'The last-N-sample ratio is a tail-sampling check only; it is not a proof that the window captured all energy.'; ...
    'If start indices 1 and 37 are not both present, window consistency is marked not_applicable rather than failed.'; ...
    'Runtime includes HDF5 I/O and process launch; it is not a performance benchmark.'; ...
    'No VSX, hardware, activation, license or large-case run was performed.'};
end

function p = local_record_policy()
p = struct();
p.requested = {'p'};
p.verified = {'/p'};
p.not_requested = {'p_rms','p_max_all','p_min_all','p_final','u'};
p.rule = ['A requested field must be present in the GPU output. If it is ' ...
    'absent, the run fails; it is never replaced by a MATLAB CPU result or a ' ...
    'different GPU field.'];
p.peaks_and_qp = ['Peaks and Qp are computed from the complete recorded p(t) ' ...
    'series on both solvers; binary accumulator fields are not used.'];
end

function c = local_limitations()
c = { ...
    'Synthetic/assumed homogeneous lossless fluid; flat rectangular pressure sources with an assumed 1 Pa per element; not voltage calibrated.'; ...
    'Pressure peaks and Qp are numerical proxies, not acoustic power, acoustic energy, heating, dose, safety or cure.'; ...
    'The GPU proof checks executable identity/hash, a direct process exit code, a CUDA/GPU console marker, the additive mode, PML-expanded source indices, source point/time dimensions and 2*dt/(3*c0*dx) scaling in the saved HDF5 input, and wrapper/direct output agreement within tolerance; it does not independently query the physical GPU model.'; ...
    'The 3DG wrapper does not expose its child exit code; the direct CUDA invocation is the exit-code check, and a mismatch beyond tolerance fails the validation.'; ...
    'The last-N-sample tail ratio is only a sampling check; a small value does not prove the full time window captured all acoustic energy.'; ...
    'Runtimes include HDF5 I/O and process launch and are not a performance benchmark.'; ...
    'No VSX, hardware, activation, license or large-case run is performed.'};
end

function c = local_config(opts, kg, source, prep, gpuInfo, kwPath, outDir)
c = struct();
c.schema_version = 1;
c.case_tag = 'curing_gpu_validation_20261111';
c.created = datestr(now, 31);
c.output_dir = outDir;
c.environment = local_environment();
c.kwave_path = kwPath;
c.kwave_version = local_kwave_version(kwPath);
c.gpu = gpuInfo;
c.options = opts;
c.grid = struct('n', prep.n, 'dx_m', prep.dx_m, 'domain_m', prep.domain_m, ...
    'pml_cells', prep.pml_cells, 'cfl', prep.cfl, 'Nt', kg.Nt, ...
    'dt_s', kg.dt, 't_end_s', kg.t_array(end), ...
    'x_vec_m', kg.x_vec, 'y_vec_m', kg.y_vec, 'z_vec_m', kg.z_vec);
c.prepare = local_prepare_json(prep);
c.source_mode = source.p_mode;
c.trace_layout = struct( ...
    'mat_traces', '[time_samples x sensor_points]', ...
    'gpu_hdf5_p', '[sensor_points x time_samples]', ...
    'note', ['The CPU kspaceFirstOrder3D and GPU kspaceFirstOrder3DC interfaces ' ...
    'return [sensor_points x time_samples] for a binary mask; both are ' ...
    'transposed once to [time_samples x sensor_points] before metrics.']);
c.record_field_policy = local_record_policy();
c.limitations = local_limitations();
end

function e = local_environment()
e = struct();
e.matlab_version = version();
e.matlab_release = version('-release');
e.computer = computer;
e.ispc = ispc();
e.date = datestr(now, 31);
try
    v = ver('matlab');
    if ~isempty(v)
        e.matlab_ver_name = v.Name;
        e.matlab_ver_version = v.Version;
        e.matlab_ver_release = v.Release;
    end
catch
end
end

function v = local_kwave_version(kwPath)
v = 'unknown';
try
    txt = fileread(fullfile(kwPath, 'Contents.m'));
    tok = regexp(txt, 'Version\s+([^\r\n]+)', 'tokens', 'once');
    if ~isempty(tok)
        v = strtrim(tok{1});
    end
catch
end
end

% =========================================================================
% Output helpers
% =========================================================================
function outDir = local_make_output_dir(outRoot)
if ~isfolder(outRoot)
    [ok, msg] = mkdir(outRoot);
    assert(ok, 'iceind:OutputDirectory', ...
        sprintf('Could not create %s: %s', outRoot, msg));
end
stamp = datestr(now, 'yyyymmdd_HHMMSS');
for k = 0:999
    if k == 0
        candidate = fullfile(outRoot, ['run_' stamp]);
    else
        candidate = fullfile(outRoot, sprintf('run_%s_%03d', stamp, k));
    end
    if exist(candidate, 'file') || exist(candidate, 'dir')
        % Never reuse, overwrite or delete an existing timestamp path.
        continue
    end
    local_make_empty_dir(candidate);
    outDir = candidate; %#ok<NASGU>
    return
end
error('iceind:OutputDirectory', ...
    'Could not create a unique timestamped output directory.');
end

function local_save_run(file, r, kg, startIndex)
traces = r.traces;
meta = struct();
meta.solver = r.solver;
meta.device = r.device;
meta.start_index = startIndex;
meta.runtime_s = r.runtime_s;
meta.n = [kg.Nx, kg.Ny, kg.Nz];
meta.dx_m = kg.dx;
meta.dt_s = kg.dt;
meta.time_s = r.time_s;
meta.trace_orientation = '[time_samples x sensor_points]';
if isfield(r, 'native_trace_orientation')
    meta.native_trace_orientation = r.native_trace_orientation;
end
meta.sensor_xyz_m = r.sensor_xyz_m;
meta.sensor_index = r.sensor_index;
if isfield(r, 'wrapper_runtime_s')
    meta.wrapper_runtime_s = r.wrapper_runtime_s;
end
if isfield(r, 'direct_runtime_s')
    meta.direct_runtime_s = r.direct_runtime_s;
end
if isfield(r, 'direct_exit_code')
    meta.direct_exit_code = r.direct_exit_code;
end
if isfield(r, 'wrapper_vs_direct_relation')
    meta.wrapper_vs_direct_relation = r.wrapper_vs_direct_relation;
end
if isfield(r, 'direct_output_sha256')
    meta.direct_output_sha256 = r.direct_output_sha256;
end
if isfield(r, 'direct_output_bytes')
    meta.direct_output_bytes = r.direct_output_bytes;
end
if isfield(r, 'direct_output_kept')
    meta.direct_output_kept = r.direct_output_kept;
end
if isfield(r, 'direct_output_h5')
    meta.direct_output_h5 = r.direct_output_h5;
end
if isfield(r, 'source_points_in_input')
    meta.source_points_in_input = r.source_points_in_input;
end
if isfield(r, 'source_samples_in_input')
    meta.source_samples_in_input = r.source_samples_in_input;
end
if isfield(r, 'source_matrix_orientation')
    meta.source_matrix_orientation = r.source_matrix_orientation;
end
if isfield(r, 'source_matrix_max_rel_error')
    meta.source_matrix_max_rel_error = r.source_matrix_max_rel_error;
end
if isfield(r, 'source_scale_factor')
    meta.source_scale_factor = r.source_scale_factor;
end
if isfield(r, 'console_log')
    meta.console_log = r.console_log;
end
if isfield(r, 'gpu_evidence')
    meta.gpu_evidence = r.gpu_evidence;
end
save(file, 'traces', 'meta', '-v7');
end

function s = local_prepare_json(p)
% Drop the large binary arrays from the JSON copy; they remain in prepare.mat.
s = p;
if isfield(s, 'mask')
    s = rmfield(s, 'mask');
end
if isfield(s, 'source_signal')
    s = rmfield(s, 'source_signal');
end
if isfield(s, 'hdf5_source_check')
    if isfield(s.hdf5_source_check, 'original_mask_index')
        s.hdf5_source_check = rmfield(s.hdf5_source_check, 'original_mask_index');
    end
    if isfield(s.hdf5_source_check, 'expected_source_index')
        s.hdf5_source_check = rmfield(s.hdf5_source_check, 'expected_source_index');
    end
end
end

function local_write_json(file, s)
try
    txt = jsonencode(s, 'PrettyPrint', true);
catch ME
    txt = jsonencode(struct('json_encode_error', ME.message, ...
        'json_encode_identifier', ME.identifier));
end
local_write_text(file, txt);
end

function local_write_text(file, txt)
fid = fopen(file, 'w');
if fid < 0
    error('iceind:OutputFile', sprintf('Could not open %s for writing.', file));
end
fprintf(fid, '%s', txt);
fclose(fid);
end

function local_require_absent(file)
assert(~exist(file, 'file') && ~exist(file, 'dir'), 'iceind:NoOverwrite', ...
    sprintf('Refusing to reuse or overwrite an existing path: %s', file));
end

function local_make_empty_dir(dirPath)
local_require_absent(dirPath);
[ok, msg] = mkdir(dirPath);
assert(ok, 'iceind:OutputDirectory', ...
    sprintf('Could not create %s: %s', dirPath, msg));
entries = dir(dirPath);
assert(numel(entries) <= 2, 'iceind:NoOverwrite', ...
    sprintf('New directory is not empty; refusing to reuse it: %s', dirPath));
end

function local_move_new(src, dst)
local_require_absent(dst);
assert(exist(src, 'file') == 2, 'iceind:OutputFile', ...
    sprintf('Source file does not exist: %s', src));
ok = false;
try
    ok = java.io.File(src).renameTo(java.io.File(dst));
catch ME
    error('iceind:OutputFile', ...
        sprintf('Could not move %s to %s without overwriting: %s', ...
        src, dst, ME.message));
end
assert(ok, 'iceind:OutputFile', ...
    sprintf(['Could not move %s to %s without overwriting (destination may ' ...
    'already exist).'], src, dst));
assert(exist(src, 'file') ~= 2 && exist(dst, 'file') == 2, ...
    'iceind:OutputFile', ...
    sprintf('Move did not produce the expected destination: %s', dst));
end

function p = local_resolve_path(p, base)
p = char(p);
if isempty(p)
    p = base;
end
if ~local_is_absolute_path(p)
    p = fullfile(base, p);
end
p = local_canonical_path(p);
end

function tf = local_is_absolute_path(p)
tf = ~isempty(regexp(p, '^([A-Za-z]:[\\/]|[\\/]{1,2})', 'once'));
end

function p = local_canonical_path(p)
p = char(p);
try
    p = char(java.io.File(p).getCanonicalPath());
catch
    p = fullfile(p);
end
end

function tf = local_is_within(child, parent)
c = lower(local_canonical_path(child));
p = lower(local_canonical_path(parent));
if strcmp(c, p)
    tf = true;
    return
end
if ~isempty(p) && (p(end) == filesep || p(end) == '/')
    prefix = p;
else
    prefix = [p filesep];
end
tf = strncmp(c, prefix, numel(prefix));
end

function local_assert_shell_safe_path(p, label)
assert(ischar(p) && ~isempty(p), 'iceind:GPUPathUntrusted', ...
    sprintf('%s must be a nonempty character path.', label));
bad = ['"','&','|','<','>','^','%','!',char(13),char(10)];
assert(~any(ismember(p, bad)), 'iceind:GPUPathUntrusted', ...
    sprintf(['%s contains a character unsafe for the Windows command line: ' ...
    '%s'], label, p));
end

% =========================================================================
% Small utilities
% =========================================================================
function [xyz, idx] = local_sensor_coords(kg, mask)
n = [kg.Nx, kg.Ny, kg.Nz];
idx = find(mask);
[ix, iy, iz] = ind2sub(n, idx);
xyz = [kg.x_vec(ix(:)), kg.y_vec(iy(:)), kg.z_vec(iz(:))];
end

function s = local_support(kg, mask)
n = [kg.Nx, kg.Ny, kg.Nz];
[ix, iy, iz] = ind2sub(n, find(mask));
s = struct();
s.nonzero_points = nnz(mask);
s.bounding_box_indices = [min(ix) max(ix); min(iy) max(iy); min(iz) max(iz)];
s.bounding_box_m = [kg.x_vec(min(ix)) kg.x_vec(max(ix)); ...
    kg.y_vec(min(iy)) kg.y_vec(max(iy)); ...
    kg.z_vec(min(iz)) kg.z_vec(max(iz))];
s.margin_cells = struct( ...
    'x_lo', min(ix)-1, 'x_hi', n(1)-max(ix), ...
    'y_lo', min(iy)-1, 'y_hi', n(2)-max(iy), ...
    'z_lo', min(iz)-1, 'z_hi', n(3)-max(iz));
s.margin_m = struct( ...
    'x_lo', (min(ix)-1)*kg.dx, 'x_hi', (n(1)-max(ix))*kg.dx, ...
    'y_lo', (min(iy)-1)*kg.dy, 'y_hi', (n(2)-max(iy))*kg.dy, ...
    'z_lo', (min(iz)-1)*kg.dz, 'z_hi', (n(3)-max(iz))*kg.dz);
s.min_margin_cells = min(cell2mat(struct2cell(s.margin_cells)));
s.min_margin_m = min(cell2mat(struct2cell(s.margin_m)));
s.nonzero_on_face = struct( ...
    'x_lo', any(mask(1,:,:), 'all'), 'x_hi', any(mask(end,:,:), 'all'), ...
    'y_lo', any(mask(:,1,:), 'all'), 'y_hi', any(mask(:,end,:), 'all'), ...
    'z_lo', any(mask(:,:,1), 'all'), 'z_hi', any(mask(:,:,end), 'all'));
faces = fieldnames(s.nonzero_on_face);
touching = {};
for k = 1:numel(faces)
    if s.nonzero_on_face.(faces{k})
        touching{end+1} = faces{k}; %#ok<AGROW>
    end
end
s.touching_faces = strjoin(touching, ',');
s.touches_boundary = ~isempty(touching);
end

function tf = local_h5_has(file, dataset)
tf = false;
try
    names = local_h5_datasets(file);
    tf = any(strcmp(names, dataset));
catch
    tf = false;
end
end

function names = local_h5_datasets(file)
names = {};
try
    info = h5info(file);
    names = {info.Datasets.Name};
catch
end
end

function r = local_ratio(num, den)
if den == 0
    if num == 0
        r = 0;
    else
        r = Inf;
    end
else
    r = num / den;
end
end

function s = local_head(txt, n)
if numel(txt) <= n
    s = txt;
else
    s = [txt(1:n), '...'];
end
end

function h = local_sha256(file)
h = '';
try
    fid = fopen(file, 'rb');
    if fid < 0
        h = 'unavailable';
        return
    end
    bytes = fread(fid, Inf, '*uint8');
    fclose(fid);
    md = java.security.MessageDigest.getInstance('SHA-256');
    md.update(typecast(bytes, 'int8'));
    digest = md.digest();
    unsigned = typecast(digest, 'uint8');
    h = lower(reshape(dec2hex(unsigned, 2)', 1, []));
catch
    h = 'unavailable';
end
end

function v = local_file_version(file)
v = 'unavailable';
try
    fvi = System.Diagnostics.FileVersionInfo.GetVersionInfo(file);
    fv = char(fvi.FileVersion);
    pv = char(fvi.ProductVersion);
    v = [fv ' / ' pv];
catch
end
end

function s = local_merge(defaults, user)
s = defaults;
if isempty(user)
    return
end
assert(isstruct(user), 'iceind:GPUValidationInput', ...
    'Options must be a scalar struct.');
names = fieldnames(user);
for k = 1:numel(names)
    name = names{k};
    if isfield(s, name) && isstruct(s.(name)) && isstruct(user.(name))
        s.(name) = local_merge(s.(name), user.(name));
    else
        s.(name) = user.(name);
    end
end
end

function opts = local_options(opts)
assert(isstruct(opts), 'iceind:GPUValidationInput', ...
    'Options must be a scalar struct.');
defaults = struct();
defaults.prepare_only = false;
defaults.output_root = '';
defaults.binary_path = '';
defaults.binary_name = 'kspaceFirstOrder-CUDA-windows.exe';
defaults.device_num = 0;
defaults.verbose_level = 2;
defaults.keep_direct_output = false;
defaults.start_indices = [1 37];
defaults.pml_cells = 8;
defaults.cfl = 0.2;
defaults.time_margin_s = 1e-6;
defaults.geometry = struct('n', [30 24 20], 'dx_m', 150e-6);
defaults.medium = struct('sound_speed_m_s', 1540, 'density_kg_m3', 1000);
defaults.source = struct( ...
    'element_x_m', [-0.5 0 0.5]*1e-3, ...
    'element_y_m', 0, ...
    'element_z_m', 0, ...
    'width_m', 0.34e-3, ...
    'height_m', 0.60e-3, ...
    'f0_hz', 1e6, ...
    'cycles', 3, ...
    'amplitude_pa', 1, ...
    'delay_samples', [0 16 32]);
defaults.bli = struct('type', 'sinc', 'tolerance', 0.05, ...
    'upsampling_rate', 10, 'single_precision', true);
defaults.tolerances = struct( ...
    'time_rel_l2', 1e-4, ...
    'time_max_abs_over_peak', 1e-3, ...
    'time_point_rel_max_above_floor', 2e-2, ...
    'time_point_floor_fraction', 1e-2, ...
    'qp_rel_l2', 1e-4, ...
    'qp_total_rel_error', 1e-4, ...
    'qp_max_rel_above_floor', 2e-2, ...
    'qp_floor_fraction', 1e-4, ...
    'peak_rel_error', 1e-4, ...
    'peak_abs_over_peak', 1e-3, ...
    'wrapper_vs_direct_rel', 1e-6, ...
    'window_consistency_rel', 1e-6, ...
    'tail_sample_ratio', 5e-3, ...
    'tail_samples', 20);
opts = local_merge(defaults, opts);

validateattributes(opts.geometry.n, {'numeric'}, ...
    {'vector', 'numel', 3, 'integer', '>=', 12}, 'curing_gpu_validation_20261111', ...
    'geometry.n');
opts.geometry.n = double(opts.geometry.n(:)');
assert(numel(unique(opts.geometry.n)) > 1, 'iceind:GPUValidationInput', ...
    'The test domain must be non-cubic (n must not have three equal values).');
validateattributes(opts.geometry.dx_m, {'numeric'}, ...
    {'scalar', 'real', 'finite', 'positive'}, ...
    'curing_gpu_validation_20261111', 'geometry.dx_m');
validateattributes(opts.medium.sound_speed_m_s, {'numeric'}, ...
    {'scalar', 'real', 'finite', 'positive'}, ...
    'curing_gpu_validation_20261111', 'medium.sound_speed_m_s');
validateattributes(opts.medium.density_kg_m3, {'numeric'}, ...
    {'scalar', 'real', 'finite', 'positive'}, ...
    'curing_gpu_validation_20261111', 'medium.density_kg_m3');
validateattributes(opts.pml_cells, {'numeric'}, ...
    {'scalar', 'integer', 'positive'}, ...
    'curing_gpu_validation_20261111', 'pml_cells');
validateattributes(opts.cfl, {'numeric'}, ...
    {'scalar', 'real', 'finite', '>', 0, '<', 1}, ...
    'curing_gpu_validation_20261111', 'cfl');
validateattributes(opts.time_margin_s, {'numeric'}, ...
    {'scalar', 'real', 'finite', '>=', 0}, ...
    'curing_gpu_validation_20261111', 'time_margin_s');

validateattributes(opts.source.element_x_m, {'numeric'}, ...
    {'vector', 'real', 'finite'}, ...
    'curing_gpu_validation_20261111', 'source.element_x_m');
nElem = numel(opts.source.element_x_m);
assert(nElem >= 2, 'iceind:GPUValidationInput', ...
    'At least two source elements are required.');
for f = {'element_y_m','element_z_m'}
    v = opts.source.(f{1});
    validateattributes(v, {'numeric'}, {'vector', 'real', 'finite'}, ...
        'curing_gpu_validation_20261111', ['source.' f{1}]);
    assert(numel(v) == 1 || numel(v) == nElem, ...
        'iceind:GPUValidationInput', ...
        sprintf('source.%s must be scalar or match the element count.', f{1}));
end
validateattributes(opts.source.width_m, {'numeric'}, ...
    {'scalar', 'real', 'finite', 'positive'}, ...
    'curing_gpu_validation_20261111', 'source.width_m');
validateattributes(opts.source.height_m, {'numeric'}, ...
    {'scalar', 'real', 'finite', 'positive'}, ...
    'curing_gpu_validation_20261111', 'source.height_m');
validateattributes(opts.source.f0_hz, {'numeric'}, ...
    {'scalar', 'real', 'finite', 'positive'}, ...
    'curing_gpu_validation_20261111', 'source.f0_hz');
validateattributes(opts.source.cycles, {'numeric'}, ...
    {'scalar', 'real', 'finite', 'positive'}, ...
    'curing_gpu_validation_20261111', 'source.cycles');
validateattributes(opts.source.amplitude_pa, {'numeric'}, ...
    {'scalar', 'real', 'finite', 'positive'}, ...
    'curing_gpu_validation_20261111', 'source.amplitude_pa');
validateattributes(opts.source.delay_samples, {'numeric'}, ...
    {'vector', 'real', 'finite', 'integer', '>=', 0}, ...
    'curing_gpu_validation_20261111', 'source.delay_samples');
opts.source.delay_samples = double(opts.source.delay_samples(:)');
assert(numel(opts.source.delay_samples) == nElem, ...
    'iceind:GPUValidationInput', ...
    'source.delay_samples must match the number of elements.');
assert(numel(unique(opts.source.delay_samples)) == nElem, ...
    'iceind:GPUValidationInput', ...
    'Every source element must have a distinct delay (multi-source delays).');
assert(min(opts.source.delay_samples) == 0, 'iceind:GPUValidationInput', ...
    'At least one element must have zero delay as the reference.');

assert(strcmpi(opts.bli.type, 'sinc'), 'iceind:GPUValidationInput', ...
    'Only BLIType ''sinc'' is supported.');
opts.bli.type = 'sinc';
validateattributes(opts.bli.tolerance, {'numeric'}, ...
    {'scalar', 'real', 'finite', '>', 0, '<', 1}, ...
    'curing_gpu_validation_20261111', 'bli.tolerance');
validateattributes(opts.bli.upsampling_rate, {'numeric'}, ...
    {'scalar', 'integer', 'positive'}, ...
    'curing_gpu_validation_20261111', 'bli.upsampling_rate');
assert(logical(opts.bli.single_precision), 'iceind:GPUValidationInput', ...
    'This comparison requires SinglePrecision=true BLI and DataCast=single.');
opts.bli.single_precision = true;

validateattributes(opts.start_indices, {'numeric'}, ...
    {'vector', 'real', 'finite', 'integer', 'positive'}, ...
    'curing_gpu_validation_20261111', 'start_indices');
opts.start_indices = sort(unique(double(opts.start_indices(:)')));
assert(~isempty(opts.start_indices), 'iceind:GPUValidationInput', ...
    'start_indices must not be empty.');
validateattributes(opts.device_num, {'numeric'}, ...
    {'scalar', 'integer', '>=', 0}, ...
    'curing_gpu_validation_20261111', 'device_num');
validateattributes(opts.verbose_level, {'numeric'}, ...
    {'scalar', 'integer', '>=', 0, '<=', 2}, ...
    'curing_gpu_validation_20261111', 'verbose_level');
validateattributes(opts.prepare_only, {'logical', 'numeric'}, {'scalar'}, ...
    'curing_gpu_validation_20261111', 'prepare_only');
opts.prepare_only = logical(opts.prepare_only);
validateattributes(opts.keep_direct_output, {'logical', 'numeric'}, {'scalar'}, ...
    'curing_gpu_validation_20261111', 'keep_direct_output');
opts.keep_direct_output = logical(opts.keep_direct_output);

names = fieldnames(defaults.tolerances);
for k = 1:numel(names)
    v = opts.tolerances.(names{k});
    validateattributes(v, {'numeric'}, ...
        {'scalar', 'real', 'finite', 'positive'}, ...
        'curing_gpu_validation_20261111', ['tolerances.' names{k}]);
end
validateattributes(opts.tolerances.tail_samples, {'numeric'}, ...
    {'scalar', 'integer', 'positive'}, ...
    'curing_gpu_validation_20261111', 'tolerances.tail_samples');
end
