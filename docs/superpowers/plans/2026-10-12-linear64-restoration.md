# Linear64 Restoration Implementation Plan

**Goal:** Restore the user-confirmed working 64-element linear baseline with physical left/right roles and traceable performance limits.

**Architecture:** Keep the finite event compiler. Restore type-0 geometry and 2D reconstruction, retain explicit synthetic matrix regressions, add source-qualified operating-envelope reporting.

**Tech Stack:** MATLAB R2024b, matlab.unittest, vendor numerical utilities only.

- [x] Update integration tests to expect type=0, 64 elements, physical 32/32 masks, 2D reconstruction; add reordered geometry and off-plane rejection. Run and retain failing results before implementation.
- [x] Update default_config/make_trans/partition_apertures/validate_config/build to implement the approved linear path; leave matrix tests on explicit synthetic fixtures.
- [x] Add operating-envelope computation and configured-limit checks. Tests cover burst duration, local duty, total on-time, unknown manufacturer limits, excessive duty/duration and invalid limits. Keep simulation-only gate.
- [x] Update export paths/verification plot to linear64; generate all three finite modes without VSX. Run all Verasonics tests and static analysis.
- [x] Write real-model hardware evidence report, update README/CHANGELOG and superseded matrix notices. Check vendor hashes and git diff --check. Report actual checks and remaining manufacturer/bench evidence gaps.

User approved the design in this chat; proceed inline without another design approval or automatic hardware execution. Existing untracked vendor/driver work is in the shared workspace, so preserve it in place rather than using a worktree that would omit those inputs. No commit/push requested.
