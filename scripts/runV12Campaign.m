function campaign = runV12Campaign(opts)
%RUNV12CAMPAIGN Multi-seed, multi-config campaign for V12A and V12B.
%
%   campaign = runV12Campaign();                  % quick: 1000 iter, 120 particles
%   campaign = runV12Campaign(struct('profile','full')); % 3000 iter, 120 particles
%   campaign = runV12Campaign(struct('variants',{{'A'}},'groups',{{'hover'}}));

    if nargin < 1 || isempty(opts)
        opts = struct();
    end
    if ~isstruct(opts)
        error('runV12Campaign:Options', 'opts must be a struct.');
    end
    projectRoot = fileparts(fileparts(mfilename('fullpath')));
    addpath(projectRoot);
    setup_project();

    base = v12Config();
    seeds = getOpt(opts, 'seeds', [2026, 608060, 3486784401]);
    variants = getOpt(opts, 'variants', {'A', 'B'});
    groups = getOpt(opts, 'groups', {'L', 'slot', 'hover'});
    if ischar(variants), variants = {variants}; end
    if ischar(groups), groups = {groups}; end

    profile = lower(getOpt(opts, 'profile', 'quick'));
    switch profile
        case 'quick'
            profileIter = 1000;
        case 'full'
            profileIter = 3000;
        otherwise
            error('runV12Campaign:Profile', ...
                'profile must be ''quick'' or ''full''.');
    end
    maxIter = getOpt(opts, 'maxIter', profileIter);
    validateattributes(maxIter, {'numeric'}, ...
        {'scalar', 'finite', 'integer', 'positive'});
    numParticles = getOpt(opts, 'numParticles', 120);
    validateattributes(numParticles, {'numeric'}, ...
        {'scalar', 'finite', 'integer', 'positive'});
    makePlots = getOpt(opts, 'makePlots', false);
    saveResults = getOpt(opts, 'saveResults', true);
    dryRun = getOpt(opts, 'dryRun', false);

    seedMode = lower(char(getOpt(opts, 'seedMode', base.optimizers.seedMode)));
    if ~any(strcmp(seedMode, {'per-scenario', 'fixed'}))
        error('runV12Campaign:SeedMode', ...
            'seedMode must be ''per-scenario'' or ''fixed''.');
    end
    phiMax = getOpt(opts, 'phiMax', base.radio.phiMax);
    polishJoint = logical(getOpt(opts, 'polishJoint', base.optimizers.polishJoint));
    initMode = lower(char(getOpt(opts, 'initMode', base.optimizers.initMode)));
    updateMode = lower(char(getOpt(opts, 'updateMode', base.optimizers.updateMode)));
    mutationMode = lower(char(getOpt(opts, 'mutationMode', base.optimizers.mutationMode)));
    maxEvals = getOpt(opts, 'maxEvals', base.optimizers.maxEvals);
    incumbentOverride = getOpt(opts, 'incumbentMode', '');
    if ~isempty(maxEvals)
        validateattributes(maxEvals, {'numeric'}, {'scalar', 'real'});
        if ~isnan(maxEvals)
            validateattributes(maxEvals, {'numeric'}, {'nonnegative'});
        end
        base.optimizers.maxEvals = maxEvals;
    end

    baseL = getOpt(opts, 'baseL', 3e6);
    baseSlot = getOpt(opts, 'baseSlot', 5e3);
    baseHover = getOpt(opts, 'baseHover', 1);
    baseAccel = getOpt(opts, 'baseAccel', base.flight.acceleration);
    basePhiMode = getOpt(opts, 'basePhiMode', base.radio.powerSplitMode);
    baseMotion = getOpt(opts, 'baseMotion', base.flight.motionMode);
    baseCausal = getOpt(opts, 'baseCausal', base.radio.enforceUlDlCausality);
    optionVals = getOpt(opts, 'optionVals', [1, 2, 3, 4]);

    Lvals = getOpt(opts, 'Lvals', [1e6, 2e6, 3e6]);
    slotVals = getOpt(opts, 'slotVals', [0, 5e3, 10e3]);
    hoverVals = getOpt(opts, 'hoverVals', [1, 2, 3]);
    accelVals = getOpt(opts, 'accelVals', [2, 3, 5]);
    phiModes = getOpt(opts, 'phiModes', {'optimal-causal', 'fixed'});
    if ischar(phiModes), phiModes = {phiModes}; end

    base.radio.phiMax = phiMax;
    base.optimizers.seedMode = seedMode;
    base.optimizers.polishJoint = polishJoint;
    base.optimizers.alphaPolishSamplesPerUser = getOpt(opts, ...
        'alphaPolishSamplesPerUser', base.optimizers.alphaPolishSamplesPerUser);
    base.optimizers.alphaPolishMinimumSamples = getOpt(opts, ...
        'alphaPolishMinimumSamples', base.optimizers.alphaPolishMinimumSamples);
    base.optimizers.initMode = initMode;
    base.optimizers.updateMode = updateMode;
    base.optimizers.mutationMode = mutationMode;
    base.optimizers.joint.numParticles = numParticles;
    base.optimizers.full.numParticles = numParticles;
    base.optimizers.ipso.numParticles = numParticles;
    base.optimizers.joint.maxIter = maxIter;
    base.optimizers.full.maxIter = maxIter;
    base.optimizers.ipso.maxIter = maxIter;

    configs = buildConfigs(groups, baseL, baseSlot, baseHover, baseAccel, basePhiMode, ...
        baseMotion, baseCausal, Lvals, slotVals, hoverVals, accelVals, phiModes, optionVals, ...
        initMode, updateMode, mutationMode, incumbentOverride);
    nRuns = numel(variants) * numel(seeds) * numel(configs);

    fprintf('\n=== V12 campaign ===\n');
    fprintf('Variants : %s\n', strjoin(variants, ', '));
    fprintf('Seeds    : %s\n', sprintf('%.0f ', seeds));
    fprintf(['Settings : seedMode=%s | init/update/mutation=%s/%s/%s | ', ...
        'phiMax=%.6g | polishJoint=%d | maxEvals=%.0f\n'], ...
        seedMode, initMode, updateMode, mutationMode, phiMax, polishJoint, effectiveMaxEvals(maxEvals, numParticles, maxIter));
    fprintf('Profile  : %s | maxIter: %d | particles: %d | runs: %d | plots: %d | saveResults: %d\n', ...
        profile, maxIter, numParticles, nRuns, makePlots, saveResults);
    fprintf('Configs  :\n');
    for c = 1:numel(configs)
        fprintf(['  [%d] %-7s %-20s L=%.3g bit/user | slot=%.3g bit/user | ', ...
            'hover=%.3g s | %s a=%.3g m/s^2 | phi=%s causal=%d | %s/%s/%s | incumbent=%s\n'], ...
            c, configs(c).group, configs(c).label, configs(c).L, ...
            configs(c).slot, configs(c).hover, configs(c).motionMode, configs(c).accel, ...
            configs(c).phiMode, configs(c).causal, configs(c).initMode, ...
            configs(c).updateMode, configs(c).mutationMode, configs(c).incumbentMode);
    end
    fprintf(['WARNING: %d runs x %d iterations x %d particles; ' ...
        'this can take many hours or days.\n'], nRuns, maxIter, numParticles);
    if makePlots && nRuns > 10
        warning('runV12Campaign:ManyFigures', ...
            'makePlots=true for %d runs will create many figures; consider false.', nRuns);
    end

    if dryRun
        campaign = struct();
        campaign.results = table();
        campaign.configs = configs;
        campaign.seeds = seeds;
        campaign.variants = variants;
        campaign.groups = groups;
        campaign.profile = profile;
        campaign.maxIter = maxIter;
        campaign.numParticles = numParticles;
        campaign.baseConfig = base;
        campaign.outputFolder = '';
        campaign.opts = opts;
        return;
    end

    stamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
    outputRoot = char(getOpt(opts, 'outputRoot', base.output.root));
    out = fullfile(outputRoot, ['campaign_', stamp]);
    suffix = 1;
    while exist(out, 'dir')
        out = fullfile(outputRoot, sprintf('campaign_%s_%d', stamp, suffix));
        suffix = suffix + 1;
    end
    [ok, msg] = mkdir(out);
    if ~ok
        error('runV12Campaign:Output', 'Cannot create %s: %s', out, msg);
    end

    template = struct( ...
        'variant', '', 'seed', 0, 'algorithmSeed', 0, 'polishSeed', 0, ...
        'group', '', 'config', '', 'algorithm', '', 'solverArm', '', ...
        'initMode', '', 'updateMode', '', 'mutationMode', '', 'incumbentMode', '', ...
        'L', NaN, 'motionMode', '', 'accel', NaN, 'phiMode', '', 'causal', 0, ...
        'ee', NaN, 'feasible', 0, ...
        'qosL', 0, 'qosSlot', 0, 'qosUserSlot', 0, 'qosUlDl', 0, ...
        'qosEnergy', 0, 'qosGeometry', 0, ...
        'bits', NaN, 'energyJ', NaN, 'flightEnergy', NaN, 'hoverEnergy', NaN, ...
        'rfEnergy', NaN, 'distance', NaN, 'missionTime', NaN, ...
        'minBitsPerSlot', NaN, 'maxBitsPerSlot', NaN, ...
        'slotsBelow', 0, 'userSlotsBelow', 0, ...
        'alphaMax', NaN, 'alphaMean', NaN, 'meanPhi', NaN, 'jain', NaN, ...
        'minUserBits', NaN, 'maxUserBits', NaN, ...
        'evalCount', NaN, 'eeRaw', NaN, 'feasibleRaw', NaN, 'evalCountRaw', NaN, ...
        'eePolished', NaN, 'feasiblePolished', NaN, 'evalCountPolished', NaN, ...
        'incumbentUsed', 0, 'incumbentRetained', 0, 'incumbentEE', NaN, ...
        'incumbentFeasible', NaN, 'incumbentSource', '', ...
        'evalCountIncumbentRaw', NaN, 'evalCountIncumbentPolish', NaN, ...
        'evalCountCumulative', NaN, 'evalCountSource', NaN, 'sourceCostComplete', NaN, ...
        'folder', '', 'error', '');
    template = template(1);
    rows = repmat(template, 0, 1);

    runIndex = 0;
    tStart = tic;
    for v = 1:numel(variants)
        for s = 1:numel(seeds)
            pool = emptyIncumbentPool();
            for c = 1:numel(configs)
                runIndex = runIndex + 1;
                cfg = base;
                cfg.random.mainSeed = seeds(s);
                if strcmpi(seedMode, 'per-scenario')
                    [cfg.random.algorithmSeed, cfg.random.polishSeed] = ...
                        deriveV12OptimizerSeeds(seeds(s));
                end
                cfg.mission.minBitsPerUser = configs(c).L;
                cfg.mission.minBitsPerSlot = 0;
                cfg.mission.minBitsPerUserPerSlot = configs(c).slot;
                cfg.mission.hoverTime = configs(c).hover;
                cfg.flight.acceleration = configs(c).accel;
                cfg.flight.motionMode = configs(c).motionMode;
                cfg.radio.powerSplitMode = configs(c).phiMode;
                cfg.radio.enforceUlDlCausality = configs(c).causal;
                cfg.optimizers.initMode = configs(c).initMode;
                cfg.optimizers.updateMode = configs(c).updateMode;
                cfg.optimizers.mutationMode = configs(c).mutationMode;
                cfg.optimizers.incumbentMode = configs(c).incumbentMode;
                % Unique stage namespace for source-cost lineage across the campaign.
                cfg.optimizers.runTag = sprintf('run%04d|V12%s|seed=%.0f|%s|%s', ...
                    runIndex, variants{v}, seeds(s), configs(c).group, configs(c).label);
                cfg.output.makePlots = makePlots;
                cfg.output.saveFigures = makePlots;
                cfg.output.saveResults = saveResults;

                fprintf('\n[%d/%d] V12%s seed=%.0f (algo=%.0f, polish=%.0f) %s (%.1f s elapsed)\n', ...
                    runIndex, nRuns, variants{v}, seeds(s), ...
                    cfg.random.algorithmSeed, cfg.random.polishSeed, ...
                    configs(c).label, toc(tStart));
                try
                    data = runV12(variants{v}, cfg, pool);
                    newRows = summarizeRun(variants{v}, seeds(s), configs(c), ...
                        data, template);
                    pool = appendRunToPool(pool, data, configs(c), variants{v}, seeds(s));
                    rows = [rows; newRows(:)]; %#ok<AGROW>
                catch err
                    warning('runV12Campaign:RunFailed', ...
                        'Run failed: V12%s seed=%.0f %s: %s', ...
                        variants{v}, seeds(s), configs(c).label, err.message);
                    newRows = errorRows(variants{v}, seeds(s), ...
                        cfg.random.algorithmSeed, cfg.random.polishSeed, ...
                        configs(c), err.message, template);
                    rows = [rows; newRows(:)]; %#ok<AGROW>
                end

                rows = rows(:);
                T = struct2table(rows);
                save(fullfile(out, 'campaign.mat'), 'T', 'configs', 'seeds', ...
                    'variants', 'groups', 'profile', 'maxIter', 'numParticles', 'opts', '-v7.3');
                writetable(T, fullfile(out, 'campaign_summary.csv'));
            end
        end
    end

    rows = rows(:);
    T = struct2table(rows);
    campaign = struct();
    campaign.results = T;
    campaign.configs = configs;
    campaign.seeds = seeds;
    campaign.variants = variants;
    campaign.groups = groups;
    campaign.profile = profile;
    campaign.maxIter = maxIter;
    campaign.numParticles = numParticles;
    campaign.outputFolder = out;
    campaign.opts = opts;
    save(fullfile(out, 'campaign.mat'), 'campaign', '-v7.3');
    writetable(T, fullfile(out, 'campaign_summary.csv'));

    fprintf('\n=== Campaign complete: %d runs, %d rows, %.1f s ===\n', ...
        nRuns, height(T), toc(tStart));
    fprintf('Summary: %s\n', fullfile(out, 'campaign_summary.csv'));
    feasible = T(T.feasible == 1, :);
    if ~isempty(feasible)
        [~, ord] = sort(feasible.ee, 'descend');
        disp(feasible(ord(1:min(10, numel(ord))), :));
    else
        fprintf('No feasible row in this campaign.\n');
    end
