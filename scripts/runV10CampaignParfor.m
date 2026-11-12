function campaign = runV10CampaignParfor(opts)
%RUNV10CAMPAGNPARFOR Parallel V10 campaign: one task per (variant, seed, config).
%
%   campaign = runV10CampaignParfor();                       % 4 workers, all algos
%   campaign = runV10CampaignParfor(struct('numWorkers',6));
%   campaign = runV10CampaignParfor(struct('algorithms',{{'Full IPSO'}}));
%
% Parallelism is over independent runs only. Each task still runs the whole
% optimizer sequence serially (5000 iterations x 120 particles for IPSO).
% runV10 resets mainSeed / algorithmSeed / polishSeed inside every task, so
% results are identical to the serial campaign (bit-for-bit).
%
% Differences from runV10Campaign (serial):
%   - every task forces cfg.output.makePlots = false;
%   - cfg.output.runTag makes each run folder unique (no name race);
%   - the CSV/campaign.mat are written after each batch, never inside parfor;
%   - runtimeSec and worker count are stored for benchmarking.
%
% Options:
%   numWorkers   : local pool size; 0 keeps the current pool (default 4)
%   batchSize    : tasks per checkpoint batch (default 7 = one seed)
%   keepPool     : true keeps the pool after the campaign (default false)
%   algorithms   : subset of Baseline / Joint PSO / Full PSO / Full IPSO
%   All runV10Campaign options (seeds, variants, groups, profile, iter*, ...)
%   are forwarded to a dry run that builds the same 21-config matrix.

    if nargin < 1 || isempty(opts)
        opts = struct();
    end
    if ~isstruct(opts)
        error('runV10CampaignParfor:Options', 'opts must be a struct.');
    end
    projectRoot = fileparts(fileparts(mfilename('fullpath')));
    addpath(projectRoot);
    setup_project();

    numWorkers = getOpt(opts, 'numWorkers', 4);
    batchSize = getOpt(opts, 'batchSize', 7);
    keepPool = getOpt(opts, 'keepPool', false);
    validateattributes(numWorkers, {'numeric'}, {'scalar','integer','nonnegative'});
    validateattributes(batchSize, {'numeric'}, {'scalar','integer','positive'});

    if ~license('test', 'Distrib_Computing_Toolbox')
        error('runV10CampaignParfor:License', ...
            'Parallel Computing Toolbox is not licensed on this machine.');
    end

    % Reuse the serial campaign's matrix builder and budget resolution.
    dryOpts = opts;
    dryOpts.dryRun = true;
    dryOpts.makePlots = false;
    dryOpts.saveResults = false;
    preview = runV10Campaign(dryOpts);
    configs = preview.configs;
    seeds = preview.seeds;
    variants = preview.variants;
    algorithms = preview.algorithms;
    solvers = setdiff(algorithms, {'Baseline'}, 'stable');

    % Build the task list in the same order as the serial campaign.
    tasks = repmat(struct('variant', '', 'seed', 0, 'config', 0, 'tag', '', ...
        'L', 0, 'slot', 0, 'hover', 0), 0, 1);
    for v = 1:numel(variants)
        for s = 1:numel(seeds)
            for c = 1:numel(configs)
                t = struct();
                t.variant = variants{v};
                t.seed = seeds(s);
                t.config = c;
                t.tag = sprintf('%s_q%.3gk_h%.3gs', ...
                    regexprep(configs(c).label, '[^A-Za-z0-9]+', ''), ...
                    configs(c).slot / 1e3, configs(c).hover);
                t.L = configs(c).L;
                t.slot = configs(c).slot;
                t.hover = configs(c).hover;
                tasks(end + 1) = t; %#ok<AGROW>
            end
        end
    end
    nTasks = numel(tasks);

    fprintf('\n=== V10 parallel campaign (parfor) ===\n');
    fprintf('Runner   : %s\n', which('runV10CampaignParfor'));
    fprintf('Tasks    : %d (%d variant x %d seed x %d config)\n', ...
        nTasks, numel(variants), numel(seeds), numel(configs));
    fprintf('Budget   : Joint %d | Full PSO %d | Full IPSO %d | particles 120\n', ...
        preview.iterJoint, preview.iterFull, preview.iterIPSO);
    fprintf('Algorithms: %s\n', strjoin(algorithms, ', '));
    fprintf('Batch    : %d task/checkpoint | requested workers: %d\n', ...
        batchSize, numWorkers);

    pool = gcp('nocreate');
    if isempty(pool)
        if numWorkers == 0
            pool = parpool('local');
        else
            pool = parpool('local', numWorkers);
        end
    end
    fprintf('Pool     : %d workers (%s)\n', pool.NumWorkers, pool.Cluster.Profile);

    base = v10Config();
    base.optimizers.joint.numParticles = 120;
    base.optimizers.full.numParticles = 120;
    base.optimizers.ipso.numParticles = 120;
    base.optimizers.joint.maxIter = preview.iterJoint;
    base.optimizers.full.maxIter = preview.iterFull;
    base.optimizers.ipso.maxIter = preview.iterIPSO;

    template = campaignTemplate();
    rows = repmat(template, 0, 1);
    stamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
    out = fullfile(base.output.root, ['campaign_parfor_', stamp]);
    [ok, msg] = mkdir(out);
    if ~ok
        error('runV10CampaignParfor:Output', 'Cannot create %s: %s', out, msg);
    end

    % Scalar broadcasts only; per-run parameters travel inside each task.
    iterJoint = preview.iterJoint;
    iterFull = preview.iterFull;
    iterIPSO = preview.iterIPSO;

    tCampaign = tic;
    for first = 1:batchSize:nTasks
        last = min(first + batchSize - 1, nTasks);
        idx = first:last;
        chunk = tasks(idx);
        dataCell = cell(numel(chunk), 1);
        elapsed = nan(numel(chunk), 1);

        parfor j = 1:numel(chunk)
            if ~exist('runV10', 'file')
                addpath(genpath(fullfile(projectRoot, 'src')));
                addpath(fullfile(projectRoot, 'scripts'));
            end
            t = chunk(j);
            cfg = v10Config();
            cfg.random.mainSeed = t.seed;
            cfg.mission.minBitsPerUser = t.L;
            cfg.mission.minBitsPerSlot = 0;
            cfg.mission.minBitsPerUserPerSlot = t.slot;
            cfg.mission.hoverTime = t.hover;
            cfg.optimizers.joint.maxIter = iterJoint;
            cfg.optimizers.full.maxIter = iterFull;
            cfg.optimizers.ipso.maxIter = iterIPSO;
            cfg.output.makePlots = false;
            cfg.output.saveFigures = false;
            cfg.output.saveResults = true;
            cfg.output.runTag = t.tag;
            t0 = tic;
            try
                dataCell{j} = runV10(t.variant, cfg, solvers);
            catch err
                dataCell{j} = struct('error', err.message);
            end
            elapsed(j) = toc(t0);
        end

        for j = 1:numel(chunk)
            t = chunk(j);
            d = dataCell{j};
            if isfield(d, 'error') && ~isempty(d.error)
                newRows = errorRows(t, configs(t.config), d.error, template, algorithms);
            else
                d.runtimeSec = elapsed(j);
                newRows = summarizeRun(t, configs(t.config), d, template, algorithms);
            end
            rows = [rows; newRows(:)]; %#ok<AGROW>
        end

        rows = rows(:);
        T = struct2table(rows);
        save(fullfile(out, 'campaign.mat'), 'T', 'configs', 'seeds', ...
            'variants', 'algorithms', 'preview', 'opts', '-v7.3');
        writetable(T, fullfile(out, 'campaign_summary.csv'));
        fprintf('Batch %d-%d done: %d rows, wall %.1f min\n', ...
            first, last, height(T), toc(tCampaign) / 60);
    end

    campaign = struct();
    campaign.results = T;
    campaign.configs = configs;
    campaign.seeds = seeds;
    campaign.variants = variants;
    campaign.algorithms = algorithms;
    campaign.iterJoint = preview.iterJoint;
    campaign.iterFull = preview.iterFull;
    campaign.iterIPSO = preview.iterIPSO;
    campaign.maxIter = preview.maxIter;
    campaign.numWorkers = pool.NumWorkers;
    campaign.wallSeconds = toc(tCampaign);
    campaign.outputFolder = out;
    campaign.opts = opts;
    save(fullfile(out, 'campaign.mat'), 'campaign', '-v7.3');

    fprintf('\n=== Parallel campaign complete: %d tasks, %d rows, %.1f min (%.2f h) ===\n', ...
        nTasks, height(T), campaign.wallSeconds / 60, campaign.wallSeconds / 3600);
    fprintf('Summary: %s\n', fullfile(out, 'campaign_summary.csv'));
    if ~keepPool && ~isempty(gcp('nocreate'))
        delete(gcp('nocreate'));
    end
