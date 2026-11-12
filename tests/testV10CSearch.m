function testV10CSearch()
%TESTV10CSEARCH Small manual tests, no output files or production campaign.
    dimensions=[144,144,164,164,184,184];
    for k=0:5
        cfg=v10cConfig(sprintf('C%d',k),'smoke');
        cfg.motion.allowExperimental=(k==5);
        cfg.output.saveResults=false; cfg.output.makePlots=false;
        cfg.mission.minBitsPerUser=0; cfg.mission.minBitsPerUserPerSlot=0;
        sim=buildV10CSimulation(cfg);
        layout=v10cSearchLayout(sim);
        assert(layout.dimension==dimensions(k+1));
        base=initialV10CCandidate(sim);
        p=encodeV10CParticle(base,sim);
        c=decodeV10CParticle(p,sim);
        r=evaluateV10CCandidate(c,sim);
        assert(r.geometryFeasible && r.timingFeasible && r.alphaFeasible);
        p=repairV10CParticle(100*ones(1,layout.dimension),sim);
        r=evaluateV10CCandidate(decodeV10CParticle(p,sim),sim);
        assert(r.geometryFeasible && r.timingFeasible && r.alphaFeasible);
        if k==4
            opts=cfg.search; opts.numParticles=3; opts.maxIter=2;
            before=rng;
            a=optimizeV10CPSO(sim,opts,'PSO');
            assert(isequal(before,rng));
            b=optimizeV10CPSO(sim,opts,'PSO');
            assert(isequal(a.bestParticle,b.bestParticle));
            assert(isequal(a.history.bestFitness,b.history.bestFitness));
            assert(a.numEvaluations==9 && a.searchPerformed);
            assert(all(diff(a.history.bestFitness)>=0));
            assert(a.result.isFeasible && a.result.isOptimized);
            assert(~a.result.optimalityGuaranteed);
            opts.stayProposalRate=1;
            z=optimizeV10CPSO(sim,opts,'IPSO');
            assert(z.numEvaluations==9 && z.searchPerformed);
            assert(z.numStayProposals>0);
            assert(all(diff(z.history.bestFitness)>=0));
            rr=evaluateV10CCandidate(z.candidate,sim);
            assert(abs(rr.eeComputed-z.result.eeComputed)<1e-9);
            opts.optimizeBS=false;
            fixed=optimizeV10CPSO(sim,opts,'PSO');
            assert(fixed.dimension==178);
            assert(isequal(fixed.candidate.bsXY,[sim.xBS(:),sim.yBS(:)]));
            assert(fixed.numEvaluations==9);
        end
    end
    cfg=v10cConfig('C4','smoke');
    tight=cfg; tight.time.totalHoverMax=2;
    ts=buildV10CSimulation(tight);
    p=encodeV10CParticle(initialV10CCandidate(ts),ts);
    p=repairV10CParticle(repairV10CParticle(p,ts),ts);
    assert(all(isfinite(p)));
    c=decodeV10CParticle(p,ts);
    assert(max(abs(c.uplinkTime+c.downlinkTime-0.1))<1e-12);
    rr=evaluateV10CCandidate(c,ts);
    assert(rr.timingFeasible);
    cfg.output.saveResults=false; cfg.output.makePlots=false;
    data=runV10C(cfg);
    assert(strcmp(data.stage,'search-complete'));
    assert(isfield(data.searches,'joint_pso') && isfield(data.searches,'full_pso') ...
        && isfield(data.searches,'full_ipso'));
    assert(data.searches.joint_pso.dimension==178);
    assert(data.searches.full_pso.dimension==184);
    assert(data.searches.full_ipso.dimension==184);
    assert(data.result.isOptimized);
    fprintf('V10C search tests passed.\n');
end
