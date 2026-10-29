function testV10Models()
%TESTV10MODELS Analytic/integration tests; run manually after setup_project.
% No test here starts a full production simulation or writes run results.
    cfg = v10Config();
    cfg.mission.minBitsPerUser = 0;
    cfg.mission.minBitsPerSlot = 0;
    cfg.mission.minBitsPerUserPerSlot = 0;
    cfg.output.makePlots = false;
    cfg.output.saveResults = false;
    cfg.output.saveFigures = false;
    rng(cfg.random.mainSeed, 'twister');
    a = buildV10Simulation(cfg, 'A');
    rng(cfg.random.mainSeed, 'twister');
    b = buildV10Simulation(cfg, 'B');
    assert(isequal(a.xUser, b.xUser) && isequal(a.gNLoSUsers, b.gNLoSUsers));

    [power, parts] = dronePropulsionPower([0, cfg.flight.cruiseSpeed], cfg.flight);
    assert(abs(power(1) - 172.387633279650) < 1e-9);
    assert(abs(power(2) - 108.940787180711) < 1e-9);
    assert(max(abs(power - parts.profile - parts.induced - parts.parasite)) < 1e-10);

    for sim = {a, b}
        s = sim{1};
        p = initialV10Particle(s, false, false);
        q = decodeV10Particle(p, s, false);
        assert(all(q.zTraj == cfg.geometry.altitude));
        assert(isequal(q.yTraj, s.stepsVec));
        [fitness, r] = evaluateTrajectoryV10(p, s, false, false);
        assert(r.isFeasible && fitness == r.eeUAV);
        assert(abs(r.totalDistance - 300) < 1e-10);
        assert(abs(r.flightTime - 300/cfg.flight.cruiseSpeed) < 1e-12);
        assert(r.totalHoverTime == (s.numSteps-1)*cfg.mission.hoverTime);
        assert(abs(r.missionTime - r.flightTime-r.totalHoverTime) < 1e-10);
        assert(abs(r.totalEnergy - r.flightEnergy-r.hoverEnergy-r.rfEnergy) < 1e-9);
        assert(abs(r.rfEnergy-r.totalHarvestedEnergy) < 1e-18);
        assert(abs(r.totalBits-sum(r.totalBitsPerUser)) < 1e-8);
        assert(abs(r.totalBits/r.totalEnergy-r.eeUAV) < 1e-9);

        % Arrival rate/power must not add another serving point.
        fake = r;
        fake.achRate(end,:) = 1e99;
        fake.pt(end) = 1e99;
        fake = addV10EnergyMetrics(fake, s);
        assert(fake.totalBits == r.totalBits && fake.rfEnergy == r.rfEnergy);
    end

    % Slot-level QoS: disabled above; enable separately to check the flags.
    pA = initialV10Particle(a,false,false);
    [~, rA] = evaluateTrajectoryV10(pA,a,false);
    s = a; s.minBitsPerUserPerSlot = 1e9;
    [~, rSlot] = evaluateTrajectoryV10(pA,s,false);
    assert(~rSlot.isFeasible && rSlot.slotQoSFeasible && ~rSlot.userSlotQoSFeasible);
    s = a; s.minBitsPerSlot = 1e9;
    [~, rSlotTotal] = evaluateTrajectoryV10(pA,s,false);
    assert(~rSlotTotal.isFeasible && ~rSlotTotal.slotQoSFeasible);
    s = a; s.minBitsPerSlot = 1; s.minBitsPerUserPerSlot = 1;
    [~, rSlotOK] = evaluateTrajectoryV10(pA,s,false);
    assert(rSlotOK.isFeasible && rSlotOK.slotQoSFeasible && rSlotOK.userSlotQoSFeasible);

    % V10B must inherit the same slot-level QoS logic.
    pB = initialV10Particle(b,false,false);
    s = b; s.minBitsPerUserPerSlot = 1e9;
    [~, rSlotB] = evaluateTrajectoryV10(pB,s,false);
    assert(~rSlotB.isFeasible && ~rSlotB.userSlotQoSFeasible);

    % Hover time scales EH/RF phases together: pt (and rate) is unchanged,
    % bits and hover energy double, cruise energy is unchanged, EE rises.
    s = a; s.hoverTime = 2; s.ehTime = 1; s.rfTime = 1;
    [~, rHover] = evaluateTrajectoryV10(pA,s,false);
    assert(abs(rHover.totalBits/rA.totalBits - 2) < 1e-9);
    assert(abs(rHover.hoverEnergy/rA.hoverEnergy - 2) < 1e-9);
    assert(abs(rHover.flightEnergy - rA.flightEnergy) < 1e-9);
    assert(rHover.eeUAV > rA.eeUAV);

    % The new radio path must use the configuration and phase-duration ratio.
    hUser = [1e-5, 2e-5, 3e-5]; hBS = [1e-4, 2e-4]; alpha = [0.5,0.3,0.2];
    [~,~,~,p1] = findAchievableRateV10(hUser,hBS,alpha,a);
    changed = a; changed.radio.bsPowerW = 2*a.radio.bsPowerW;
    [~,~,~,p2] = findAchievableRateV10(hUser,hBS,alpha,changed);
    assert(abs(p2/p1-2) < 1e-12);
    changed = a; changed.ehTime = 0.75; changed.rfTime = 0.25;
    [~,~,~,p3] = findAchievableRateV10(hUser,hBS,alpha,changed);
    assert(abs(p3/p1-3) < 1e-12);
    [rates,~,~,~] = findAchievableRateV10(ones(1,3)*1e-5,hBS,ones(1,3)/3,a);
    assert(all(isfinite(rates)) && all(rates >= 0));
    % pMin bounds RAW weights; it must not floor the normalized alpha again.
    skew = a; skew.pMin = 0.1;
    p = initialV10Particle(skew,false,false); layout = v10ParticleLayout(skew,false);
    weights = repmat([1,repmat(0.1,1,skew.noUsers-1)],skew.numSteps,1);
    p(layout.alpha) = reshape(weights.',1,[]);
    [~,r] = evaluateTrajectoryV10(p,skew,false);
    for t=1:skew.numSteps
        assert(max(abs(r.alphaTrace(t,r.idxWeak2StrongTrace(t,:))-r.alphaOrdTrace(t,:))) < 1e-12);
    end

    % B repairs repeated/reversed proposals into directed progress with exact endpoints.
    p = initialV10Particle(b, true, false); layout = v10ParticleLayout(b,true);
    p(layout.y) = 300;
    p = repairV10Particle(p,b,true);
    q = decodeV10Particle(p,b,true);
    assert(q.yTraj(1)==b.yStart && q.yTraj(end)==b.yEnd);
    assert(all(b.yDirection*diff(q.yTraj) >= b.minYProgress-1e-10));
    cfgBad = cfg; cfgBad.geometry.minYProgress = 16;
    assertThrows(@() buildV10Simulation(cfgBad,'B'));
    cfgBad = cfg; cfgBad.mission.ehFraction = 1;
    assertThrows(@() buildV10Simulation(cfgBad,'A'));

    % All-data-infeasible and all-energy-infeasible runs must still return a result.
    opts = cfg.optimizers.joint; opts.numParticles = 3; opts.maxIter = 1;
    short = a; short.minBitsPerUser = 1e30;
    r = optimizeTrajectoryV10JointPSO(short,opts);
    assert(~r.isFeasible && isfinite(r.bestFitness) && r.bestFitness < 0);
    limited = b; limited.energyBudgetJ = 1;
    opts = cfg.optimizers.full; opts.numParticles = 3; opts.maxIter = 1;
    raw = optimizeTrajectoryV10FullPSO(limited,opts);
    assert(~raw.isFeasible && isfinite(raw.bestFitness));
    polished = polishAlphaV10(raw,limited,3);
    assert(polished.bestFitness >= raw.bestFitness);
    assert(isequal(polished.bestHistory,raw.bestHistory));
    opts = cfg.optimizers.ipso; opts.numParticles = 3; opts.maxIter = 1;
    r = optimizeTrajectoryV10FullIPSO(b,opts);
    assert(isfield(r,'rfEnergyHistory') && numel(r.bestHistory)==2);
    assert(max(abs(r.totalEnergyHistory-r.flightEnergyHistory-r.hoverEnergyHistory-r.rfEnergyHistory)) < 1e-8);
    assert(max(abs(sum(r.transmitPowerHistory,2)*r.downlinkTime-r.rfEnergyHistory)) < 1e-18);
    fprintf('V10 model/integration checks passed.\n');
end

function assertThrows(action)
    caught = false;
    try
        action();
    catch
        caught = true;
    end
    assert(caught,'Expected invalid configuration to throw.');
end
