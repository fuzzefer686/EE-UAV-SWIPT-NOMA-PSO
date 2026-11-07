function best = optimizeV10CPSO(sim,opts,algorithm)
%OPTIMIZEV10CPSO Runnable toolbox-free joint PSO/IPSO research reference.
% This is not the planned block SCA/Dinkelbach hybrid. No global optimality
% claim is made. Mutation replaces a proposal, so both methods use P*(I+1) evaluations.
    if nargin<3, algorithm='PSO'; end
    algorithm=upper(char(algorithm));
    if ~any(strcmp(algorithm,{'PSO','IPSO'}))
        error('V10C:Algorithm','Use PSO or IPSO.');
    end
    if isfield(opts,'displayName') && ~isempty(opts.displayName)
        displayName=char(opts.displayName);
    else
        displayName=algorithm;
    end
    sim.searchOptimizeBS=true;
    if isfield(opts,'optimizeBS')
        validateattributes(opts.optimizeBS,{'logical'},{'scalar'});
        sim.searchOptimizeBS=opts.optimizeBS;
    end
    validateattributes(opts.numParticles,{'numeric'},{'scalar','finite','integer','positive'});
    validateattributes(opts.maxIter,{'numeric'},{'scalar','finite','integer','nonnegative'});
    validateattributes(opts.w,{'numeric'},{'real','scalar','finite','nonnegative'});
    validateattributes(opts.c1,{'numeric'},{'real','scalar','finite','nonnegative'});
    validateattributes(opts.c2,{'numeric'},{'real','scalar','finite','nonnegative'});
    validateattributes(opts.velocityLimit,{'numeric'},{'real','scalar','finite','positive'});
    validateattributes(opts.stayProposalRate,{'numeric'},{'real','scalar','>=',0,'<=',1});
    validateattributes(opts.mutationRate,{'numeric'},{'real','scalar','>=',0,'<=',1});
    validateattributes(opts.stallIter,{'numeric'},{'scalar','integer','positive'});
    validateattributes(opts.verbose,{'logical'},{'scalar'});
    before=rng; cleanup=onCleanup(@() rng(before)); %#ok<NASGU>
    rng(opts.seed,'twister');
    L=v10cSearchLayout(sim); D=L.dimension; P=opts.numParticles; I=opts.maxIter;
    pos=zeros(P,D); vel=zeros(P,D); personal=zeros(P,D); scores=-Inf(P,1);
    evaluations=0; stayCount=0; globalScore=-Inf; globalPosition=[];
    initial=encodeV10CParticle(initialV10CCandidate(sim),sim);
    hasSeed=isfield(opts,'seedCandidate') && ~isempty(opts.seedCandidate);
    if hasSeed && P<2
        error('V10C:WarmStartParticles','Warm starts require >=2 particles to retain the baseline.');
    end
    if hasSeed
        seed=encodeV10CParticle(opts.seedCandidate,sim);
    else
        seed=initial;
    end
    for i=1:P
        if i==1
            p=initial;
        elseif i==2 && hasSeed
            p=seed;
        elseif mod(i,3)==0
            p=repairV10CParticle(seed+0.15*randn(1,D),sim);
        else
            p=repairV10CParticle(rand(1,D),sim);
        end
        if i>2 && sim.minYProgress==0 && rand<opts.stayProposalRate
            p=stayProposal(p); stayCount=stayCount+1;
        end
        [p,c,r,s]=evaluate(p);
        pos(i,:)=p; personal(i,:)=p; scores(i)=s;
        if isempty(globalPosition) || s>globalScore
            globalScore=s; globalPosition=p; globalCandidate=c; globalResult=r;
        end
    end
    history.bestFitness=zeros(I+1,1); history.eeComputed=zeros(I+1,1);
    history.feasible=false(I+1,1); history.energyJ=zeros(I+1,1);
    history.bits=zeros(I+1,1); history.hoverSeconds=zeros(I+1,1);
    record(1); stall=0;
    for iter=1:I
        previousScore=globalScore;
        if strcmp(algorithm,'IPSO')
            w=0.9-0.5*(iter/max(1,I));
        else
            w=opts.w;
        end
        for i=1:P
            vel(i,:)=w*vel(i,:)+opts.c1*rand(1,D).*(personal(i,:)-pos(i,:)) ...
                +opts.c2*rand(1,D).*(globalPosition-pos(i,:));
            vel(i,:)=min(max(vel(i,:),-opts.velocityLimit),opts.velocityLimit);
            p=pos(i,:)+vel(i,:);
            if strcmp(algorithm,'IPSO')
                rate=min(1,opts.mutationRate*(1+double(stall>=opts.stallIter)));
                if rand<rate
                    mask=rand(1,D)<0.15;
                    if ~any(mask), mask(randi(D))=true; end
                    p(mask)=globalPosition(mask)+0.15*randn(1,sum(mask));
                end
            end
            p=repairV10CParticle(p,sim);
            if sim.minYProgress==0 && rand<opts.stayProposalRate
                p=stayProposal(p); stayCount=stayCount+1;
            end
            [p,c,r,s]=evaluate(p); pos(i,:)=p;
            if s>scores(i), personal(i,:)=p; scores(i)=s; end
            if s>globalScore
                globalScore=s; globalPosition=p; globalCandidate=c; globalResult=r;
            end
        end
        if globalScore>previousScore, stall=0; else, stall=stall+1; end
        record(iter+1);
        if opts.verbose && (iter==1 || mod(iter,25)==0 || iter==I)
            fprintf(['%s %s iter %4d/%4d | EE = %.4e bit/J | ' ...
                'L:%d bitUserSlot:%d | feasible:%d\n'], ...
                sim.preset,displayName,iter,I,globalResult.eeComputed, ...
                globalResult.missionQoSFeasible,globalResult.userSlotQoSFeasible, ...
                globalResult.isFeasible);
        end
    end
    globalResult.isOptimized=true;
    globalResult.optimalityGuaranteed=false;
    best=struct('candidate',globalCandidate,'result',globalResult, ...
        'bestParticle',globalPosition,'bestFitness',globalScore,'history',history, ...
        'algorithm',algorithm,'numEvaluations',evaluations,'dimension',D, ...
        'numStayProposals',stayCount,'searchPerformed',true, ...
        'optimizeBS',sim.searchOptimizeBS,'options',opts);

    function [p,c,r,s] = evaluate(p)
        p=repairV10CParticle(p,sim);
        c=decodeV10CParticle(p,sim);
        r=evaluateV10CCandidate(c,sim);
        s=v10cFitness(r,sim); evaluations=evaluations+1;
    end

    function p = stayProposal(p)
        % Collapse one or more consecutive service slots to an exact position.
        % Endpoints and resource blocks are untouched. Nonincreasing Y survives.
        start=randi(numel(L.x)); last=min(numel(L.x),start+randi(3)-1);
        if start==1
            x=(sim.xStart-sim.x_min)/(sim.x_max-sim.x_min);
            y=(sim.yStart-sim.y_min)/(sim.y_max-sim.y_min);
        else
            x=p(L.x(start-1)); y=p(L.y(start-1));
        end
        p(L.x(start:last))=x; p(L.y(start:last))=y;
        p=repairV10CParticle(p,sim);
    end

    function record(row)
        history.bestFitness(row)=globalScore;
        history.eeComputed(row)=globalResult.eeComputed;
        history.feasible(row)=globalResult.isFeasible;
        history.energyJ(row)=globalResult.totalEnergy;
        history.bits(row)=globalResult.totalBits;
        history.hoverSeconds(row)=globalResult.totalHoverTime;
    end
end
