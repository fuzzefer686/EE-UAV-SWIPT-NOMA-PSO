function campaign = runV10Campaign(opts)
%RUNV10CAMPAIGN Multi-seed, multi-config campaign for V10A and V10B.
%
%   campaign = runV10Campaign();                  % Joint 1000, Full PSO 2000, IPSO 5000
%   campaign = runV10Campaign(struct('profile','quick')); % 1000 for all (smoke test)
%   campaign = runV10Campaign(struct('variants',{{'A'}},'groups',{{'hover'}}));
%
% Default matrix: 3 seeds x 3 configs per group (L, per-user slot QoS, hover).
% The three groups share the base point (L=3 Mbit, q=5 kbit, hover 1 s), so the
% raw list has 9 labels but only 7 unique parameter sets. buildConfigs keeps the
% first label and records the merged aliases; duplicates are never re-run.
% V10A and V10B use the same configuration and the same evaluators; only the
% Y geometry differs. Algorithm/polishing seeds are kept fixed so that all
% variants and configurations are compared on the same random stream.
%
% The table stores the computed EE even for infeasible particles, together
% with the L / slot / user-slot / energy / geometry flags. The internal PSO
% score is not written to the console or the summary.

    if nargin < 1 || isempty(opts)
        opts = struct();
    end
    if ~isstruct(opts)
        error('runV10Campaign:Options', 'opts must be a struct.');
    end
    projectRoot = fileparts(fileparts(mfilename('fullpath')));
    addpath(projectRoot);
    setup_project();

    base = v10Config();
    seeds = getOpt(opts, 'seeds', [2026, 608060, 3486784401]);
    variants = getOpt(opts, 'variants', {'A', 'B'});
    groups = getOpt(opts, 'groups', {'L', 'slot', 'hover'});
    if ischar(variants), variants = {variants}; end
    if ischar(groups), groups = {groups}; end
    algorithms = getOpt(opts, 'algorithms', ...
        {'Baseline', 'Joint PSO', 'Full PSO', 'Full IPSO'});
    if ischar(algorithms), algorithms = {algorithms}; end
    knownAlgorithms = {'Baseline', 'Joint PSO', 'Full PSO', 'Full IPSO'};
    if ~all(ismember(algorithms, knownAlgorithms))
        error('runV10Campaign:Algorithms', ...
            'algorithms must be a subset of Baseline / Joint PSO / Full PSO / Full IPSO.');
    end
    solvers = setdiff(algorithms, {'Baseline'}, 'stable');

    % Production budget is asymmetric: Joint PSO and Full PSO run 1000
    % iterations, Full IPSO runs 5000. 'quick' keeps 1000 for all three and is
    % only a smoke test. JointIter/FullIter/IpsoIter override one optimizer;
    % maxIter overrides all three (legacy uniform setting).
    profile = lower(getOpt(opts, 'profile', 'full'));
    switch profile
        case {'full', 'production'}
            iterJoint = 1000;
            iterFull = 2000;
            iterIPSO = 5000;
        case 'quick'
            iterJoint = 1000;
            iterFull = 1000;
            iterIPSO = 1000;
        otherwise
            error('runV10Campaign:Profile', ...
                'profile must be ''full'' (asymmetric) or ''quick'' (uniform 1000).');
    end
    iterJoint = getOpt(opts, 'jointIter', iterJoint);
    iterFull = getOpt(opts, 'fullIter', iterFull);
    iterIPSO = getOpt(opts, 'ipsoIter', iterIPSO);
    if isfield(opts, 'maxIter') && ~isempty(opts.maxIter)
        iterJoint = opts.maxIter;
        iterFull = opts.maxIter;
        iterIPSO = opts.maxIter;
    end
    iterJoint = validateIter(iterJoint, 'jointIter');
    iterFull = validateIter(iterFull, 'fullIter');
    iterIPSO = validateIter(iterIPSO, 'ipsoIter');
    maxIter = max([iterJoint, iterFull, iterIPSO]);
    numParticles = 120;
    makePlots = getOpt(opts, 'makePlots', false);
    saveResults = getOpt(opts, 'saveResults', true);
    dryRun = getOpt(opts, 'dryRun', false);

    baseL = getOpt(opts, 'baseL', 3e6);
    baseSlot = getOpt(opts, 'baseSlot', 5e3);
    baseHover = getOpt(opts, 'baseHover', 1);
    Lvals = getOpt(opts, 'Lvals', [1e6, 2e6, 3e6]); % add 4e6 for the limit test
    slotVals = getOpt(opts, 'slotVals', [0, 5e3, 10e3]);
    hoverVals = getOpt(opts, 'hoverVals', [1, 2, 3]);

    % Same 120-particle swarm for every optimizer; only the iteration caps
    % differ. Polishing samples stay at the v10Config defaults.
    base.optimizers.joint.numParticles = numParticles;
    base.optimizers.full.numParticles = numParticles;
    base.optimizers.ipso.numParticles = numParticles;
    base.optimizers.joint.maxIter = iterJoint;
    base.optimizers.full.maxIter = iterFull;
    base.optimizers.ipso.maxIter = iterIPSO;

    configs = buildConfigs(groups, baseL, baseSlot, baseHover, ...
        Lvals, slotVals, hoverVals);
    nLabels = numel(configs);
    configs = dedupeConfigs(configs);
    nRuns = numel(variants) * numel(seeds) * numel(configs);

    fprintf('\n=== V10 campaign ===\n');
    fprintf('Runner   : %s\n', which('runV10Campaign'));
    fprintf('Variants : %s\n', strjoin(variants, ', '));
    fprintf('Algorithms: %s\n', strjoin(algorithms, ', '));
    fprintf('Seeds    : %s\n', sprintf('%.0f ', seeds));
    fprintf('Profile  : %s | Joint %d | Full PSO %d | Full IPSO %d iterations | particles: %d | runs: %d | plots: %d | saveResults: %d\n', ...
        profile, iterJoint, iterFull, iterIPSO, numParticles, nRuns, makePlots, saveResults);
    if nLabels > numel(configs)
        fprintf('Dedupe   : %d nhãn -> %d cấu hình duy nhất (%d bản trùng bị bỏ)\n', ...
            nLabels, numel(configs), nLabels - numel(configs));
    end
    if iterIPSO ~= iterJoint || iterIPSO ~= iterFull
        fprintf('NOTE     : iteration budget is asymmetric (IPSO %d vs %d/%d); EE comparison is NOT equal-budget.\n', ...
            iterIPSO, iterJoint, iterFull);
    end
    fprintf('Configs  :\n');
    for c = 1:numel(configs)
        fprintf('  [%d] %-5s %-14s L=%.3g bit/user | slot=%.3g bit/user | hover=%.3g s%s\n', ...
            c, configs(c).group, configs(c).label, configs(c).L, ...
            configs(c).slot, configs(c).hover, aliasText(configs(c)));
    end
    fprintf(['WARNING: %d runs x max(%d,%d,%d) iterations x %d particles; ' ...
        'this can take many hours or days.\n'], nRuns, iterJoint, iterFull, iterIPSO, numParticles);
    if makePlots && nRuns > 10
        warning('runV10Campaign:ManyFigures', ...
            'makePlots=true for %d runs will create many figures; consider false.', nRuns);
    end

    if dryRun
        campaign = struct();
        campaign.results = table();
        campaign.configs = configs;
        campaign.seeds = seeds;
        campaign.variants = variants;
        campaign.algorithms = algorithms;
        campaign.groups = groups;
        campaign.profile = profile;
        campaign.iterJoint = iterJoint;
        campaign.iterFull = iterFull;
        campaign.iterIPSO = iterIPSO;
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
        error('runV10Campaign:Output', 'Cannot create %s: %s', out, msg);
    end

    template = struct( ...
        'variant', '', 'seed', 0, 'group', '', 'config', '', 'configAliases', '', 'algorithm', '', ...
        'ee', NaN, 'feasible', 0, ...
        'qosL', 0, 'qosSlot', 0, 'qosUserSlot', 0, 'qosEnergy', 0, 'qosGeometry', 0, ...
        'bits', NaN, 'energyJ', NaN, 'flightEnergy', NaN, 'hoverEnergy', NaN, ...
        'rfEnergy', NaN, 'distance', NaN, 'missionTime', NaN, ...
        'minBitsPerSlot', NaN, 'maxBitsPerSlot', NaN, ...
        'slotsBelow', 0, 'userSlotsBelow', 0, ...
        'alphaMax', NaN, 'alphaMean', NaN, 'jain', NaN, ...
        'minUserBits', NaN, 'maxUserBits', NaN, ...
        'folder', '-', 'error', '-');
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
                cfg.output.makePlots = makePlots;
                cfg.output.saveFigures = makePlots;
                cfg.output.saveResults = saveResults;

                fprintf('\n[%d/%d] V10%s seed=%.0f %s (%.1f s elapsed)\n', ...
                    runIndex, nRuns, variants{v}, seeds(s), configs(c).label, toc(tStart));
                try
                    data = runV10(variants{v}, cfg, solvers);
                    newRows = summarizeRun(variants{v}, seeds(s), configs(c), ...
                        data, template, algorithms);
                    rows = [rows; newRows(:)]; %#ok<AGROW>
                catch err
                    warning('runV10Campaign:RunFailed', ...
                        'Run failed: V10%s seed=%.0f %s: %s', ...
                        variants{v}, seeds(s), configs(c).label, err.message);
                    newRows = errorRows(variants{v}, seeds(s), configs(c), ...
                        err.message, template, algorithms);
                    rows = [rows; newRows(:)]; %#ok<AGROW>
                end

                % Save the partial table after every run so a long campaign
                % can be inspected or stopped without losing completed rows.
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
    campaign.algorithms = algorithms;
    campaign.groups = groups;
    campaign.profile = profile;
    campaign.iterJoint = iterJoint;
    campaign.iterFull = iterFull;
    campaign.iterIPSO = iterIPSO;
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

