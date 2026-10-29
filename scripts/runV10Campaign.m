function campaign = runV10Campaign(opts)
%RUNV10CAMPAIGN Multi-seed, multi-config campaign for V10A and V10B.
%
%   campaign = runV10Campaign();                  % quick: 1000 iter, 120 particles
%   campaign = runV10Campaign(struct('profile','full')); % 3000 iter, 120 particles
%   campaign = runV10Campaign(struct('variants',{{'A'}},'groups',{{'hover'}}));
%
% Default matrix: 3 seeds x 3 configs per group (L, per-user slot QoS, hover).
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

    profile = lower(getOpt(opts, 'profile', 'quick'));
    switch profile
        case 'quick'
            profileIter = 1000;
        case 'full'
            profileIter = 3000;
        otherwise
            error('runV10Campaign:Profile', ...
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
    Lvals = getOpt(opts, 'Lvals', [1e6, 2e6, 3e6]); % add 4e6 for the limit test
    slotVals = getOpt(opts, 'slotVals', [0, 5e3, 10e3]);
    hoverVals = getOpt(opts, 'hoverVals', [1, 2, 3]);

    % Both profiles use the same 120-particle swarm; they differ only in the
    % iteration cap. Polishing samples stay at the v10Config defaults.
    base.optimizers.joint.numParticles = numParticles;
    base.optimizers.full.numParticles = numParticles;
    base.optimizers.ipso.numParticles = numParticles;
    base.optimizers.joint.maxIter = maxIter;
    base.optimizers.full.maxIter = maxIter;
    base.optimizers.ipso.maxIter = maxIter;

    configs = buildConfigs(groups, baseL, baseSlot, baseHover, ...
        Lvals, slotVals, hoverVals);
    nRuns = numel(variants) * numel(seeds) * numel(configs);

    fprintf('\n=== V10 campaign ===\n');
    fprintf('Variants : %s\n', strjoin(variants, ', '));
    fprintf('Seeds    : %s\n', sprintf('%.0f ', seeds));
    fprintf('Profile  : %s | maxIter: %d | particles: %d | runs: %d | plots: %d | saveResults: %d\n', ...
        profile, maxIter, numParticles, nRuns, makePlots, saveResults);
    fprintf('Configs  :\n');
    for c = 1:numel(configs)
        fprintf('  [%d] %-5s %-14s L=%.3g bit/user | slot=%.3g bit/user | hover=%.3g s\n', ...
            c, configs(c).group, configs(c).label, configs(c).L, ...
            configs(c).slot, configs(c).hover);
    end
    fprintf(['WARNING: %d runs x %d iterations x %d particles; ' ...
        'this can take many hours or days.\n'], nRuns, maxIter, numParticles);
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
        error('runV10Campaign:Output', 'Cannot create %s: %s', out, msg);
    end

    template = struct( ...
        'variant', '', 'seed', 0, 'group', '', 'config', '', 'algorithm', '', ...
        'ee', NaN, 'feasible', 0, ...
        'qosL', 0, 'qosSlot', 0, 'qosUserSlot', 0, 'qosEnergy', 0, 'qosGeometry', 0, ...
        'bits', NaN, 'energyJ', NaN, 'flightEnergy', NaN, 'hoverEnergy', NaN, ...
        'rfEnergy', NaN, 'distance', NaN, 'missionTime', NaN, ...
        'minBitsPerSlot', NaN, 'maxBitsPerSlot', NaN, ...
        'slotsBelow', 0, 'userSlotsBelow', 0, ...
        'alphaMax', NaN, 'alphaMean', NaN, 'jain', NaN, ...
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
                cfg.output.makePlots = makePlots;
                cfg.output.saveFigures = makePlots;
                cfg.output.saveResults = saveResults;

                fprintf('\n[%d/%d] V10%s seed=%.0f %s (%.1f s elapsed)\n', ...
                    runIndex, nRuns, variants{v}, seeds(s), configs(c).label, toc(tStart));
                try
                    data = runV10(variants{v}, cfg);
                    newRows = summarizeRun(variants{v}, seeds(s), configs(c), ...
                        data, template);
                    rows = [rows; newRows(:)]; %#ok<AGROW>
                catch err
                    warning('runV10Campaign:RunFailed', ...
                        'Run failed: V10%s seed=%.0f %s: %s', ...
                        variants{v}, seeds(s), configs(c).label, err.message);
                    newRows = errorRows(variants{v}, seeds(s), configs(c), ...
                        err.message, template);
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

function configs = buildConfigs(groups, baseL, baseSlot, baseHover, Lvals, slotVals, hoverVals)
    configs = repmat(struct('group', '', 'label', '', 'L', 0, 'slot', 0, 'hover', 0), 0, 1);
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

function c = mkConfig(group, label, L, slot, hover)
    c = struct('group', group, 'label', label, 'L', L, 'slot', slot, 'hover', hover);
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
