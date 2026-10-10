function best = optimizeTrajectory_PSO_SWIPT_clean(sim, opts)
%   particle = [xInternal, zInternal]

    if nargin < 2
        opts = struct();
    end

    numParticles = getOptField(opts, 'numParticles', 40);
    maxIter      = getOptField(opts, 'maxIter', 100);
    w            = getOptField(opts, 'w', 0.7);
    c1           = getOptField(opts, 'c1', 1.5);
    c2           = getOptField(opts, 'c2', 1.5);

    %% Kich thuoc particle
    T = sim.numSteps;
    nInternal = T - 2;

    % particle = [x2 ... xT-1, z2 ... zT-1]
    D = 2 * nInternal;

    %% Khoi tao bo nho PSO
    particlesPos = zeros(numParticles, D);
    particlesVel = zeros(numParticles, D);

    pbestPos = zeros(numParticles, D);
    pbestVal = -inf * ones(numParticles, 1);

    gbestPos = zeros(1, D);
    gbestVal = -inf;
    gbestRes = struct();

    bestHistory = zeros(maxIter + 1, 1);
    
    xBase = linspace(sim.xStart, sim.xEnd, T);
    zBase = linspace(sim.zStart, sim.zEnd, T);
    baseParticle = [xBase(2:end-1), zBase(2:end-1)];
    %% Khoi tao bay dan theo baseline
    for i = 1:numParticles

        if i == 1
            particlesPos(i, :) = baseParticle;
        else
            particlesPos(i, 1:nInternal) = sim.x_min + rand(1, nInternal) * (sim.x_max - sim.x_min);
    
            particlesPos(i, nInternal+1:end) = sim.z_min + rand(1, nInternal) * (sim.z_max - sim.z_min);
        end

        particlesVel(i, :) = zeros(1, D);

        particlesPos(i, :) = repairPositionParticle(particlesPos(i, :), sim);
        [fit_i, res_i] = evaluateTrajectory_SWIPT_clean(particlesPos(i, :), sim);

        pbestPos(i, :) = particlesPos(i, :);
        pbestVal(i) = fit_i;

        if fit_i > gbestVal
            gbestVal = fit_i;
            gbestPos = particlesPos(i, :);
            gbestRes = res_i;
        end
    end

    bestHistory(1) = gbestVal;

    %% Vong lap PSO chuan
    for iter = 1:maxIter
        for i = 1:numParticles
            r1 = rand(1, D);
            r2 = rand(1, D);
            particlesVel(i, :) = w * particlesVel(i, :) + c1 * r1 .* (pbestPos(i, :) - particlesPos(i, :)) + c2 * r2 .* (gbestPos - particlesPos(i, :));
            particlesPos(i, :) = particlesPos(i, :) + particlesVel(i, :);
            particlesPos(i, :) = repairPositionParticle(particlesPos(i, :), sim);
            [fit_i, res_i] = evaluateTrajectory_SWIPT_clean(particlesPos(i, :), sim);

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
            fprintf('PSO iter %3d/%3d | best fitness = %.4e bps\n', ...
                iter, maxIter, gbestVal);
        end
    end

    %% Dong goi ket qua tot nhat
    best = gbestRes;

    best.bestParticle = gbestPos;
    best.bestFitness = gbestVal;
    best.bestHistory = bestHistory;
    best.mode = 'pso-swipt-clean';

    best.numParticles = numParticles;
    best.maxIter = maxIter;
    best.w = w;
    best.c1 = c1;
    best.c2 = c2;
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