function testV12Models()
%TESTV12MODELS Analytic/integration tests for V12 causal DF and quasi-steady acceleration.
    cfg = v12Config();
    cfg.mission.minBitsPerUser = 0;
    cfg.mission.minBitsPerSlot = 0;
    cfg.mission.minBitsPerUserPerSlot = 0;
    cfg.output.makePlots = false;
    cfg.output.saveResults = false;
    cfg.output.saveFigures = false;

    % 1. Exact V10 equivalence when steady-cruise + fixed power split + non-causal DL rate
    cfgEq = cfg;
    cfgEq.flight.motionMode = 'steady-cruise';
    cfgEq.radio.powerSplitMode = 'fixed';
    cfgEq.radio.enforceUlDlCausality = false;
    rng(cfgEq.random.mainSeed, 'twister');
    sim10B = buildV10Simulation(cfgEq, 'B');
    rng(cfgEq.random.mainSeed, 'twister');
    sim12B = buildV12Simulation(cfgEq, 'B');
    assert(isequal(sim10B.xUser, sim12B.xUser) && isequal(sim10B.gNLoSUsers, sim12B.gNLoSUsers));
    assert(isequal(sim10B.gNLoSBS, sim12B.gNLoSBS));

    pB = initialV10Particle(sim12B, true, true);
    pB = repairV10Particle(pB, sim12B, true);
    [fit10, res10] = evaluateTrajectoryV10(pB, sim10B, true, false);
    [fit12, res12] = evaluateTrajectoryV12(pB, sim12B, true, false);
    assert(abs(res12.totalBits - res10.totalBits) / max(1, res10.totalBits) < 1e-13);
    assert(abs(res12.totalEnergy - res10.totalEnergy) / max(1, res10.totalEnergy) < 1e-13);
    assert(abs(res12.eeUAV - res10.eeUAV) / max(1, res10.eeUAV) < 1e-13);
    assert(abs(fit12 - fit10) / max(1, abs(fit10)) < 1e-13);

    % 2a. Optimal causal power splitting at ehFraction = 0.5 (closed-form phiStar)
    cfgOpt = cfg;
    cfgOpt.radio.powerSplitMode = 'optimal-causal';
    cfgOpt.radio.enforceUlDlCausality = true;
    cfgOpt.mission.ehFraction = 0.5;
    rng(cfgOpt.random.mainSeed, 'twister');
    simOpt = buildV12Simulation(cfgOpt, 'B');
    [~, resOpt] = evaluateTrajectoryV12(pB, simOpt, true, false);

    cfgFixCausal = cfgOpt;
    cfgFixCausal.radio.powerSplitMode = 'fixed';
    cfgFixCausal.radio.powerSplit = 0.9;
    rng(cfgFixCausal.random.mainSeed, 'twister');
    simFixCausal = buildV12Simulation(cfgFixCausal, 'B');
    [~, resFixCausal] = evaluateTrajectoryV12(pB, simFixCausal, true, false);

    for t = 1:(simOpt.numSteps - 1)
        gMax = max(resOpt.h2UserTrace(t, :));
        phiClosed = 1 / (1 + simOpt.radio.ehEfficiency * gMax);
        assert(abs(resOpt.phiTrace(t) - phiClosed) < 1e-13);
        strongestUser = resOpt.idxWeak2StrongTrace(t, end);
        bUL = resOpt.ulBitsPerUserPerSlot(t, strongestUser);
        bDL = resOpt.dlBitsPerUserPerSlot(t, strongestUser);
        assert(abs(bUL - bDL) < 1e-9);
        assert(all(resOpt.ulBitsPerUserPerSlot(t, :) >= resOpt.dlBitsPerUserPerSlot(t, :) - 1e-9));
    end
    assert(resOpt.ulDlFeasible);
    assert(resOpt.totalBits > resFixCausal.totalBits);

    % 2b. Optimal causal power splitting at ehFraction = 0.35 (bisection phiStar)
    cfgAsym = cfgOpt;
    cfgAsym.mission.ehFraction = 0.35;
    rng(cfgAsym.random.mainSeed, 'twister');
    simAsym = buildV12Simulation(cfgAsym, 'B');
    [~, resAsym] = evaluateTrajectoryV12(pB, simAsym, true, false);
    for t = 1:(simAsym.numSteps - 1)
        diffMin = min(resAsym.ulBitsPerUserPerSlot(t, :) - resAsym.dlBitsPerUserPerSlot(t, :));
        assert(abs(diffMin) < 1e-8);
    end
    assert(resAsym.ulDlFeasible);

    % 3. Gauss-Legendre 16-node quadrature vs MATLAB integral() for quasi-steady-accel
    f = simOpt.flight;
    dTest = [0; 2.5; 15; 80.123; 150];
    motion = droneMotionEnergyV12(dTest, f, simOpt.cruisePower);
    assert(motion.flightTimePerSegment(1) == 0 && motion.flightEnergyPerSlot(1) == 0);
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

    % 4. Smoke tests (3 particles, 1 iteration) for all V12 optimizers + dryRun campaign
    optsJ = cfg.optimizers.joint; optsJ.numParticles = 3; optsJ.maxIter = 1;
    rJ = optimizeTrajectoryV12JointPSO(simOpt, optsJ);
    assert(strcmp(rJ.mode, 'v12-joint-pso') && numel(rJ.bestHistory) == 2);

    optsF = cfg.optimizers.full; optsF.numParticles = 3; optsF.maxIter = 1;
    rF = optimizeTrajectoryV12FullPSO(simOpt, optsF);
    assert(strcmp(rF.mode, 'v12-full-pso') && numel(rF.bestHistory) == 2);
    rFPol = polishAlphaV12(rF, simOpt, 3);
    assert(rFPol.bestFitness >= rF.bestFitness && rFPol.alphaPolished);

    optsI = cfg.optimizers.ipso; optsI.numParticles = 3; optsI.maxIter = 1;
    rI = optimizeTrajectoryV12FullIPSO(simOpt, optsI);
    assert(strcmp(rI.mode, 'v12-full-ipso') && numel(rI.bestHistory) == 2);

    camp = runV12Campaign(struct('dryRun', true, 'groups', {{'L', 'accel', 'phi'}}));
    assert(isstruct(camp) && ~isempty(camp.configs));

    fprintf('V12 model/integration checks passed 100%%.\n');
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
