# Independent ICE simulation implementation plan

Goal: an isolated MATLAB R2024b point-target imaging benchmark without VSX or vendor runtime dependencies.

Architecture: local +iceind package, SI configuration, ideal normally incident plane wave, Gaussian-modulated RF pulse, omnidirectional point receivers, and coherent delay-and-sum reconstruction. This is an analytic timing/position benchmark, not a finite-aperture transmit solver or reproduction of the ICE FlashAngles sequence. No hardware, license edits, downloads, or external services.

Decisions: keep all scripts, tests, documentation and generated results in independent_simulation; restore MATLAB path after entry points; no addpath(genpath(repository)), no savepath; explicitly launch R2024b. Element count/pitch/frequency are copied as unverified software-reference values only. Synthetic target and assumed medium/pulse use SI units. No absolute pressure or curing claims.

Implementation steps:
1. Write tests for center-channel round-trip timing, off-grid off-axis target localization, left/right symmetry, invalid sampling and truncated acquisition rejection.
2. Run tests before implementation and retain failure log.
3. Implement config, forward RF model and DAS; repeat tests and run single-point demo.
4. Inspect exported figures, save numerical report/config and Code Analyzer output, run git diff --check.

Acceptance: timing error <= one sample; localization error <= image grid diagonal (proposed software acceptance, not physical accuracy); symmetric RF channels for a centered target; no acquisition clipping accepted. Forward and inverse use the same simplified propagation assumptions, so localization is an internal consistency check. Future MUST/k-Wave comparisons and measured validation remain pending.

Files: run_independent_demo.m, run_independent_tests.m, +iceind/default_config.m, +iceind/simulate_rf.m, +iceind/reconstruct.m, tests/test_point_target.m, README.md, results/.

Reference for future comparison: https://www.biomecardio.com/MUST/functions/html/quick_start_demo.html (SIMUS -> RF/IQ -> DAS workflow). No MUST code or runtime is included in this initial benchmark.

Completed 2026-10-09: all four steps executed; 5/5 tests pass, 6 MATLAB files have zero Code Analyzer messages, result PNG inspected. Outputs and limitations are recorded in model_and_validation.md. No commit or push performed.
