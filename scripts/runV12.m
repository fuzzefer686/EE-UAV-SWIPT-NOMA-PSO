function data = runV12(variant, cfg, incumbentPool)
%RUNV12 Same V10/V9 optimization sequence for A/B, using V12 causal DF and accel physics.
    if nargin<2 || isempty(cfg)
        cfg=v12Config();
    end
    if nargin<3 || isempty(incumbentPool)
        incumbentPool=struct();
        if isfield(cfg,'optimizers') && isfield(cfg.optimizers,'incumbentPool') ...
                && isstruct(cfg.optimizers.incumbentPool)
            incumbentPool=cfg.optimizers.incumbentPool;
        end
    end
    seedMode='fixed';
    if isfield(cfg,'optimizers') && isfield(cfg.optimizers,'seedMode') ...
            && ~isempty(cfg.optimizers.seedMode)
        seedMode=lower(char(cfg.optimizers.seedMode));
    end
    switch seedMode
        case 'per-scenario'
            [cfg.random.algorithmSeed,cfg.random.polishSeed]= ...
                deriveV12OptimizerSeeds(cfg.random.mainSeed);
        case 'fixed'
            % Keep supplied algorithmSeed and polishSeed unchanged.
        otherwise
            error('runV12:SeedMode', ...
                'optimizers.seedMode must be ''per-scenario'' or ''fixed''.');
    end
    incumbentMode='none';
    if isfield(cfg,'optimizers') && isfield(cfg.optimizers,'incumbentMode') ...
            && ~isempty(cfg.optimizers.incumbentMode)
        incumbentMode=normalizeIncumbentMode(cfg.optimizers.incumbentMode);
    end
    rng(cfg.random.mainSeed,'twister');
    sim=buildV12Simulation(cfg,variant);
    sim.incumbentMode=incumbentMode;
    validateattributes(cfg.optimizers.alphaPolishSamplesPerUser,{'numeric'}, ...
        {'real','finite','scalar','integer','nonnegative'});
    validateattributes(cfg.optimizers.alphaPolishMinimumSamples,{'numeric'}, ...
        {'real','finite','scalar','integer','nonnegative'});
    fprintf('\n=== V12%s | mainSeed=%.0f | algoSeed=%.0f | polishSeed=%.0f | L (bit/user): ', ...
        sim.variant,cfg.random.mainSeed,cfg.random.algorithmSeed,cfg.random.polishSeed);
    fprintf('%.9g ',sim.minBitsPerUser); fprintf('===\n');
    fprintf('UAV Z=%.3f m | cruise=%.3f m/s | hover=%.3f s (EH %.3f/RF %.3f)\n', ...
        sim.altitude,sim.flight.cruiseSpeed,sim.hoverTime,sim.ehTime,sim.rfTime);
    fprintf('Drones Eq.(11): cruise=%.9f W | hover=%.9f W | gross budget=%.9g J\n', ...
        sim.cruisePower,sim.hoverPower,sim.energyBudgetJ);
    fprintf(['V12 physics: motion=%s (a=%.3g m/s^2) | solver=%s/%s/%s | ', ...
        'incumbent=%s | powerSplitMode=%s (causal=%d, phiMax=%.6g)\n'], ...
        sim.flight.motionMode,sim.flight.acceleration,sim.initMode,sim.updateMode, ...
        sim.mutationMode,sim.incumbentMode,sim.radio.powerSplitMode, ...
        sim.radio.enforceUlDlCausality,sim.radio.phiMax);
    fprintf('Scope: horizontal cruise + requested hover + RF; EH supplies RF only.\n');
    fprintf('User X: '); disp(sim.xUser); fprintf('User Y: '); disp(sim.yUser);

    p=initialV10Particle(sim,false,false);
    [~,resBase]=evaluateTrajectoryV12(p,sim,false,true);
    resBase.evalCount=1;

    jointOpts=prepareOptimizerOpts(cfg.optimizers.joint,cfg.optimizers,sim,70,150);
    fullOpts=prepareOptimizerOpts(cfg.optimizers.full,cfg.optimizers,sim,100,250);
    ipsoOpts=prepareOptimizerOpts(cfg.optimizers.ipso,cfg.optimizers,sim,100,250);

    samples=max(cfg.optimizers.alphaPolishMinimumSamples, ...
        cfg.optimizers.alphaPolishSamplesPerUser*sim.noUsers);
    polishJoint=true;
    if isfield(cfg.optimizers,'polishJoint') && ~isempty(cfg.optimizers.polishJoint)
        validateattributes(cfg.optimizers.polishJoint,{'logical','numeric'},{'scalar','binary'});
        polishJoint=logical(cfg.optimizers.polishJoint);
    end

    runTag=resolveRunTag(cfg,sim);
    noDeps=emptyLineage();

    if strcmp(incumbentMode,'none')
        % Controlled comparison / legacy parity branch: zero incumbent perturbations.
        rng(cfg.random.algorithmSeed,'twister');
        trajJointRaw=optimizeTrajectoryV12JointPSO(sim,jointOpts);
        rng(cfg.random.polishSeed,'twister');
        trajJointPolished=polishAlphaV12(trajJointRaw,sim,samples,false);
        rng(cfg.random.algorithmSeed,'twister');
        trajFullRaw=optimizeTrajectoryV12FullPSO(sim,fullOpts);
        rng(cfg.random.polishSeed,'twister');
        trajFull=polishAlphaV12(trajFullRaw,sim,samples,true);
        rng(cfg.random.algorithmSeed,'twister');
        trajIPSORaw=optimizeTrajectoryV12FullIPSO(sim,ipsoOpts);
        rng(cfg.random.polishSeed,'twister');
        trajIPSO=polishAlphaV12(trajIPSORaw,sim,samples,true);

        [trajJointRaw,trajJointPolished]=annotateStagePair(trajJointRaw, ...
            trajJointPolished,[runTag,'|Joint PSO'],noDeps,noDeps);
        [trajFullRaw,trajFull]=annotateStagePair(trajFullRaw,trajFull, ...
            [runTag,'|Full PSO'],noDeps,noDeps);
        [trajIPSORaw,trajIPSO]=annotateStagePair(trajIPSORaw,trajIPSO, ...
            [runTag,'|Full IPSO'],noDeps,noDeps);
    else
        rawPool=getPoolEntries(incumbentPool,'raw');
        polPool=getPoolEntries(incumbentPool,'polished');

        candsJointRaw=gatherPoolCandidates(rawPool,'Joint PSO',incumbentMode,sim);
        incJoint=selectBestIncumbent(candsJointRaw,sim,false,jointOpts.maxEvals, ...
            jointOpts.numParticles);
        jointOptsRun=applyIncumbentOpts(jointOpts,incJoint);
        rng(cfg.random.algorithmSeed,'twister');
        trajJointRaw=optimizeTrajectoryV12JointPSO(sim,jointOptsRun);

        candsJointPol=gatherPoolCandidates(polPool,'Joint PSO',incumbentMode,sim);
        jointPolOpts=makePolishOpts(candsJointPol);
        rng(cfg.random.polishSeed,'twister');
        trajJointPolished=polishAlphaV12(trajJointRaw,sim,samples,false,jointPolOpts);
        [trajJointRaw,trajJointPolished]=annotateStagePair(trajJointRaw, ...
            trajJointPolished,[runTag,'|Joint PSO'], ...
            usedLineage(candsJointRaw,incJoint.usedIdx), ...
            usedLineage(candsJointPol,trajJointPolished.polishCandidatesUsed));

        liftedJointRaw=makeCandidate(liftJointToFull(trajJointRaw.bestParticle,sim), ...
            'jointRaw',resultLineage(trajJointRaw));
        liftedJointPol=makeCandidate(liftJointToFull(trajJointPolished.bestParticle,sim), ...
            'jointPolished',resultLineage(trajJointPolished));

        candsFullRaw=[liftedJointRaw;gatherPoolCandidates(rawPool,'Full PSO',incumbentMode,sim)];
        incFull=selectBestIncumbent(candsFullRaw,sim,true,fullOpts.maxEvals, ...
            fullOpts.numParticles);
        fullOptsRun=applyIncumbentOpts(fullOpts,incFull);
        rng(cfg.random.algorithmSeed,'twister');
        trajFullRaw=optimizeTrajectoryV12FullPSO(sim,fullOptsRun);

        candsFullPol=[liftedJointPol;gatherPoolCandidates(polPool,'Full PSO',incumbentMode,sim)];
        fullPolOpts=makePolishOpts(candsFullPol);
        rng(cfg.random.polishSeed,'twister');
        trajFull=polishAlphaV12(trajFullRaw,sim,samples,true,fullPolOpts);
        [trajFullRaw,trajFull]=annotateStagePair(trajFullRaw,trajFull, ...
            [runTag,'|Full PSO'],usedLineage(candsFullRaw,incFull.usedIdx), ...
            usedLineage(candsFullPol,trajFull.polishCandidatesUsed));

        candsIPSORaw=[liftedJointRaw;gatherPoolCandidates(rawPool,'Full IPSO',incumbentMode,sim)];
        incIPSO=selectBestIncumbent(candsIPSORaw,sim,true,ipsoOpts.maxEvals, ...
            ipsoOpts.numParticles);
        ipsoOptsRun=applyIncumbentOpts(ipsoOpts,incIPSO);
        rng(cfg.random.algorithmSeed,'twister');
        trajIPSORaw=optimizeTrajectoryV12FullIPSO(sim,ipsoOptsRun);

        candsIPSOPol=[liftedJointPol;gatherPoolCandidates(polPool,'Full IPSO',incumbentMode,sim)];
        ipsoPolOpts=makePolishOpts(candsIPSOPol);
        rng(cfg.random.polishSeed,'twister');
        trajIPSO=polishAlphaV12(trajIPSORaw,sim,samples,true,ipsoPolOpts);
        [trajIPSORaw,trajIPSO]=annotateStagePair(trajIPSORaw,trajIPSO, ...
            [runTag,'|Full IPSO'],usedLineage(candsIPSORaw,incIPSO.usedIdx), ...
            usedLineage(candsIPSOPol,trajIPSO.polishCandidatesUsed));
    end
    if polishJoint
        trajJoint=trajJointPolished;
    else
        trajJoint=trajJointRaw;
    end
    resBase=annotateLineage(resBase,[runTag,'|Baseline'],resBase.evalCount,noDeps);

    data=struct('cfg',cfg,'sim',sim,'resBase',resBase,'trajJoint',trajJoint, ...
        'trajJointRaw',trajJointRaw,'trajJointPolished',trajJointPolished, ...
        'trajFullRaw',trajFullRaw,'trajIPSORaw',trajIPSORaw, ...
        'trajFull',trajFull,'trajIPSO',trajIPSO,'outputFolder','');
    printSummary(1,data);
    if cfg.output.saveResults || (cfg.output.makePlots && cfg.output.saveFigures)
        stamp=char(datetime('now','Format','yyyyMMdd_HHmmss_SSS'));
        if isscalar(sim.minBitsPerUser)
            lLabel=strrep(sprintf('%.9g',sim.minBitsPerUser/1e6),'.','p');
        else
            lLabel='perUser';
        end
        root=fullfile(cfg.output.root,['V12',sim.variant]);
        stem=sprintf('seed%.0f_L%sMbit_%s',cfg.random.mainSeed,lLabel,stamp);
        folder=fullfile(root,stem); suffix=1;
        while exist(folder,'file') || exist(folder,'dir')
            folder=fullfile(root,sprintf('%s_%02d',stem,suffix)); suffix=suffix+1;
        end
        [ok,message]=mkdir(folder);
        if ~ok
            error('runV12:OutputFolder','Cannot create output folder: %s',message);
        end
        data.outputFolder=folder;
    end
    % Save numerical/configuration provenance before optional graphics can fail.
    if cfg.output.saveResults
        save(fullfile(data.outputFolder,'results.mat'),'data','-v7.3');
        fid=fopen(fullfile(data.outputFolder,'summary.txt'),'w');
        if fid<0
            error('runV12:SummaryFile','Cannot write summary.txt.');
        end
        cleaner=onCleanup(@() fclose(fid));
        printSummary(fid,data);
        clear cleaner;
        fprintf('V12 configuration and raw/final results saved: %s\n',data.outputFolder);
    end
    if cfg.output.makePlots
        didPlot=plotV10Diagnostics(data);
        if cfg.output.saveFigures && didPlot
            figureFolder=saveV9Figures(data.outputFolder);
            fprintf('V12 figures saved: %s\n',figureFolder);
        end
    end
