# V10C runnable research prototype

User correction: initialization alone does not satisfy the intended task. Deliver an actual search loop for C0–C5 that the user can run to test the ideas. This authorizes implementation now; do not request another approval round.

## Scope

- Retain C4 default and C5 experimental opt-in. Preserve pre-V10C MATLAB source.
- Implement toolbox-free joint PSO and adaptive-mutation IPSO reference solvers over geometry, NOMA shares and the time variables enabled by each preset. This reference solver deliberately does not claim to implement SCA or Dinkelbach. A later hybrid can be compared against this working baseline.
- Normalize particle coordinates, repair endpoints/Y/timing budget, assign ordered NOMA shares to physical user identities using each candidate's channels, and use feasibility-first ranking.
- Explicit stay proposals must create exact coincident service locations without charging a transition or silently ignoring tiny distances.
- Save initial and searched candidates, all constraint flags, EE, histories, evaluation counts, model identity and configuration; plot trajectory, timing, user bits, convergence and energy.
- Add a comparison runner for C0–C5. The user's later request authorizes short MATLAB runtime checks. Do not launch the full 54-search campaign; deliver code for the user to run it.

## Tasks

1. Add failing prototype API contracts and MATLAB tests for enabled variable counts, repair, feasible retention, deterministic PSO/IPSO and runner dispatch.
2. Implement particle layout/encoding/repair/decoding and feasibility-first objective.
3. Implement PSO/IPSO and stay proposals with the same evaluation budget per algorithm.
4. Wire runV10C defaults to optimization, retain explicit initialize mode for diagnostics, add plots and comparison runner, update guide.
5. Run static/parser and independent math checks; independently review the code. Execute short MATLAB model/search tests and all six presets with three methods, keeping the full campaign for the user.

## Final delivery scope — 2026-11-04

Tasks 1–5 are implemented. The campaign entry point is `scripts/maincodeV10CCampaign.m`: C0–C5, seeds 2026/608060/3486784401, L=3e6 bit/user, q=5e3 bit/user/slot; Joint PSO with fixed BS, Full PSO and Full IPSO, each with 120 particles and 1000 iterations. Numerical outputs and comparison checkpoints are saved in unique folders.

This completes the runnable joint-search prototype. SCA/Dinkelbach and physical validation of the experimental C5 extension are separate research work; neither is represented as delivered. See `docs/V10C_VERIFICATION_2026-11-04.md` for final execution evidence.
