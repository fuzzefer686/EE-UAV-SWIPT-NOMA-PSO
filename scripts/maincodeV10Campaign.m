% V10B campaign: exactly 21 unique runs, asymmetric iteration budget.
% Budget: Joint PSO 1000, Full PSO 2000, Full IPSO 5000 iterations.
% This is NOT an equal-budget comparison: IPSO receives 5x the iterations.
% Layout: 3 scenario seeds x 7 unique parameter sets.
%   L sweep    : L = 1, 2, 3 Mbit      (q = 5 kbit, hover = 1 s)
%   q sweep    : q = 0, 5, 10 kbit     (L = 3 Mbit, hover = 1 s)
%   hover sweep: hover = 1, 2, 3 s     (L = 3 Mbit, q = 5 kbit)
% The base point (L=3 Mbit, q=5 kbit, hover=1 s) appears once in each group,
% so 9 labels collapse to 7 unique configurations. runV10Campaign removes the
% repeats before running, therefore 3 x 7 = 21 runs (84 result rows).
%
% Each run always evaluates Baseline, Joint PSO, Full PSO and Full IPSO.
% Output: results/v10/V10B/<seed>_L<...>Mbit_<timestamp>/ plus one campaign
% folder under results/v10/campaign_<timestamp>/ with campaign.mat and CSV.
%
% Figure 1 is created by runV10 and has rotate3d enabled; drag it in MATLAB
% to orbit the 3D view. Saved PNG/FIG files are static; the .fig can be
% reopened and rotated.

clc;
close all;

opts = struct();
opts.profile = 'full';           % Joint 1000, Full PSO 2000, IPSO 5000
opts.makePlots = false;          % 21 runs x full figure set is heavy
opts.saveResults = true;

opts.variants = {'B'};           % V10B only
opts.seeds = [2026, 608060, 3486784401];
opts.groups = {'L', 'slot', 'hover'};

opts.Lvals = [1e6, 2e6, 3e6];
opts.slotVals = [0, 5e3, 10e3];
opts.hoverVals = [1, 2, 3];
opts.baseL = 3e6;
opts.baseSlot = 5e3;
opts.baseHover = 1;

% Dry-run first to confirm "9 nhãn -> 7 cấu hình" and 21 runs, then solve.
thisFile = mfilename('fullpath');
fprintf('Script   : %s\n', thisFile);
shadow = which('runV10Campaign', '-all');
if numel(shadow) > 1
    warning('V10B:ShadowedPath', ...
        'runV10Campaign is shadowed; first match will be used. Use rmpath on older copies.');
    for k = 1:numel(shadow)
        fprintf('  path %d: %s\n', k, shadow{k});
    end
end

previewOpts = opts;
previewOpts.dryRun = true;
preview = runV10Campaign(previewOpts);
fprintf('\nPreview: %d cấu hình x %d seed = %d run.\n', ...
    numel(preview.configs), numel(preview.seeds), ...
    numel(preview.configs) * numel(preview.seeds));
if numel(preview.configs) * numel(preview.seeds) ~= 21
    error('V10B:RunCount', 'Expected 21 unique runs, got %d.', ...
        numel(preview.configs) * numel(preview.seeds));
end
if preview.iterJoint ~= 1000 || preview.iterFull ~= 2000 || preview.iterIPSO ~= 5000
    error('V10B:IterCount', ...
        'Expected 1000/2000/5000 iterations, got %d/%d/%d. Old code or old path is winning.', ...
        preview.iterJoint, preview.iterFull, preview.iterIPSO);
end
fprintf('OK: 21 run | Joint %d | Full PSO %d | Full IPSO %d vòng | 120 hạt | variants=%s\n', ...
    preview.iterJoint, preview.iterFull, preview.iterIPSO, ...
    strjoin(preview.variants, ','));

campaign = runV10Campaign(opts);
