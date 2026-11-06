# ICE Dual-mode Implementation Plan

> **For agentic workers:** Use `superpowers:subagent-driven-development` for the independent probe and event modules; the root agent integrates and reviews both against the accepted design.

**Goal:** Build an inspectable MATLAB ICE imaging/exposure/interleaved sequence using the existing 64-element baseline and replaceable probe configuration.

**Architecture:** Pure probe/delay and finite event compiler modules feed a builder that retains existing image reconstruction/display structures. A separate save entry exports MAT/JSON/CSV without launching VSX.

**Tech Stack:** MATLAB R2024b for offline tests; Vantage NXT 2.3.2-p2 documented runtime remains R2024a; no runtime activation in tests.

---

- [x] Probe module: add `+icevs/make_trans.m`, `tx_delays.m` and `tests/test_verasonics_probe.m`; verify dimension/mapping rejection and `delay/frequency + distance/c` is constant at a positive focus; compare baseline imaging delays with vendor mathematical utility.
- [x] Event module: add `+icevs/compile_events.m` and `tests/test_verasonics_events.m`; test three modes, valid receive indices, explicit profile waits, no DMA for exposure-only, finite `stop`, and positive PRI bounds before implementation.
- [x] Builder: add `default_config.m`, `validate_config.m`, `build.m`, `save_sequence.m`, `SetUpICE_ImagingCuring.m`, plus `tests/test_verasonics_dual_mode.m`. Test baseline values, 96-element explicit remapping, multi-focus delays, row alignment, save/load and invalid parameters before implementation.
- [x] Integration: run `runtests` on new tests then `run_tests`; run `checkcode` on new source files. Produce a default sequence and JSON/CSV evidence under `results/verasonics_dual_mode` without VSX.
- [x] Review: independent review first for accepted-design compliance then code/timing correctness; fix actionable issues and repeat affected checks.
- [x] Documentation: update dual-mode README, add upgrade report and CHANGELOG entry, record actual tests and limitations, run `git diff --check`. Keep pre-existing changes and vendor files untouched; no commit or push requested.

All source modules above live in `verasonics/dual_mode/+icevs`, except the public entry in `verasonics/dual_mode`. Do not run an original SetUp as a way to load baseline data because it calls VSX. Load only its saved MAT variables.
