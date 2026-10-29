function bestOut = polishAlphaV10(bestIn, sim, nSamples)
%POLISHALPHAV10 V9 candidate search, accepting by the full V10 mission fitness.
% Geometry/BS and optimizer histories are unchanged; polishing is separate.
    validateattributes(nSamples,{'numeric'},{'scalar','finite','integer','nonnegative'});
    layout=v10ParticleLayout(sim,true);
    particle=bestIn.bestParticle;
    [~,current]=evaluateTrajectoryV10(particle,sim,true);
    initial=current;
    for t=1:(sim.numSteps-1)
        idx=layout.positionCount+(t-1)*sim.noUsers+(1:sim.noUsers);
        bestParticle=particle; bestResult=current;
        for sample=1:nSamples
            if sample==1
                alpha=ones(1,sim.noUsers)/sim.noUsers;
            elseif sample==2
                alpha=particle(idx);
            else
                alpha=rand(1,sim.noUsers);
            end
            alpha=max(alpha,sim.pMin); alpha=alpha/sum(alpha);
            trial=particle; trial(idx)=alpha;
            [trialFitness,trialResult]=evaluateTrajectoryV10(trial,sim,true);
            if trialFitness>bestResult.fitness
                bestParticle=trial; bestResult=trialResult;
            end
        end
        particle=bestParticle; current=bestResult;
    end
    bestOut=bestIn;
    fields=fieldnames(current);
    for k=1:numel(fields)
        bestOut.(fields{k})=current.(fields{k});
    end
    bestOut.bestParticle=particle; bestOut.bestFitness=current.fitness;
    bestOut.bestEE=current.eeComputed; bestOut.bestFeasible=current.isFeasible;
    bestOut.alphaPolished=true; bestOut.alphaPolishSamples=nSamples;
    bestOut.mode=[bestIn.mode,'-alpha-polished'];
    fprintf(['V10 alpha polishing: EE %.6e -> %.6e bit/J | ', ...
        'L:%d bitSlot:%d bitUserSlot:%d | feasible %d\n'], ...
        initial.eeComputed,current.eeComputed,current.missionQoSFeasible, ...
        current.slotQoSFeasible,current.userSlotQoSFeasible,current.isFeasible);
end
