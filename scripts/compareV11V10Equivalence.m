function report = compareV11V10Equivalence(variant, seed, Lbit, opts)
%COMPAREV11V10EQUIVALENCE Explicit V10/V11 comparison, never auto-started.
% Approved sole V11-script exception to the no-V10-call rule.
% Defaults use real 120/1000 budgets and unchanged random-polish sample counts.
% opts.dryRun inspects configurations without optimizers, directories or logs.
    if nargin<1, variant='B'; end
    if nargin<2, seed=2026; end
    if nargin<3, Lbit=3e6; end
    if nargin<4, opts=struct(); end
    variant=validatestring(upper(char(variant)),{'A','B'});
    validateattributes(seed,{'numeric'},{'real','finite','integer','scalar','>=',0,'<=',2^32-1});
    validateattributes(Lbit,{'numeric'},{'real','finite','nonnegative','vector','nonempty'});
    preset=getOpt(opts,'preset','particle_noma_random');
    cfg10=v10Config(); cfg11=v11AlphaPreset(preset);
    n=getOpt(opts,'numParticles',cfg11.optimizers.full.numParticles);
    iters=getOpt(opts,'maxIter',cfg11.optimizers.full.maxIter);
    validateattributes(n,{'numeric'},{'scalar','integer','positive','finite'});
    validateattributes(iters,{'numeric'},{'scalar','integer','nonnegative','finite'});
    if ~isscalar(Lbit) && numel(Lbit)~=cfg11.geometry.noUsers
        error('compareV11V10Equivalence:Target','Lbit must be scalar or one entry per user.');
    end
    names={'joint','full','ipso'};
    for k=1:3
        cfg10.optimizers.(names{k}).numParticles=n; cfg11.optimizers.(names{k}).numParticles=n;
        cfg10.optimizers.(names{k}).maxIter=iters; cfg11.optimizers.(names{k}).maxIter=iters;
    end
    cfg10.random.mainSeed=seed; cfg10.random.algorithmSeed=seed; cfg10.random.polishSeed=seed;
    cfg11.random=cfg10.random;
    cfg10.mission.minBitsPerUser=Lbit; cfg11.mission.minBitsPerUser=Lbit;
    cfg10.output.makePlots=false; cfg10.output.saveFigures=false; cfg10.output.saveResults=false;
    cfg11.output.makePlots=false; cfg11.output.saveFigures=false; cfg11.output.saveResults=false;
    geometryOnly=~strcmp(cfg11.alpha.presetName,'particle_noma_random');
    if geometryOnly
        warning('compareV11V10Equivalence:DifferentPreset', ...
            'Different mode/repair/solver: results need not match; comparing only geometry fields.');
    end
    dryRun=getOpt(opts,'dryRun',false);
    report=struct('allPass',[],'preset',cfg11.alpha.presetName,'variant',variant, ...
        'seed',seed,'Lbit',Lbit,'cfg10',cfg10,'cfg11',cfg11, ...
        'geometryOnly',geometryOnly,'dryRun',dryRun,'logFile','');
    if dryRun, return; end
    stamp=char(datetime('now','Format','yyyyMMdd_HHmmss_SSS'));
    folder=fullfile(cfg11.output.root,['verification_',stamp]); stem=folder; suffix=0;
    while exist(folder,'dir'), suffix=suffix+1; folder=sprintf('%s_%02d',stem,suffix); end
    [ok,message]=mkdir(folder);
    if ~ok, error('compareV11V10Equivalence:Output','%s',message); end
    report.logFile=fullfile(folder,'equivalence_full.log');
    fid=fopen(report.logFile,'w');
    if fid<0, error('compareV11V10Equivalence:Log','Cannot create equivalence log.'); end
    cleaner=onCleanup(@() fclose(fid));
    printBoth('V10/V11 comparison | variant=%s seed=%.0f preset=%s | particles=%d iterations=%d\n', ...
        variant,seed,cfg11.alpha.presetName,n,iters);
    printBoth('Lbit=%s | threshold absolute <=1e-12 | geometryOnly=%d\n',mat2str(Lbit),geometryOnly);
    printBoth('Polish samples/slot: %d (V10) / %d (V11)\n', ...
        max(cfg10.optimizers.alphaPolishMinimumSamples,cfg10.optimizers.alphaPolishSamplesPerUser*cfg10.geometry.noUsers), ...
        max(cfg11.optimizers.alphaPolishMinimumSamples,cfg11.optimizers.alphaPolishSamplesPerUser*cfg11.geometry.noUsers));
    % Nested printBoth makes this a static workspace: predeclare evalc outputs.
    data10=[]; data11=[];
    timer=tic; transcript=evalc('data10=runV10(variant,cfg10);'); report.secondsV10=toc(timer); printBoth('%s',transcript);
    timer=tic; transcript=evalc('data11=runV11(variant,cfg11);'); report.secondsV11=toc(timer); printBoth('%s',transcript);
    algorithms={'trajFull','trajIPSO','trajJoint'}; % trajIPSOP in the task refers to the existing trajIPSO field.
    fields={'bestFitness','bestParticle','totalBits','eeUAV','totalEnergy','rfEnergy', ...
        'achRate','alphaTrace','pt','isFeasible'};
    if geometryOnly, fields={'xTraj','yTraj','zTraj','xBS','yBS','zBS'}; end
    algorithmColumn={}; fieldColumn={}; maxAbsDiff=[]; relDiff=[]; passColumn=false(0,1); details={};
    for a=1:numel(algorithms)
        printBoth('\n%s\nfield | maxAbsDiff | relDiff | PASS/FAIL\n',algorithms{a});
        for f=1:numel(fields)
            x=double(data10.(algorithms{a}).(fields{f})); y=double(data11.(algorithms{a}).(fields{f}));
            detail=''; absolute=Inf; relative=Inf;
            if ~isequal(size(x),size(y))
                detail='size mismatch';
            elseif any(~isfinite(x(:))) || any(~isfinite(y(:)))
                detail='nonfinite value';
            elseif isempty(x)
                absolute=0; relative=0;
            else
                absolute=max(abs(x(:)-y(:)));
                relative=absolute/max([abs(x(:));abs(y(:));realmin]);
            end
            passed=absolute<=1e-12; label='FAIL'; if passed, label='PASS'; end
            printBoth('%s | %.16g | %.16g | %s %s\n',fields{f},absolute,relative,label,detail);
            algorithmColumn{end+1,1}=algorithms{a}; fieldColumn{end+1,1}=fields{f};
            maxAbsDiff(end+1,1)=absolute; relDiff(end+1,1)=relative;
            passColumn(end+1,1)=passed; details{end+1,1}=detail;
        end
    end
    report.comparisons=table(algorithmColumn,fieldColumn,maxAbsDiff,relDiff,passColumn,details, ...
        'VariableNames',{'algorithm','field','maxAbsDiff','relDiff','pass','detail'});
    report.allPass=all(passColumn);
    printBoth('\nallPass=%d | %d/%d fields | V10 %.6f s | V11 %.6f s\n', ...
        report.allPass,sum(passColumn),numel(passColumn),report.secondsV10,report.secondsV11);
    printBoth('Log: %s\n',report.logFile);

    function printBoth(varargin)
        fprintf(1,varargin{:}); fprintf(fid,varargin{:});
    end
end

function value = getOpt(opts,name,fallback)
    if isfield(opts,name) && ~isempty(opts.(name)), value=opts.(name); else, value=fallback; end
end
