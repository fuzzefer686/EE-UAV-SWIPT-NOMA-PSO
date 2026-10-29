function testRFSlotMetrics()
% Run after setup_project; addpath('tests'); testRFSlotMetrics;
% Analytic checks of units, slot counting, phase durations and invalid energy.
    sim.Tslot = 1;
    input.achRate = [10, 20; 30, 40; 1e9, 1e9];
    input.pt = [2; 4; 1000];
    input.fitness = 123;
    input.isFeasible = true;
    r = addRFSlotMetrics(input, sim);

    % Two 1 s segments; arrival's huge rate/power must not enter totals.
    assert(isequal(r.slotIdx, 1:2));
    assert(isequal(r.timeSeconds, [0, 1, 2]));
    assert(r.missionTime == 2 && r.uplinkTime == 0.5 && r.downlinkTime == 0.5);
    assert(isequal(r.bitsPerUserPerSlot, [5, 10; 15, 20]));
    assert(isequal(r.bitsPerSlot, [15; 35]));
    assert(isequal(r.totalBitsPerUser, [20, 30]));
    assert(r.totalBits == 50 && r.totalEnergy == 3);
    assert(isequal(r.energyPerSlot, [1; 2]));
    assert(isequal(r.energyPerSlot, r.harvestedEnergyPerSlot));
    assert(abs(r.eeRF - 50/3) < 1e-12 && r.fitness == r.eeRF);
    assert(r.rateFitness == 123 && r.isFeasible);

    % Data QoS uses mission totals per user, not a sum across users or arrival.
    sim.minBitsPerUser = 25;
    short = addRFSlotMetrics(input, sim);
    assert(isequal(short.bitsShortfallPerUser, [5, 0]));
    assert(~short.dataQoSFeasible && ~short.isFeasible);
    assert(abs(short.fitness + 0.2) < 1e-12 && short.eeRF == r.eeRF);

    % Less shortage wins even before any feasible particle has been found.
    improvedInput = input;
    improvedInput.achRate(1, 1) = 18;
    improved = addRFSlotMetrics(improvedInput, sim);
    assert(improved.fitness > short.fitness && improved.fitness < 0);
    assert(r.fitness > improved.fitness);

    % User-specific targets accept column vectors; equality is feasible.
    sim.minBitsPerUser = [20; 40];
    perUser = addRFSlotMetrics(input, sim);
    assert(isequal(perUser.bitsShortfallPerUser, [0, 10]));
    assert(abs(perUser.fitness + 0.25) < 1e-12 && ~perUser.isFeasible);
    sim.minBitsPerUser = [20, 30];
    satisfied = addRFSlotMetrics(input, sim);
    assert(satisfied.dataQoSFeasible && satisfied.isFeasible);
    assert(satisfied.fitness == satisfied.eeRF);

    % Disabled requirements preserve the previous fitness.
    sim.minBitsPerUser = 0;
    disabled = addRFSlotMetrics(input, sim);
    assert(disabled.fitness == r.fitness && disabled.isFeasible);
    sim.minBitsPerUser = [];
    disabled = addRFSlotMetrics(input, sim);
    assert(disabled.fitness == r.fitness && disabled.isFeasible);

    % Doubling slot duration doubles bits and joules, preserving RF EE.
    sim.Tslot = 2;
    doubled = addRFSlotMetrics(input, sim);
    assert(doubled.totalBits == 100 && doubled.totalEnergy == 6);
    assert(doubled.missionTime == 4 && doubled.eeRF == r.eeRF);

    % Ratio of sums differs from unweighted mean of per-slot EE.
    assert(abs(r.eeRF - mean(r.bitsPerSlot ./ r.energyPerSlot)) > 1e-3);

    % Zero RF energy is undefined, never an artificially large EE.
    sim.Tslot = 1;
    input.pt(:) = 0;
    invalid = addRFSlotMetrics(input, sim);
    assert(isnan(invalid.eeRF) && invalid.fitness == -Inf && ~invalid.isFeasible);

    % A physically invalid particle cannot outrank feasible particles.
    input.pt = [2; 4; 1000];
    input.isFeasible = false;
    sim.minBitsPerUser = 100;
    invalid = addRFSlotMetrics(input, sim);
    assert(isfinite(invalid.eeRF) && invalid.fitness == -Inf && ~invalid.isFeasible);
    fprintf('RF slot accounting checks passed.\n');
end
