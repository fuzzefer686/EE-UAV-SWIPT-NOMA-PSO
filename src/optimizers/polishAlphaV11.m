function bestOut = polishAlphaV11(bestIn, sim, nSamples)
%POLISHALPHAV11 V9 candidate search, accepting by the full V11 mission fitness.
% Geometry/BS and optimizer histories are unchanged; polishing is separate.
    validateattributes(nSamples,{'numeric'},{'scalar','finite','integer','nonnegative'});
    solver=getSimField(sim,'alphaFinalSolver','random');
    if strcmp(solver,'none')
        bestOut=bestIn; bestOut.alphaSolver='none'; return;
    elseif strcmp(solver,'qos')
        [alpha,info]=solveAlphaQoSV11(bestIn.xTraj,bestIn.yTraj,bestIn.xBS,bestIn.yBS,sim);
        bestOut=applyAlpha(bestIn,alpha,sim);
        bestOut.alphaSolver='qos'; bestOut.alphaSolverInfo=info;
        bestOut.alphaSource='final-solver';
        bestOut.numFitnessEvals=getSimField(bestIn,'numFitnessEvals',0)+1;
        return;
    elseif ~strcmp(solver,'random')
        error('polishAlphaV11:Solver','Unknown alpha final solver.');
    end
    [layout,optimizeBS]=particleLayout(bestIn,sim);
    if isempty(layout.alpha)
        bestOut=randomUniform(bestIn,sim,nSamples); return;
    end
    particle=bestIn.bestParticle;
    [~,current]=evaluateTrajectoryV11(particle,sim,optimizeBS);
    initial=current;
    numFitnessEvals=getSimField(bestIn,'numFitnessEvals',0)+1;
    for t=1:(sim.numSteps-1)
        idx=layout.alpha((t-1)*sim.noUsers+(1:sim.noUsers));
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
            [trialFitness,trialResult]=evaluateTrajectoryV11(trial,sim,optimizeBS);
            numFitnessEvals=numFitnessEvals+1;
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
    bestOut.alphaSolver='random'; bestOut.numFitnessEvals=numFitnessEvals;
    bestOut.bestParticle=particle; bestOut.bestFitness=current.fitness;
    bestOut.bestEE=current.eeComputed; bestOut.bestFeasible=current.isFeasible;
    bestOut.alphaPolished=true; bestOut.alphaPolishSamples=nSamples;
    bestOut.mode=[bestIn.mode,'-alpha-polished'];
    fprintf(['V11 alpha polishing: EE %.6e -> %.6e bit/J | ', ...
        'L:%d bitSlot:%d bitUserSlot:%d | feasible %d\n'], ...
        initial.eeComputed,current.eeComputed,current.missionQoSFeasible, ...
        current.slotQoSFeasible,current.userSlotQoSFeasible,current.isFeasible);
end

function out = applyAlpha(in,alpha,sim)
% The final serving allocation is authoritative, especially with no alpha block.
    out=in; out.rawAlpha=alpha;
    users=[sim.xUser(:),sim.yUser(:),sim.zUser(:)];
    bs=[in.xBS(:),in.yBS(:),sim.zBS(:)];
    for t=1:sim.numSteps
        point=[in.xTraj(t),in.yTraj(t),sim.altitude];
        hu=v11Channel(point,users,sim.gNLoSUsers,sim.radio);
        hb=v11Channel(point,bs,sim.gNLoSBS,sim.radio);
        [rate,ordered,order,power]=findAchievableRateV11(hu,hb,alpha(t,:),sim);
        out.alphaTrace(t,:)=alpha(t,:); out.alphaOrdTrace(t,:)=ordered;
        out.idxWeak2StrongTrace(t,:)=order; out.achRate(t,:)=rate; out.pt(t)=power;
    end
    out.stepMin=min(out.achRate,[],2);
    out.minFit=min(out.stepMin(out.fitIdx));
    out.meanFit=mean(out.stepMin(out.fitIdx));
    out.minInternal=min(out.stepMin(2:sim.numSteps-1));
    out.meanInternal=mean(out.stepMin(2:sim.numSteps-1));
    out=addV11EnergyMetrics(out,sim);
    out.bestFitness=out.fitness; out.bestEE=out.eeComputed; out.bestFeasible=out.isFeasible;
    out.alphaPolished=true; out.mode=[getSimField(in,'mode','v11'),'-alpha-polished'];
    out.alphaSource='final-solver';
    % Keep bestParticle as the optimizer's particle; final alpha is saved separately.
end

function out = randomUniform(in,sim,nSamples)
    out=in; count=getSimField(in,'numFitnessEvals',0);
    for t=1:sim.numSteps-1
        current=out; alpha=out.alphaTrace;
        for sample=1:nSamples
            if sample==1
                row=ones(1,sim.noUsers)/sim.noUsers;
            elseif sample==2
                row=alpha(t,:);
            else
                row=rand(1,sim.noUsers);
            end
            row=max(row,sim.pMin); row=row/sum(row);
            if strcmp(getSimField(sim,'alphaRepair','noma'),'noma')
                order=out.idxWeak2StrongTrace(t,:);
                sorted=sort(row,'descend'); row(order)=sorted;
            end
            candidate=alpha; candidate(t,:)=row;
            trial=applyAlpha(out,candidate,sim); count=count+1;
            if trial.fitness>current.fitness, current=trial; end
        end
        out=current;
    end
    out.alphaSolver='random'; out.numFitnessEvals=count;
    out.alphaPolishSamples=nSamples;
    if isfield(out,'alphaPolished') && out.alphaPolished
        out.mode=[getSimField(in,'mode','v11'),'-alpha-polished'];
    end
end

function value = getSimField(s, name, fallback)
    if isfield(s,name) && ~isempty(s.(name))
        value=s.(name);
    else
        value=fallback;
    end
end

function [layout,optimizeBS] = particleLayout(best,sim)
% Infer the optimizer from its particle, including older results without metadata.
    layout=v11ParticleLayout(sim,false); optimizeBS=false;
    if numel(best.bestParticle)~=layout.dimension
        layout=v11ParticleLayout(sim,true); optimizeBS=true;
    end
    if numel(best.bestParticle)~=layout.dimension
        error('polishAlphaV11:ParticleSize','Particle size matches neither Joint nor Full layout.');
    end
end
