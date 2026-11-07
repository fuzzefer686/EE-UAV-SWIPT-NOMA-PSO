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
    numParticles = 120;
    makePlots = getOpt(opts, 'makePlots', false);
    saveResults = getOpt(opts, 'saveResults', true);
    dryRun = getOpt(opts, 'dryRun', false);

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

    base.optimizers.joint.numParticles = numParticles;
    base.optimizers.full.numParticles = numParticles;
    base.optimizers.ipso.numParticles = numParticles;
    base.optimizers.joint.maxIter = maxIter;
    base.optimizers.full.maxIter = maxIter;
    base.optimizers.ipso.maxIter = maxIter;

    configs = buildConfigs(groups, baseL, baseSlot, baseHover, baseAccel, basePhiMode, ...
        baseMotion, baseCausal, Lvals, slotVals, hoverVals, accelVals, phiModes, optionVals);
    nRuns = numel(variants) * numel(seeds) * numel(configs);

    fprintf('\n=== V12 campaign ===\n');
    fprintf('Variants : %s\n', strjoin(variants, ', '));
    fprintf('Seeds    : %s\n', sprintf('%.0f ', seeds));
    fprintf('Profile  : %s | maxIter: %d | particles: %d | runs: %d | plots: %d | saveResults: %d\n', ...
        profile, maxIter, numParticles, nRuns, makePlots, saveResults);
    fprintf('Configs  :\n');
    for c = 1:numel(configs)
        fprintf('  [%d] %-6s %-14s L=%.3g bit/user | slot=%.3g bit/user | hover=%.3g s | %s a=%.3g m/s^2 | phi=%s causal=%d\n', ...
            c, configs(c).group, configs(c).label, configs(c).L, ...
            configs(c).slot, configs(c).hover, configs(c).motionMode, configs(c).accel, ...
            configs(c).phiMode, configs(c).causal);
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
        campaign.outputFolder = '';
        campaign.opts = opts;
        return;
    end

    stamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
    out = fullfile(base.output.root, ['campaign_', stamp]);
    [ok, msg] = mkdir(out);
    if ~ok
        error('runV12Campaign:Output', 'Cannot create %s: %s', out, msg);
    end

    template = struct( ...
        'variant', '', 'seed', 0, 'group', '', 'config', '', 'algorithm', '', ...
        'L', NaN, 'motionMode', '', 'accel', NaN, 'phiMode', '', 'causal', 0, ...
        'ee', NaN, 'feasible', 0, ...
        'qosL', 0, 'qosSlot', 0, 'qosUserSlot', 0, 'qosEnergy', 0, 'qosGeometry', 0, ...
        'bits', NaN, 'energyJ', NaN, 'flightEnergy', NaN, 'hoverEnergy', NaN, ...
        'rfEnergy', NaN, 'distance', NaN, 'missionTime', NaN, ...
        'minBitsPerSlot', NaN, 'maxBitsPerSlot', NaN, ...
        'slotsBelow', 0, 'userSlotsBelow', 0, ...
        'alphaMax', NaN, 'alphaMean', NaN, 'meanPhi', NaN, 'jain', NaN, ...
        'minUserBits', NaN, 'maxUserBits', NaN, ...
        'folder', '', 'error', '');
    template = template(1);
    rows = repmat(template, 0, 1);

    runIndex = 0;
    tStart = tic;
    for v = 1:numel(variants)
        for s = 1:numel(seeds)
            for c = 1:numel(configs)
                runIndex = runIndex + 1;
                cfg = base;
                cfg.random.mainSeed = seeds(s);
                cfg.mission.minBitsPerUser = configs(c).L;
                cfg.mission.minBitsPerSlot = 0;
                cfg.mission.minBitsPerUserPerSlot = configs(c).slot;
                cfg.mission.hoverTime = configs(c).hover;
                cfg.flight.acceleration = configs(c).accel;
                cfg.flight.motionMode = configs(c).motionMode;
                cfg.radio.powerSplitMode = configs(c).phiMode;
                cfg.radio.enforceUlDlCausality = configs(c).causal;
                cfg.output.makePlots = makePlots;
                cfg.output.saveFigures = makePlots;
                cfg.output.saveResults = saveResults;

                fprintf('\n[%d/%d] V12%s seed=%.0f %s (%.1f s elapsed)\n', ...
                    runIndex, nRuns, variants{v}, seeds(s), configs(c).label, toc(tStart));
                try
                    data = runV12(variants{v}, cfg);
                    newRows = summarizeRun(variants{v}, seeds(s), configs(c), ...
                        data, template);
                    rows = [rows; newRows(:)]; %#ok<AGROW>
                catch err
                    warning('runV12Campaign:RunFailed', ...
                        'Run failed: V12%s seed=%.0f %s: %s', ...
                        variants{v}, seeds(s), configs(c).label, err.message);
                    newRows = errorRows(variants{v}, seeds(s), configs(c), ...
                        err.message, template);
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
        baseMotion, baseCausal, Lvals, slotVals, hoverVals, accelVals, phiModes, optionVals)
    b = mkConfig('base', 'base', baseL, baseSlot, baseHover, baseAccel, basePhiMode, ...
        baseMotion, baseCausal);
    configs = repmat(b, 0, 1);
    for g = 1:numel(groups)
        switch lower(groups{g})
            case 'l'
                for x = Lvals(:).'
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
                % Ablation: Opt1 parity V10B, Opt2 causal DF, Opt3 accel, Opt4 full V12.
                for o = optionVals(:).'
                    for x = Lvals(:).'
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
            otherwise
                error('runV12Campaign:Group', ...
                    'Unknown group %s. Use L, slot, hover, accel, phi or option.', groups{g});
        end
    end
    if isempty(configs)
        configs = b;
    end
end

function c = mkConfig(group, label, L, slot, hover, accel, phiMode, motionMode, causal)
    c = struct('group', group, 'label', label, 'L', L, 'slot', slot, ...
        'hover', hover, 'accel', accel, 'phiMode', char(phiMode), ...
        'motionMode', char(motionMode), 'causal', logical(causal));
end

function rows = summarizeRun(variant, seed, cfgSpec, data, template)
    names = {'Baseline', 'Joint PSO', 'Full PSO', 'Full IPSO'};
    results = {data.resBase, data.trajJoint, data.trajFull, data.trajIPSO};
    rows = repmat(template, numel(results), 1);
    for k = 1:numel(results)
        r = results{k};
        row = template;
        row.variant = variant;
        row.seed = seed;
        row.group = cfgSpec.group;
        row.config = cfgSpec.label;
        row.algorithm = names{k};
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
        row.folder = data.outputFolder;
        rows(k) = row;
    end
end

function rows = errorRows(variant, seed, cfgSpec, message, template)
    names = {'Baseline', 'Joint PSO', 'Full PSO', 'Full IPSO'};
    rows = repmat(template, numel(names), 1);
    for k = 1:numel(names)
        row = template;
        row.variant = variant;
        row.seed = seed;
        row.group = cfgSpec.group;
        row.config = cfgSpec.label;
        row.algorithm = names{k};
        row.L = cfgSpec.L;
        row.motionMode = cfgSpec.motionMode;
        row.accel = cfgSpec.accel;
        row.phiMode = cfgSpec.phiMode;
        row.causal = double(cfgSpec.causal);
        row.error = message;
        rows(k) = row;
    end
end

function value = getOpt(opts, name, default)
    if isfield(opts, name) && ~isempty(opts.(name))
        value = opts.(name);
    else
        value = default;
    end
end