end

function template = campaignTemplate()
    template = struct( ...
        'variant', '', 'seed', 0, 'group', '', 'config', '', ...
        'configAliases', '-', 'algorithm', '', ...
        'ee', NaN, 'feasible', 0, ...
        'qosL', 0, 'qosSlot', 0, 'qosUserSlot', 0, 'qosEnergy', 0, 'qosGeometry', 0, ...
        'bits', NaN, 'energyJ', NaN, 'flightEnergy', NaN, 'hoverEnergy', NaN, ...
        'rfEnergy', NaN, 'distance', NaN, 'missionTime', NaN, ...
        'minBitsPerSlot', NaN, 'maxBitsPerSlot', NaN, ...
        'slotsBelow', 0, 'userSlotsBelow', 0, ...
        'alphaMax', NaN, 'alphaMean', NaN, 'jain', NaN, ...
        'minUserBits', NaN, 'maxUserBits', NaN, 'runtimeSec', NaN, ...
        'folder', '-', 'error', '-');
    template = template(1);
end

function rows = summarizeRun(task, cfgSpec, data, template, algorithms)
    names = {'Baseline', 'Joint PSO', 'Full PSO', 'Full IPSO'};
    fields = {'resBase', 'trajJoint', 'trajFull', 'trajIPSO'};
    rows = repmat(template, numel(algorithms), 1);
    for j = 1:numel(algorithms)
        k = find(strcmp(names, algorithms{j}), 1);
        r = data.(fields{k});
        row = template;
        row.variant = task.variant;
        row.seed = task.seed;
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
        row.runtimeSec = data.runtimeSec;
        row.folder = data.outputFolder;
        if isempty(row.folder)
            row.folder = '-';
        end
        rows(j) = row;
    end
end

function rows = errorRows(task, cfgSpec, message, template, algorithms)
    rows = repmat(template, numel(algorithms), 1);
    for j = 1:numel(algorithms)
        row = template;
        row.variant = task.variant;
        row.seed = task.seed;
        row.group = cfgSpec.group;
        row.config = cfgSpec.label;
        row.configAliases = strjoin(cfgSpec.aliases, ' | ');
        if isempty(row.configAliases)
            row.configAliases = '-';
        end
        row.algorithm = algorithms{j};
        row.error = message;
        rows(j) = row;
    end
end

function value = getOpt(opts, name, default)
    if isfield(opts, name) && ~isempty(opts.(name))
        value = opts.(name);
    else
        value = default;
    end
end
