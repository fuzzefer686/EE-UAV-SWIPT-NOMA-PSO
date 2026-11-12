# V10C runnable prototype — final verification, 2026-11-04

## Delivered code

From the project root in MATLAB:

```matlab
setup_project;
maincodeV10CCampaign;
```

`scripts/maincodeV10CCampaign.m` calls `runV10CComparison('full',seeds,0:5)` with seeds `[2026,608060,3486784401]`. Every preset uses L=3e6 bit/user, q=5e3 bit/user/service slot and Emax=17000 J. Each of the three methods has 120 particles and 1000 iterations. Total: 54 searches, each with 120120 objective evaluations including swarm initialization. The full campaign has not been launched in this delivery.

| Method | BS position | Particle dimensions C0/C1, C2/C3, C4/C5 |
|---|---|---|
| Joint PSO | Fixed at scenario coordinates | 138, 158, 178 |
| Full PSO | Optimized | 144, 164, 184 |
| Full IPSO | Optimized | 144, 164, 184 |

All enabled geometry, NOMA and time variables are searched by PSO/IPSO. This is an implemented joint-search reference, not SCA/Dinkelbach. Stay proposals, directed Y repair, hover-budget repair, channel-ranked NOMA shares, feasibility-first fitness and best-so-far histories are implemented. The fixed-BS method excludes the six BS coordinates from its particle and retains the original scenario BS locations.

Each preset/seed combination writes a unique `results/v10c/Cx/.../results.mat` and `summary.txt`. These contain the baseline, three searched candidates, configuration, constraint flags, histories and evaluation counts. The campaign writes `comparison.csv` and `comparison.mat` after each completed preset/seed combination. These are progress checkpoints, not an automatic resume facility. Campaign plotting is disabled; standalone `runV10C` can produce diagnostic figures.

## Execution evidence

Final verification used MATLAB R2025a and completed with exit code 0 and the marker `FINAL_V10C_VERIFICATION_PASSED`.

| Check | Actual result |
|---|---|
| `testV10CModels` | Passed, including C0 evaluator comparison and variable-time/model checks |
| `testV10CSearch` | Passed, including six layouts, repair, tight 2 s hover budget, deterministic search, RNG restoration, monotone best fitness, fixed BS and three-method runner |
| Six-preset campaign smoke run | Completed: one scenario seed (2026), all three methods, 4 particles, 3 iterations |
| Saved smoke output assertions | Passed: 18 rows, six presets, three method labels, 16 evaluations per search |
| Full-profile configuration assertions for C0–C5 | Passed: 120 particles, 1000 iterations, three methods, L=3e6 and q=5e3 |
| `check_v10c_search.py` | 7 passed |
| `check_v10c_static.py` | 10 passed |
| `check_v10_static.py` | 12 passed |
| `check_v11_static.py` | 6 passed |
| `test_v11_static_guard.py` | 5 passed |
| MISS_HIT parser, syntax only | 25 MATLAB files passed |
| `git diff --check` | Exit 0 |

The 40 Python checks are source-contract, preservation and independent numerical checks; they are distinct from MATLAB execution. All 79 MATLAB sources recorded before V10C remain unchanged. The parser is not MATLAB Code Analyzer and does not establish algorithmic correctness.

Logs and a source SHA-256 manifest are saved under `results/v10c/verification_20261104/`. The smoke campaign outputs are under `results/v10c/comparisons/tp8c89c545_8e81_44df_870f_0692ed7b74b9/`.

The smoke run did not find feasible candidates at this very small budget. This verifies execution and saving, not optimization quality or infeasibility of the requested problem. A previous 20-particle/100-iteration campaign used only two methods; it must not be presented as the requested three-method full experiment.

## Remaining research scope

- SCA and Dinkelbach are not implemented; `v10cTimeBlockData` provides coefficients only. The requested three search methods do not depend on either solver.
- C5 uses an explicitly enabled, unvalidated quasi-steady rest-to-rest extension with assumed acceleration. It is not the published Dai model. Physical validation and comparison under a common energy backend remain research tasks.
- C0 inherits the V10B physical evaluator and main constraints; its normalized search encoding/operators differ, so it does not promise the same trajectory or PSO history as V10B at the same seed.
- No global optimum or feasible solution is guaranteed by PSO/IPSO. Infeasible computed EE remains diagnostic; `feasibleEE` is NaN in the comparison table until every constraint passes.

No commit, push or branch switch was performed. Existing V11 work was retained. No dependency was added to the project; the optional parser was installed only in a temporary directory.
