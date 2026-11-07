% V12 campaign: ablation Option 2..4, variant B only, three L levels, seed set S3.
%   Option 1 = parity V10B   : steady-cruise      + phi fixed 0.9 + causality off
%   Option 2 = causal DF     : steady-cruise      + phi optimal-causal
%   Option 3 = acceleration  : quasi-steady-accel + phi fixed 0.9 + causality off
%   Option 4 = full V12      : quasi-steady-accel + phi optimal-causal
% Option 1 is NOT rerun: results/v10/campaign_20261029_125559 (group L, B,
% S3, quick 1000/120, slot 5 kbit, hover 1 s) is the Option 1 reference;
% V12-O1 re-evaluates all 27 saved V10B solutions with zero difference.
% Fixed for this run: a = 3 m/s^2, bit/user/slot = 5 kbit, hover = 1 s.
% Both profiles use 120 particles: quick = 1000 iterations, full = 3000.
% Matrix: 1 variant x 3 seeds x (3 options x 3 L) = 27 runs (+1 parity run).

clc;
close all;

runParityCheck = true;           % 1 run O1 seed 2026 L=3M; compare with V10B summary

opts = struct();
opts.profile = 'quick';          % 'quick' (1000/120) or 'full' (3000/120)
opts.makePlots = false;          % many runs: keep figures off; replot from results.mat
opts.saveResults = true;
opts.variants = {'B'};
opts.groups = {'option'};        % 'L', 'slot', 'hover', 'accel', 'phi', 'option'
opts.baseAccel = 3;              % m/s^2, used by Option 3 and 4
opts.baseSlot = 5e3;             % min bits per user per serving slot
opts.baseHover = 1;              % hover = 1 s

if runParityCheck
    % Expected to match results/v10/V10B/seed2026_L3Mbit_20261029_142436_310.
    parity = opts;
    parity.seeds = 2026;
    parity.optionVals = 1;
    parity.Lvals = 3e6;
    campaignParity = runV12Campaign(parity);
end

opts.seeds = [2026, 608060, 3486784401];   % S3, same as V10 campaign default
opts.optionVals = [2, 3, 4];
opts.Lvals = [1e6, 2e6, 3e6];    % three L levels

% Set opts.dryRun = true to print the 9 configurations without running.
campaign = runV12Campaign(opts);
