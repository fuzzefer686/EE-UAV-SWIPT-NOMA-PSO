% Rerun ONLY Full IPSO at 5000 iterations with a fixed cooling horizon.
%
% Why: the old IPSO schedule used w(iter) = w_max - (w_max-w_min)*sqrt(iter/maxIter).
% Changing maxIter therefore changed the inertia from iteration 1, so a 5000-iteration
% run was NOT a continuation of the 1000-iteration run and could end worse.
% Now cfg.optimizers.ipso.wHorizon = 1000 fixes the cooling curve: the first 1000
% iterations are identical to the old 1000-iteration run, then w stays at w_min and
% the remaining 4000 iterations are pure exploitation. Extra budget can only help.
%
% Scope: V10B only, 3 seeds x 7 unique configs = 21 IPSO runs.
% Baseline/Joint/Full PSO are NOT rerun; their results stay in campaign_20261112_095405.
% Output: new campaign folder under results/v10/ with 21 rows (Full IPSO only).

clc;
close all;

opts = struct();
opts.profile = 'full';                 % Joint 1000 / Full PSO 2000 / IPSO 5000
opts.algorithms = {'Full IPSO'};       % rerun only IPSO
opts.variants = {'B'};
opts.seeds = [2026, 608060, 3486784401];
opts.groups = {'L', 'slot', 'hover'};
opts.Lvals = [1e6, 2e6, 3e6];
opts.slotVals = [0, 5e3, 10e3];
opts.hoverVals = [1, 2, 3];
opts.baseL = 3e6;
opts.baseSlot = 5e3;
opts.baseHover = 1;
opts.ipsoIter = 5000;
opts.makePlots = false;
opts.saveResults = true;

% Confirm count and budget before solving.
previewOpts = opts;
previewOpts.dryRun = true;
preview = runV10Campaign(previewOpts);
nRuns = numel(preview.configs) * numel(preview.seeds);
fprintf('Preview: %d cấu hình x %d seed = %d run IPSO-only.\n', ...
    numel(preview.configs), numel(preview.seeds), nRuns);
if nRuns ~= 21
    error('V10B:RunCount', 'Expected 21 unique IPSO runs, got %d.', nRuns);
end
if preview.iterIPSO ~= 5000
    error('V10B:IterCount', 'Expected 5000 IPSO iterations, got %d.', preview.iterIPSO);
end
wHorizon = v10Config().optimizers.ipso.wHorizon;
fprintf('OK: 21 IPSO run | 5000 vòng | wHorizon=%d | polishing on\n', wHorizon);

campaign = runV10Campaign(opts);
fprintf('\nIPSO-only campaign done: %s\n', campaign.outputFolder);
