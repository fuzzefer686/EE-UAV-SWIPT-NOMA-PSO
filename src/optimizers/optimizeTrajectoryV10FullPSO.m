function best = optimizeTrajectoryV10FullPSO(sim, opts)

% Particle:
%   [xInternal, optionalYInternal, rawPowerAllSteps, xBS, yBS]

    if nargin < 2
        opts = struct();
    end

    numParticles = getOptField(opts, 'numParticles', 100);
    maxIter      = getOptField(opts, 'maxIter', 250);
    w            = getOptField(opts, 'w', 0.7);
    c1           = getOptField(opts, 'c1', 1.5);
    c2           = getOptField(opts, 'c2', 1.5);

    validateattributes(numParticles, {'numeric'}, {'scalar','finite','integer','positive'});
    validateattributes(maxIter, {'numeric'}, {'scalar','finite','integer','nonnegative'});
    validateattributes(c1, {'numeric'}, {'scalar','finite','real','nonnegative'});
    validateattributes(c2, {'numeric'}, {'scalar','finite','real','nonnegative'});

    T = sim.numSteps;
    nInternal = T - 2;
    noUsers = sim.noUsers;
    noBS = sim.noBS;

    layout = v10ParticleLayout(sim, true);
    D_pos = layout.positionCount;
    D_pow = T * noUsers;
    D_bs  = 2 * noBS;

    D = D_pos + D_pow + D_bs;

    pMin = getSimField(sim, 'pMin', 1e-3);
    pMax = getSimField(sim, 'pMax', 1.0);

    %% Kiem tra bien BS
    requiredFields = {'xBS_min', 'xBS_max', 'yBS_min', 'yBS_max'};

    for k = 1:numel(requiredFields)
        if ~isfield(sim, requiredFields{k})
            error('optimizeTrajectory_JointBS_PSO_SWIPT_clean: sim thieu field %s.', requiredFields{k});
        end
    end

    %% Bo nho PSO
    particlesPos = zeros(numParticles, D);
    particlesVel = zeros(numParticles, D);

    pbestPos = zeros(numParticles, D);
    pbestVal = -inf * ones(numParticles, 1);

    gbestPos = zeros(1, D);
    gbestVal = -inf;
    gbestRes = struct();

    bestHistory = zeros(maxIter + 1, 1);
    trackEE = isfield(sim, 'objectiveMode') && strcmpi(sim.objectiveMode, 'ee-uav-drones');
    if trackEE
        totalBitsHistory = NaN(maxIter + 1, 1);
        totalEnergyHistory = NaN(maxIter + 1, 1);
        flightEnergyHistory = NaN(maxIter + 1, 1);
        hoverEnergyHistory = NaN(maxIter + 1, 1);
        rfEnergyHistory = NaN(maxIter + 1, 1);
        missionTimeHistory = NaN(maxIter + 1, 1);
        totalDistanceHistory = NaN(maxIter + 1, 1);
        feasibleHistory = NaN(maxIter + 1, 1);
        % Rows: iteration (starting at 0); slots exclude the arrival waypoint.
        totalBitsPerUserHistory = NaN(maxIter + 1, sim.noUsers);
        transmitPowerHistory = NaN(maxIter + 1, sim.numSteps - 1);
        alphaUserHistory = NaN(maxIter + 1, sim.numSteps - 1, sim.noUsers);
    end

    % V9 straight/equal-alpha baseline, with V10 geometry.
    baseFullParticle = initialV10Particle(sim, true, false);

    hasSeedFull = isfield(opts, 'seedFullParticle') && ~isempty(opts.seedFullParticle) ...
        && numel(opts.seedFullParticle) == D;

    %% Khoi tao bay dan
    for i = 1:numParticles

        particlesPos(i, :) = initialV10Particle(sim, true, i > 1);
        if i == 1 && hasSeedFull
            particlesPos(i, :) = opts.seedFullParticle;
        end

        particlesVel(i, :) = zeros(1, D);

        particlesPos(i, :) = repairV10Particle(particlesPos(i, :), sim, true);

        [fit_i, res_i] = evaluateTrajectoryV10(particlesPos(i, :), sim, true);

        pbestPos(i, :) = particlesPos(i, :);
        pbestVal(i) = fit_i;

        if isempty(fieldnames(gbestRes)) || fit_i > gbestVal
            gbestVal = fit_i;
            gbestPos = particlesPos(i, :);
            gbestRes = res_i;
        end
    end

    bestHistory(1) = gbestVal;
    if trackEE
        totalBitsHistory(1) = gbestRes.totalBits;
        totalEnergyHistory(1) = gbestRes.totalEnergy;
        flightEnergyHistory(1) = gbestRes.flightEnergy;
        hoverEnergyHistory(1) = gbestRes.hoverEnergy;
        rfEnergyHistory(1) = gbestRes.rfEnergy;
        missionTimeHistory(1) = gbestRes.missionTime;
        totalDistanceHistory(1) = gbestRes.totalDistance;
        feasibleHistory(1) = gbestRes.isFeasible;
        totalBitsPerUserHistory(1, :) = gbestRes.totalBitsPerUser;
        transmitPowerHistory(1, :) = reshape(gbestRes.pt(gbestRes.slotIdx), 1, []);
        % alphaTrace follows physical User ID, not weak-to-strong rank.
        alphaUserHistory(1, :, :) = reshape(gbestRes.alphaTrace(gbestRes.slotIdx, :), ...
            1, sim.numSteps - 1, sim.noUsers);
    end

    %% PSO loop
    for iter = 1:maxIter

        for i = 1:numParticles

            r1 = rand(1, D);
            r2 = rand(1, D);

            particlesVel(i, :) = w * particlesVel(i, :) + c1 * r1 .* (pbestPos(i, :) - particlesPos(i, :)) + c2 * r2 .* (gbestPos - particlesPos(i, :));

            particlesPos(i, :) = particlesPos(i, :) + particlesVel(i, :);

            particlesPos(i, :) = repairV10Particle(particlesPos(i, :), sim, true);

            [fit_i, res_i] = evaluateTrajectoryV10(particlesPos(i, :), sim, true);

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
            flightEnergyHistory(iter + 1) = gbestRes.flightEnergy;
            hoverEnergyHistory(iter + 1) = gbestRes.hoverEnergy;
            rfEnergyHistory(iter + 1) = gbestRes.rfEnergy;
            missionTimeHistory(iter + 1) = gbestRes.missionTime;
            totalDistanceHistory(iter + 1) = gbestRes.totalDistance;
            feasibleHistory(iter + 1) = gbestRes.isFeasible;
            totalBitsPerUserHistory(iter + 1, :) = gbestRes.totalBitsPerUser;
            transmitPowerHistory(iter + 1, :) = reshape(gbestRes.pt(gbestRes.slotIdx), 1, []);
            % alphaTrace follows physical User ID, not weak-to-strong rank.
            alphaUserHistory(iter + 1, :, :) = reshape(gbestRes.alphaTrace(gbestRes.slotIdx, :), ...
                1, sim.numSteps - 1, sim.noUsers);
        end

        if mod(iter, 10) == 0 || iter == 1 || iter == maxIter
            fprintf(['Full Joint+BS PSO iter %3d/%3d | EE = %.4e bit/J | ', ...
                'L:%d bitSlot:%d bitUserSlot:%d | feasible:%d\n'], ...
                iter, maxIter, gbestRes.eeComputed, ...
                gbestRes.missionQoSFeasible, gbestRes.slotQoSFeasible, ...
                gbestRes.userSlotQoSFeasible, gbestRes.isFeasible);
        end
    end

    %% Dong goi ket qua
    best = gbestRes;

    best.bestParticle = gbestPos;
    best.bestFitness = gbestVal;
    best.bestEE = best.eeComputed;
    best.bestFeasible = best.isFeasible;
    best.bestHistory = bestHistory;
    if trackEE
        best.totalBitsHistory = totalBitsHistory;
        best.totalEnergyHistory = totalEnergyHistory;
        best.flightEnergyHistory = flightEnergyHistory;
        best.hoverEnergyHistory = hoverEnergyHistory;
        best.rfEnergyHistory = rfEnergyHistory;
        best.missionTimeHistory = missionTimeHistory;
        best.totalDistanceHistory = totalDistanceHistory;
        best.feasibleHistory = feasibleHistory;
        best.totalBitsPerUserHistory = totalBitsPerUserHistory;
        best.transmitPowerHistory = transmitPowerHistory;
        best.alphaUserHistory = alphaUserHistory;
    end

    best.mode = 'v10-full-pso';

    best.numParticles = numParticles;
    best.maxIter = maxIter;
    best.w = w;
    best.c1 = c1;
    best.c2 = c2;
end

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