end

function configs = buildConfigs(groups, baseL, baseSlot, baseHover, baseAccel, basePhiMode, ...
        baseMotion, baseCausal, Lvals, slotVals, hoverVals, accelVals, phiModes, optionVals, ...
        initMode, updateMode, mutationMode, incumbentOverride)
    b = mkConfig('base', 'base', baseL, baseSlot, baseHover, baseAccel, basePhiMode, ...
        baseMotion, baseCausal);
    b = setSolver(b, initMode, updateMode, mutationMode);
    configs = repmat(b, 0, 1);
    Ldescending = sort(reshape(Lvals, 1, []), 2, 'descend');
    for g = 1:numel(groups)
        first = numel(configs) + 1;
        switch lower(groups{g})
            case 'l'
                for x = Ldescending
                    c = b; c.group = 'L'; c.label = sprintf('L=%.3gM', x/1e6); c.L = x;
                    configs(end+1) = c; %#ok<AGROW>
                end
            case 'slot'
                for x = slotVals(:).'
                    c = b; c.group = 'slot'; c.label = sprintf('slot=%.3gk', x/1e3); c.slot = x;
                    configs(end+1) = c; %#ok<AGROW>
                end
            case 'hover'
                for x = hoverVals(:).'
                    c = b; c.group = 'hover'; c.label = sprintf('hover=%.3gs', x); c.hover = x;
                    configs(end+1) = c; %#ok<AGROW>
                end
            case 'accel'
                for x = accelVals(:).'
                    c = b; c.group = 'accel'; c.label = sprintf('a=%.3g', x); c.accel = x;
                    configs(end+1) = c; %#ok<AGROW>
                end
            case {'phi', 'phimode'}
                for k = 1:numel(phiModes)
                    c = b; c.group = 'phi'; c.phiMode = char(phiModes{k});
                    c.label = sprintf('phi=%s', c.phiMode);
                    configs(end+1) = c; %#ok<AGROW>
                end
            case 'option'
                % One frozen solver across O1-O4; descending L order only matters for
                % an explicit warm-start branch (incumbentMode='crossModel').
                for o = optionVals(:).'
                    for x = Ldescending
                        c = b; c.group = sprintf('opt%d', o); c.L = x;
                        c.label = sprintf('O%d_L=%.3gM', o, x/1e6);
                        switch o
                            case 1
                                c.motionMode = 'steady-cruise'; c.phiMode = 'fixed'; c.causal = false;
                            case 2
                                c.motionMode = 'steady-cruise'; c.phiMode = 'optimal-causal'; c.causal = true;
                            case 3
                                c.motionMode = 'quasi-steady-accel'; c.phiMode = 'fixed'; c.causal = false;
                            case 4
                                c.motionMode = 'quasi-steady-accel'; c.phiMode = 'optimal-causal'; c.causal = true;
                            otherwise
                                error('runV12Campaign:Option', 'optionVals must be in 1..4.');
                        end
                        configs(end+1) = c; %#ok<AGROW>
                    end
                end
            case 'solver'
                % Separate solver ablation at one common physical scenario.
                arms = {'S1', 'v10', 'independent', 'elementwise'; ...
                        'S2', 'clustered', 'independent', 'elementwise'; ...
                        'S3', 'v10', 'correlated', 'elementwise'; ...
                        'S4', 'clustered', 'correlated', 'elementwise'; ...
                        'S5', 'clustered', 'correlated', 'block'};
                for a = 1:size(arms, 1)
                    c = setSolver(b, arms{a, 2}, arms{a, 3}, arms{a, 4});
                    c.group = 'solver';
                    c.label = sprintf('%s_%s', arms{a, 1}, c.solverArm);
                    configs(end+1) = c; %#ok<AGROW>
                end
            otherwise
                error('runV12Campaign:Group', ...
                    'Unknown group %s. Use L, slot, hover, accel, phi, option or solver.', groups{g});
        end
        incumbentMode = resolveIncumbentMode(incumbentOverride);
        for k = first:numel(configs)
            configs(k).incumbentMode = incumbentMode;
        end
    end
    if isempty(configs)
        b.incumbentMode = resolveIncumbentMode(incumbentOverride);
        configs = b;
    end
