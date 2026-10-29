function best = optimizeTrajectory_JointPSO_SWIPT_clean(sim, opts)

% Moi particle:
%   particle = [xInternal, zInternal, rawPowerAllSteps]
%
% rawPowerAllSteps co kich thuoc = T * noUsers
    if nargin < 2
        opts = struct();
    end

    fitnessUnit = 'bit/s';
    if isfield(sim, 'objectiveMode') && strcmpi(sim.objectiveMode, 'ee-rf')
        fitnessUnit = 'bit/J';
    end

    numParticles = getOptField(opts, 'numParticles', 70);
    maxIter      = getOptField(opts, 'maxIter', 150);
    w            = getOptField(opts, 'w', 0.7);
    c1           = getOptField(opts, 'c1', 1.5);
    c2           = getOptField(opts, 'c2', 1.5);

    %% Kich thuoc particle
    T = sim.numSteps;
    nInternal = T - 2;
    noUsers = sim.noUsers;

    D_pos = 2 * nInternal;
    D_pow = T * noUsers;
    D = D_pos + D_pow;

    %% Bien power
    pMin = getSimField(sim, 'pMin', 1e-3);
    pMax = getSimField(sim, 'pMax', 1.0);

    %% Khoi tao bo nho PSO
    particlesPos = zeros(numParticles, D);
    particlesVel = zeros(numParticles, D);

    pbestPos = zeros(numParticles, D);
    pbestVal = -inf * ones(numParticles, 1);

    gbestPos = zeros(1, D);
    gbestVal = -inf;
    gbestRes = struct();

    bestHistory = zeros(maxIter + 1, 1);
    trackEE = isfield(sim, 'objectiveMode') && strcmpi(sim.objectiveMode, 'ee-rf');
    if trackEE
        totalBitsHistory = NaN(maxIter + 1, 1);
        totalEnergyHistory = NaN(maxIter + 1, 1);
        % Rows: iteration (starting at 0); slots exclude the arrival waypoint.
        totalBitsPerUserHistory = NaN(maxIter + 1, sim.noUsers);
        transmitPowerHistory = NaN(maxIter + 1, sim.numSteps - 1);
        alphaUserHistory = NaN(maxIter + 1, sim.numSteps - 1, sim.noUsers);
    end

    %% Particle baseline: duong bay thang + alpha deu
    xBase = linspace(sim.xStart, sim.xEnd, T);
    zBase = linspace(sim.zStart, sim.zEnd, T);

    alphaBase = ones(T, noUsers) / noUsers;

    baseParticle = [ ...
        xBase(2:end-1), ...
        zBase(2:end-1), ...
        reshape(alphaBase.', 1, []) ...
    ];

    %% Khoi tao bay dan
    for i = 1:numParticles

        if i == 1
            particlesPos(i, :) = baseParticle;
        else
            % random deu trong bien
            particlesPos(i, 1:nInternal) = sim.x_min + rand(1, nInternal) * (sim.x_max - sim.x_min);
            particlesPos(i, nInternal+1:2*nInternal) = sim.z_min + rand(1, nInternal) * (sim.z_max - sim.z_min);

            % raw power random deu trong [pMin, pMax]
            particlesPos(i, 2*nInternal+1:end) = pMin + rand(1, D_pow) * (pMax - pMin);
        end

        particlesVel(i, :) = zeros(1, D);

        particlesPos(i, :) = repairJointParticle(particlesPos(i, :), sim, pMin, pMax);

        [fit_i, res_i] = evaluateTrajectory_JointSWIPT_clean(particlesPos(i, :), sim);

        pbestPos(i, :) = particlesPos(i, :);
        pbestVal(i) = fit_i;

        if fit_i > gbestVal
            gbestVal = fit_i;
            gbestPos = particlesPos(i, :);
            gbestRes = res_i;
        end
    end

    bestHistory(1) = gbestVal;
    if trackEE
        totalBitsHistory(1) = gbestRes.totalBits;
        totalEnergyHistory(1) = gbestRes.totalEnergy;
        totalBitsPerUserHistory(1, :) = gbestRes.totalBitsPerUser;
        transmitPowerHistory(1, :) = reshape(gbestRes.pt(gbestRes.slotIdx), 1, []);
        % alphaTrace follows physical User ID, not weak-to-strong rank.
        alphaUserHistory(1, :, :) = reshape(gbestRes.alphaTrace(gbestRes.slotIdx, :), ...
            1, sim.numSteps - 1, sim.noUsers);
    end

    %% 7. Vong lap PSO
    for iter = 1:maxIter

        for i = 1:numParticles

            r1 = rand(1, D);
            r2 = rand(1, D);

            particlesVel(i, :) = w * particlesVel(i, :) + c1 * r1 .* (pbestPos(i, :) - particlesPos(i, :)) + c2 * r2 .* (gbestPos - particlesPos(i, :));

            particlesPos(i, :) = particlesPos(i, :) + particlesVel(i, :);

            particlesPos(i, :) = repairJointParticle(particlesPos(i, :), sim, pMin, pMax);

            [fit_i, res_i] = evaluateTrajectory_JointSWIPT_clean(particlesPos(i, :), sim);

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
        if trackEE
            % Both metrics belong to the same best-EE particle this iteration.
            totalBitsHistory(iter + 1) = gbestRes.totalBits;
            totalEnergyHistory(iter + 1) = gbestRes.totalEnergy;
            totalBitsPerUserHistory(iter + 1, :) = gbestRes.totalBitsPerUser;
            transmitPowerHistory(iter + 1, :) = reshape(gbestRes.pt(gbestRes.slotIdx), 1, []);
            % alphaTrace follows physical User ID, not weak-to-strong rank.
            alphaUserHistory(iter + 1, :, :) = reshape(gbestRes.alphaTrace(gbestRes.slotIdx, :), ...
                1, sim.numSteps - 1, sim.noUsers);
        end

        if mod(iter, 10) == 0 || iter == 1 || iter == maxIter
            fprintf('Joint PSO iter %3d/%3d | best fitness = %.4e %s\n', ...
                iter, maxIter, gbestVal, fitnessUnit);
        end
    end

    %% 8. Dong goi ket qua
    best = gbestRes;

    best.bestParticle = gbestPos;
    best.bestFitness = gbestVal;
    best.bestHistory = bestHistory;
    if trackEE
        best.totalBitsHistory = totalBitsHistory;
        best.totalEnergyHistory = totalEnergyHistory;
        best.totalBitsPerUserHistory = totalBitsPerUserHistory;
        best.transmitPowerHistory = transmitPowerHistory;
        best.alphaUserHistory = alphaUserHistory;
    end
    best.mode = 'joint-pso-swipt-clean';

    best.numParticles = numParticles;
    best.maxIter = maxIter;
    best.w = w;
    best.c1 = c1;
    best.c2 = c2;
end

%  Repair Joint Particle
function particle = repairJointParticle(particle, sim, pMin, pMax)

    T = sim.numSteps;
    nInternal = T - 2;
    noUsers = sim.noUsers;

    %% 1. Repair position block
    posBlock = particle(1:2*nInternal);
    posBlock = repairPositionBlock(posBlock, sim);

    %% 2. Repair raw power block
    rawP = real(particle(2*nInternal+1:end));

    rawP = min(max(rawP, pMin), pMax);

    rawP = reshape(rawP, noUsers, T).';   % [T x noUsers]

    rowSum = sum(rawP, 2);
    bad = rowSum <= 0;

    if any(bad)
        rawP(bad, :) = 1 / noUsers;
        rowSum = sum(rawP, 2);
    end

    rawP = rawP ./ rowSum;

    particle = [posBlock, reshape(rawP.', 1, [])];
end


%  Repair Position Block
function posBlock = repairPositionBlock(posBlock, sim)

    T = sim.numSteps;
    nInternal = T - 2;

    xInternal = real(posBlock(1:nInternal));
    zInternal = real(posBlock(nInternal+1:end));

    xInternal = min(max(xInternal, sim.x_min), sim.x_max);
    zInternal = min(max(zInternal, sim.z_min), sim.z_max);

    xTraj = [sim.xStart, xInternal, sim.xEnd];
    zTraj = [sim.zStart, zInternal, sim.zEnd];

    xTraj(1) = sim.xStart;
    xTraj(end) = sim.xEnd;

    zTraj(1) = sim.zStart;
    zTraj(end) = sim.zEnd;

    zTraj(2:end-1) = min(max(zTraj(2:end-1), sim.z_min), sim.z_max);

    %% Repair x theo dxMax
    for pass = 1:3

        % Forward
        for t = 2:(T-1)
            lo = max(sim.x_min, xTraj(t-1) - sim.dxMax);
            hi = min(sim.x_max, xTraj(t-1) + sim.dxMax);
            xTraj(t) = min(max(xTraj(t), lo), hi);
        end

        % Backward
        for t = (T-1):-1:2
            lo = max(sim.x_min, xTraj(t+1) - sim.dxMax);
            hi = min(sim.x_max, xTraj(t+1) + sim.dxMax);
            xTraj(t) = min(max(xTraj(t), lo), hi);
        end
    end

    %% Repair z theo dzMax neu co
    if isfield(sim, 'dzMax') && ~isempty(sim.dzMax)

        for pass = 1:3

            % Forward
            for t = 2:(T-1)
                lo = max(sim.z_min, zTraj(t-1) - sim.dzMax);
                hi = min(sim.z_max, zTraj(t-1) + sim.dzMax);
                zTraj(t) = min(max(zTraj(t), lo), hi);
            end

            % Backward
            for t = (T-1):-1:2
                lo = max(sim.z_min, zTraj(t+1) - sim.dzMax);
                hi = min(sim.z_max, zTraj(t+1) + sim.dzMax);
                zTraj(t) = min(max(zTraj(t), lo), hi);
            end
        end
    end

    xTraj(2:end-1) = min(max(xTraj(2:end-1), sim.x_min), sim.x_max);
    zTraj(2:end-1) = min(max(zTraj(2:end-1), sim.z_min), sim.z_max);

    posBlock = [xTraj(2:end-1), zTraj(2:end-1)];
end


%% ========================================================================
%  Helper functions
%% ========================================================================
function val = getOptField(opts, fieldName, defaultVal)

    if isfield(opts, fieldName) && ~isempty(opts.(fieldName))
        val = opts.(fieldName);
    else
        val = defaultVal;
    end
end


function val = getSimField(sim, fieldName, defaultVal)

    if isfield(sim, fieldName) && ~isempty(sim.(fieldName))
        val = sim.(fieldName);
    else
        val = defaultVal;
    end
end
