function score = v10cFitness(result,sim)
%V10CFITNESS Feasible EE beats all infeasible candidates; otherwise reduce QoS deficit.
    if ~result.isDefined || ~result.geometryFeasible ...
            || ~result.timingFeasible || ~result.alphaFeasible
        score=-Inf; return;
    end
    if result.isFeasible, score=result.eeComputed; return; end
    L=sim.minBitsPerUser+zeros(1,sim.noUsers);
    q=sim.minBitsPerUserPerSlot+zeros(1,sim.noUsers);
    deficit=sum(result.bitsShortfallPerUser./max(1,L)) ...
        +mean(mean(result.userSlotShortfall./max(1,q))) ...
        +mean(result.slotShortfall/max(1,sim.minBitsPerSlot));
    if isfinite(sim.energyBudgetJ)
        deficit=deficit+max(0,result.totalEnergy-sim.energyBudgetJ)/sim.energyBudgetJ;
    end
    score=-max(deficit,eps);
end
