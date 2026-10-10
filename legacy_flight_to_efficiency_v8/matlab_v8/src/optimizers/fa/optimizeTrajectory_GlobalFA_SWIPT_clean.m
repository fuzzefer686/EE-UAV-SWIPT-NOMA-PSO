function best = optimizeTrajectory_GlobalFA_SWIPT_clean(sim, opts)
% Global Firefly Algorithm for SWIPT trajectory optimization
% particle = [xInternal, zInternal]
%
% Khac voi FA chuan O(P^2), Global FA chi cho moi firefly di ve global best.
% Do do so tuong tac moi iteration la O(P).

    if nargin < 2
        opts = struct();
    end

    %% Tham so Global FA
    numParticles = getOptField(opts, 'numParticles', 40);
    maxIter      = getOptField(opts, 'maxIter', 100);
    alpha        = getOptField(opts, 'alpha', 0.25);
    beta0        = getOptField(opts, 'beta0', 1.0);
    gamma        = getOptField(opts, 'gamma', 1e-8);
    alphaDamp    = getOptField(opts, 'alphaDamp', 0.97);
    stepScale    = getOptField(opts, 'stepScale', 2000);
    topK         = getOptField(opts, 'topKAttractors',7);
    alpha0 = alpha;

    %% Kich thuoc particle
    T = sim.numSteps;
    nInternal = T - 2;

    % particle = [x2 ... xT-1, z2 ... zT-1]
    D = 2 * nInternal;

    %% Khoi tao bo nho Global FA
    particlesPos = zeros(numParticles, D);
    particlesBrightness = -inf * ones(numParticles, 1);
    particlesRes = cell(numParticles, 1);

    gbestPos = zeros(1, D);
    gbestVal = -inf;
    gbestRes = struct();

    bestHistory = zeros(maxIter + 1, 1);

    %% Baseline trajectory
    xBase = linspace(sim.xStart, sim.xEnd, T);
    zBase = linspace(sim.zStart, sim.zEnd, T);
    baseParticle = [xBase(2:end-1), zBase(2:end-1)];

    %% Khoi tao quan the
    for i = 1:numParticles

        if i == 1
            particlesPos(i, :) = baseParticle;
        else
            particlesPos(i, 1:nInternal) = sim.x_min + ...
                rand(1, nInternal) * (sim.x_max - sim.x_min);

            particlesPos(i, nInternal+1:end) = sim.z_min + ...
                rand(1, nInternal) * (sim.z_max - sim.z_min);
        end

        particlesPos(i, :) = repairPositionParticle(particlesPos(i, :), sim);
        [fit_i, res_i] = evaluateTrajectory_SWIPT_clean(particlesPos(i, :), sim);

        particlesBrightness(i) = fit_i;
        particlesRes{i} = res_i;

        if fit_i > gbestVal
            gbestVal = fit_i;
            gbestPos = particlesPos(i, :);
            gbestRes = res_i;
        end
    end

    bestHistory(1) = gbestVal;

    %% Vong lap Global FA
    for iter = 1:maxIter

    for i = 1:numParticles

        xi = particlesPos(i, :);
        fi = particlesBrightness(i);
        res_i = particlesRes{i};
        moved = false;

        % Find fireflies brighter than firefly i
        brighter = find(particlesBrightness > particlesBrightness(i));

        if ~isempty(brighter)

            % Sort brighter fireflies by descending brightness
            [~, order] = sort(particlesBrightness(brighter), 'descend');
            brighter = brighter(order);

            % Select at most topK attractors
            k = min(topK, numel(brighter));
            selected = brighter(1:k);

            % O(K), not O(P)
            for jj = 1:k
                j = selected(jj);

                distance = particlesPos(j, :) - xi;
                r_ij = norm(distance);
                beta = beta0 * exp(-gamma * r_ij^2);
                randomVec = randn(1, D) - 0.5;

                xi = xi + beta * distance + alpha * randomVec * stepScale;

                xi = repairPositionParticle(xi, sim);
                [fi, res_i] = evaluateTrajectory_SWIPT_clean(xi, sim);

                moved = true;
            end
        end

        % If no brighter firefly exists, perform random walk
        if ~moved
            randomVec = randn(1, D) - 0.5;
            xi = xi + alpha * randomVec * stepScale;

            xi = repairPositionParticle(xi, sim);
            [fi, res_i] = evaluateTrajectory_SWIPT_clean(xi, sim);
        end

        particlesPos(i, :) = xi;
        particlesBrightness(i) = fi;
        particlesRes{i} = res_i;

        if fi > gbestVal
            gbestVal = fi;
            gbestPos = xi;
            gbestRes = res_i;
        end
    end

    bestHistory(iter + 1) = gbestVal;
    alpha = alpha * alphaDamp;
