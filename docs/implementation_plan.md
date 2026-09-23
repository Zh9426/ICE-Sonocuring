# ICE-Sonocuring implementation plan

**Goal:** A MATLAB research simulator for configurable side-looking linear and matrix ICE apertures, beam modes, array partitions, and threshold-based exposure comparisons.

**Architecture:** SI units throughout. A homogeneous, linear, baffled-piston Rayleigh integral (midpoint surface quadrature) maps element normal-velocity phasors to pressure phasors. Geometry, excitation, propagation, exposure aggregation, metrics, and plotting are separate functions in `simulation/+ice`. No measured ICE specifications are assumed. Hardware control is outside phase one.

**Tech stack:** MATLAB R2024b, base MATLAB only, `matlab.unittest` function tests. No mandatory k-Wave or Verasonics installation.

## Physics and interfaces

- Coordinates: aperture in x-y plane; x along catheter/linear array, y elevation, z outward side-looking normal. Positions are N-by-3 metres; grid uses ndgrid(x,y,z), flattened in MATLAB column order.
- Time convention: real(p exp(+i omega t)). Delayed element velocity is v exp(-i omega delay). Focus delay = (max(distance)-distance)/c, so phase aligns at the requested point.
- Pressure: p = i rho c k/(2 pi) sum_elements sum_patches [v_element dS exp(-i k r)/r]. Units Pa with a declared velocity in m/s. Positive z only. Finite dimensions enter patch positions and areas.
- A shot has `weights` (N-by-1 complex, dimensionless), `delay_s` (N-by-1), `focus_m` (1-by-3 or NaNs). Sequence contains `shots`, `dwell_weights` (sum 1), `mode`.
- Expanded focus uses separate sequential focal shots. Pressure envelope uses maximum shot magnitude; time-average intensity uses dwell-weighted squared magnitude times duty cycle, divided by 2 rho c. No coherent addition between separate shots.
- Thresholds specify pressure/intensity, relative/absolute, and explicit intensity basis (pulse_average or temporal_average). Relative comparisons share a baseline reference. Absolute thresholds require calibrated velocity and provenance. Threshold coverage is a screening proxy, not a cure prediction.
- Geometry `ice.make_geometry(cfg.array)` returns positions_m, width_m, height_m, grid_indices, shape, normal. `ice.partition_elements(geom,cfg.architecture)` returns imaging_mask/curing_mask. `ice.make_sequence(geom,mask,cfg)` builds excitations.
- Grid `ice.make_grid(cfg.grid)` returns points_m, shape, x_m/y_m/z_m, voxel_volume_m3. `ice.solve_pressure(geom,shot,points,cfg)` returns Pa. `ice.simulate(cfg,reference)` orchestrates and returns pressure shots, aggregated exposure, target mask, metrics, cut metrics and references.

## Execution checklist

- [x] Write/run missing-module tests for geometry, partition masks, delays and apodization. Implement modules; verify symmetry, counts, disjoint complements, deterministic random masks, and phase alignment.
- [x] Write/run propagation tests. Implement Rayleigh quadrature, grid validation and exposure aggregation. Verify single-source analytical limit, inverse-distance decay, superposition, focus gain, quadrature convergence, duty scaling, zero-drive behavior and dimensions.
- [x] Write/run threshold and profile tests. Implement volume coverage, off-target fraction, target coefficient of variation, -6 dB width and explicitly scoped secondary-peak estimates. Avoid automatic classification of every off-axis peak as a grating lobe.
- [x] Add synthetic demo config and non-runnable real-device template, executable demos, reproducible architecture comparison and parameter sweeps with common reference and excitation normalization recorded.
- [x] Add inspectable k-Wave/Verasonics handoff specifications, units dictionary, architecture/experiment docs and research questions.
- [x] Run all MATLAB tests, produce plots and CSV/MAT outputs, inspect plots, conduct independent physics/code review, fix issues, and record actual verification results. The voxel-threshold convergence limitation is recorded in `docs/verification.md`.

## Planned files and ownership

- Array worker: `simulation/+ice/make_geometry.m`, `partition_elements.m`, `make_sequence.m`, `tests/test_geometry_excitation.m`.
- Metrics worker: `simulation/+ice/evaluate_threshold.m`, `beam_metrics.m`, `tests/test_metrics.m`, `adapters/` and adapter tests/documentation.
- Main worker: `config/`, grid/propagation/aggregation/simulation functions, scripts, plotting, README and research documentation.

Unknown measured specifications remain in `config/real_ice_template.m` as NaN/empty values; validation must reject it until completed. Demonstration values belong only to `config/demo_config.m` and are labelled synthetic.
