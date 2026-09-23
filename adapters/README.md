# Inspectable backend handoff

`iceio.export_handoff(geom, sequence, cfg, filename)` exports an ordinary JSON
data file and returns the same MATLAB structure. Use an empty filename to
inspect the structure without writing a file. The schema declares
`executable = false`; it is neither a Verasonics setup script nor a complete
k-Wave simulation. No adapter evaluates MATLAB files, controls hardware, or
chooses undocumented hardware settings.

The handoff records:

- Geometry coordinates, element widths/heights and outward normal. Coordinates
  and sizes use metres, with the array in the x-y plane and positive z outward.
- Per-shot dimensionless complex weights as separate real and imaginary
  arrays, physical delays in seconds, and peak normal-velocity phasor values
  before delays in metres per second. The convention is
  `real(v * exp(+i*omega*t))`; a positive delay contributes
  `exp(-i*omega*delay_s)`.
- Sequence mode and normalized shot dwell weights; separate shots are
  sequential exposures, not coherent simultaneous sources.
- Frequency in Hz, sound speed in m/s, density in kg/m^3, duty cycle and
  total elapsed exposure time in seconds. Exposure time is metadata and does
  not supply a material cure model.
- Source velocity calibration flag and provenance text. Synthetic values
  remain explicitly uncalibrated unless supplied otherwise.
- A separate hardware section with unknown channel mapping, device identity,
  drive-voltage conversion and delay-clock conversion. Unknown numerical
  values are NaN in MATLAB and JSON null on export. They must be resolved
  from actual device specifications and measured calibration.

`|p|^2/(2*rho*c)` denotes plane-progressive-wave equivalent intensity from a
peak pressure phasor. It is not the exact active intensity vector in an
interference or near field; that would require particle velocity as well.
Threshold crossings represent exposure screening and do not establish cure.

## k-Wave preparation interface

`iceio.prepare_kwave_input(geom, sequence, cfg)` returns a requirements report
containing the validated handoff, `status = 'requirements_only'` and
`ready_to_run = false`. The report lists decisions still required for a real
backend: spatial and temporal sampling, PML placement, medium and attenuation,
surface-to-voxel source mapping, pulse waveform and timing, sensor placement,
and benchmark validation against the current frequency-domain solver.

This interface intentionally produces no pressure field and does not silently
substitute point sources, a scalar pressure boundary, or guessed time steps
for finite normal-velocity radiators. A future implementation must preserve
element area and source strength during voxelization, define how adjacent
elements sharing grid cells combine, and validate grid/time-step convergence.

## Verasonics preparation boundary

Physical delays remain `delay_s`. Conversion to backend `TX.Delay`, channel
order, transducer descriptor, transmit voltage, pulse cycles, clock timing,
acquisition and safety settings is unresolved. In particular, the adapter
does not assume that an undocumented hardware delay field is measured in
seconds or microseconds. Mapping and conversion require the actual platform,
transducer and backend documentation. No generated file can be executed as a
hardware program.

The current export does not establish an electroacoustic voltage-to-velocity
calibration or validate a medical/device operating envelope.
