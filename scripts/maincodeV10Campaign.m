% V10 campaign: one seed, both variants, three L levels.
% Fixed for this run: seed 3486784401, bit/user/slot = 5 kbit, hover = 1 s.
% Both profiles use 120 particles: quick = 1000 iterations, full = 3000.
%
% Figure 1 is created by runV10 and has rotate3d enabled; drag it in MATLAB
% to orbit the 3D view. Saved PNG/FIG files are static; the .fig can be
% reopened in MATLAB and rotated.

clc;
close all;

opts = struct();
opts.profile = 'quick';          % 'quick' (1000/120) or 'full' (3000/120)
opts.makePlots = true;           % needed to see and rotate Figure 1
opts.saveResults = true;

opts.seeds = 3486784401;         % one common scenario seed for A and B
opts.variants = {'A', 'B'};
opts.groups = {'L'};             % only the L sweep
opts.Lvals = [1e6, 2e6, 3e6];    % three L levels
opts.baseSlot = 5e3;             % min bits per user per serving slot
opts.baseHover = 1;              % hover = 1 s

% This is 2 variants x 1 seed x 3 L = 6 runs.
% Change profile to 'full' for 3000 iterations; add 4e6 to Lvals for the
% L=4 limit test.

campaign = runV10Campaign(opts);