end

function mode = normalizeIncumbentMode(rawMode)
    switch lower(strtrim(char(rawMode)))
        case 'none'
            mode='none';
        case 'jointtofull'
            mode='jointToFull';
        case 'lcontinuation'
            mode='LContinuation';
        case 'crossmodel'
            mode='crossModel';
        otherwise
            error('runV12:IncumbentMode', ...
                'optimizers.incumbentMode must be ''none'', ''jointToFull'', ''LContinuation'', or ''crossModel''.');
    end
end

function optsOut = prepareOptimizerOpts(optsIn, cfgOpt, sim, defaultP, defaultIter)
    optsOut=optsIn;
    if ~isfield(optsOut,'initMode') || isempty(optsOut.initMode)
        optsOut.initMode=sim.initMode;
    end
    if ~isfield(optsOut,'updateMode') || isempty(optsOut.updateMode)
        optsOut.updateMode=sim.updateMode;
    end
    if ~isfield(optsOut,'mutationMode') || isempty(optsOut.mutationMode)
        optsOut.mutationMode=sim.mutationMode;
    end
    % Pin swarm size so incumbent screening and the solver use the same P.
    optsOut.numParticles=getFieldDefault(optsOut,'numParticles',defaultP);
    if ~isfield(optsOut,'maxEvals') || isempty(optsOut.maxEvals)
        if isfield(cfgOpt,'maxEvals') && ~isempty(cfgOpt.maxEvals)
            optsOut.maxEvals=cfgOpt.maxEvals;
        else
            pCount=getFieldDefault(optsOut,'numParticles',defaultP);
            nIter=getFieldDefault(optsOut,'maxIter',defaultIter);
            optsOut.maxEvals=double(pCount)*(double(nIter)+1);
        end
    end
