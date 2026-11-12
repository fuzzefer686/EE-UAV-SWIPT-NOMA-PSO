% V12 campaign: ablation Option 1..4, variant B only, three L levels, S3 or S10.
%   Option 1 = parity V10B   : steady-cruise      + phi fixed 0.9 + causality off
%   Option 2 = causal DF     : steady-cruise      + phi optimal-causal (phiMax=0.999)
%   Option 3 = acceleration  : quasi-steady-accel + phi fixed 0.9 + causality off
%   Option 4 = full V12      : quasi-steady-accel + phi optimal-causal (phiMax=0.999)
% Physics ablation freezes one identical solver across Option 1..4:
%   initMode='v10', updateMode='independent', mutationMode='elementwise',
%   polishJoint=true, finite equal raw budget maxEvals = P*(maxIter+1),
%   and incumbentMode='none' (equal total cost: no inherited incumbents, so
%   evalCount == evalCountCumulative and results do not depend on option order).
% Optional warm-start branch (runWarmStart=true) uses crossModel continuation
%   with descending L; report it separately with evalCountCumulative /
%   evalCountSource (cost of every source stage that produced a screened incumbent).
% Separate solver ablation uses opts.groups = {'solver'} (arms S1..S5).
% Legacy V10B regression parity overrides maxEvals=Inf, polishJoint=false, incumbentMode='none'.
% Fixed for this run: a = 3 m/s^2, bit/user/slot = 5 kbit, hover = 1 s.
% Both profiles use 120 particles: quick = 1000 iterations, full = 3000.

clc;
close all;

runParityCheck = true;           % 1 run O1 seed 2026 L=3M; compare with V10B summary
runWarmStart = false;            % separate crossModel branch; NOT an equal-budget comparison
seedSet = 'S3';                  % 'S3' (3 seeds, 36 runs; verify first) or 'S10' (10 seeds, 120 runs)

seedsS3  = [2026, 608060, 3486784401];
seedsS10 = [2026, 608060, 3486784401, 2027, 2028, 2029, 2030, 2031, 2032, 2033];

opts = struct();
opts.profile = 'quick';             % 'quick' (1000/120) or 'full' (3000/120)
opts.seedMode = 'per-scenario';     % 'per-scenario' (CRN per scenario; seed 2026 == V10B) or 'fixed'
opts.phiMax = 0.999;                % design cap assumption (>= 0.1% ID branch power)
opts.initMode = 'v10';              % frozen physics-ablation initializer ('v10' or 'clustered')
opts.updateMode = 'independent';    % frozen physics-ablation velocity update ('independent' or 'correlated')
opts.mutationMode = 'elementwise';  % frozen physics-ablation IPSO mutation ('elementwise' or 'block')
opts.polishJoint = true;            % symmetric alpha polishing across Joint/Full/IPSO
opts.makePlots = false;             % many runs: keep figures off; replot from results.mat
opts.saveResults = true;
opts.variants = {'B'};
opts.groups = {'option'};           % 'L', 'slot', 'hover', 'accel', 'phi', 'option', 'solver'
opts.baseAccel = 3;                 % m/s^2, used by Option 3 and 4
opts.baseSlot = 5e3;                % min bits per user per serving slot
opts.baseHover = 1;                 % hover = 1 s
opts.incumbentMode = 'none';        % equal-budget control branch (paper results)

if runParityCheck
    % Expected to match results/v10/V10B/seed2026_L3Mbit_20261029_142436_310 bit-exactly.
    parity = opts;
    parity.seeds = 2026;
    parity.optionVals = 1;
    parity.Lvals = 3e6;
    parity.maxEvals = Inf;
    parity.polishJoint = false;
    parity.incumbentMode = 'none';
    campaignParity = runV12Campaign(parity);
end

switch upper(seedSet)
    case 'S3'
        opts.seeds = seedsS3;
    case 'S10'
        opts.seeds = seedsS10;
    otherwise
        error('maincodeV12Campaign:SeedSet', 'seedSet must be ''S3'' or ''S10''.');
end
opts.optionVals = [1, 2, 3, 4];     % paired Option 1..4 under identical CRN seeds and frozen solver
opts.Lvals = [1e6, 2e6, 3e6];       % ordered descending [3e6, 2e6, 1e6] inside each option

% Set opts.dryRun = true to print the configurations without running.
campaign = runV12Campaign(opts);

if runWarmStart
    % Warm-start quality check: compare EE together with evalCountCumulative,
    % never against the control branch at equal evalCount alone.
    warm = opts; %#ok<UNRCH> runWarmStart is a user toggle
    warm.incumbentMode = 'crossModel';
    campaignWarm = runV12Campaign(warm);
end
