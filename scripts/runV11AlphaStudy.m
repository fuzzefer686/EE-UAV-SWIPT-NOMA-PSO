function T = runV11AlphaStudy(opts)
%RUNV11ALPHASTUDY Explicit multi-seed alpha study; dryRun never starts PSO.
% Every preset has the same swarm settings, not the same final-solver cost.
% One row describes Full PSO (raw/final); runV11 also retains Joint and IPSO.
    if nargin<1, opts=struct(); end
    presets=getOpt(opts,'presets',{'particle_noma_random','particle_noma_none', ...
        'uniform_noma_none','uniform_noma_qos','uniform_noc3_qos'});
    variants=getOpt(opts,'variants',{'A','B'});
    targets=getOpt(opts,'minBitsPerUser',[1e6,2e6,3e6]);
    % Numeric values are a scalar sweep; each cell is one scalar/vector target.
    if ~iscell(targets), targets=num2cell(targets(:).'); end
    for k=1:numel(targets)
        validateattributes(targets{k},{'numeric'},{'real','finite','nonnegative','vector','nonempty'});
        targets{k}=targets{k}(:).';
    end
    seeds=getOpt(opts,'seeds',[2026,608060,3486784401]);
    if ischar(presets) || isstring(presets), presets=cellstr(presets); end
    if ischar(variants) || isstring(variants), variants=cellstr(variants); end
    dryRun=getOpt(opts,'dryRun',false);
    smoke=getOpt(opts,'smoke',false);
    if smoke
        warning('runV11AlphaStudy:Smoke','SMOKE — không dùng cho kết quả paper');
    end
    base=getOpt(opts,'cfg',v11Config());
    rows=struct([]); index=0;
    for p=1:numel(presets)
        for v=1:numel(variants)
            for targetIndex=1:numel(targets)
                L=targets{targetIndex};
                LLabel=mat2str(L,17);
                Lscalar=NaN; if isscalar(L), Lscalar=L; end
                for seed=seeds(:).'
                    cfg=v11AlphaPreset(presets{p},base); cfg.mission.minBitsPerUser=L;
                    cfg.random.mainSeed=seed;
                    % Vary scenario and optimizer initialization across replicates.
                    cfg.random.algorithmSeed=mod(seed+149457261,2^32);
                    cfg.random.polishSeed=mod(seed+149459261,2^32);
                    names={'joint','full','ipso'};
                    for k=1:3
                        cfg.optimizers.(names{k}).numParticles=120;
                        cfg.optimizers.(names{k}).maxIter=1000;
                    end
                    % Explicit small settings are useful only for a bounded smoke run.
                    if isfield(opts,'numParticles')
                        for k=1:3, cfg.optimizers.(names{k}).numParticles=opts.numParticles; end
                    end
                    if isfield(opts,'maxIter')
                        for k=1:3, cfg.optimizers.(names{k}).maxIter=opts.maxIter; end
                    end
                    if smoke
                        for k=1:3
                            cfg.optimizers.(names{k}).numParticles=5;
                            cfg.optimizers.(names{k}).maxIter=3;
                        end
                    end
                    cfg.output.makePlots=false; cfg.output.saveFigures=false;
                    cfg.output.saveResults=false;
                    state=rng; rng(seed,'twister'); sim=buildV11Simulation(cfg,variants{v}); rng(state);
                    layout=v11ParticleLayout(sim,true);
                    index=index+1;
                    row=struct('preset',presets{p},'variant',sim.variant,'L',Lscalar,'LLabel',LLabel,'LPerUser',mat2str(L,17),'seed',seed, ...
                        'dimension',layout.dimension,'alphaFinalizeJoint',sim.alphaFinalizeJoint,'eeUAV',NaN,'eeRF',NaN,'totalBits',NaN, ...
                        'totalEnergy',NaN,'feasible',false,'missionQoS',false,'slotQoS',false, ...
                        'userSlotQoS',false,'energyOK',false,'minDeliveredOverL',NaN, ...
                        'maxAlphaDeviationFromUniform',NaN,'wallClockSeconds',NaN, ...
                        'numFitnessEvals',0,'swarmFitnessEvals',0,'alphaRateEvals',0, ...
                        'runNumFitnessEvals',0,'numParticles',cfg.optimizers.full.numParticles, ...
                        'maxIter',cfg.optimizers.full.maxIter,'algorithm','Full PSO');
                    if ~dryRun
                        timer=tic; data=runV11(variants{v},cfg); row.wallClockSeconds=toc(timer);
                        r=data.trajFull;
                        row.eeUAV=r.eeUAV; row.eeRF=r.eeRF; row.totalBits=r.totalBits;
                        row.totalEnergy=r.totalEnergy; row.feasible=r.isFeasible;
                        row.missionQoS=r.missionQoSFeasible; row.slotQoS=r.slotQoSFeasible;
                        row.userSlotQoS=r.userSlotQoSFeasible; row.energyOK=r.energyFeasible;
                        target=L; if isscalar(target), target=repmat(target,1,sim.noUsers); end
                        ratios=Inf(1,sim.noUsers); positive=target>0;
                        ratios(positive)=r.totalBitsPerUser(positive)./target(positive);
                        row.minDeliveredOverL=min(ratios);
                        row.maxAlphaDeviationFromUniform=max(max(abs(r.alphaTrace(1:end-1,:)-1/sim.noUsers)));
                        row.numFitnessEvals=r.numFitnessEvals;
                        row.swarmFitnessEvals=data.trajFullRaw.numFitnessEvals;
                        row.runNumFitnessEvals=data.numFitnessEvals;
                        if isfield(r,'alphaSolverInfo'), row.alphaRateEvals=r.alphaSolverInfo.numRateEvals; end
                    end
                    if index==1, rows=row; else, rows(index)=row; end
                end
            end
        end
    end
    T=struct2table(rows);
    if dryRun
        fprintf('V11 alpha study dryRun: %d combinations; no optimizers or output files.\n',height(T));
        return;
    end
    stamp=char(datetime('now','Format','yyyyMMdd_HHmmss_SSS'));
    folder=fullfile(base.output.root,'alphaStudy',stamp); suffix=0; stem=folder;
    while exist(folder,'dir'), suffix=suffix+1; folder=sprintf('%s_%02d',stem,suffix); end
    [ok,message]=mkdir(folder); if ~ok, error('runV11AlphaStudy:Output','%s',message); end
    writetable(T,fullfile(folder,'table.csv')); save(fullfile(folder,'table.mat'),'T','opts');
    fid=fopen(fullfile(folder,'summary.txt'),'w');
    if fid<0, error('runV11AlphaStudy:Summary','Cannot create summary.txt.'); end
    cleanup=onCleanup(@() fclose(fid));
    writeV11AlphaStudySummary(fid,T,presets,variants,targets);
    fprintf('V11 alpha study saved: %s\n',folder);
end

function value = getOpt(opts,name,fallback)
    if isfield(opts,name) && ~isempty(opts.(name)), value=opts.(name); else, value=fallback; end
end
