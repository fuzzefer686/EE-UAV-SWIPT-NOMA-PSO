function report = testV11Models()
%TESTV11MODELS Core-only acceptance tests; never runs a production campaign.
    assert(exist('v11Config','file')==2,'V11 implementation is missing.');
    cfg10=v10Config(); cfg11=v11Config();
    rng(2026,'twister'); s10=buildV10Simulation(cfg10,'B');
    rng(2026,'twister'); s11=buildV11Simulation(cfg11,'B');
    rng(23,'twister'); p=initialV10Particle(s10,true,true);
    [f10,r10]=evaluateTrajectoryV10(p,s10,true);
    [f11,r11]=evaluateTrajectoryV11(p,s11,true);
    fields={'totalBits','eeUAV','totalEnergy','rfEnergy','achRate','alphaTrace','pt'};
    for k=1:numel(fields)
        delta=abs(r10.(fields{k})-r11.(fields{k})); assert(all(delta(:)<1e-12),fields{k});
    end
    assert(abs(f10-f11)<1e-12);
    opts=cfg10.optimizers.full; opts.numParticles=4; opts.maxIter=50;
    rng(2026,'twister'); old=optimizeTrajectoryV10FullPSO(s10,opts);
    rng(2026,'twister'); fresh=optimizeTrajectoryV11FullPSO(s11,opts);
    assert(abs(old.bestFitness-fresh.bestFitness)<1e-12);
    assert(all(abs(old.bestParticle-fresh.bestParticle)<1e-12));
    assert(abs(old.totalBits-fresh.totalBits)<1e-12);
    assert(fresh.numFitnessEvals==204);
    rng(123,'twister'); po=polishAlphaV10(old,s10,3);
    rng(123,'twister'); pn=polishAlphaV11(fresh,s11,3);
    assert(isequal(po.bestParticle,pn.bestParticle)); assert(po.totalBits==pn.totalBits);
    baseline=struct('seed',2026,'numParticles',4,'maxIter',50, ...
        'bestFitness',old.bestFitness,'bestParticle',old.bestParticle,'totalBits',old.totalBits);
    root=fileparts(fileparts(mfilename('fullpath')));
    reference=jsondecode(fileread(fullfile(root,'tests','fixtures','v11_baseline_50iter_seed2026.json')));
    numericFields=fieldnames(baseline);
    for k=1:numel(numericFields)
        key=numericFields{k}; assert(isequal(reference.(key)(:),baseline.(key)(:)),key);
    end
    testV11BaselineFixture();
    fprintf('6.1 PASS: evaluator + 50-iteration optimizer + random polish exact equivalence.\n');
    report.equivalence=true;

    dimensions=[124,130,143,149;19,25,38,44];
    for mode=1:2
        names={'particle','uniform'};
        for variant=1:2
            variants={'A','B'}; rng(2026,'twister'); s=buildV11Simulation(cfg11,variants{variant}); s.alphaMode=names{mode};
            for bs=0:1
                l=v11ParticleLayout(s,logical(bs)); assert(l.dimension==dimensions(mode,2*(variant-1)+bs+1));
                p=initialV11Particle(s,logical(bs),true); assert(numel(p)==l.dimension && all(isfinite(p)));
                p=repairV11Particle(p,s,logical(bs)); q=decodeV11Particle(p,s,logical(bs));
                if mode==2, assert(all(abs(q.rawAlpha(:)-1/s.noUsers)<1e-12)); end
            end
        end
    end
    fprintf('6.2 PASS: all eight literal particle dimensions.\n'); report.dimensions=true;
    s=s11; s.alphaMode='uniform'; before=rng; alphaPolicyV11(s); after=rng; assert(isequal(before,after));
    s=s11; p=initialV11Particle(s,true,false); l=v11ParticleLayout(s,true);
    raw=repmat([.1,.3,.15,.25,.2],s.numSteps,1); p(l.alpha)=reshape(raw.',1,[]);
    s.alphaRepair='none'; [~,r]=evaluateTrajectoryV11(p,s,true); assert(max(abs(r.alphaTrace(1,:)-raw(1,:)))<1e-12);
    s.alphaRepair='noma'; [~,r]=evaluateTrajectoryV11(p,s,true); assert(all(all(diff(r.alphaOrdTrace,1,2)<=1e-12)));
    fallback=rmfield(s,{'alphaMode','alphaRepair','alphaFinalSolver','alphaQosMaxOuterIter','alphaQosTol','alphaQosSeed','alphaPresetName'});
    assert(v11ParticleLayout(fallback,true).dimension==149);
    [~,rf]=evaluateTrajectoryV11(p,fallback,true); assert(isequal(rf.alphaTrace,r.alphaTrace));
    fprintf('6.3 PASS: uniform policy, no RNG consumption, repair on/off, fallback fields.\n'); report.alpha=true;

    s=s11; s.alphaMode='uniform'; s.minBitsPerUser=0; s.minBitsPerSlot=0; s.minBitsPerUserPerSlot=0;
    p=initialV11Particle(s,true,false); q=decodeV11Particle(p,s,true);
    timer=tic; [alpha,info]=solveAlphaQoSV11(q.xTraj,q.yTraj,q.xBS,q.yBS,s); report.solverSeconds=toc(timer);
    assert(max(max(abs(alpha(1:end-1,:)-1/s.noUsers)))<1e-2); assert(info.feasible);
    state=rng; [alpha2,info2]=solveAlphaQoSV11(q.xTraj,q.yTraj,q.xBS,q.yBS,s);
    assert(isequal(alpha,alpha2) && isequal(info,info2) && isequal(state,rng));
    s.minBitsPerUser=1e12; [aBad,bad]=solveAlphaQoSV11(q.xTraj,q.yTraj,q.xBS,q.yBS,s);
    assert(~bad.feasible && all(bad.shortfall>0) && all(isfinite(aBad(:))));
    s.minBitsPerUser=0; s.minBitsPerUserPerSlot=1e12;
    [aSlot,badSlot]=solveAlphaQoSV11(q.xTraj,q.yTraj,q.xBS,q.yBS,s); assert(~badSlot.feasible && all(isfinite(aSlot(:))));
    s=s11; s.alphaMode='uniform'; s.alphaFinalSolver='qos';
    [~,r]=evaluateTrajectoryV11(p,s,true); r.bestParticle=p; r.bestFitness=r.fitness; r.bestHistory=r.fitness;
    clock=tic; polished=polishAlphaV11(r,s,0); report.qosFinalSeconds=toc(clock);
    fprintf('Solver default constrained finalization: %.6f s, outerIter=%d, rateEvals=%d\n',report.qosFinalSeconds,polished.alphaSolverInfo.outerIter,polished.alphaSolverInfo.numRateEvals);
    assert(all(all(diff(polished.alphaOrdTrace,1,2)<=1e-10)));
    recalculated=addV11EnergyMetrics(polished,s); assert(recalculated.totalBits==polished.totalBits);
    assert(isequal(polished.stepMin,min(polished.achRate,[],2)),'Final min-rate diagnostics are stale.');
    assert(isequal(polished.bestHistory,r.bestHistory)); assert(numel(polished.bestParticle)==44);
    assert(strcmp(polished.alphaSource,'final-solver'));
    assert(max(abs(polished.alphaSolverInfo.perUserBits-polished.totalBitsPerUser))<1e-7);
    sFree=s; sFree.alphaRepair='none'; sFree.minBitsPerUser=0;
    sFree.minBitsPerUserPerSlot=0; sFree.minBitsPerSlot=0;
    clock=tic; [aFree,freeInfo]=solveAlphaQoSV11(q.xTraj,q.yTraj,q.xBS,q.yBS,sFree);
    report.noC3Seconds=toc(clock);
    [~,physical]=evaluateTrajectoryV11(p,sFree,true);
    order=physical.idxWeak2StrongTrace(1,:);
    assert(aFree(1,order(end))>aFree(1,order(1)));
    fprintf('Solver C3-OFF: %.6f s, outerIter=%d, rateEvals=%d\n',report.noC3Seconds,freeInfo.outerIter,freeInfo.numRateEvals);
    fprintf('6.4 PASS: uniform optimum, determinism, impossible mission/C5, C3, final recomputation.\n');
    fprintf('Solver no-QoS cold call: %.6f s; impossible-mission outerIter: %d\n',report.solverSeconds,bad.outerIter);
    report.solver=true;
    presets={'particle_noma_random','particle_noma_none','uniform_noma_none','uniform_noma_qos','uniform_noc3_qos','particle_noc3_random'};
    for k=1:numel(presets), c=v11AlphaPreset(presets{k}); assert(strcmp(c.alpha.presetName,presets{k})); end
    for mode={'particle','uniform'}
        s=s11; s.alphaMode=mode{1}; op=cfg11.optimizers.full; op.numParticles=3; op.maxIter=1;
        fns={@optimizeTrajectoryV11JointPSO,@optimizeTrajectoryV11FullPSO,@optimizeTrajectoryV11FullIPSO};
        for k=1:3
            r=fns{k}(s,op); assert(all(isfinite(r.bestParticle)) && isfinite(r.bestFitness));
            assert(r.numFitnessEvals>=6); assert(numel(r.bestHistory)==2);
        end
    end
    s=s11; s.alphaMode='uniform'; s.alphaFinalSolver='random';
    r=optimizeTrajectoryV11FullPSO(s,op); r=polishAlphaV11(r,s,3);
    assert(numel(r.bestParticle)==44 && isfinite(r.totalBits));
    assert(isequal(r.stepMin,min(r.achRate,[],2)));
    studyOpts=struct('dryRun',true,'presets',{{'uniform_noma_none'}},'variants',{{'B'}},'minBitsPerUser',1e6,'seeds',2026);
    plan=runV11AlphaStudy(studyOpts); assert(height(plan)==1 && plan.dimension==44);
    fprintf('Additional PASS: presets, all optimizers/modes, uniform random polish, one-case study dryRun.\n');
    % Short matched-budget benchmark, not a production comparison.
    bench=struct([]); names={'particle_noma_random','uniform_noma_none'};
    for k=1:2
        c=v11AlphaPreset(names{k}); rng(2026,'twister'); s=buildV11Simulation(c,'B');
        o=c.optimizers.full; o.numParticles=4; o.maxIter=2;
        rng(2026,'twister'); clock=tic; r=optimizeTrajectoryV11FullPSO(s,o);
        rawCount=r.numFitnessEvals;
        if strcmp(c.alpha.finalSolver,'random'), rng(123,'twister'); r=polishAlphaV11(r,s,3); end
        bench(k).preset=names{k}; bench(k).seconds=toc(clock);
        bench(k).numFitnessEvals=r.numFitnessEvals; bench(k).swarmEvals=rawCount;
        fprintf('BENCH %s: %.6f s | swarmEvals=%d | numFitnessEvals=%d\n',names{k},bench(k).seconds,rawCount,r.numFitnessEvals);
    end
    report.benchmark=bench;
    testInheritedV11Models();
    report.latencyUnder100ms=report.qosFinalSeconds<0.1 && report.noC3Seconds<0.1 && report.solverSeconds<0.1;
    fprintf('LATENCY <100ms across tested cases: %d\n',report.latencyUnder100ms);
    testV11JointFinalization();
    testV11EquivalenceScript();
    testV11AlphaStudyEdges();
    fprintf('V11 runtime correctness acceptance tests PASSED.\n');
end

function testInheritedV11Models()
%TESTV11MODELS Analytic/integration tests; run manually after setup_project.
% No test here starts a full production simulation or writes run results.
    cfg = v11Config();
    cfg.mission.minBitsPerUser = 0;
    cfg.mission.minBitsPerSlot = 0;
    cfg.mission.minBitsPerUserPerSlot = 0;
    cfg.output.makePlots = false;
    cfg.output.saveResults = false;
    cfg.output.saveFigures = false;
    rng(cfg.random.mainSeed, 'twister');
    a = buildV11Simulation(cfg, 'A');
    rng(cfg.random.mainSeed, 'twister');
    b = buildV11Simulation(cfg, 'B');
    assert(isequal(a.xUser, b.xUser) && isequal(a.gNLoSUsers, b.gNLoSUsers));

    [power, parts] = dronePropulsionPower([0, cfg.flight.cruiseSpeed], cfg.flight);
    assert(abs(power(1) - 172.387633279650) < 1e-9);
    assert(abs(power(2) - 108.940787180711) < 1e-9);
    assert(max(abs(power - parts.profile - parts.induced - parts.parasite)) < 1e-10);

    for sim = {a, b}
        s = sim{1};
        p = initialV11Particle(s, false, false);
        q = decodeV11Particle(p, s, false);
        assert(all(q.zTraj == cfg.geometry.altitude));
        assert(isequal(q.yTraj, s.stepsVec));
        [fitness, r] = evaluateTrajectoryV11(p, s, false, false);
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
        fake = addV11EnergyMetrics(fake, s);
        assert(fake.totalBits == r.totalBits && fake.rfEnergy == r.rfEnergy);
    end

    % Slot-level QoS: disabled above; enable separately to check the flags.
    pA = initialV11Particle(a,false,false);
    [~, rA] = evaluateTrajectoryV11(pA,a,false);
    s = a; s.minBitsPerUserPerSlot = 1e9;
    [~, rSlot] = evaluateTrajectoryV11(pA,s,false);
    assert(~rSlot.isFeasible && rSlot.slotQoSFeasible && ~rSlot.userSlotQoSFeasible);
    s = a; s.minBitsPerSlot = 1e9;
    [~, rSlotTotal] = evaluateTrajectoryV11(pA,s,false);
    assert(~rSlotTotal.isFeasible && ~rSlotTotal.slotQoSFeasible);
    s = a; s.minBitsPerSlot = 1; s.minBitsPerUserPerSlot = 1;
    [~, rSlotOK] = evaluateTrajectoryV11(pA,s,false);
    assert(rSlotOK.isFeasible && rSlotOK.slotQoSFeasible && rSlotOK.userSlotQoSFeasible);

    % V11B must inherit the same slot-level QoS logic.
    pB = initialV11Particle(b,false,false);
    s = b; s.minBitsPerUserPerSlot = 1e9;
    [~, rSlotB] = evaluateTrajectoryV11(pB,s,false);
    assert(~rSlotB.isFeasible && ~rSlotB.userSlotQoSFeasible);

    % Hover time scales EH/RF phases together: pt (and rate) is unchanged,
    % bits and hover energy double, cruise energy is unchanged, EE rises.
    s = a; s.hoverTime = 2; s.ehTime = 1; s.rfTime = 1;
    [~, rHover] = evaluateTrajectoryV11(pA,s,false);
    assert(abs(rHover.totalBits/rA.totalBits - 2) < 1e-9);
    assert(abs(rHover.hoverEnergy/rA.hoverEnergy - 2) < 1e-9);
    assert(abs(rHover.flightEnergy - rA.flightEnergy) < 1e-9);
    assert(rHover.eeUAV > rA.eeUAV);

    % The new radio path must use the configuration and phase-duration ratio.
    hUser = [1e-5, 2e-5, 3e-5]; hBS = [1e-4, 2e-4]; alpha = [0.5,0.3,0.2];
    [~,~,~,p1] = findAchievableRateV11(hUser,hBS,alpha,a);
    changed = a; changed.radio.bsPowerW = 2*a.radio.bsPowerW;
    [~,~,~,p2] = findAchievableRateV11(hUser,hBS,alpha,changed);
    assert(abs(p2/p1-2) < 1e-12);
    changed = a; changed.ehTime = 0.75; changed.rfTime = 0.25;
    [~,~,~,p3] = findAchievableRateV11(hUser,hBS,alpha,changed);
    assert(abs(p3/p1-3) < 1e-12);
    [rates,~,~,~] = findAchievableRateV11(ones(1,3)*1e-5,hBS,ones(1,3)/3,a);
    assert(all(isfinite(rates)) && all(rates >= 0));
    % pMin bounds RAW weights; it must not floor the normalized alpha again.
    skew = a; skew.pMin = 0.1;
    p = initialV11Particle(skew,false,false); layout = v11ParticleLayout(skew,false);
    weights = repmat([1,repmat(0.1,1,skew.noUsers-1)],skew.numSteps,1);
    p(layout.alpha) = reshape(weights.',1,[]);
    [~,r] = evaluateTrajectoryV11(p,skew,false);
    for t=1:skew.numSteps
        assert(max(abs(r.alphaTrace(t,r.idxWeak2StrongTrace(t,:))-r.alphaOrdTrace(t,:))) < 1e-12);
    end

    % B repairs repeated/reversed proposals into directed progress with exact endpoints.
    p = initialV11Particle(b, true, false); layout = v11ParticleLayout(b,true);
    p(layout.y) = 300;
    p = repairV11Particle(p,b,true);
    q = decodeV11Particle(p,b,true);
    assert(q.yTraj(1)==b.yStart && q.yTraj(end)==b.yEnd);
    assert(all(b.yDirection*diff(q.yTraj) >= b.minYProgress-1e-10));
    cfgBad = cfg; cfgBad.geometry.minYProgress = 16;
    assertThrows(@() buildV11Simulation(cfgBad,'B'));
    cfgBad = cfg; cfgBad.mission.ehFraction = 1;
    assertThrows(@() buildV11Simulation(cfgBad,'A'));

    % All-data-infeasible and all-energy-infeasible runs must still return a result.
    opts = cfg.optimizers.joint; opts.numParticles = 3; opts.maxIter = 1;
    short = a; short.minBitsPerUser = 1e30;
    r = optimizeTrajectoryV11JointPSO(short,opts);
    assert(~r.isFeasible && isfinite(r.bestFitness) && r.bestFitness < 0);
    limited = b; limited.energyBudgetJ = 1;
    opts = cfg.optimizers.full; opts.numParticles = 3; opts.maxIter = 1;
    raw = optimizeTrajectoryV11FullPSO(limited,opts);
    assert(~raw.isFeasible && isfinite(raw.bestFitness));
    polished = polishAlphaV11(raw,limited,3);
    assert(polished.bestFitness >= raw.bestFitness);
    assert(isequal(polished.bestHistory,raw.bestHistory));
    opts = cfg.optimizers.ipso; opts.numParticles = 3; opts.maxIter = 1;
    r = optimizeTrajectoryV11FullIPSO(b,opts);
    assert(isfield(r,'rfEnergyHistory') && numel(r.bestHistory)==2);
    assert(max(abs(r.totalEnergyHistory-r.flightEnergyHistory-r.hoverEnergyHistory-r.rfEnergyHistory)) < 1e-8);
    assert(max(abs(sum(r.transmitPowerHistory,2)*r.downlinkTime-r.rfEnergyHistory)) < 1e-18);
    fprintf('V11 model/integration checks passed.\n');
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
