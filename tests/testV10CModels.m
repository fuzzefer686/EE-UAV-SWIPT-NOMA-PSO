function testV10CModels()
%TESTV10CMODELS Manual core-MATLAB tests; no production optimization runs.
    cfg=v10cConfig('C0');
    cfg.mission.minBitsPerUser=0;
    cfg.mission.minBitsPerUserPerSlot=0;
    state=rng;
    sim=buildV10CSimulation(cfg);
    assert(isequal(state,rng),'Scenario builder changed caller RNG.');
    c=initialV10CCandidate(sim);
    r=evaluateV10CCandidate(c,sim);
    rng(cfg.random.mainSeed,'twister');
    old=buildV10Simulation(cfg,'B');
    p=initialV10Particle(old,true,false);
    [~,legacy]=evaluateTrajectoryV10(p,old,true,false);
    assert(abs(r.totalEnergy-legacy.totalEnergy)<1e-8);
    assert(abs(r.totalBits-legacy.totalBits)<1e-6);
    assert(size(c.alpha,1)==20 && size(c.waypoints,1)==21);
    assert(numel(r.bitsPerSlot)==20 && r.totalHoverTime==20);
    assert(r.isFeasible && ~r.isOptimized);
    layout=v10cGeometryLayout(sim,true);
    assert(layout.dimension==44 && ~isfield(layout,'alpha'));
    g=[c.waypoints(2:end-1,1).',c.waypoints(2:end-1,2).', ...
        c.bsXY(:,1).',c.bsXY(:,2).'];
    restored=decodeV10CGeometry(g,c,sim,true);
    assert(isequal(c,restored));

    for k=0:5
        preset=v10cConfig(sprintf('C%d',k));
        if k==5
            mustFail(@() buildV10CSimulation(preset),'V10C:ExperimentalOptIn');
            preset.motion.allowExperimental=true;
        end
        s=buildV10CSimulation(preset);
        x=initialV10CCandidate(s);
        result=evaluateV10CCandidate(x,s);
        assert(result.isDefined && numel(result.segmentDistance)==20);
    end
    cfg=v10cConfig('C4');
    cfg.mission.minBitsPerUser=0; cfg.mission.minBitsPerUserPerSlot=0;
    sim=buildV10CSimulation(cfg); c=initialV10CCandidate(sim);
    c.waypoints(2,:)=c.waypoints(1,:);
    r=evaluateV10CCandidate(c,sim);
    assert(r.geometryFeasible && r.movementTimePerSegment(1)==0);
    assert(r.movementEnergyPerSegment(1)==0 && r.numServiceVisits==19);
    assert(r.numSlots==20 && r.hoverEnergy>0);
    tiny=c; tiny.waypoints(2,1)=tiny.waypoints(1,1)+1e-9;
    rt=evaluateV10CCandidate(tiny,sim);
    assert(rt.segmentDistance(1)>0 && rt.movementEnergyPerSegment(1)>0);

    c.uplinkTime=linspace(0.1,0.9,20).';
    c.downlinkTime=1-c.uplinkTime;
    r=evaluateV10CCandidate(c,sim);
    block=v10cTimeBlockData(c,sim);
    D=c.downlinkTime.*sim.radio.bandwidthHz.*log2(1+ ...
        block.signalCoefficient.*c.uplinkTime./ ...
        (c.downlinkTime+block.interferenceCoefficient.*c.uplinkTime));
    assert(max(abs(D(:)-r.bitsPerUserPerSlot(:)))<1e-7);
    energy=block.fixedEnergy+block.uplinkEnergyCoefficient.'*c.uplinkTime ...
        +block.downlinkEnergyCoefficient.'*c.downlinkTime;
    assert(abs(energy-r.totalEnergy)<1e-8);
    assert(max(abs(r.rfEnergyPerSlot-r.harvestedEnergyPerSlot))<1e-12);

    bad=c; bad.downlinkTime(1)=0;
    mustFail(@() evaluateV10CCandidate(bad,sim),'V10C:CandidateTime');
    bad=c; bad.alpha(1,:)=0;
    mustFail(@() evaluateV10CCandidate(bad,sim),'V10C:CandidateAlpha');
    bad=c; bad.alpha(1,1)=NaN;
    mustFail(@() evaluateV10CCandidate(bad,sim),'V10C:CandidateShape');
    bad=c; bad.waypoints(1,1)=151;
    invalid=evaluateV10CCandidate(bad,sim);
    assert(~invalid.geometryFeasible);
    bad=c; bad.uplinkTime=2*ones(20,1); bad.downlinkTime=ones(20,1);
    invalid=evaluateV10CCandidate(bad,sim);
    assert(~invalid.timingFeasible);
    fixed=buildV10CSimulation(v10cConfig('C0'));
    bad=initialV10CCandidate(fixed);
    bad.uplinkTime(:)=0.4; bad.downlinkTime(:)=0.6;
    invalid=evaluateV10CCandidate(bad,fixed);
    assert(~invalid.timingFeasible);

    m=sim.motion; m.mode='rest-to-rest-experimental'; m.allowExperimental=true;
    motion=v10cMotionEnergy([0;1;200],sim.flight,m);
    assert(motion.time(1)==0 && motion.energy(1)==0);
    assert(abs(motion.time(2)-2*sqrt(1/m.acceleration))<1e-10);
    assert(motion.peakSpeed(2)<sim.flight.cruiseSpeed);
    assert(motion.cruiseTime(3)>0 && all(motion.energy(2:3)>0));
    runner=v10cConfig('C4'); runner.execution.mode='initialize';
    runner.output.saveResults=false; runner.output.makePlots=false;
    data=runV10C(runner);
    assert(strcmp(data.stage,'initialized-not-optimized'));
    assert(~data.result.isOptimized && isempty(data.outputFolder));
    fprintf('V10C MATLAB model tests passed.\n');
end

function mustFail(f,id)
    caught=false;
    try
        f();
    catch err
        assert(strcmp(err.identifier,id),'Unexpected error: %s',err.identifier);
        caught=true;
    end
    assert(caught,'Expected error %s was not raised.',id);
end