function configs = buildConfigs(groups, baseL, baseSlot, baseHover, Lvals, slotVals, hoverVals)
    configs = repmat(struct('group', '', 'label', '', 'L', 0, 'slot', 0, ...
        'hover', 0, 'aliases', {{}}), 0, 1);
    for g = 1:numel(groups)
        switch lower(groups{g})
            case 'l'
                for x = Lvals(:).'
                    configs(end+1) = mkConfig('L', sprintf('L=%.3gM', x/1e6), ...
                        x, baseSlot, baseHover); %#ok<AGROW>
                end
            case 'slot'
                for x = slotVals(:).'
                    configs(end+1) = mkConfig('slot', sprintf('slot=%.3gk', x/1e3), ...
                        baseL, x, baseHover); %#ok<AGROW>
                end
            case 'hover'
                for x = hoverVals(:).'
                    configs(end+1) = mkConfig('hover', sprintf('hover=%.3gs', x), ...
                        baseL, baseSlot, x); %#ok<AGROW>
                end
            otherwise
                error('runV10Campaign:Group', ...
                    'Unknown group %s. Use L, slot or hover.', groups{g});
        end
    end
    if isempty(configs)
        configs = mkConfig('base', 'base', baseL, baseSlot, baseHover);
    end
end

function configs = dedupeConfigs(configs)
% Remove repeated (L,q,hover) parameter sets while keeping the first label.
    if isempty(configs)
        return;
    end
    keep = true(1, numel(configs));
    for i = 1:numel(configs)
        if ~keep(i)
            continue;
        end
        for j = i+1:numel(configs)
            if ~keep(j)
                continue;
            end
            sameL = configs(i).L == configs(j).L;
            sameSlot = configs(i).slot == configs(j).slot;
            sameHover = configs(i).hover == configs(j).hover;
            if sameL && sameSlot && sameHover
                configs(i).aliases{end+1} = configs(j).label;
                keep(j) = false;
            end
        end
    end
    configs = configs(keep);
