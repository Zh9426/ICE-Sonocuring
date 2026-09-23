function preparation = prepare_kwave_input(geom, sequence, cfg)
%PREPARE_KWAVE_INPUT Export requirements, not an implemented k-Wave backend.
% There is deliberately no guessed source voxelizer, solver invocation,
% fabricated pressure result, or automatic backend default selection.

preparation = struct();
preparation.status = 'requirements_only';
preparation.ready_to_run = false;
preparation.handoff = iceio.export_handoff(geom, sequence, cfg, '');
preparation.required_decisions = {'grid_resolution_and_pml'; ...
    'time_step_duration_and_cfl'; 'medium_attenuation_and_nonlinearity'; ...
    'source_velocity_to_grid_mapping'; 'pulse_waveform_and_shot_timing'; ...
    'sensor_positions_and_recorded_observables'; 'homogeneous_benchmark_and_grid_convergence'};
preparation.source_mapping_requirements = ...
    'Preserve finite element area, outward normal and peak velocity; define overlap and subvoxel behavior.';
preparation.validation_requirements = ...
    'Validate source units, delay signs, pulse amplitude, propagation and convergence before comparing fields.';
preparation.execution_note = ...
    'A complete k-Wave input generator and installed compatible backend are required before execution.';
end