end

function c = setSolver(c, initMode, updateMode, mutationMode)
    c.initMode = lower(char(initMode));
    c.updateMode = lower(char(updateMode));
    c.mutationMode = lower(char(mutationMode));
    if strcmp(c.initMode, 'v10')
        initLabel = 'v10';
    else
        initLabel = 'clust';
    end
    if strcmp(c.updateMode, 'independent')
        updateLabel = 'ind';
    else
        updateLabel = 'corr';
    end
    if strcmp(c.mutationMode, 'elementwise')
        mutationLabel = 'ep';
    else
        mutationLabel = 'blk';
    end
    c.solverArm = sprintf('%s_%s_%s', initLabel, updateLabel, mutationLabel);
    c.solverKey = sprintf('%s|%s|%s', c.initMode, c.updateMode, c.mutationMode);
    c.incumbentMode = 'none';
end

function mode = resolveIncumbentMode(override)
    if ~isempty(override)
        switch lower(char(override))
            case {'none', 'jointtofull', 'lcontinuation', 'crossmodel'}
                mode = lower(char(override));
            otherwise
                error('runV12Campaign:IncumbentMode', ...
                    'incumbentMode must be none, jointToFull, LContinuation or crossModel.');
        end
        switch mode
            case 'jointtofull', mode = 'jointToFull';
            case 'lcontinuation', mode = 'LContinuation';
            case 'crossmodel', mode = 'crossModel';
        end
    else
        % Equal-budget control by default: no inherited incumbents for any group.
        % Warm start must be requested explicitly and is reported with its
        % cumulative source cost (evalCountCumulative / evalCountSource).
        mode = 'none';
    end