end

    %% Dong goi ket qua tot nhat
    best = gbestRes;

    best.bestParticle = gbestPos;
    best.bestFitness = gbestVal;
    best.bestHistory = bestHistory;
    best.mode = 'global-fa-swipt-clean';

    best.numParticles = numParticles;
    best.maxIter = maxIter;
    best.alpha = alpha;
    best.alpha0 = alpha0;
    best.beta0 = beta0;
    best.gamma = gamma;
    best.alphaDamp = alphaDamp;
    best.stepScale = stepScale;
end
function particle = repairPositionParticle(particle, sim)

    T = sim.numSteps;
    nInternal = T - 2;

    xInternal = real(particle(1:nInternal));
    zInternal = real(particle(nInternal+1:end));

    % Khoa bien x, z truoc
    xInternal = min(max(xInternal, sim.x_min), sim.x_max);
    zInternal = min(max(zInternal, sim.z_min), sim.z_max);

    xTraj = [sim.xStart, xInternal, sim.xEnd];
    zTraj = [sim.zStart, zInternal, sim.zEnd];

    xTraj(1) = sim.xStart;
    xTraj(end) = sim.xEnd;

    zTraj(1) = sim.zStart;
    zTraj(end) = sim.zEnd;

    % Khoa bien z 
    zTraj(2:end-1) = min(max(zTraj(2:end-1), sim.z_min), sim.z_max);

    for pass = 1:3

        % Forward pass
        for t = 2:(T-1)
            lo = max(sim.x_min, xTraj(t-1) - sim.dxMax);
            hi = min(sim.x_max, xTraj(t-1) + sim.dxMax);
            xTraj(t) = min(max(xTraj(t), lo), hi);
        end

        % Backward pass
        for t = (T-1):-1:2
            lo = max(sim.x_min, xTraj(t+1) - sim.dxMax);
            hi = min(sim.x_max, xTraj(t+1) + sim.dxMax);
            xTraj(t) = min(max(xTraj(t), lo), hi);
        end
    end
    for pass = 1:3

        % Forward pass cho z
        for t = 2:(T-1)
            lo = max(sim.z_min, zTraj(t-1) - sim.dzMax);
            hi = min(sim.z_max, zTraj(t-1) + sim.dzMax);
            zTraj(t) = min(max(zTraj(t), lo), hi);
        end

        % Backward pass cho z
        for t = (T-1):-1:2
            lo = max(sim.z_min, zTraj(t+1) - sim.dzMax);
            hi = min(sim.z_max, zTraj(t+1) + sim.dzMax);
            zTraj(t) = min(max(zTraj(t), lo), hi);
        end
    end

    xTraj(2:end-1) = min(max(xTraj(2:end-1), sim.x_min), sim.x_max);
    zTraj(2:end-1) = min(max(zTraj(2:end-1), sim.z_min), sim.z_max);

    particle = [xTraj(2:end-1), zTraj(2:end-1)];
end

function val = getOptField(opts, fieldName, defaultVal)

    if isfield(opts, fieldName) && ~isempty(opts.(fieldName))
        val = opts.(fieldName);
    else
        val = defaultVal;
    end
end