end

function val = getFieldDefault(s, fieldName, defaultVal)
    if isfield(s,fieldName) && ~isempty(s.(fieldName))
        val=s.(fieldName);
    else
        val=defaultVal;
    end
end

function entries = getPoolEntries(pool, stageField)
    if isstruct(pool) && isfield(pool,stageField) && ~isempty(pool.(stageField))
        entries=pool.(stageField);
    else
        entries=struct([]);
    end
end

function pFull = liftJointToFull(jointParticle, sim)
    xBS=min(max(sim.xBS(:).',sim.xBS_min(:).'),sim.xBS_max(:).');
    yBS=min(max(sim.yBS(:).',sim.yBS_min(:).'),sim.yBS_max(:).');
    pFull=[jointParticle(:).',xBS,yBS];
end

function cands = gatherPoolCandidates(poolEntries, targetAlg, incumbentMode, sim)
    cands=repmat(makeCandidate([],'',emptyLineage()),0,1);
    if ~any(strcmp(incumbentMode,{'LContinuation','crossModel'})) || isempty(poolEntries)
        return;
    end
    curSolverKey=sprintf('%s|%s|%s',sim.initMode,sim.updateMode,sim.mutationMode);
    curL=sim.minBitsPerUser(:).';
    curSlot=sim.minBitsPerUserPerSlot(:).';
    curHover=sim.hoverTime;
    dJoint=v10ParticleLayout(sim,false).dimension;
    dFull=v10ParticleLayout(sim,true).dimension;

    for m=1:numel(poolEntries)
        e=poolEntries(m);
        if ~isfield(e,'algorithm') || ~isfield(e,'particle') || isempty(e.particle)
            continue;
        end
        if isfield(e,'solverKey') && ~isempty(e.solverKey) ...
                && ~strcmpi(char(e.solverKey),curSolverKey)
            continue;
        end
        if isfield(e,'L') && ~isempty(e.L)
            eL=e.L(:).';
            if ~all(eL - curL >= -1e-9)
                continue;
            end
        end
        if isfield(e,'slot') && ~isempty(e.slot)
            if any(abs(e.slot(:).' - curSlot) > 1e-12)
                continue;
            end
        end
        if isfield(e,'hover') && ~isempty(e.hover)
            if abs(e.hover - curHover) > 1e-12
                continue;
            end
        end
        if strcmp(incumbentMode,'LContinuation')
            if isfield(e,'motionMode') && ~isempty(e.motionMode) ...
                    && ~strcmpi(char(e.motionMode),sim.flight.motionMode)
                continue;
            end
            if strcmpi(sim.flight.motionMode,'quasi-steady-accel') ...
                    && isfield(e,'accel') && ~isempty(e.accel) ...
                    && abs(e.accel - sim.flight.acceleration) > 1e-12
                continue;
            end
            if isfield(e,'phiMode') && ~isempty(e.phiMode) ...
                    && ~strcmpi(char(e.phiMode),sim.radio.powerSplitMode)
                continue;
            end
            if isfield(e,'causal') && ~isempty(e.causal) ...
                    && logical(e.causal) ~= logical(sim.radio.enforceUlDlCausality)
                continue;
            end
            if strcmpi(sim.radio.powerSplitMode,'optimal-causal') ...
                    && isfield(e,'phiMax') && ~isempty(e.phiMax) ...
                    && abs(e.phiMax - sim.radio.phiMax) > 1e-12
                continue;
            end
        end

        alg=char(e.algorithm);
        p=e.particle(:).';
        src='';
        if isfield(e,'source') && ~isempty(e.source)
            src=char(e.source);
        end
        % Missing lineage => source cost unknown; reported via sourceCostComplete=false.
        lin=emptyLineage();
        lin.complete=false;
        if isfield(e,'lineage') && isstruct(e.lineage) && isfield(e.lineage,'keys')
            lin=e.lineage;
        end
        if strcmp(targetAlg,'Joint PSO')
            if strcmp(alg,'Joint PSO') && numel(p)==dJoint
                cands(end+1,1)=makeCandidate(p,src,lin); %#ok<AGROW>
            end
        else
            if strcmp(alg,targetAlg) && numel(p)==dFull
                cands(end+1,1)=makeCandidate(p,src,lin); %#ok<AGROW>
            elseif strcmp(alg,'Joint PSO') && numel(p)==dJoint
                cands(end+1,1)=makeCandidate(liftJointToFull(p,sim), ...
                    [src,':lifted'],lin); %#ok<AGROW>
            end
        end
    end
end

function inc = selectBestIncumbent(cands, sim, optimizeBS, maxEvals, numParticles)
% Screening may spend at most maxEvals-(numParticles-1) evaluations (repairs
% included), so the solver can always initialize the remaining particles.
    inc=struct('found',false,'particle',[],'result',struct(),'source','', ...
        'evalsSpent',0,'usedIdx',zeros(1,0));
    if isempty(cands)
        return;
    end
    validateattributes(numParticles,{'numeric'},{'scalar','finite','integer','positive'});
    if isempty(maxEvals) || isnan(maxEvals) || (isinf(maxEvals) && maxEvals>0)
        cap=Inf;
    else
        cap=double(maxEvals)-(double(numParticles)-1);
    end
    if cap<1
        return;
    end
    layout=v10ParticleLayout(sim,optimizeBS);
    D=layout.dimension;
    seen=zeros(0,D);
    bestFit=-inf;
    for m=1:numel(cands)
        if inc.evalsSpent>=cap
            break;
        end
        if ~isfield(cands(m),'particle') || numel(cands(m).particle)~=D
            continue;
        end
        p=reshape(cands(m).particle,1,D);
        if ~all(isfinite(p))
            continue;
        end
        if ~isempty(seen) && any(max(abs(seen - p),[],2)<=1e-15)
            continue;
        end
        seen=[seen;p]; %#ok<AGROW>
        [fit,res]=evaluateTrajectoryV12(p,sim,optimizeBS);
        inc.evalsSpent=inc.evalsSpent+1;
        inc.usedIdx(end+1)=m;
        if ~res.geometryFeasible && inc.evalsSpent<cap
            p=repairV10Particle(p,sim,optimizeBS);
            [fit,res]=evaluateTrajectoryV12(p,sim,optimizeBS);
            inc.evalsSpent=inc.evalsSpent+1;
        end
        src='';
        if isfield(cands(m),'source') && ~isempty(cands(m).source)
            src=char(cands(m).source);
        end
        if ~inc.found || fit>bestFit
            inc.found=true;
            bestFit=fit;
            inc.particle=p;
            inc.result=res;
            inc.source=src;
        end
    end
end

function optsOut = applyIncumbentOpts(optsIn, inc)
    optsOut=optsIn;
    if inc.found
        optsOut.seedParticle=inc.particle;
        optsOut.seedResult=inc.result;
        optsOut.seedSource=inc.source;
        optsOut.initialEvalCount=inc.evalsSpent;
    end
end

function polOpts = makePolishOpts(cands)
    polOpts=struct();
    if ~isempty(cands)
        polOpts.candidates=cands;
    end
end

function c = makeCandidate(particle, source, lineage)
    c=struct('particle',particle,'source',source,'lineage',lineage);
end

function lin = emptyLineage()
% keys: unique stage IDs; evals: marginal evaluations of each stage;
% complete=false when some ancestor stage carried no cost record.
    lin=struct('keys',{cell(1,0)},'evals',zeros(1,0),'complete',true);
end

function out = mergeLineage(a, b)
    out=a;
    out.complete=logical(a.complete) && logical(b.complete);
    for k=1:numel(b.keys)
        if ~any(strcmp(out.keys,b.keys{k}))
            out.keys{end+1}=b.keys{k};
            out.evals(end+1)=b.evals(k);
        end
    end
end

function lin = usedLineage(cands, usedIdx)
% Union of lineages of every candidate screened (evaluated or reused), not only the winner.
    lin=emptyLineage();
    for m=unique(usedIdx(:).')
        if isfield(cands(m),'lineage') && isstruct(cands(m).lineage) ...
                && isfield(cands(m).lineage,'keys')
            lin=mergeLineage(lin,cands(m).lineage);
        else
            lin.complete=false;
        end
    end
end

function lin = resultLineage(r)
    if isfield(r,'lineage') && isstruct(r.lineage)
        lin=r.lineage;
    else
        lin=emptyLineage();
        lin.complete=false;
    end
end

function r = annotateLineage(r, ownKey, ownEvals, deps)
    assertFreshKey(deps,ownKey);
    own=emptyLineage();
    own.keys={ownKey};
    own.evals=double(ownEvals);
    lin=mergeLineage(deps,own);
    r.lineage=lin;
    r.evalCountCumulative=sum(lin.evals);
    r.evalCountSource=r.evalCountCumulative-r.evalCount;
    r.sourceCostComplete=logical(lin.complete);
end

function [rawOut, polOut] = annotateStagePair(rawIn, polIn, algTag, rawDeps, polDeps)
% Raw stage owns its PSO evaluations; polished stage owns only its polish evaluations
% and inherits the raw stage lineage, so shared ancestors are counted once.
    rawOut=annotateLineage(rawIn,[algTag,'|raw'],rawIn.evalCount,rawDeps);
    polOut=polIn;
    polKey=[algTag,'|polished'];
    deps=mergeLineage(rawOut.lineage,polDeps);
    assertFreshKey(deps,polKey);
    own=emptyLineage();
    own.keys={polKey};
    own.evals=double(polIn.evalCountPolish);
    lin=mergeLineage(deps,own);
    polOut.lineage=lin;
    polOut.evalCountCumulative=sum(lin.evals);
    polOut.evalCountSource=polOut.evalCountCumulative-polOut.evalCount;
    polOut.sourceCostComplete=logical(lin.complete);
end

function tag = resolveRunTag(cfg, sim)
% Readable prefix (cfg.optimizers.runTag or scenario description) plus a
% per-invocation ID, so repeated calls with identical cfg/runTag never share
% lineage keys. The ID does not touch the global RNG stream.
    if isfield(cfg,'optimizers') && isfield(cfg.optimizers,'runTag') ...
            && ~isempty(cfg.optimizers.runTag)
        prefix=char(cfg.optimizers.runTag);
    else
        prefix=sprintf('V12%s|seed=%.0f|L=%s|slot=%s|hover=%.9g|%s|a=%.9g|%s|causal=%d|%s|%s|%s', ...
            sim.variant,cfg.random.mainSeed,sprintf('%.9g,',sim.minBitsPerUser), ...
            sprintf('%.9g,',sim.minBitsPerUserPerSlot),sim.hoverTime,sim.flight.motionMode, ...
            sim.flight.acceleration,sim.radio.powerSplitMode, ...
            double(logical(sim.radio.enforceUlDlCausality)),sim.initMode,sim.updateMode, ...
            sim.mutationMode);
    end
    tag=sprintf('%s|call=%s',prefix,newInvocationId());
end

function id = newInvocationId()
    persistent counter
    if isempty(counter)
        counter=0;
    end
    counter=counter+1;
    [~,tmp]=fileparts(tempname);   % tempname embeds a UUID; no RNG consumption
    id=sprintf('%s_%d',tmp,counter);
end

function assertFreshKey(deps, key)
% A stage key already present among its ancestors would make mergeLineage drop
% this stage's own evaluations; fail loudly instead of under-reporting cost.
    if any(strcmp(deps.keys,key))
        error('runV12:DuplicateLineageKey', ...
            'Lineage key "%s" already exists among source stages; runTag is not unique.',key);
    end
end

function printSummary(fid,data)
% One metric per line, following the V10/V9 console layout; also used by summary.txt.
    sim=data.sim; cfg=data.cfg;
    fprintf(fid,'\n=== V12%s total UAV EE (propulsion + hover + RF) ===\n',sim.variant);
    fprintf(fid,'Version                   = %s\n',cfg.version);
    fprintf(fid,'Scenario seed             = %.0f\n',cfg.random.mainSeed);
    fprintf(fid,'Algorithm seed            = %.0f\n',cfg.random.algorithmSeed);
    fprintf(fid,'Polishing seed            = %.0f\n',cfg.random.polishSeed);
    fprintf(fid,'Initializer mode          = %s\n',sim.initMode);
    fprintf(fid,'Update / mutation mode    = %s / %s\n',sim.updateMode,sim.mutationMode);
    fprintf(fid,'Incumbent mode            = %s\n',sim.incumbentMode);
    fprintf(fid,'L (bit/user):\n');
    for u=1:sim.noUsers
        target=sim.minBitsPerUser(min(u,numel(sim.minBitsPerUser)));
        fprintf(fid,'  User %d                  = %.12e bit\n',u,target);
    end
    fprintf(fid,'Min bits per slot (total)  = %.12g bit\n',sim.minBitsPerSlot);
    fprintf(fid,'Min bits per user-slot     = ');
    fprintf(fid,'%.12g ',sim.minBitsPerUserPerSlot); fprintf(fid,'bit\n');
    fprintf(fid,'\nTiming and flight settings\n');
    fprintf(fid,'Hover per serving point   = %.9g s\n',sim.hoverTime);
    fprintf(fid,'EH / uplink time          = %.9g s\n',sim.ehTime);
    fprintf(fid,'RF / downlink time        = %.9g s\n',sim.rfTime);
    fprintf(fid,'Motion mode               = %s\n',sim.flight.motionMode);
    fprintf(fid,'Max acceleration          = %.9g m/s^2\n',sim.flight.acceleration);
    fprintf(fid,'Cruise speed              = %.9g m/s\n',sim.flight.cruiseSpeed);
    fprintf(fid,'UAV altitude              = %.9g m\n',sim.altitude);
    fprintf(fid,'Energy budget (gross)     = %.12g J\n',sim.energyBudgetJ);
    fprintf(fid,'Cruise power              = %.12g W\n',sim.cruisePower);
    fprintf(fid,'Hover power               = %.12g W\n',sim.hoverPower);
    fprintf(fid,'\nRadio settings\n');
    fprintf(fid,'BS transmit power         = %.9g dBm\n',sim.radio.bsPowerDbm);
    fprintf(fid,'Power split mode          = %s\n',sim.radio.powerSplitMode);
    fprintf(fid,'Power splitting phi       = %.9g\n',sim.radio.powerSplit);
    fprintf(fid,'Power split bounds        = [%.9g, %.9g]\n',sim.radio.phiMin,sim.radio.phiMax);
    fprintf(fid,'EH efficiency eta         = %.9g\n',sim.radio.ehEfficiency);
    fprintf(fid,'Bandwidth                 = %.9g Hz\n',sim.radio.bandwidthHz);
    fprintf(fid,'Reference gain beta0      = %.9g dB\n',sim.radio.referenceGainDb);
    names={'Baseline straight trajectory','Joint PSO without BS optimization', ...
        'Full PSO with BS optimization','Full IPSO with BS optimization'};
    results={data.resBase,data.trajJoint,data.trajFull,data.trajIPSO};
    for k=1:numel(results)
        r=results{k}; ee=r.eeComputed;
        fprintf(fid,'\n%s\n',names{k});
        fprintf(fid,'Feasible                  = %d\n',r.isFeasible);
        fprintf(fid,'EE (computed)             = %.12e bit/J\n',ee);
        if isfield(r,'evalCount') && ~isempty(r.evalCount)
            if isfield(r,'evalCountPolish')
                fprintf(fid,'Function evaluations      = %.0f (raw %.0f + polish %.0f)\n', ...
                    r.evalCount,r.evalCountRaw,r.evalCountPolish);
            else
                fprintf(fid,'Function evaluations      = %.0f\n',r.evalCount);
            end
        end
        if isfield(r,'incumbentUsed') && logical(r.incumbentUsed)
            fprintf(fid,'Incumbent                 = %s (retained=%d, EE=%.6e, feasible=%g)\n', ...
                r.incumbentSource,double(logical(r.incumbentRetained)), ...
                r.incumbentEE,r.incumbentFeasible);
        end
        if k==2 && isfield(data,'trajJointPolished')
            jp=data.trajJointPolished;
            fprintf(fid,'Joint alpha-polished EE   = %.12e bit/J (feasible=%d, evals=%.0f)\n', ...
                jp.eeComputed,jp.isFeasible,jp.evalCount);
        end
        fprintf(fid,'L / bit-slot / bit-user-slot QoS = %d / %d / %d\n', ...
            r.missionQoSFeasible,r.slotQoSFeasible,r.userSlotQoSFeasible);
        if isfield(r,'ulDlFeasible')
            fprintf(fid,'UL/DL causality QoS       = %d\n',r.ulDlFeasible);
        end
        fprintf(fid,'Energy / geometry         = %d / %d\n',r.energyFeasible,r.geometryFeasible);
        if isfield(r,'meanPhi')
            fprintf(fid,'Mean optimal phi          = %.12g\n',r.meanPhi);
        end
        fprintf(fid,'Total bits                = %.12e bit\n',r.totalBits);
        fprintf(fid,'Min bits per slot         = %.12e bit\n',r.slotBitsMin);
        fprintf(fid,'Max bits per slot         = %.12e bit\n',r.slotBitsMax);
        fprintf(fid,'Slots below slot QoS      = %d\n',r.numSlotsBelowMin);
        fprintf(fid,'User-slots below QoS      = %d\n',r.numUserSlotsBelowMin);
        fprintf(fid,'Total UAV energy          = %.12e J\n',r.totalEnergy);
        fprintf(fid,'Cruise energy             = %.12e J\n',r.flightEnergy);
        fprintf(fid,'Hover energy              = %.12e J\n',r.hoverEnergy);
        fprintf(fid,'RF transmit energy        = %.12e J\n',r.rfEnergy);
        fprintf(fid,'Harvested energy          = %.12e J\n',r.totalHarvestedEnergy);
        fprintf(fid,'Total flight distance     = %.9f m\n',r.totalDistance);
        fprintf(fid,'Flight time               = %.9f s\n',r.flightTime);
        fprintf(fid,'Total hover time          = %.9f s\n',r.totalHoverTime);
        fprintf(fid,'Mission time              = %.9f s\n',r.missionTime);
        fprintf(fid,'Excess energy             = %.12e J\n',r.energyShortfall);
        fprintf(fid,'Bits per user:\n');
        for u=1:numel(r.totalBitsPerUser)
            fprintf(fid,'  User %d                  = %.12e bit\n',u,r.totalBitsPerUser(u));
        end
        fprintf(fid,'Bit shortfall per user:\n');
        for u=1:numel(r.bitsShortfallPerUser)
            fprintf(fid,'  User %d                  = %.12e bit\n',u,r.bitsShortfallPerUser(u));
        end
    end
end
