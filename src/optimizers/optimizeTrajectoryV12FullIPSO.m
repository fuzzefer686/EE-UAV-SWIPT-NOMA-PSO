function best = optimizeTrajectoryV12FullIPSO(sim, opts)

% Particle:
%   [xInternal, optionalYInternal, rawPowerAllSteps, xBS, yBS]

    if nargin < 2
        opts = struct();
    end

    numParticles = getOptField(opts, 'numParticles', 100);
    maxIter      = getOptField(opts, 'maxIter', 250);

    % lay w_max, w_min va ty le dot bien
    w_max        = getOptField(opts, 'w_max', 0.9);
    w_min        = getOptField(opts, 'w_min', 0.4);
    % Adaptive mutation setting
    mutRateLow = getOptField(opts, 'mutRateLow', 0.02);
    mutParticleRateLow = getOptField(opts, 'mutParticleRateLow', 0.05);

    mutRateHigh = getOptField(opts, 'mutRateHigh', 0.08);
    mutParticleRateHigh = getOptField(opts, 'mutParticleRateHigh', 0.20);

    stallIter = getOptField(opts, 'stallIter', 100);
    eliteRate = getOptField(opts, 'eliteRate', 0.05);

    sigmaScaleLow = getOptField(opts, 'sigmaScaleLow', 0.03);
    sigmaScaleHigh = getOptField(opts, 'sigmaScaleHigh', 0.05);

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

    initMode = lower(char(getOptField(opts, 'initMode', getSimField(sim, 'initMode', 'v10'))));
    switch initMode
        case 'clustered'
            useClustered = true;
        case 'v10'
            useClustered = false;
        otherwise
            error('optimizeTrajectoryV12FullIPSO:InitMode', ...
                'initMode must be ''v10'' or ''clustered''.');
    end

    updateMode = lower(char(getOptField(opts, 'updateMode', getSimField(sim, 'updateMode', 'independent'))));
    switch updateMode
        case 'correlated'
            useCorrelated = true;
        case 'independent'
            useCorrelated = false;
        otherwise
            error('optimizeTrajectoryV12FullIPSO:UpdateMode', ...
                'updateMode must be ''independent'' or ''correlated''.');
    end

    mutationMode = lower(char(getOptField(opts, 'mutationMode', getSimField(sim, 'mutationMode', 'elementwise'))));
    switch mutationMode
        case 'block'
            useBlockMutation = true;
        case 'elementwise'
            useBlockMutation = false;
        otherwise
            error('optimizeTrajectoryV12FullIPSO:MutationMode', ...
                'mutationMode must be ''elementwise'' or ''block''.');
    end

    maxEvals = parseMaxEvals(opts);

    requiredFields = {'xBS_min', 'xBS_max', 'yBS_min', 'yBS_max'};
    for k = 1:numel(requiredFields)
        if ~isfield(sim, requiredFields{k})
            error('optimizeTrajectoryV12FullIPSO:MissingField', 'sim thieu field %s.', requiredFields{k});
        end
    end

    seedParticle = [];
    if isfield(opts, 'seedFullParticle') && ~isempty(opts.seedFullParticle)
        seedParticle = opts.seedFullParticle;
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
        error('optimizeTrajectoryV12FullIPSO:MaxEvals', ...
            'maxEvals must cover initialEvalCount plus complete swarm initialization.');
    end

    seedSource = '';
    if hasSeed && isfield(opts, 'seedSource') && ~isempty(opts.seedSource)
        seedSource = char(opts.seedSource);
    end
    seedParticleFinal = [];
    seedEE = NaN;
    seedFeasible = NaN;

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

    %% Khoi tao bay dan
    for i = 1:numParticles
        if i > 1 && evalCount >= maxEvals
            break;
        end

        if useClustered
            particlesPos(i, :) = initialV12Particle(sim, true, i > 1);
        else
            particlesPos(i, :) = initialV10Particle(sim, true, i > 1);
        end

        particlesVel(i, :) = zeros(1, D);

        if i == 1 && hasSeed
            particlesPos(1, :) = seedParticle;
            if hasSeedResult
                res_i = opts.seedResult;
                fit_i = res_i.fitness;
            else
                if evalCount >= maxEvals
                    error('optimizeTrajectoryV12FullIPSO:MaxEvals', ...
                        'initialEvalCount must be < maxEvals when seedResult is omitted.');
                end
                [fit_i, res_i] = evaluateTrajectoryV12(particlesPos(1, :), sim, true);
                evalCount = evalCount + 1;
                if ~res_i.geometryFeasible && evalCount < maxEvals
                    particlesPos(1, :) = repairV10Particle(particlesPos(1, :), sim, true);
                    [fit_i, res_i] = evaluateTrajectoryV12(particlesPos(1, :), sim, true);
                    evalCount = evalCount + 1;
                end
            end
            seedParticleFinal = particlesPos(1, :);
            seedEE = res_i.eeComputed;
            seedFeasible = double(res_i.isFeasible);
        else
            if evalCount >= maxEvals
                if i == 1
                    error('optimizeTrajectoryV12FullIPSO:MaxEvals', ...
                        'initialEvalCount must be < maxEvals when no seedResult is supplied.');
                end
                break;
            end
            particlesPos(i, :) = repairV10Particle(particlesPos(i, :), sim, true);
            [fit_i, res_i] = evaluateTrajectoryV12(particlesPos(i, :), sim, true);
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
    lastImproveIter = 0;

    %% IPSO loop
    for iter = 1:maxIter
        if evalCount >= maxEvals
            break;
        end

        if isfinite(maxEvals)
            evalProgress = evalCount / max(1, maxEvals - numParticles);
        else
            evalProgress = 0;
        end
        progress = min(1, max(iter / max(1, maxIter), evalProgress));
        w_current = w_max - (w_max - w_min) * sqrt(progress);

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

            particlesVel(i, :) = w_current * particlesVel(i, :) + c1 * r1 .* (pbestPos(i, :) - particlesPos(i, :)) + c2 * r2 .* (gbestPos - particlesPos(i, :));

            particlesPos(i, :) = particlesPos(i, :) + particlesVel(i, :);

            particlesPos(i, :) = repairV10Particle(particlesPos(i, :), sim, true);

            [fit_i, res_i] = evaluateTrajectoryV12(particlesPos(i, :), sim, true);
            evalCount = evalCount + 1;

            if fit_i > pbestVal(i)
                pbestVal(i) = fit_i;
                pbestPos(i, :) = particlesPos(i, :);
            end

            if fit_i > gbestVal
                gbestVal = fit_i;
                gbestPos = particlesPos(i, :);
                gbestRes = res_i;
                lastImproveIter = iter;
            end
        end

        %% Adaptive safe mutation based on stagnation
        if evalCount < maxEvals
            stallCount = iter - lastImproveIter;

            if stallCount >= stallIter
                curMutRate = mutRateHigh;
                curMutParticleRate = mutParticleRateHigh;
                curSigmaScale = sigmaScaleHigh;
            else
                curMutRate = mutRateLow;
                curMutParticleRate = mutParticleRateLow;
                curSigmaScale = sigmaScaleLow;
            end

            numElite = max(1, round(eliteRate * numParticles));
            numMutParticles = max(1, round(curMutParticleRate * numParticles));
            [~, sortIdx] = sort(pbestVal, 'ascend');
            weakPool = sortIdx(1 : max(1, numParticles - numElite));

            numMutParticles = min(numMutParticles, numel(weakPool));
            mutParticleIdx = weakPool(randperm(numel(weakPool), numMutParticles));

            for kk = 1:numMutParticles
                if evalCount >= maxEvals
                    break;
                end
                k = mutParticleIdx(kk);
                oldPos = particlesPos(k, :);

                if useBlockMutation
                    % Block mutation around personal best to preserve contiguous hover clusters
                    trialPos = pbestPos(k, :);
                    uMut = rand;
                    if uMut < 0.60
                        ab = sort(randi(nInternal, 1, 2));
                        seg = ab(1):ab(2);
                        trialPos(layout.x(seg)) = trialPos(layout.x(seg)) + 12 * randn;
                        if ~isempty(layout.y)
                            trialPos(layout.y(seg)) = trialPos(layout.y(seg)) + 20 * randn;
                        end
                        if ~isempty(layout.xBS) && rand < 0.35
                            trialPos(layout.xBS) = trialPos(layout.xBS) + 8 * randn(1, noBS);
                            trialPos(layout.yBS) = trialPos(layout.yBS) + 8 * randn(1, noBS);
                        end
                    elseif uMut < 0.85
                        ab = sort(randi(nInternal, 1, 2));
                        seg = ab(1):ab(2);
                        trialPos(layout.x(seg)) = mean(trialPos(layout.x(seg))) + 8 * randn;
                        if ~isempty(layout.y)
                            yMid = mean(trialPos(layout.y(seg))) + 12 * randn;
                            offsets = ((1:numel(seg)) - 0.5 * (numel(seg) + 1)) * sim.minYProgress;
                            trialPos(layout.y(seg)) = yMid + sim.yDirection * offsets;
                        end
                    else
                        nonPosIdx = (layout.positionCount + 1):D;
                        subMask = rand(1, numel(nonPosIdx)) < max(curMutRate, 0.10);
                        if ~any(subMask)
                            subMask(randi(numel(nonPosIdx))) = true;
                        end
                        targetIdx = nonPosIdx(subMask);
                        sigma = curSigmaScale * abs(trialPos(targetIdx)) + 1e-2;
                        trialPos(targetIdx) = trialPos(targetIdx) + randn(1, numel(targetIdx)) .* sigma;
                    end
                    doEvalTrial = true;
                else
                    % Tao trial rieng, khong pha truc tiep hat hien tai
                    trialPos = oldPos;
                    mutMask = rand(1, D) < curMutRate;
                    doEvalTrial = any(mutMask);
                    if doEvalTrial
                        sigma = curSigmaScale * abs(trialPos(mutMask)) + 1e-3;
                        trialPos(mutMask) = trialPos(mutMask) + randn(1, sum(mutMask)) .* sigma;
                    end
                end

                if doEvalTrial
                    trialPos = repairV10Particle(trialPos, sim, true);
                    [fitTrial, resTrial] = evaluateTrajectoryV12(trialPos, sim, true);
                    evalCount = evalCount + 1;

                    if fitTrial > pbestVal(k)
                        particlesPos(k, :) = trialPos;
                        pbestVal(k) = fitTrial;
                        pbestPos(k, :) = trialPos;
                        particlesVel(k, :) = zeros(1, D);

                        if fitTrial > gbestVal
                            gbestVal = fitTrial;
                            gbestPos = trialPos;
                            gbestRes = resTrial;
                            lastImproveIter = iter;
                        end
                    else
                        particlesPos(k, :) = oldPos;
                    end
                end
            end
        end

        bestHistory(iter + 1) = gbestVal;
        if trackEE
            % Record after mutation, so EE, bits and energy use the same gbest.
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
            fprintf(['Full Joint+BS IPSO iter %3d/%3d | EE = %.4e bit/J | ', ...
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

    best.mode = 'v12-full-ipso';

    best.numParticles = numParticles;
    best.maxIter = maxIter;
    best.maxEvals = maxEvals;
    best.w_max = w_max;
    best.w_min = w_min;
    best.c1 = c1;
    best.c2 = c2;
    best.mutRateLow = mutRateLow;
    best.mutParticleRateLow = mutParticleRateLow;
    best.mutRateHigh = mutRateHigh;
    best.mutParticleRateHigh = mutParticleRateHigh;
    best.stallIter = stallIter;
    best.eliteRate = eliteRate;
    best.sigmaScaleLow = sigmaScaleLow;
    best.sigmaScaleHigh = sigmaScaleHigh;
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
