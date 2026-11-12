function testV12Models()
%TESTV12MODELS Analytic and lightweight integration tests for V12.
    cfg = v12Config();
    assert(abs(cfg.radio.phiMax - 0.999) < 1e-15);
    cfg.mission.minBitsPerUser = 0;
    cfg.mission.minBitsPerSlot = 0;
    cfg.mission.minBitsPerUserPerSlot = 0;
    cfg.output.makePlots = false;
    cfg.output.saveResults = false;
    cfg.output.saveFigures = false;

    % 1. V10 equivalence for steady cruise + fixed phi + non-causal DL rate.
    cfgEq = cfg;
    cfgEq.flight.motionMode = 'steady-cruise';
    cfgEq.radio.powerSplitMode = 'fixed';
    cfgEq.radio.enforceUlDlCausality = false;
    rng(cfgEq.random.mainSeed, 'twister');
    sim10B = buildV10Simulation(cfgEq, 'B');
    rng(cfgEq.random.mainSeed, 'twister');
    sim12B = buildV12Simulation(cfgEq, 'B');
    assert(isequal(sim10B.xUser, sim12B.xUser));
    assert(isequal(sim10B.gNLoSUsers, sim12B.gNLoSUsers));
    assert(isequal(sim10B.gNLoSBS, sim12B.gNLoSBS));

    pB = initialV10Particle(sim12B, true, true);
    pB = repairV10Particle(pB, sim12B, true);
    [fit10, res10] = evaluateTrajectoryV10(pB, sim10B, true, false);
    [fit12, res12] = evaluateTrajectoryV12(pB, sim12B, true, false);
    assert(abs(res12.totalBits - res10.totalBits) / max(1, res10.totalBits) < 1e-13);
    assert(abs(res12.totalEnergy - res10.totalEnergy) / max(1, res10.totalEnergy) < 1e-13);
    assert(abs(res12.eeUAV - res10.eeUAV) / max(1, res10.eeUAV) < 1e-13);
    assert(abs(fit12 - fit10) / max(1, abs(fit10)) < 1e-13);

    % 2a. Fixed causal reference and practical-cap projection on real UAV channels.
    cfgOpt = cfg;
    cfgOpt.radio.powerSplitMode = 'optimal-causal';
    cfgOpt.radio.enforceUlDlCausality = true;
    cfgOpt.mission.ehFraction = 0.5;
    rng(cfgOpt.random.mainSeed, 'twister');
    simOpt = buildV12Simulation(cfgOpt, 'B');
    assert(abs(simOpt.radio.phiMax - 0.999) < 1e-15);
    [~, resOpt] = evaluateTrajectoryV12(pB, simOpt, true, false);
    assert(all(abs(resOpt.phiTrace - 0.999) < 1e-15));
    assert(resOpt.ulDlFeasible);

    cfgFixCausal = cfgOpt;
    cfgFixCausal.radio.powerSplitMode = 'fixed';
    cfgFixCausal.radio.powerSplit = 0.9;
    rng(cfgFixCausal.random.mainSeed, 'twister');
    simFixCausal = buildV12Simulation(cfgFixCausal, 'B');
    [~, resFixCausal] = evaluateTrajectoryV12(pB, simFixCausal, true, false);
    assert(resOpt.totalBits > resFixCausal.totalBits);

    % Sum-rate optimality against dense fixed-phi scans; no per-user Pareto claim.
    phiGrid = unique([linspace(0.001, 0.99, 400), linspace(0.99, 0.999, 600)]);
    qDec = decodeV10Particle(pB, simOpt, true);
    pos1 = [qDec.xTraj(1), qDec.yTraj(1), qDec.zTraj(1)];
    posUsers = [simOpt.xUser(:), simOpt.yUser(:), simOpt.zUser(:)];
    posBS = [qDec.xBS(:), qDec.yBS(:), qDec.zBS(:)];
    hU1 = v10Channel(pos1, posUsers, simOpt.gNLoSUsers, simOpt.radio);
    hB1 = v10Channel(pos1, posBS, simOpt.gNLoSBS, simOpt.radio);
    alpha1 = resOpt.alphaTrace(1, :);
    [rateOpt1, ~, ~, ~, ~, phiChosen1] = ...
        findAchievableRateV12(hU1, hB1, alpha1, simOpt);
    assert(abs(phiChosen1 - simOpt.radio.phiMax) < 1e-15);
    maxSumGrid = fixedGridMaximum(hU1, hB1, alpha1, simOpt, phiGrid);
    assert(sum(rateOpt1) >= maxSumGrid - 1e-10);

    % 2b. Exact symmetric single-user kink must be returned to zero ULP.
    simKink = localRadioCase(1 - 1e-12);
    hKink = 2;
    [~, ~, ~, ~, ~, phiKink] = findAchievableRateV12(hKink, 1, 1, simKink);
    phiKinkExpected = 1 / (1 + simKink.radio.ehEfficiency * abs(hKink)^2);
    assert(phiKink == phiKinkExpected);

    % 2c. Regression counterexample: old strongest-user rule loses 69.946680%.
    gains = [0.01, 0.1, 1];
    alphaCounter = [0.998, 0.001, 0.001];
    [rateCounter, ~, ~, ~, ~, phiCounter] = ...
        findAchievableRateV12(sqrt(gains), 1, alphaCounter, simKink);
    assert(abs(phiCounter - 0.991080277502478) < 2e-12);
    phiOld = 1 / (1 + simKink.radio.ehEfficiency * max(gains));
    simOld = simKink;
    simOld.radio.powerSplitMode = 'fixed';
    simOld.radio.powerSplit = phiOld;
    rateOld = findAchievableRateV12(sqrt(gains), 1, alphaCounter, simOld);
    relativeGain = sum(rateCounter) / sum(rateOld) - 1;
    assert(relativeGain > 0.6994667 && relativeGain < 0.6994669);
    phiCounterGrid = unique([linspace(0, 1, 5001), ...
        linspace(0.98, 0.999999, 4001), phiCounter]);
    maxCounterGrid = fixedGridMaximum(sqrt(gains), 1, alphaCounter, simKink, phiCounterGrid);
    assert(sum(rateCounter) >= maxCounterGrid - 1e-12);

    % 2d. Asymmetric UL/DL timing: bisection result versus dense scan.
    cfgAsym = cfgOpt;
    cfgAsym.mission.ehFraction = 0.35;
    cfgAsym.radio.phiMax = 1 - 1e-12;
    rng(cfgAsym.random.mainSeed, 'twister');
    simAsym = buildV12Simulation(cfgAsym, 'B');
    hUInt = 10 * hU1;
    [rateIntOpt, ~, ~, ~, ~, phiInt] = ...
        findAchievableRateV12(hUInt, hB1, alpha1, simAsym);
    assert(phiInt > simAsym.radio.phiMin && phiInt < simAsym.radio.phiMax);
    phiDense = unique([linspace(0.001, 0.999, 5000), ...
        linspace(0.999, 1 - 1e-12, 1000), phiInt]);
    bestCausalSum = fixedGridMaximum(hUInt, hB1, alpha1, simAsym, phiDense);
    assert(sum(rateIntOpt) >= bestCausalSum - 1e-8 * max(1, bestCausalSum));

    % 3a. Gauss-Legendre quadrature versus MATLAB integral().
    f = simOpt.flight;
    dTest = [0; 2.5; 15; 80.123; 150];
    motion = droneMotionEnergyV12(dTest, f, simOpt.cruisePower);
    assert(motion.flightTimePerSegment(1) == 0);
    assert(motion.flightEnergyPerSlot(1) == 0);
    for idx = 2:numel(dTest)
        di = dTest(idx);
        vp = min(f.cruiseSpeed, sqrt(f.acceleration * di));
        pFunPos = @(v) localQuasiSteadyPower(v, f.acceleration, f);
        pFunNeg = @(v) localQuasiSteadyPower(v, -f.acceleration, f);
        eRampRef = integral(@(t) pFunPos(f.acceleration * t), 0, vp / f.acceleration, ...
            'RelTol', 1e-13, 'AbsTol', 1e-15) ...
            + integral(@(t) pFunNeg(vp - f.acceleration * t), 0, vp / f.acceleration, ...
            'RelTol', 1e-13, 'AbsTol', 1e-15);
        relErr = abs(motion.rampEnergyPerSlot(idx) - eRampRef) / max(1, eRampRef);
        assert(relErr < 1e-12);
    end

    % 3b. Thrust/tilt bounds and acceleration versus steady-cruise ordering.
    vSamples = linspace(0, f.cruiseSpeed, 50);
    for aSigned = [-f.acceleration, 0, f.acceleration]
        drag = 0.5 * f.airDensity * f.flatPlateArea .* (vSamples.^2);
        horizForce = f.mass * aSigned + drag;
        vertForce = f.mass * f.gravity;
        totalThrust = hypot(vertForce, horizForce);
        tiltRad = atan2(abs(horizForce), vertForce);
        pVals = localQuasiSteadyPower(vSamples, aSigned, f);
        assert(all(totalThrust >= vertForce - 1e-12));
        assert(all(tiltRad >= 0 & tiltRad < pi / 4));
        assert(all(isfinite(pVals) & pVals > 0));
    end

    fSteady = f;
    fSteady.motionMode = 'steady-cruise';
    fA2 = f;
    fA2.acceleration = 2.0;
    fA3 = f;
    fA3.acceleration = 3.0;
    fA5 = f;
    fA5.acceleration = 5.0;
    mSteady = droneMotionEnergyV12(dTest, fSteady, simOpt.cruisePower);
    mA2 = droneMotionEnergyV12(dTest, fA2, simOpt.cruisePower);
    mA3 = droneMotionEnergyV12(dTest, fA3, simOpt.cruisePower);
    mA5 = droneMotionEnergyV12(dTest, fA5, simOpt.cruisePower);
    assert(all(mA2.flightTimePerSegment(2:end) > mA3.flightTimePerSegment(2:end)));
    assert(all(mA3.flightTimePerSegment(2:end) > mA5.flightTimePerSegment(2:end)));
    assert(all(mA5.flightTimePerSegment(2:end) > mSteady.flightTimePerSegment(2:end)));
    assert(all(mA2.flightEnergyPerSlot(2:end) > mA3.flightEnergyPerSlot(2:end)));
    assert(all(mA3.flightEnergyPerSlot(2:end) > mA5.flightEnergyPerSlot(2:end)));
    assert(all(mA5.flightEnergyPerSlot(2:end) > mSteady.flightEnergyPerSlot(2:end)));

    % 4. Per-scenario seed hash parity and S10 uniqueness (configuration only).
    [a2026, p2026] = deriveV12OptimizerSeeds(2026);
    v10Def = v10Config();
    assert(a2026 == v10Def.random.algorithmSeed);
    assert(p2026 == v10Def.random.polishSeed);
    s10 = [2026, 608060, 3486784401, 2027, 2028, 2029, 2030, 2031, 2032, 2033];
    algoSeeds = zeros(size(s10));
    polSeeds = zeros(size(s10));
    for idx = 1:numel(s10)
        [algoSeeds(idx), polSeeds(idx)] = deriveV12OptimizerSeeds(s10(idx));
        assert(algoSeeds(idx) >= 0 && algoSeeds(idx) < 2^32);
        assert(polSeeds(idx) >= 0 && polSeeds(idx) < 2^32);
        assert(algoSeeds(idx) ~= polSeeds(idx));
    end
    assert(numel(unique(algoSeeds)) == numel(s10));
    assert(numel(unique(polSeeds)) == numel(s10));

    % 5. Clustered initialization: deterministic mode uses no RNG.
    rngStateBefore = rng;
    pDetFull = initialV12Particle(simOpt, true, false);
    pDetJoint = initialV12Particle(simOpt, false, false);
    rngStateAfter = rng;
    assert(isequal(rngStateBefore, rngStateAfter));
    [~, resDetFull] = evaluateTrajectoryV12(pDetFull, simOpt, true);
    [~, resDetJoint] = evaluateTrajectoryV12(pDetJoint, simOpt, false);
    assert(resDetFull.energyFeasible && resDetFull.geometryFeasible);
    assert(resDetJoint.energyFeasible && resDetJoint.geometryFeasible);

    rng(151459287, 'twister');
    for i = 1:20
        pClust = initialV12Particle(simOpt, true, i > 1);
        [~, resClust] = evaluateTrajectoryV12(pClust, simOpt, true);
        assert(resClust.energyFeasible && resClust.geometryFeasible);
    end

    % 6a. Strict budget caps, history padding, solver modes and joint polishing.
    P = 3;
    N = 4;
    cap = 7;
    nSamp = 3;
    optsJ = cfg.optimizers.joint;
    optsJ.numParticles = P;
    optsJ.maxIter = N;
    optsJ.maxEvals = cap;
    optsJ.initMode = 'v10';
    optsJ.updateMode = 'independent';
    optsJ.mutationMode = 'elementwise';
    rJ = optimizeTrajectoryV12JointPSO(simOpt, optsJ);
    assert(strcmp(rJ.mode, 'v12-joint-pso'));
    assert(numel(rJ.bestHistory) == N + 1);
    assert(~rJ.useClustered && rJ.evalCount == cap);
    assert(all(isfinite(rJ.bestHistory)));
    assert(strcmp(rJ.updateMode, 'independent'));
    rJPol = polishAlphaV12(rJ, simOpt, nSamp, false);
    assert(rJPol.bestFitness >= rJ.bestFitness && rJPol.alphaPolished);
    assert(numel(rJPol.bestParticle) == numel(rJ.bestParticle));
    assert(rJPol.evalCountPolish == 1 + (simOpt.numSteps - 1) * nSamp);
    assert(rJPol.evalCountTotal == rJ.evalCount + rJPol.evalCountPolish);

    optsF = cfg.optimizers.full;
    optsF.numParticles = P;
    optsF.maxIter = N;
    optsF.maxEvals = cap;
    optsF.initMode = 'v10';
    optsF.updateMode = 'independent';
    optsF.mutationMode = 'elementwise';
    rF = optimizeTrajectoryV12FullPSO(simOpt, optsF);
    assert(strcmp(rF.mode, 'v12-full-pso'));
    assert(numel(rF.bestHistory) == N + 1);
    assert(~rF.useClustered && rF.evalCount == cap);
    assert(all(isfinite(rF.bestHistory)));
    rFPol = polishAlphaV12(rF, simOpt, nSamp);
    assert(rFPol.bestFitness >= rF.bestFitness && rFPol.alphaPolished);
    assert(rFPol.evalCountTotal == cap + 1 + (simOpt.numSteps - 1) * nSamp);

    optsI = cfg.optimizers.ipso;
    optsI.numParticles = P;
    optsI.maxIter = N;
    optsI.maxEvals = cap;
    optsI.initMode = 'v10';
    optsI.updateMode = 'independent';
    optsI.mutationMode = 'elementwise';
    rI = optimizeTrajectoryV12FullIPSO(simOpt, optsI);
    assert(strcmp(rI.mode, 'v12-full-ipso'));
    assert(numel(rI.bestHistory) == N + 1);
    assert(~rI.useClustered && rI.evalCount == cap);
    assert(all(isfinite(rI.bestHistory)));

    optsJSolver = optsJ;
    optsJSolver.maxEvals = P;
    optsJSolver.maxIter = 0;
    optsJSolver.initMode = 'clustered';
    optsJSolver.updateMode = 'correlated';
    rJSolver = optimizeTrajectoryV12JointPSO(simOpt, optsJSolver);
    assert(rJSolver.useClustered && strcmp(rJSolver.updateMode, 'correlated'));
    assert(rJSolver.evalCount == P);
    optsISolver = optsI;
    optsISolver.maxEvals = 2 * P;
    optsISolver.maxIter = 1;
    optsISolver.initMode = 'clustered';
    optsISolver.updateMode = 'correlated';
    optsISolver.mutationMode = 'block';
    rISolver = optimizeTrajectoryV12FullIPSO(simOpt, optsISolver);
    assert(rISolver.useClustered && strcmp(rISolver.updateMode, 'correlated'));
    assert(strcmp(rISolver.mutationMode, 'block'));
    assert(rISolver.evalCount <= 2 * P);

    % 6b. A prescreened seed must survive a zero-iteration, one-particle budget.
    seedJ = struct('numParticles', 1, 'maxIter', 0, 'maxEvals', 1, ...
        'seedParticle', rJ.bestParticle, 'seedResult', rJ, ...
        'seedSource', 'unit-joint', 'initialEvalCount', 1);
    rJSeed = optimizeTrajectoryV12JointPSO(simOpt, seedJ);
    assert(rJSeed.evalCount == 1 && rJSeed.evalCountIncumbentRaw == 1);
    assert(rJSeed.incumbentUsed && rJSeed.incumbentRetained);
    assert(isequal(rJSeed.bestParticle, rJ.bestParticle));
    assert(rJSeed.bestFitness >= rJ.bestFitness);
    assert(strcmp(rJSeed.incumbentSource, 'unit-joint'));

    seedF = struct('numParticles', 1, 'maxIter', 0, 'maxEvals', 1, ...
        'seedParticle', rF.bestParticle, 'seedResult', rF, ...
        'seedSource', 'unit-full', 'initialEvalCount', 1);
    rFSeed = optimizeTrajectoryV12FullPSO(simOpt, seedF);
    assert(rFSeed.incumbentUsed && rFSeed.incumbentRetained);
    assert(isequal(rFSeed.bestParticle, rF.bestParticle));

    seedI = struct('numParticles', 1, 'maxIter', 0, 'maxEvals', 1, ...
        'seedParticle', rI.bestParticle, 'seedResult', rI, ...
        'seedSource', 'unit-ipso', 'initialEvalCount', 1);
    rISeed = optimizeTrajectoryV12FullIPSO(simOpt, seedI);
    assert(rISeed.incumbentUsed && rISeed.incumbentRetained);
    assert(isequal(rISeed.bestParticle, rI.bestParticle));

    % Too-small budgets must fail before leaving a partly initialized swarm.
    badJ = optsJ;
    badJ.maxEvals = P - 1;
    assertBudgetError(@() optimizeTrajectoryV12JointPSO(simOpt, badJ), ...
        'optimizeTrajectoryV12JointPSO:MaxEvals');
    badF = optsF;
    badF.maxEvals = P - 1;
    assertBudgetError(@() optimizeTrajectoryV12FullPSO(simOpt, badF), ...
        'optimizeTrajectoryV12FullPSO:MaxEvals');
    badI = optsI;
    badI.maxEvals = P - 1;
    assertBudgetError(@() optimizeTrajectoryV12FullIPSO(simOpt, badI), ...
        'optimizeTrajectoryV12FullIPSO:MaxEvals');

    % 6c. End-to-end Joint-to-Full lift, followed by cross-model continuation.
    cfgRun = cfg;
    cfgRun.mission.minBitsPerUser = 2e6;
    cfgRun.optimizers.joint.numParticles = 2;
    cfgRun.optimizers.joint.maxIter = 1;
    cfgRun.optimizers.full.numParticles = 2;
    cfgRun.optimizers.full.maxIter = 1;
    cfgRun.optimizers.ipso.numParticles = 2;
    cfgRun.optimizers.ipso.maxIter = 1;
    cfgRun.optimizers.alphaPolishSamplesPerUser = 0;
    cfgRun.optimizers.alphaPolishMinimumSamples = 1;
    cfgRun.optimizers.polishJoint = true;
    cfgRun.optimizers.incumbentMode = 'jointToFull';
    data1 = runV12('B', cfgRun);
    rawBudget = 2 * (1 + 1);
    raw1 = {data1.trajJointRaw, data1.trajFullRaw, data1.trajIPSORaw};
    polished1 = {data1.trajJointPolished, data1.trajFull, data1.trajIPSO};
    assert(~data1.trajJointRaw.incumbentUsed);
    assert(data1.trajFullRaw.incumbentUsed && data1.trajIPSORaw.incumbentUsed);
    for k = 1:numel(raw1)
        assert(raw1{k}.evalCount == rawBudget);
        assert(polished1{k}.evalCount == rawBudget + 1 + (simOpt.numSteps - 1));
        assert(polished1{k}.bestFitness >= raw1{k}.bestFitness);
    end

    pool = localPoolFromRun(data1);
    cfgNext = cfgRun;
    cfgNext.mission.minBitsPerUser = 1e6;
    cfgNext.optimizers.incumbentMode = 'crossModel';
    data2 = runV12('B', cfgNext, pool);
    raw2 = {data2.trajJointRaw, data2.trajFullRaw, data2.trajIPSORaw};
    polished2 = {data2.trajJointPolished, data2.trajFull, data2.trajIPSO};
    for k = 1:numel(raw2)
        assert(raw2{k}.incumbentUsed);
        assert(raw2{k}.evalCount == rawBudget);
        assert(raw2{k}.evalCountIncumbentRaw >= 1);
        assert(polished2{k}.evalCount == rawBudget + 1 + (simOpt.numSteps - 1));
        assert(polished2{k}.bestFitness >= raw2{k}.bestFitness);
        % Source cost: every screened ancestor stage is counted exactly once.
        assert(raw2{k}.sourceCostComplete && polished2{k}.sourceCostComplete);
        assert(raw2{k}.evalCountCumulative == sum(raw2{k}.lineage.evals));
        assert(numel(unique(raw2{k}.lineage.keys)) == numel(raw2{k}.lineage.keys));
        assert(raw2{k}.evalCountSource >= rawBudget);
        assert(raw2{k}.evalCountCumulative == raw2{k}.evalCount + raw2{k}.evalCountSource);
        assert(polished2{k}.evalCountCumulative >= raw2{k}.evalCountCumulative ...
            + polished2{k}.evalCountPolish);
    end
    % data1 Joint raw had no pool: zero source cost. Full raw inherits Joint raw once.
    assert(data1.trajJointRaw.evalCountSource == 0);
    assert(data1.trajFullRaw.evalCountSource == data1.trajJointRaw.evalCount);
    assert(data1.trajFull.evalCountCumulative == data1.trajFull.evalCount ...
        + data1.trajJointPolished.evalCountPolish + data1.trajJointRaw.evalCount);

    % 6d. P2 regression: screening a large pool must leave numParticles-1 evaluations.
    cfgP2 = cfgNext;
    cfgP2.optimizers.incumbentMode = 'crossModel';
    rng(cfgP2.random.mainSeed, 'twister');
    simP2 = buildV12Simulation(cfgP2, 'B');
    rng(11, 'twister');
    poolP2 = struct('raw', repmat(struct('algorithm', 'Joint PSO', 'particle', [], ...
        'source', ''), 4, 1), 'polished', repmat(struct('algorithm', 'Joint PSO', ...
        'particle', [], 'source', ''), 0, 1));
    for m = 1:4
        poolP2.raw(m).particle = repairV10Particle(initialV10Particle(simP2, false, true), ...
            simP2, false);
        poolP2.raw(m).source = sprintf('unit-p2-%d', m);
    end
    dataP2 = runV12('B', cfgP2, poolP2);
    assert(dataP2.trajJointRaw.incumbentUsed);
    assert(dataP2.trajJointRaw.evalCountIncumbentRaw == rawBudget - 1);
    assert(dataP2.trajJointRaw.evalCount == rawBudget);
    assert(~dataP2.trajJointRaw.sourceCostComplete); % pool without lineage => unknown cost

    % 6e. Control branch: no incumbents, cumulative cost equals own cost.
    cfgNone = cfgRun;
    cfgNone.optimizers.incumbentMode = 'none';
    dataNone = runV12('B', cfgNone, pool);
    stagesNone = {dataNone.trajJointRaw, dataNone.trajJointPolished, ...
        dataNone.trajFullRaw, dataNone.trajFull, dataNone.trajIPSORaw, dataNone.trajIPSO};
    for k = 1:numel(stagesNone)
        assert(~stagesNone{k}.incumbentUsed);
        assert(stagesNone{k}.evalCountSource == 0 && stagesNone{k}.sourceCostComplete);
        assert(stagesNone{k}.evalCountCumulative == stagesNone{k}.evalCount);
    end

    % 6f. Direct warm-start calls with identical cfg (no runTag, then the same
    % explicit runTag) must keep distinct lineage keys: source cost is additive.
    cfgDup = cfgRun;
    cfgDup.optimizers.incumbentMode = 'crossModel';
    for tagCase = 1:2
        if tagCase == 2
            cfgDup.optimizers.runTag = 'same-tag';
        end
        dupA = runV12('B', cfgDup);
        dupB = runV12('B', cfgDup, localPoolFromRun(dupA));
        assert(dupA.trajJointRaw.evalCountCumulative == rawBudget);
        assert(dupB.trajJointRaw.incumbentUsed && dupB.trajJointRaw.sourceCostComplete);
        assert(isempty(intersect(dupA.trajJointRaw.lineage.keys(end), ...
            dupB.trajJointRaw.lineage.keys(end))));
        assert(dupB.trajJointRaw.evalCountSource >= dupA.trajJointRaw.evalCount);
        assert(dupB.trajJointRaw.evalCountCumulative >= 2 * rawBudget);
    end

    % 7 off. Configuration-only campaign tests; no campaign optimization here.
    camp = runV12Campaign(struct('dryRun', true, 'groups', {{'L', 'option', 'solver'}}));
    assert(isstruct(camp) && numel(camp.configs) == 20);
    assert(all(strcmp({camp.configs.incumbentMode}, 'none')));
    campWarm = runV12Campaign(struct('dryRun', true, 'groups', {{'option'}}, ...
        'incumbentMode', 'crossModel'));
    assert(all(strcmp({campWarm.configs.incumbentMode}, 'crossModel')));
    smoke = runV12Campaign(struct('dryRun', true, 'groups', {{'hover'}}, ...
        'hoverVals', 1, 'alphaPolishSamplesPerUser', 0, ...
        'alphaPolishMinimumSamples', 1));
    assert(smoke.baseConfig.optimizers.alphaPolishSamplesPerUser == 0);
    assert(smoke.baseConfig.optimizers.alphaPolishMinimumSamples == 1);
    Lconfig = camp.configs(strcmp({camp.configs.group}, 'L'));
    assert(isequal([Lconfig.L], [3e6, 2e6, 1e6]));
    solverConfig = camp.configs(strcmp({camp.configs.group}, 'solver'));
    assert(numel(solverConfig) == 5);
    optionConfig = camp.configs(strncmp({camp.configs.group}, 'opt', 3));
    assert(numel(optionConfig) == 12);
    assert(isequal([optionConfig(1:3).L], [3e6, 2e6, 1e6]));

    fprintf('V12 model/integration checks passed 100%%.\n');
