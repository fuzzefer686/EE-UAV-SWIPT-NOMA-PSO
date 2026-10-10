function best = optimizeBSPosition_BaselineSWIPT_clean(sim, opts)
% opts.mode:
%   'xy'    : toi uu ca xBS va yBS cua 3 BS
%   'yonly' : giu xBS co dinh chi toi uu yBS cua 3 BS

    if nargin < 2
        opts = struct();
    end

    numParticles = getOptField_local(opts, 'numParticles', 50);
    maxIter      = getOptField_local(opts, 'maxIter', 150);
    w            = getOptField_local(opts, 'w', 0.7);
    c1           = getOptField_local(opts, 'c1', 1.5);
    c2           = getOptField_local(opts, 'c2', 1.5);

    mode = getOptField_local(opts, 'mode', 'xy');

    noBS = sim.noBS;

    %% Build search bounds
    switch lower(mode)
        case 'xy'
            D = 2 * noBS;

            lowerBound = [sim.xBS_min(:).', sim.yBS_min(:).'];
            upperBound = [sim.xBS_max(:).', sim.yBS_max(:).'];

            baseParticle = [sim.xBS(:).', sim.yBS(:).'];

        case 'yonly'
            D = noBS;

            lowerBound = sim.yBS_min(:).';
            upperBound = sim.yBS_max(:).';

            baseParticle = sim.yBS(:).';

        otherwise
            error('opts.mode phai la ''xy'' hoac ''yonly''.');
    end

    %% PSO memory
    particlesPos = zeros(numParticles, D);
    particlesVel = zeros(numParticles, D);

    pbestPos = zeros(numParticles, D);
    pbestVal = -inf * ones(numParticles, 1);

    gbestPos = zeros(1, D);
    gbestVal = -inf;
    gbestRes = struct();

    bestHistory = zeros(maxIter + 1, 1);

    %% Initialize swarm
    for i = 1:numParticles

        if i == 1
            % First particle is original BS positions
            particlesPos(i, :) = baseParticle;
        else
            particlesPos(i, :) = lowerBound + rand(1, D) .* (upperBound - lowerBound);
        end

        particlesVel(i, :) = zeros(1, D);
        particlesPos(i, :) = repairParticle_local(particlesPos(i, :), lowerBound, upperBound);

        [fit_i, res_i] = evaluateFromOptParticle_local(particlesPos(i, :), sim, mode);

        pbestPos(i, :) = particlesPos(i, :);
        pbestVal(i) = fit_i;

        if fit_i > gbestVal
            gbestVal = fit_i;
            gbestPos = particlesPos(i, :);
            gbestRes = res_i;
        end
    end

    bestHistory(1) = gbestVal;

    %% PSO loop
    for iter = 1:maxIter

        for i = 1:numParticles
            r1 = rand(1, D);
            r2 = rand(1, D);

            particlesVel(i, :) = w * particlesVel(i, :) + c1 * r1 .* (pbestPos(i, :) - particlesPos(i, :)) + c2 * r2 .* (gbestPos - particlesPos(i, :));

            particlesPos(i, :) = particlesPos(i, :) + particlesVel(i, :);
            particlesPos(i, :) = repairParticle_local(particlesPos(i, :), lowerBound, upperBound);

            [fit_i, res_i] = evaluateFromOptParticle_local(particlesPos(i, :), sim, mode);

            if fit_i > pbestVal(i)
                pbestVal(i) = fit_i;
                pbestPos(i, :) = particlesPos(i, :);
            end

            if fit_i > gbestVal
                gbestVal = fit_i;
                gbestPos = particlesPos(i, :);
                gbestRes = res_i;
            end
        end

        bestHistory(iter + 1) = gbestVal;

        if mod(iter, 10) == 0 || iter == 1 || iter == maxIter
            fprintf('BS-only baseline PSO [%s] iter %3d/%3d | best fitness = %.4e bps\n', ...
                upper(mode), iter, maxIter, gbestVal);
        end
    end

    %% Package best result
    best = gbestRes;

    best.bestOptParticle = gbestPos;
    best.bestFitness = gbestVal;
    best.bestHistory = bestHistory;

    best.mode = ['bs-only-baseline-', lower(mode)];

    best.numParticles = numParticles;
    best.maxIter = maxIter;
    best.w = w;
    best.c1 = c1;
    best.c2 = c2;
end

%% Helper: evaluate particle according to mode
function [fit, res] = evaluateFromOptParticle_local(optParticle, sim, mode)

    noBS = sim.noBS;

    switch lower(mode)
        case 'xy'
            xBS_use = optParticle(1:noBS);
            yBS_use = optParticle(noBS+1:end);

        case 'yonly'
            xBS_use = sim.xBS(:).';
            yBS_use = optParticle(1:noBS);

        otherwise
            error('Unknown mode.');
    end

    particleBS = [xBS_use, yBS_use];

    [fit, res] = evaluateBSOnly_BaselineSWIPT_clean(particleBS, sim);
end

%% Helper: boundary repair
function particle = repairParticle_local(particle, lowerBound, upperBound)
    particle = real(particle);
    particle = min(max(particle, lowerBound), upperBound);
end

%% Helper: option field
function val = getOptField_local(opts, fieldName, defaultVal)
    if isfield(opts, fieldName) && ~isempty(opts.(fieldName))
        val = opts.(fieldName);
    else
        val = defaultVal;
    end
end