function c=matrix96_config
%MATRIX96_CONFIG Physical count/layout user-reported; dimensions uncalibrated.
c.layout=[12 8]; c.pitch_m=[160 160]*1e-6;
c.element_size_m=[140 140]*1e-6;
c.frequency_hz=6e6; c.bandwidth_hz=3.6e6;
c.sound_speed_m_s=1540; c.density_kg_m3=1000;
c.focus_m=[0 0 .020]; c.cycles=20; c.source_pressure_pa=1;
c.dx_m=64e-6; c.cfl=.2; c.domain_m=[10.24 10.24 25.6]*1e-3;
c.pml_m=1.28e-3; c.source_offset_m=.64e-3;
c.roi_z_m=[.012 .024];
c.provenance=struct('layout','user_reported_12x8_not_independently_measured', ...
    'pitch_and_frequency','assumed_literature_inspired_not_a_12x8_product_spec', ...
    'element_size','assumed_140um_not_from_paper', ...
    'medium_waveform_focus_and_amplitude','assumed', ...
    'wiring_and_calibration','unknown_simulation_indices_only', ...
    'reference','https://doi.org/10.1016/j.ultrasmedbio.2023.11.001');
end