end

function maxSum = fixedGridMaximum(hUsers, hBS, alphaUser, sim, phiGrid)
    simScan = sim;
    simScan.radio.powerSplitMode = 'fixed';
    maxSum = -inf;
    for idx = 1:numel(phiGrid)
        simScan.radio.powerSplit = phiGrid(idx);
        rGrid = findAchievableRateV12(hUsers, hBS, alphaUser, simScan);
        maxSum = max(maxSum, sum(rGrid));
    end
end

function sim = localRadioCase(phiMax)
    sim.radio = struct('powerSplitMode', 'optimal-causal', ...
        'enforceUlDlCausality', true, 'powerSplit', 0.9, ...
        'ehEfficiency', 0.9, 'bsPowerW', 0.01, 'noisePowerW', 1, ...
        'bandwidthHz', 1, 'phiMin', 0, 'phiMax', phiMax);
    sim.ehTime = 0.5;
    sim.rfTime = 0.5;
end

function assertBudgetError(callable, expectedIdentifier)
    didThrow = false;
    try
        callable();
    catch err
        didThrow = true;
        assert(strcmp(err.identifier, expectedIdentifier));
    end
    assert(didThrow, 'Insufficient initialization budget did not raise an error.');
end

function pool = localPoolFromRun(data)
    algorithms = {'Joint PSO', 'Full PSO', 'Full IPSO'};
    rawResults = {data.trajJointRaw, data.trajFullRaw, data.trajIPSORaw};
    polishedResults = {data.trajJointPolished, data.trajFull, data.trajIPSO};
    template = struct('algorithm', '', 'particle', [], 'source', '', ...
        'L', data.sim.minBitsPerUser, 'slot', data.sim.minBitsPerUserPerSlot, ...
        'hover', data.sim.hoverTime, 'motionMode', data.sim.flight.motionMode, ...
        'accel', data.sim.flight.acceleration, 'phiMode', data.sim.radio.powerSplitMode, ...
        'phiMax', data.sim.radio.phiMax, 'causal', data.sim.radio.enforceUlDlCausality, ...
        'solverKey', sprintf('%s|%s|%s', data.sim.initMode, ...
        data.sim.updateMode, data.sim.mutationMode));
    raw = repmat(template, numel(algorithms), 1);
    polished = raw;
    for k = 1:numel(algorithms)
        raw(k).algorithm = algorithms{k};
        raw(k).particle = rawResults{k}.bestParticle;
        raw(k).source = ['unit-cross-raw-', algorithms{k}];
        raw(k).lineage = rawResults{k}.lineage;
        polished(k).algorithm = algorithms{k};
        polished(k).particle = polishedResults{k}.bestParticle;
        polished(k).source = ['unit-cross-polished-', algorithms{k}];
        polished(k).lineage = polishedResults{k}.lineage;
    end
    pool = struct('raw', raw, 'polished', polished);
end

function P = localQuasiSteadyPower(V, a, flight)
    n = flight.numRotors;
    rho = flight.airDensity;
    A = flight.rotorArea;
    cT = flight.thrustCoefficient;
    cs = flight.rotorSolidity;
    drag = 0.5 * rho * flight.flatPlateArea .* (V.^2);
    thrust = hypot(flight.mass * flight.gravity, flight.mass * a + drag) / n;
    profile = n * flight.bladeDrag / 8 .* (thrust / (cT * rho * A) + 3 * (V.^2)) ...
        .* sqrt(thrust * rho * cs^2 * A / cT);
    u = thrust / (2 * rho * A);
    w = (V.^2) / 2;
    induced = n * (1 + flight.inducedCorrection) .* thrust .* sqrt((u.^2) ./ (hypot(u, w) + w));
    parasite = n * 0.5 * flight.fuselageDragRatio * rho * cs * A .* (V.^3);
    P = profile + induced + parasite;
end