end

function c = mkConfig(group, label, L, slot, hover)
    c = struct('group', group, 'label', label, 'L', L, 'slot', slot, ...
        'hover', hover, 'aliases', {{}});
end

function txt = aliasText(cfg)
    if isempty(cfg.aliases)
        txt = '';
    else
        txt = [' (=', strjoin(cfg.aliases, ', '), ')'];
    end
end

function value = validateIter(value, name)
    validateattributes(value, {'numeric'}, ...
        {'scalar', 'finite', 'integer', 'positive'}, mfilename, name);
end

function rows = summarizeRun(variant, seed, cfgSpec, data, template, algorithms)
    names = {'Baseline', 'Joint PSO', 'Full PSO', 'Full IPSO'};
    fields = {'resBase', 'trajJoint', 'trajFull', 'trajIPSO'};
    rows = repmat(template, numel(algorithms), 1);
    for j = 1:numel(algorithms)
        k = find(strcmp(names, algorithms{j}), 1);
        r = data.(fields{k});
        row = template;
        row.variant = variant;
        row.seed = seed;
        row.group = cfgSpec.group;
        row.config = cfgSpec.label;
        row.configAliases = strjoin(cfgSpec.aliases, ' | ');
        if isempty(row.configAliases)
            row.configAliases = '-';
        end
        row.algorithm = names{k};
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
        b = r.totalBitsPerUser;
        row.jain = (sum(b)^2) / (numel(b) * sum(b.^2) + eps);
        row.minUserBits = min(b);
        row.maxUserBits = max(b);
        row.folder = data.outputFolder;
        if isempty(row.folder)
            row.folder = '-';
        end
        rows(j) = row;
    end
end

function rows = errorRows(variant, seed, cfgSpec, message, template, algorithms)
    rows = repmat(template, numel(algorithms), 1);
    for k = 1:numel(algorithms)
        row = template;
        row.variant = variant;
        row.seed = seed;
        row.group = cfgSpec.group;
        row.config = cfgSpec.label;
        row.configAliases = strjoin(cfgSpec.aliases, ' | ');
        if isempty(row.configAliases)
            row.configAliases = '-';
        end
        row.algorithm = algorithms{k};
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
