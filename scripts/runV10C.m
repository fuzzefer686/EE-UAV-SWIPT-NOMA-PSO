function data = runV10C(cfg)
%RUNV10C Run real reference PSO/IPSO; retain initialize mode for diagnostics.
    if nargin<1, cfg=v10cConfig(); end
    if ~any(strcmp(cfg.execution.mode,{'initialize','optimize'}))
        error('V10C:ExecutionMode','Use initialize or optimize.');
    end
    sim=buildV10CSimulation(cfg);
    candidate=initialV10CCandidate(sim);
    result=evaluateV10CCandidate(candidate,sim);
    data=struct('cfg',cfg,'sim',sim,'initialCandidate',candidate,'initialResult',result, ...
        'candidate',candidate,'result',result,'searches',struct(), ...
        'geometryLayout',v10cGeometryLayout(sim,true), ...
        'searchLayout',v10cSearchLayout(sim),'selectedAlgorithm','initial', ...
        'stage','initialized-not-optimized','outputFolder','');
    if strcmp(cfg.execution.mode,'optimize')
        methods=cfg.execution.algorithms;
        if ischar(methods) || isstring(methods), methods=cellstr(methods); end
        if ~iscell(methods) || isempty(methods)
            error('V10C:Algorithm','Specify at least one of PSO or IPSO.');
        end
        bestScore=-Inf; selected=false;
        for k=1:numel(methods)
            algorithm=upper(char(methods{k}));
            options=cfg.search; options.optimizeBS=true;
            switch algorithm
                case 'JOINT_PSO'
                    engine='PSO'; options.optimizeBS=false; ...
                    label='Joint PSO (fixed BS)'; logLabel='Joint PSO';
                case {'FULL_PSO','PSO'}
                    engine='PSO'; label='Full PSO'; logLabel='Full PSO';
                case {'FULL_IPSO','IPSO'}
                    engine='IPSO'; label='Full IPSO'; logLabel='Full IPSO';
                otherwise
                    error('V10C:Algorithm','Use JOINT_PSO, FULL_PSO or FULL_IPSO.');
            end
            options.displayName=logLabel;
            searched=optimizeV10CPSO(sim,options,engine);
            searched.engine=engine; searched.algorithm=label; searched.method=algorithm;
            data.searches.(lower(algorithm))=searched;
            if ~selected || searched.bestFitness>bestScore
                bestScore=searched.bestFitness; selected=true;
                data.candidate=searched.candidate; data.result=searched.result;
                data.selectedAlgorithm=algorithm;
            end
        end
        data.stage='search-complete';
    end
    printSummary(1,data);
    if cfg.output.saveResults
        parent=fullfile(cfg.output.root,cfg.preset);
        if ~isfolder(parent)
            [ok,msg]=mkdir(parent);
            if ~ok, error('V10C:OutputFolder','%s',msg); end
        end
        folder=tempname(parent);
        [ok,msg]=mkdir(folder);
        if ~ok, error('V10C:OutputFolder','%s',msg); end
        data.outputFolder=folder;
        save(fullfile(folder,'results.mat'),'data','-v7.3');
        fid=fopen(fullfile(folder,'summary.txt'),'w');
        if fid<0, error('V10C:SummaryFile','Cannot write summary.'); end
        cleanup=onCleanup(@() fclose(fid)); %#ok<NASGU>
        printSummary(fid,data);
        fprintf('V10C results saved: %s\n',folder);
    end
    if cfg.output.makePlots, plotV10CResults(data); end
end

function printSummary(fid,d)
    fprintf(fid,'\nV10C %s | %s\n',d.cfg.preset,d.cfg.description);
    fprintf(fid,'Stage: %s | selected algorithm: %s\n',d.stage,d.selectedAlgorithm);
    fprintf(fid,'Reference PSO/IPSO; SCA/Dinkelbach hybrid not used.\n');
    fprintf(fid,'Energy model: %s\n',d.result.energyModelStatus);
    fprintf(fid,'Geometry dimensions / joint search dimensions: %d / %d\n', ...
        d.geometryLayout.dimension,d.searchLayout.dimension);
    fprintf(fid,'Seed / particles / iterations: %.0f / %d / %d\n', ...
        d.cfg.random.mainSeed,d.cfg.search.numParticles,d.cfg.search.maxIter);
    fprintf(fid,'L bit/user: '); fprintf(fid,'%.9g ',d.sim.minBitsPerUser); fprintf(fid,'\n');
    fprintf(fid,'q bit/user/slot: '); fprintf(fid,'%.9g ',d.sim.minBitsPerUserPerSlot); fprintf(fid,'\n');
    report('Initial candidate',d.initialResult);
    names=fieldnames(d.searches);
    for k=1:numel(names)
        s=d.searches.(names{k});
        fprintf(fid,'\n%s | dimensions %d | evaluations %d | score %.12g\n', ...
            s.algorithm,s.dimension,s.numEvaluations,s.bestFitness);
        report('Searched candidate',s.result);
    end
    fprintf(fid,'\nBest candidate coordinates and slot times\n');
    fprintf(fid,'slot X_m Y_m UL_s DL_s hover_s\n');
    c=d.candidate;
    for t=1:d.sim.numSlots
        fprintf(fid,'%d %.12g %.12g %.12g %.12g %.12g\n',t, ...
            c.waypoints(t,1),c.waypoints(t,2),c.uplinkTime(t), ...
            c.downlinkTime(t),c.uplinkTime(t)+c.downlinkTime(t));
    end
    fprintf(fid,'arrival %.12g %.12g\n',c.waypoints(end,1),c.waypoints(end,2));
    fprintf(fid,'No global optimality guarantee. If infeasible, EE is diagnostic only.\n');

    function report(label,r)
        fprintf(fid,'%s: feasible %d | EE %.12g bit/J\n',label,r.isFeasible,r.eeComputed);
        fprintf(fid,'Total bits / energy J / budget J: %.12g / %.12g / %.12g\n', ...
            r.totalBits,r.totalEnergy,d.sim.energyBudgetJ);
        fprintf(fid,'Movement / hover / RF energy J: %.12g / %.12g / %.12g\n', ...
            r.movementEnergy,r.hoverEnergy,r.rfEnergy);
        fprintf(fid,'Distance m / hover s / mission s / service visits: %.9g / %.9g / %.9g / %d\n', ...
            r.totalDistance,r.totalHoverTime,r.missionTime,r.numServiceVisits);
        % Flags: geometry, timing, alpha, mission L, per-user-slot q, energy.
        % The slot-total QoS flag is omitted here; minBitsPerSlot is 0 in V10C.
        fprintf(fid,'Geometry / time / alpha / L / q / energy: %d %d %d %d %d %d\n', ...
            r.geometryFeasible,r.timingFeasible,r.alphaFeasible,r.missionQoSFeasible, ...
            r.userSlotQoSFeasible,r.energyFeasible);
        fprintf(fid,'Bits per physical user: '); fprintf(fid,'%.12g ',r.totalBitsPerUser); fprintf(fid,'\n');
    end
end
