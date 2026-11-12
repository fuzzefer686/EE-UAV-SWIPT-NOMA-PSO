function report = runV10CComparison(profile,seeds,presets)
%RUNV10CCOMPARISON Explicit C0..C5 experiment with a common data/QoS setup.
% Equal particle/iteration budgets, fresh RNG, no cross-preset warm start.
    if nargin<1, profile='quick'; end
    if nargin<2, seeds=[2026,608060,3486784401]; end
    if nargin<3, presets=0:5; end
    validateattributes(seeds,{'numeric'},{'real','finite','vector','integer','nonnegative'});
    validateattributes(presets,{'numeric'},{'real','finite','vector','integer','>=',0,'<=',5});
    cfg=v10cConfig('C4',profile);
    parent=fullfile(cfg.output.root,'comparisons');
    if ~isfolder(parent)
        [ok,msg]=mkdir(parent);
        if ~ok, error('V10C:OutputFolder','%s',msg); end
    end
    report.outputFolder=tempname(parent);
    [ok,msg]=mkdir(report.outputFolder);
    if ~ok, error('V10C:OutputFolder','%s',msg); end
    report.seeds=seeds; report.presets=presets; report.profile=profile;
    report.runs=cell(numel(seeds),numel(presets)); rows=struct([]); row=0;
    for i=1:numel(seeds)
        for j=1:numel(presets)
            k=presets(j);
            cfg=v10cConfig(sprintf('C%d',k),profile);
            cfg.random.mainSeed=seeds(i); cfg.output.makePlots=false;
            cfg.mission.minBitsPerUser=3e6;
            cfg.mission.minBitsPerUserPerSlot=5e3;
            if k==5, cfg.motion.allowExperimental=true; end
            fprintf('\nCAMPAIGN seed %.0f (%d/%d), C%d (%d/%d)\n', ...
                seeds(i),i,numel(seeds),k,j,numel(presets));
            d=runV10C(cfg); report.runs{i,j}=d;
            algorithms=fieldnames(d.searches);
            for a=1:numel(algorithms)
                row=row+1; s=d.searches.(algorithms{a}); r=s.result;
                rows(row).preset=cfg.preset;
                rows(row).seed=seeds(i);
                rows(row).algorithm=s.algorithm;
                rows(row).feasible=r.isFeasible;
                rows(row).computedEE=r.eeComputed;
                rows(row).feasibleEE=NaN;
                if r.isFeasible, rows(row).feasibleEE=r.eeComputed; end
                rows(row).bits=r.totalBits;
                rows(row).energyJ=r.totalEnergy;
                rows(row).distanceM=r.totalDistance;
                rows(row).hoverSeconds=r.totalHoverTime;
                rows(row).serviceVisits=r.numServiceVisits;
                rows(row).evaluations=s.numEvaluations;
                rows(row).dimension=s.dimension;
                rows(row).folder=d.outputFolder;
                rows(row).energyModel=r.energyModelStatus;
            end
            report.summary=struct2table(rows);
            writetable(report.summary,fullfile(report.outputFolder,'comparison.csv'));
            save(fullfile(report.outputFolder,'comparison.mat'),'report','-v7.3');
        end
    end
    report.summary=struct2table(rows); disp(report.summary);
    writetable(report.summary,fullfile(report.outputFolder,'comparison.csv'));
    save(fullfile(report.outputFolder,'comparison.mat'),'report','-v7.3');
    fprintf('V10C comparison saved: %s\n',report.outputFolder);
end