end

function c = mkConfig(group, label, L, slot, hover, accel, phiMode, motionMode, causal)
    c = struct('group', group, 'label', label, 'L', L, 'slot', slot, ...
        'hover', hover, 'accel', accel, 'phiMode', char(phiMode), ...
        'motionMode', char(motionMode), 'causal', logical(causal), ...
        'solverArm', '', 'solverKey', '', 'initMode', '', 'updateMode', '', ...
        'mutationMode', '', 'incumbentMode', 'none');
end

function rows = summarizeRun(variant, seed, cfgSpec, data, template)
    names = {'Baseline', 'Joint PSO', 'Full PSO', 'Full IPSO'};
    results = {data.resBase, data.trajJoint, data.trajFull, data.trajIPSO};
    rawResults = {data.resBase, data.trajJointRaw, data.trajFullRaw, data.trajIPSORaw};
    polResults = {[], data.trajJointPolished, data.trajFull, data.trajIPSO};
    rows = repmat(template, numel(results), 1);
    for k = 1:numel(results)
        r = results{k};
        rRaw = rawResults{k};
        rPol = polResults{k};
        row = template;
        row.variant = variant;
        row.seed = seed;
        row.algorithmSeed = data.cfg.random.algorithmSeed;
        row.polishSeed = data.cfg.random.polishSeed;
        row.group = cfgSpec.group;
        row.config = cfgSpec.label;
        row.algorithm = names{k};
        row.solverArm = cfgSpec.solverArm;
        row.initMode = data.sim.initMode;
        row.updateMode = data.sim.updateMode;
        row.mutationMode = data.sim.mutationMode;
        row.incumbentMode = data.sim.incumbentMode;
        row.L = cfgSpec.L;
        row.motionMode = cfgSpec.motionMode;
        row.accel = cfgSpec.accel;
        row.phiMode = cfgSpec.phiMode;
        row.causal = double(cfgSpec.causal);
        row.ee = r.eeComputed;
        row.feasible = double(r.isFeasible);
        row.qosL = double(r.missionQoSFeasible);
        row.qosSlot = double(r.slotQoSFeasible);
        row.qosUserSlot = double(r.userSlotQoSFeasible);
        if isfield(r, 'ulDlFeasible')
            row.qosUlDl = double(r.ulDlFeasible);
        end
        row.qosEnergy = double(r.energyFeasible);
        row.qosGeometry = double(r.geometryFeasible);
        row.bits = r.totalBits;
        row.energyJ = r.totalEnergy;
        row.flightEnergy = r.flightEnergy;
        row.hoverEnergy = r.hoverEnergy;
        row.rfEnergy = r.rfEnergy;
        row.distance = r.totalDistance;
        row.missionTime = r.missionTime;
        row.minBitsPerSlot = r.slotBitsMin;
        row.maxBitsPerSlot = r.slotBitsMax;
        row.slotsBelow = r.numSlotsBelowMin;
        row.userSlotsBelow = r.numUserSlotsBelowMin;
        a = r.alphaTrace(r.slotIdx, :);
        row.alphaMax = max(a(:));
        row.alphaMean = mean(a(:));
        if isfield(r, 'meanPhi')
            row.meanPhi = r.meanPhi;
        end
        b = r.totalBitsPerUser;
        row.jain = (sum(b)^2) / (numel(b) * sum(b.^2) + eps);
        row.minUserBits = min(b);
        row.maxUserBits = max(b);
        if isfield(r, 'evalCount') && ~isempty(r.evalCount)
            row.evalCount = r.evalCount;
        end
        row.eeRaw = rRaw.eeComputed;
        row.feasibleRaw = double(rRaw.isFeasible);
        if isfield(rRaw, 'evalCount') && ~isempty(rRaw.evalCount)
            row.evalCountRaw = rRaw.evalCount;
        end
        if k > 1 && isfield(rRaw, 'evalCountIncumbentRaw')
            row.evalCountIncumbentRaw = rRaw.evalCountIncumbentRaw;
        end
        row.incumbentUsed = double(isfield(r, 'incumbentUsed') && logical(r.incumbentUsed));
        row.incumbentRetained = double(isfield(r, 'incumbentRetained') && logical(r.incumbentRetained));
        if isfield(r, 'incumbentEE')
            row.incumbentEE = r.incumbentEE;
            row.incumbentFeasible = r.incumbentFeasible;
            row.incumbentSource = r.incumbentSource;
        end
        % Cumulative cost = this stage + every distinct ancestor stage that produced
        % a screened incumbent (shared ancestors counted once). Equal to evalCount
        % when incumbentMode='none'.
        if isfield(r, 'evalCountCumulative')
            row.evalCountCumulative = r.evalCountCumulative;
            row.evalCountSource = r.evalCountSource;
            row.sourceCostComplete = double(r.sourceCostComplete);
        end
        if isempty(rPol)
            % Baseline has no alpha-polishing stage.
            row.eePolished = rRaw.eeComputed;
            row.feasiblePolished = double(rRaw.isFeasible);
            row.evalCountPolished = NaN;
        else
            row.eePolished = rPol.eeComputed;
            row.feasiblePolished = double(rPol.isFeasible);
            if isfield(rPol, 'evalCount') && ~isempty(rPol.evalCount)
                row.evalCountPolished = rPol.evalCount;
            end
            if isfield(rPol, 'evalCountIncumbentPolish')
                row.evalCountIncumbentPolish = rPol.evalCountIncumbentPolish;
            end
        end
        row.folder = data.outputFolder;
        rows(k) = row;
    end
