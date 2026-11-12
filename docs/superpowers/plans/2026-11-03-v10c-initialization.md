# V10C Initialization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Initialize an independently named MATLAB V10C configuration, candidate and evaluator pipeline, with explicit research-model status and no fabricated optimizer output.

**Architecture:** Reuse read-only V10 channel, propulsion and scenario builders. Keep geometry, per-slot times and physical-user alpha in separate candidate fields. A geometry-only particle layout prepares the future alternating optimizer; resource blocks are not added to that particle.

**Tech Stack:** MATLAB core functions; Python source-contract and independent numerical checks. No new project dependencies.

**Spec:** This document records the initialization scope authorized by the user's 2026-11-03 request and the V10C model discussed in this chat.

## Global Constraints

- Add new V10C files. Preserve all existing tracked and untracked MATLAB source byte-for-byte; do not commit, push, reset, or change branches. One narrowly scoped Python guard fix is recorded below.
- User requested code initialization. Implement a candidate initialization/evaluation runner, not an unverified full SCA/Dinkelbach optimizer.
- Do not launch MATLAB or a production campaign during this initialization; distinguish static/numerical checks from MATLAB execution.
- Default C4: 20 serving slots, arrival without service, H=30 m, monotone nonincreasing Y with stay allowed, variable hover [0.1,3] s, total hover <=20 s, variable EH fraction [0.05,0.95].
- Six presets C0 compatibility, C1 stay, C2 hover, C3 split, C4 joint time, C5 experimental motion. Geometry remains within the V10 corridor and fixed endpoints.
- L=3e6 bit/user, user-slot target 5e3 bits, gross UAV load budget 17000 J. Same radio and physical parameters as the current V10 defaults.
- Stable energy backend: unchanged Drones power plus explicit hover and RF. Experimental backend: deterministic rest-to-rest speed profile and quasi-steady thrust extension; explicitly NOT the published Dai model and disabled unless opted in.
- No extra stop or turn fee on top of motion energy. Zero-distance transitions have zero movement time/energy; consecutive coincident slots form one physical service visit.
- SCA and Dinkelbach remain declared future integration points. Provide time-block coefficients for independent validation; no silent substitute solver.

## Review Focus

1. Arrival point must not contribute service, hover, RF or an alpha row.
2. Stay must not create a fake movement or extra stop; no tolerance may make nonzero movement free.
3. Invalid time/geometry/alpha candidates must not be silently normalized or projected by the evaluator.
4. Variable per-slot times must enter harvested energy, RF power, bits and energy consistently.
5. Experimental physics and initialization outputs must not be labeled validated or optimized; bounds and disabled modes must be enforced.

## Task 1: Configuration and initialization kernel

**Files:** New `v10cConfig`, `buildV10CSimulation`, `initialV10CCandidate`, geometry layout/decode helpers, and source/MATLAB tests.

- [x] Write source-contract tests and a MATLAB analytical/integration test before implementation.
- [x] Run source-contract tests and confirm missing V10C API fails.
- [x] Implement presets, validation, local-RNG scenario generation and candidate initialization.

## Task 2: Physics and evaluator

**Files:** New `v10cMotionEnergy`, `evaluateV10CCandidate`, `v10cTimeBlockData`.

- [x] Implement inherited steady energy and gated experimental rest-to-rest motion.
- [x] Evaluate raw candidates without repair; track all data, geometric, timing and energy constraints.
- [x] Expose normalized NOMA time coefficients with exact affine energy coefficients for future Dinkelbach work.
- [x] Verify source contracts and independent numerical identities. Leave MATLAB test execution explicitly pending.

## Task 3: Runner, documentation and review

**Files:** New `scripts/runV10C.m`, `scripts/maincodeV10C_EE.m`, `docs/V10C_GUIDE.md`.

- [x] Add an initialization-only runner and uniquely named output folders with saved configuration and honest status.
- [x] Document preset matrix, manual MATLAB checks and future solver integration.
- [x] Confirm all prior MATLAB hashes unchanged, run V10/V11 source guards and review new V10C files independently.

## Execution notes

The existing workspace contains unrelated untracked V11 work. New V10C filenames provide separation in the current user workspace; no worktree or branch mutation is required. The user's explicit request authorizes initialization, so routine implementation choices are recorded here rather than adding another approval round. Runtime MATLAB execution is pending; source checks are not a substitute for it.

User selected C4 explicitly through the configuration question. No project dependency was installed, and no MATLAB execution or optimization run was performed.

Independent review found no critical/important issue. Two minor points were addressed: `modelInherited` now avoids claiming empirical validation, and MATLAB tests use local result variables before field access. The status-label regression check failed before the rename and passed afterward.

Ruling: `tests/check_v11_static.py` used `maincodeV10*.m` to enumerate a historical snapshot, incorrectly including the newly added V10C entry point. The snapshot coverage check failed with exactly that new path. Replace the wildcard with the original A/B/Campaign entry-point list; all original checksum checks remain intact. This is a test-only scope correction, not a V11 MATLAB change. The guard passed after the fix.

No commits were created because the existing project handoff requires explicit user instruction for commit/push. The completed checkboxes refer to initialization and source/numerical verification only, not MATLAB runtime or the future optimizer.
