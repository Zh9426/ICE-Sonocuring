# Matrix partition correction plan

User-approved design: one 12-by-8 matrix, left 6-by-8 imaging, right 6-by-8 exposure. Implementation stays offline. See ../specs/2026-10-09-matrix-partition-correction.md.

1. Replace default linear probe with explicit matrix geometry and provenance. Add matrix Trans construction; retain linear math only for historical utility tests.
2. Add coordinate-based fixed masks and forbid custom weights outside each physical region; update both imaging TX and RX.
3. Use 3D focal distances and type-2 plane-wave delays; switch imaging PData/display to 3D coordinates with one XZ slice. Recompute receive distance bounds.
4. Run changed integration tests (RED observed on 2026-10-09), add mapping permutation, geometry and vendor focal-delay comparisons, then full regression and Code Analyzer.
5. Export current matrix artifacts under a distinct schema/stem with element-map CSV. Mark old line-array results/report as superseded; update README and CHANGELOG with actual validation, limitations and sources. No hardware execution, commit or push.
