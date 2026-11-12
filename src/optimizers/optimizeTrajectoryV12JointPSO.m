function best = optimizeTrajectoryV12JointPSO(sim, opts)

% Moi particle:
%   particle = [xInternal, optionalYInternal, rawPowerAllSteps]
%
% rawPowerAllSteps co kich thuoc = T * noUsers
    if nargin < 2
        opts = struct();
    end

    numParticles = getOptField(opts, 'numParticles', 70);
    maxIter      = getOptField(opts, 'maxIter', 150);
    w            = getOptField(opts, 'w', 0.7);
    c1           = getOptField(opts, 'c1', 1.5);
    c2           = getOptField(opts, 'c2', 1.5);

    %% Kich thuoc particle
    validateattributes(numParticles, {'numeric'}, {'scalar','finite','integer','positive'});
    validateattributes(maxIter, {'numeric'}, {'scalar','finite','integer','nonnegative'});
    validateattributes(c1, {'numeric'}, {'scalar','finite','real','nonnegative'});
    validateattributes(c2, {'numeric'}, {'scalar','finite','real','nonnegative'});

    T = sim.numSteps;
    noUsers = sim.noUsers;

    layout = v10ParticleLayout(sim, false);
    D_pos = layout.positionCount;
    D_pow = T * noUsers;
    D = D_pos + D_pow;

    initMode = lower(char(getOptField(opts, 'initMode', getSimField(sim, 'initMode', 'v10'))));
    switch initMode
        case 'clustered'
            useClustered = true;
        case 'v10'
            useClustered = false;
        otherwise
            error('optimizeTrajectoryV12JointPSO:InitMode', ...
                'initMode must be ''v10'' or ''clustered''.');
    end

    updateMode = lower(char(getOptField(opts, 'updateMode', getSimField(sim, 'updateMode', 'independent'))));
    switch updateMode
        case 'correlated'
            useCorrelated = true;
        case 'independent'
            useCorrelated = false;
        otherwise
            error('optimizeTrajectoryV12JointPSO:UpdateMode', ...
                'updateMode must be ''independent'' or ''correlated''.');
    end

    mutationMode = lower(char(getOptField(opts, 'mutationMode', getSimField(sim, 'mutationMode', 'elementwise'))));
    if ~any(strcmp(mutationMode, {'elementwise', 'block', 'none'}))
        error('optimizeTrajectoryV12JointPSO:MutationMode', ...
            'mutationMode must be ''elementwise'', ''block'', or ''none''.');
    end

    maxEvals = parseMaxEvals(opts);

    seedParticle = [];
    if isfield(opts, 'seedJointParticle') && ~isempty(opts.seedJointParticle)
        seedParticle = opts.seedJointParticle;
    elseif isfield(opts, 'seedParticle') && ~isempty(opts.seedParticle)
        seedParticle = opts.seedParticle;
    end
    hasSeed = ~isempty(seedParticle) && numel(seedParticle) == D && all(isfinite(seedParticle(:)));
    if hasSeed
        seedParticle = reshape(seedParticle, 1, D);
    end
    hasSeedResult = hasSeed && isfield(opts, 'seedResult') && isstruct(opts.seedResult) ...
        && isfield(opts.seedResult, 'fitness');

    defaultInitEvals = double(hasSeedResult);
    initialEvalCount = getOptField(opts, 'initialEvalCount', defaultInitEvals);
    validateattributes(initialEvalCount, {'numeric'}, {'scalar','finite','integer','nonnegative'});
    initialEvalCount = double(initialEvalCount);
    evalCount = initialEvalCount;
    requiredInitialEvals = initialEvalCount + numParticles - double(hasSeedResult);
    if isfinite(maxEvals) && maxEvals < requiredInitialEvals
        error('optimizeTrajectoryV12JointPSO:MaxEvals', ...
            'maxEvals must cover initialEvalCount plus complete swarm initialization.');
    end

    seedSource = '';
    if hasSeed && isfield(opts, 'seedSource') && ~isempty(opts.seedSource)
        seedSource = char(opts.seedSource);
    end
    seedParticleFinal = [];
    seedEE = NaN;
    seedFeasible = NaN;

    %% Khoi tao bo nho PSO
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

    %% Khoi tao bay dan
    for i = 1:numParticles
        if i > 1 && evalCount >= maxEvals
            break;
        end

        if useClustered
            particlesPos(i, :) = initialV12Particle(sim, false, i > 1);
        else
            particlesPos(i, :) = initialV10Particle(sim, false, i > 1);
        end

        particlesVel(i, :) = zeros(1, D);

        if i == 1 && hasSeed
            particlesPos(1, :) = seedParticle;
            if hasSeedResult
                res_i = opts.seedResult;
                fit_i = res_i.fitness;
            else
                if evalCount >= maxEvals
                    error('optimizeTrajectoryV12JointPSO:MaxEvals', ...
                        'initialEvalCount must be < maxEvals when seedResult is omitted.');
                end
                [fit_i, res_i] = evaluateTrajectoryV12(particlesPos(1, :), sim, false);
                evalCount = evalCount + 1;
                if ~res_i.geometryFeasible && evalCount < maxEvals
                    particlesPos(1, :) = repairV10Particle(particlesPos(1, :), sim, false);
                    [fit_i, res_i] = evaluateTrajectoryV12(particlesPos(1, :), sim, false);
                    evalCount = evalCount + 1;
                end
            end
            seedParticleFinal = particlesPos(1, :);
            seedEE = res_i.eeComputed;
            seedFeasible = double(res_i.isFeasible);
        else
            if evalCount >= maxEvals
                if i == 1
                    error('optimizeTrajectoryV12JointPSO:MaxEvals', ...
                        'initialEvalCount must be < maxEvals when no seedResult is supplied.');
                end
                break;
            end
            particlesPos(i, :) = repairV10Particle(particlesPos(i, :), sim, false);
            [fit_i, res_i] = evaluateTrajectoryV12(particlesPos(i, :), sim, false);
            evalCount = evalCount + 1;
        end

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
    lastHistIdx = 1;

    %% 7. Vong lap PSO
    for iter = 1:maxIter
        if evalCount >= maxEvals
            break;
        end

        for i = 1:numParticles
            if evalCount >= maxEvals
                break;
            end

            if useCorrelated
                r1 = drawCorrelatedR(layout, D);
                r2 = drawCorrelatedR(layout, D);
            else
                r1 = rand(1, D);
                r2 = rand(1, D);
            end

            particlesVel(i, :) = w * particlesVel(i, :) + c1 * r1 .* (pbestPos(i, :) - particlesPos(i, :)) + c2 * r2 .* (gbestPos - particlesPos(i, :));

            particlesPos(i, :) = particlesPos(i, :) + particlesVel(i, :);

            particlesPos(i, :) = repairV10Particle(particlesPos(i, :), sim, false);

            [fit_i, res_i] = evaluateTrajectoryV12(particlesPos(i, :), sim, false);
            evalCount = evalCount + 1;

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
        lastHistIdx = iter + 1;

        if mod(iter, 10) == 0 || iter == 1 || iter == maxIter || evalCount >= maxEvals
            fprintf(['Joint PSO iter %3d/%3d | EE = %.4e bit/J | ', ...
                'L:%d bitSlot:%d bitUserSlot:%d | feasible:%d\n'], ...
                iter, maxIter, gbestRes.eeComputed, ...
                gbestRes.missionQoSFeasible, gbestRes.slotQoSFeasible, ...
                gbestRes.userSlotQoSFeasible, gbestRes.isFeasible);
        end

        if evalCount >= maxEvals
            break;
        end
    end

    if lastHistIdx < maxIter + 1
        padIdx = (lastHistIdx + 1):(maxIter + 1);
        bestHistory(padIdx) = gbestVal;
        if trackEE
            totalBitsHistory(padIdx) = gbestRes.totalBits;
            totalEnergyHistory(padIdx) = gbestRes.totalEnergy;
            flightEnergyHistory(padIdx) = gbestRes.flightEnergy;
            hoverEnergyHistory(padIdx) = gbestRes.hoverEnergy;
            rfEnergyHistory(padIdx) = gbestRes.rfEnergy;
            missionTimeHistory(padIdx) = gbestRes.missionTime;
            totalDistanceHistory(padIdx) = gbestRes.totalDistance;
            feasibleHistory(padIdx) = gbestRes.isFeasible;
            totalBitsPerUserHistory(padIdx, :) = repmat(gbestRes.totalBitsPerUser, numel(padIdx), 1);
            ptRow = reshape(gbestRes.pt(gbestRes.slotIdx), 1, []);
            transmitPowerHistory(padIdx, :) = repmat(ptRow, numel(padIdx), 1);
            alphaSlice = reshape(gbestRes.alphaTrace(gbestRes.slotIdx, :), ...
                1, sim.numSteps - 1, sim.noUsers);
            alphaUserHistory(padIdx, :, :) = repmat(alphaSlice, numel(padIdx), 1, 1);
        end
    end

    %% 8. Dong goi ket qua
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
    best.mode = 'v12-joint-pso';

    best.numParticles = numParticles;
    best.maxIter = maxIter;
    best.maxEvals = maxEvals;
    best.w = w;
    best.c1 = c1;
    best.c2 = c2;
    best.evalCount = evalCount;
    best.evalCountRaw = evalCount;
    best.evalCountIncumbentRaw = initialEvalCount;
    best.initMode = initMode;
    best.updateMode = updateMode;
    best.mutationMode = mutationMode;
    best.useClustered = useClustered;
    best.incumbentUsed = hasSeed;
    if hasSeed
        best.incumbentRetained = max(abs(gbestPos - seedParticleFinal)) <= 1e-15;
    else
        best.incumbentRetained = false;
    end
    best.incumbentEE = seedEE;
    best.incumbentFeasible = seedFeasible;
    best.incumbentSource = seedSource;
end

function maxEvals = parseMaxEvals(opts)
    if ~isfield(opts, 'maxEvals') || isempty(opts.maxEvals)
        maxEvals = Inf;
        return;
    end
    val = opts.maxEvals;
    validateattributes(val, {'numeric'}, {'scalar', 'real'});
    if isnan(val) || (isinf(val) && val > 0)
        maxEvals = Inf;
    else
        validateattributes(val, {'numeric'}, {'scalar', 'finite', 'integer', 'positive'});
        maxEvals = double(val);
    end
end

function r = drawCorrelatedR(layout, D)
    r = zeros(1, D);
    nx = numel(layout.x);
    r(layout.x) = 0.85 * rand + 0.15 * rand(1, nx);
    if ~isempty(layout.y)
        ny = numel(layout.y);
        r(layout.y) = 0.85 * rand + 0.15 * rand(1, ny);
    end
    if layout.positionCount < D
        r((layout.positionCount + 1):D) = rand(1, D - layout.positionCount);
    end
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