end

function rows = errorRows(variant, seed, algoSeed, polSeed, cfgSpec, message, template)
    names = {'Baseline', 'Joint PSO', 'Full PSO', 'Full IPSO'};
    rows = repmat(template, numel(names), 1);
    for k = 1:numel(names)
        row = template;
        row.variant = variant;
        row.seed = seed;
        row.algorithmSeed = algoSeed;
        row.polishSeed = polSeed;
        row.group = cfgSpec.group;
        row.config = cfgSpec.label;
        row.algorithm = names{k};
        row.solverArm = cfgSpec.solverArm;
        row.initMode = cfgSpec.initMode;
        row.updateMode = cfgSpec.updateMode;
        row.mutationMode = cfgSpec.mutationMode;
        row.incumbentMode = cfgSpec.incumbentMode;
        row.L = cfgSpec.L;
        row.motionMode = cfgSpec.motionMode;
        row.accel = cfgSpec.accel;
        row.phiMode = cfgSpec.phiMode;
        row.causal = double(cfgSpec.causal);
        row.error = message;
        rows(k) = row;
    end
end

function pool = emptyIncumbentPool()
    e = emptyPoolEntry();
    pool = struct('raw', repmat(e, 0, 1), 'polished', repmat(e, 0, 1));
end

function e = emptyPoolEntry()
    e = struct('algorithm', '', 'particle', [], 'source', '', ...
        'variant', '', 'seed', 0, 'L', NaN, 'slot', NaN, 'hover', NaN, ...
        'motionMode', '', 'accel', NaN, 'phiMode', '', 'phiMax', NaN, ...
        'causal', false, 'solverKey', '', 'lineage', struct('keys', {cell(1, 0)}, ...
        'evals', zeros(1, 0), 'complete', true));
