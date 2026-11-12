% V10B PARFOR TEST — same configuration and budgets as the serial V10B run.
% Budget (unchanged): Joint PSO 1000, Full PSO 2000, Full IPSO 5000 iterations.
% Matrix: V10B, 3 seeds x 7 unique configs = 21 runs, 4 methods per run.
% Each run is independent; parfor distributes whole runs across workers.
% Results are bit-identical to the serial campaign because runV10 resets all
% three RNG seeds inside every task.
%
% Tuning for Intel i5-10400 (6 cores / 12 threads, typically 16 GB):
%   numWorkers = 4 is the safe default (4-5 recommended; 6 may swap with 8 GB).
%   batchSize  = 7 checkpoints after each seed (7 runs).
% Change numWorkers to 5 or 6 only if Task Manager shows RAM headroom.

clc;
close all;

opts = struct();
opts.profile = 'full';                 % 1000 / 2000 / 5000, unchanged
opts.variants = {'B'};                 % V10B only
opts.seeds = [2026, 608060, 3486784401];
opts.groups = {'L', 'slot', 'hover'};
opts.Lvals = [1e6, 2e6, 3e6];
opts.slotVals = [0, 5e3, 10e3];
opts.hoverVals = [1, 2, 3];
opts.baseL = 3e6;
opts.baseSlot = 5e3;
opts.baseHover = 1;

opts.numWorkers = 4;                   % i5-10400: 4 safe, 5-6 if RAM allows
opts.batchSize = 7;                    % checkpoint after each seed
opts.keepPool = false;                 % shut the pool down when finished
opts.makePlots = false;
opts.saveResults = true;

% Dry run: confirm matrix and budget before starting the pool.
previewOpts = opts;
previewOpts.dryRun = true;
preview = runV10Campaign(previewOpts);
nRuns = numel(preview.configs) * numel(preview.seeds);
fprintf('\nPreview: %d config x %d seed = %d run\n', ...
    numel(preview.configs), numel(preview.seeds), nRuns);
if nRuns ~= 21
    error('V10BParfor:RunCount', 'Expected 21 runs, got %d.', nRuns);
end
if preview.iterJoint ~= 1000 || preview.iterFull ~= 2000 || preview.iterIPSO ~= 5000
    error('V10BParfor:IterCount', ...
        'Expected 1000/2000/5000, got %d/%d/%d.', ...
        preview.iterJoint, preview.iterFull, preview.iterIPSO);
end

campaign = runV10CampaignParfor(opts);

T = campaign.results;
fprintf('\n=== KET QUA PARFOR ===\n');
fprintf('Rows: %d | workers: %d | wall: %.1f phut\n', ...
    height(T), campaign.numWorkers, campaign.wallSeconds / 60);
for a = {'Joint PSO', 'Full PSO', 'Full IPSO'}
    sub = T(strcmp(T.algorithm, a{1}), :);
    feasible = sub(sub.feasible == 1, :);
    if isempty(feasible)
        continue;
    end
    fprintf('%-10s feasible %2d/%2d | EE median %9.1f | EE max %9.1f | runtime TB %.1f phut\n', ...
        a{1}, height(feasible), height(sub), median(feasible.ee), max(feasible.ee), ...
        mean(sub.runtimeSec(~isnan(sub.runtimeSec))) / 60);
end
fprintf('Summary CSV: %s\n', fullfile(campaign.outputFolder, 'campaign_summary.csv'));
