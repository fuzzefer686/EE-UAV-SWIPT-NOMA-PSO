# V10C initialization verification — 2026-11-03

> Historical report for the initial scaffold only. It does not describe the current runnable code. See [the current verification report](V10C_VERIFICATION_2026-11-04.md) for implemented PSO/IPSO, MATLAB runtime checks and the requested full campaign entry point.

## Scope delivered

Six presets C0–C5; user explicitly selected C4 as default. New MATLAB entry point, scenario builder, geometry-only particle interface, candidate initialization, time-aware NOMA/data/energy/constraint evaluator and future time-block solver coefficients. Runner stage is `initialized-not-optimized`; no optimizer is implemented or claimed.

Default energy inherits the existing Drones model plus explicit hover and RF. C5 is a gated, unvalidated quasi-steady thrust extension, not the published Dai model. No empirical validation is claimed.

## Checks actually executed

| Command | Result |
|---|---|
| `python3 tests/check_v10c_static.py` | 10 passed |
| `python3 tests/check_v10_static.py` | 12 passed |
| `python3 tests/check_v11_static.py` | 6 passed |
| `python3 -m unittest discover -s tests -p 'test_v11_static_guard.py' -v` | 5 passed |
| `git diff --check` | exit 0 |

These 33 checks are source-contract, preservation and independent numerical checks. They do not execute MATLAB. All 79 pre-existing MATLAB source files match their recorded SHA-256 hashes. No production simulation, optimization, MATLAB Code Analyzer or MATLAB unit test was run. `tests/testV10CModels.m` is prepared but remains runtime-unverified.

## Review and corrections

An independent read-only review found no critical/important issue in the initialization scope. Two minor recommendations were addressed: rename `modelValidated` to `modelInherited`, and avoid direct field access on function-return expressions in the manual MATLAB tests. The new source status check failed before the rename and passed after it.

The legacy V11 snapshot coverage check initially failed because its `maincodeV10*.m` wildcard included the new V10C entry point. The only existing-file change is a narrow Python test-guard fix: enumerate the three historical A/B/Campaign entry points explicitly. Original checksum validation remains unchanged. The snapshot guard and its five existing regression tests pass after the fix.

## Pending work

- Run the prepared MATLAB tests when authorized, including C0/V10B runtime equivalence and variable-time integration tests.
- Implement geometry PSO/repair with stay, select/implement the alpha solver and implement the Dinkelbach time solver.
- Validate experimental acceleration physics and parameter mappings before research claims or production campaigns.

No branch switch, commit, push, worktree creation or dependency installation was performed. Existing untracked V11 work and saved simulation outputs were preserved.
