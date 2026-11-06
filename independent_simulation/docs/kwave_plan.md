# SetUp to k-Wave implementation plan

User-approved scope: MATLAB R2024b, independent_simulation only, actual array/source/grid/sensor propagation, no curing or VSX runtime.

1. Read saved SetUp structures without executing the .m or activating vendor software. Record source paths and SHA256; compile finite traversal of Event/SeqControl into a manifest, preserving TX/TW indices, profile and lower-bound timing. Stop at backward jump; unsupported commands fail closed.
2. Convert Trans geometry to SI and TX.Delay using Trans.frequency. Preserve parametric TW frequency, half-cycle active fraction/count and polarity; retain voltage as metadata only. Reject unsupported geometry/waveforms.
3. Generate a nominal tri-state drive shape and pass through an explicitly assumed bandpass impulse response; normalize to an assumed 1 Pa reference source. This is not a calibrated electroacoustic transfer function or hardware waveform quantization.
4. Map finite rectangular elements to a 3D k-Wave source plane using conservative area-overlap weights. Keep actual per-element TX delays/apodization. Represent flat elements, omitting elevation lens; preserve its source metadata and state omission.
5. Solve kspaceFirstOrder3D on GPU if supported, save sparse sensor p(t), pressure extrema volumes and XZ/XY cuts. Unique TX solutions may be reused for identical repeated events only under a static linear medium and non-overlapping acoustic windows. Do not claim execution of unselected TX events.
6. Test compiler/units/unsupported cases first, run original imaging TX and dual-mode exposure TX examples; compare two grids and classify convergence from actual differences. Full 15-angle sweeps remain executable but not claimed unless run.

Manual basis: D00163 Rev.K p89 (TW), A107 (noop/stop), A110 (TTNA), A171 (TX.Delay/Apod). All absolute pressures conditional on assumed source; geometry existing_code_unverified. Actual hardware capabilities/clinical/curing conclusions remain unknown.
