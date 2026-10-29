function best = optimizeTrajectoryV10FullIPSO(sim, opts)

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

    pMin = getSimField(sim, 'pMin', 1e-3);
    pMax = getSimField(sim, 'pMax', 1.0);

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
    lastImproveIter = 0;
    
    %% IPSO loop
    for iter = 1:maxIter
        w_current = w_max - (w_max - w_min) * sqrt(iter / maxIter);
        for i = 1:numParticles
            r1 = rand(1, D);
            r2 = rand(1, D);

            particlesVel(i, :) = w_current * particlesVel(i, :) + c1 * r1 .* (pbestPos(i, :) - particlesPos(i, :)) + c2 * r2 .* (gbestPos - particlesPos(i, :));

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
                lastImproveIter = iter;
            end
        end

        %% Adaptive safe mutation based on stagnation

        % So vong lap da troi qua ke tu lan cuoi gbest duoc cai thien
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
        
        % Khong mutation nhom elite tot nhat
        numElite = max(1, round(eliteRate * numParticles));
        
        % So hat duoc thu mutation trong iteration nay
        numMutParticles = max(1, round(curMutParticleRate * numParticles));
        
        % Sap xep theo pbest tu te nhat den tot nhat
        [~, sortIdx] = sort(pbestVal, 'ascend');
        
        % Chi mutation nhom yeu hon, khong dong vao top elite
        weakPool = sortIdx(1 : max(1, numParticles - numElite));
        
        numMutParticles = min(numMutParticles, numel(weakPool));
        mutParticleIdx = weakPool(randperm(numel(weakPool), numMutParticles));
        
        for kk = 1:numMutParticles
            k = mutParticleIdx(kk);
        
            oldPos = particlesPos(k, :);
        
            % Tao trial rieng, khong pha truc tiep hat hien tai
            trialPos = oldPos;
        
            mutMask = rand(1, D) < curMutRate;
        
            if any(mutMask)
                sigma = curSigmaScale * abs(trialPos(mutMask)) + 1e-3;
        
                trialPos(mutMask) = trialPos(mutMask) + randn(1, sum(mutMask)) .* sigma;
        
                % Repair trial sau mutation
                trialPos = repairV10Particle(trialPos, sim, true);
        
                % Evaluate trial
                [fitTrial, resTrial] = evaluateTrajectoryV10(trialPos, sim, true);
        
                % Safe accept:
                % Chi nhan mutation neu trial tot hon pbest cua hat do
                if fitTrial > pbestVal(k)
                    particlesPos(k, :) = trialPos;
                    pbestVal(k) = fitTrial;
                    pbestPos(k, :) = trialPos;
        
                    % Reset velocity nhe de hat khong bi keo nguoc qua manh
                    particlesVel(k, :) = zeros(1, D);
        
                    if fitTrial > gbestVal
                        gbestVal = fitTrial;
                        gbestPos = trialPos;
                        gbestRes = resTrial;
                        lastImproveIter = iter;
                    end
                else
                    % Neu mutation khong tot hon, giu nguyen hat cu
                    particlesPos(k, :) = oldPos;
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

        if mod(iter, 10) == 0 || iter == 1 || iter == maxIter
            fprintf(['Full Joint+BS IPSO iter %3d/%3d | EE = %.4e bit/J | ', ...
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

    best.mode = 'v10-full-ipso';

    best.numParticles = numParticles;
    best.maxIter = maxIter;
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
