# Single-point k-Wave numerical validation implementation plan

> Execute inline with superpowers:executing-plans. The user approved the single-point/domain/PML/exposure approach on 2026-10-22. All additions stay in independent_simulation; existing dirty files and the saved baseline remain in place. No hardware operation, vendor execution, commit or push is part of this task.

**Goal:** Test whether the current even-32 single-point field is robust to boundaries and discretization, and quantify spatial pressure-squared-time exposure inside/outside explicitly assumed target volumes.

**Architecture:** Reuse the saved MAT and existing source preparation without modifying its defaults. A separate runner records full-volume RMS and extrema, avoiding a full four-dimensional pressure array. Convert RMS to the discrete proxy Qp = dt * Nt * p_rms^2, with record_start_index=1. Compare five controlled cases on a common interpolated physical ROI; retain input/source hashes, source arrival checks and solver metadata. All propagation remains assumed homogeneous, linear, lossless and without elevation lens or calibrated pressure.

**Tech stack:** MATLAB R2024b, local k-Wave 1.4.1, gpuArray-single, Python numpy/scipy/h5py/matplotlib for independent auditing and figures.

## Experimental contract

- Output directory: results/kwave_singlepoint_validation_2026-10-22. Refuse to overwrite completed case MATs unless explicitly rerun after inspection.
- Cases: baseline65 (10.4 x 5.2 x 31.2 mm, 1.04 mm PML); pml65 (same domain, 1.56 mm PML); wide65 (15.6 x 10.4 x 31.2 mm); long65 (10.4 x 5.2 x 41.6 mm); fine52 (baseline domain, 52 um). Unchanged quantities include saved TX16, source reference, density, sound speed and CFL=0.2.
- Common recording window at least 40 us, from the first solver step. This extends the historic recording window; explicitly compare extrema with that historic baseline. All-time convergence is not claimed.
- Peak metrics keep the existing z >= 2 mm definition. Common field-comparison samples: x=-4:0.13:4 mm, y=-2:0.13:2 mm, z=2:0.13:29 mm, using interpolation and no individual amplitude normalization.
- Proposed internal sensitivity criteria, declared before solving: relative field L2 and maximum-pressure/Qp changes <=5%, peak-location change <=0.13 mm. These are numerical diagnostics, not device/material acceptance limits. A small L2 does not override a large peak-location change in a broad focus.
- Assumed material evaluation box x=[-4,4], y=[-2,2], z=[10,28] mm. Synthetic target box halfwidths [0.5,0.5,0.5], [0.5,1,0.5], [1,1,1], [0.5,1,2] mm around the fixed [0,0,20] mm target. These dimensions are sensitivity examples, not actual sample dimensions. Report clipping and observed-domain limits.
- Qp spatial integrals have units Pa^2 s m^3 and their ratios are only observed-volume proxy fractions. Neither is deposited energy, heat or cure. Compare target coverage above 0.5 of the within-target Qp maximum only as a relative acoustic statistic.
- Audit delay units against D00163 Rev. K, TX.Delay A171-A172 and computeTXDelays A176. The other three system manuals were read in this conversation; no hardware features are assumed installed.

## Tasks

- [x] Write meaningful failing tests for controlled cases, known exposure masks/clipping/units and full-RMS integration versus directly recorded p(t) on a small k-Wave problem.
- [x] Implement +iceind/kwave_validation_cases.m and +iceind/pressure_exposure_metrics.m. Keep existing source defaults unchanged.
- [x] Implement run_kwave_singlepoint_validation.m and a PowerShell R2024b launcher, with GPU memory preflight, per-case progress, no overwrite, persisted XYZ extrema/Qp and source diagnostics.
- [x] Run the new tests, inspect Code Analyzer, then launch one MATLAB process sequentially for all five solves. Record failures, not inferred completion.
- [x] Independently audit the produced MATs, compare raw common-ROI fields and source/saved-input invariants, produce summary tables/plots and a Chinese report. An optional monochromatic rectangular-source reference is a model comparison only, not a replacement solver or physical validation.
- [x] Run independent regression tests into the new validation directory, inspect figures, verify preserved baseline hashes and git diff --check. Update README/CHANGELOG with implemented/verified/pending boundaries and actual results.

## Actual outcome and exploratory addition

All five solves completed. MATLAB 26/26 and Python 10/10 tests passed; 6 MATLAB files had no Code Analyzer messages. The enlarged XY case discovered a stronger off-axis forward pressure maximum at [6.37,0,2.015] mm outside the old extent, on the z >= 2 mm search boundary. Thus the global-peak sensitivity check failed even though common-ROI field differences remained small. See the Chinese results report; this is a completed investigation with a negative numerical criterion, not a validated hardware focus/cure result.

After observing the initial target fraction, supplementary exploratory postprocessing varied only the assumed material integration box thickness (1/2/4/18 mm) while preserving the 1 mm target numerator. This was not a prespecified pass criterion or a resimulation of different material thicknesses. Actual SonoInk recipe, absorption, thermal/kinetic parameters and bench equipment remain unknown per the user's update.

## Not included

No assumed elevation-lens implementation, attenuation/thermal/cure model, steering/line solver or hardware action. The next stage depends on these single-point findings and actual material/probe data. The finite enlarged domain still cannot establish all-space sidelobe or grating-lobe bounds.