end

function pool = appendRunToPool(pool, data, cfgSpec, variant, seed)
    algorithm = {'Joint PSO', 'Full PSO', 'Full IPSO'};
    rawResults = {data.trajJointRaw, data.trajFullRaw, data.trajIPSORaw};
    polishedResults = {data.trajJointPolished, data.trajFull, data.trajIPSO};
    stages = {'raw', 'polished'};
    stageResults = {rawResults, polishedResults};
    for stage = 1:numel(stages)
        results = stageResults{stage};
        entries = pool.(stages{stage});
        for k = 1:numel(algorithm)
            r = results{k};
            e = emptyPoolEntry();
            e.algorithm = algorithm{k};
            e.particle = r.bestParticle;
            e.source = sprintf('%s/%s/%s/seed=%.0f/%s', variant, ...
                cfgSpec.group, cfgSpec.label, seed, stages{stage});
            e.variant = variant;
            e.seed = seed;
            e.L = cfgSpec.L;
            e.slot = cfgSpec.slot;
            e.hover = cfgSpec.hover;
            e.motionMode = cfgSpec.motionMode;
            e.accel = cfgSpec.accel;
            e.phiMode = cfgSpec.phiMode;
            e.phiMax = data.sim.radio.phiMax;
            e.causal = data.sim.radio.enforceUlDlCausality;
            e.solverKey = sprintf('%s|%s|%s', data.sim.initMode, ...
                data.sim.updateMode, data.sim.mutationMode);
            if isfield(r, 'lineage') && isstruct(r.lineage)
                e.lineage = r.lineage;
            else
                e.lineage.complete = false;
            end
            entries(end+1, 1) = e; %#ok<AGROW>
        end
        pool.(stages{stage}) = entries;
    end
end

function cap = effectiveMaxEvals(maxEvals, numParticles, maxIter)
    if isempty(maxEvals) || isnan(maxEvals) || (isinf(maxEvals) && maxEvals > 0)
        cap = maxEvals;
        if isempty(cap) || isnan(cap)
            cap = double(numParticles) * (double(maxIter) + 1);
        end
    else
        cap = maxEvals;
    end
end

function value = getOpt(opts, name, default)
    if isfield(opts, name) && ~isempty(opts.(name))
        value = opts.(name);
    else
        value = default;
    end
end
