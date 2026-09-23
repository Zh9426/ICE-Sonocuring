# Array geometry, partitions and excitation

All distances use metres and times use seconds. These modules create numerical
descriptions only; they do not control an ultrasound system.

`ice.make_geometry(cfg.array)` places rectangular elements in the x-y plane at
z = 0. x follows the catheter/linear array; z is the outward side-looking normal.
`size = [Nx Ny]` describes element counts. A linear array requires Ny = 1.
`pitch_m = [px py]` specifies centre spacing. Coordinates are centred around
zero, with x varying fastest in the flattened element list. Element width is
along x and element height along y. The y pitch does not limit element height
for a single row. Multirow arrays require height <= y pitch.

`ice.partition_elements(geom, architecture)` returns logical column masks.
Shared architecture enables every element for both functions. Partitioned
architecture assigns each element to exactly one of imaging or curing. For
generated masks, the number of curing elements is `round(curing_fraction*N)`,
clamped to [1, N-1]. This ensures both subarrays exist, including very small
requested fractions. Custom masks supply the assignment directly.

Central and peripheral patterns rank the physical squared x-y distance from
the aperture centre. Equal-distance ties use original element index. Thus the
geometric criterion is symmetric, but an exact requested count cutting through
a tied pair/ring can produce an asymmetric subset. Checkerboard prefers even
`ix + iy` parity, then ranks centre distance and original index within each
parity. At fractions away from one half this is an exact-count extension of
checkerboard, rather than a strictly alternating mask. Random sparse uses a
local seeded random stream, leaving MATLAB's global random stream unchanged.

`ice.make_sequence(geom, mask, cfg)` creates one shot for focused or broad mode,
and one separate shot per regional point in expanded mode. Shots contain
dimensionless element amplitudes in `weights`, physical delays in `delay_s`,
and the requested focal position in `focus_m` (NaNs for broad mode). The solver
must apply delays once, using the positive-time phasor convention:

```
real(p * exp(+i*omega*t))
delayed_velocity = velocity * weights .* exp(-i*omega*delay_s)
```

Focused delays are `(max(active_distance)-distance)/c`. Broad-mode delays are
`(position*direction-min(active_position*direction))/c`, with direction
`[sin(az)*cos(el), sin(el), cos(az)*cos(el)]`. Angles are degrees and describe
forward steering. Broad mode represents a finite unfocused aperture; it does
not guarantee spatially uniform pressure or exposure. A nonempty custom delay
column overrides calculated delays for every shot.

The aperture rectangle is centred at x = y = 0 and includes elements by their
centre coordinates. Numeric apodization supplies one nonnegative amplitude per
element. Uniform apodization supplies ones. Hann apodization is separable over
the distinct x and y coordinates included by the aperture rectangle, before
applying the partition mask; a masked hole does not compress the Hann window.
A singleton dimension has Hann weight one. A conventional two-sample Hann is
all zeros and therefore cannot alone create an effective excitation.

Fixed-element normalization preserves the requested nonzero amplitudes.
Fixed-total normalization scales them so that
`sum(element_area .* abs(weights).^2) == sum(all_element_areas)`.
Its reference is the full geometry with uniform unit amplitude, even when an
aperture or partition excludes elements. This can require larger per-element
amplitude; it is a mathematical comparison and does not assert hardware voltage
or power capability. This norm is an aperture source-drive proxy, not the
integral of radiated acoustic power, which includes element interactions.

Expanded shots are temporally separate. Their nonnegative dwell weights must
sum to one; their pressure phasors must not be added coherently across shots.
