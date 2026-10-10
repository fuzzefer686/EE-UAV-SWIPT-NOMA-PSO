function best = optimizeTrajectory_JointBS_IPSO_SWIPT_clean(sim, opts)

% Particle:
%   [xInternal, zInternal, rawPowerAllSteps, xBS, yBS]

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

    T = sim.numSteps;
    nInternal = T - 2;
    noUsers = sim.noUsers;
    noBS = sim.noBS;

    D_pos = 2 * nInternal;
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

    %% Khoi tao baseline
    xBase = linspace(sim.xStart, sim.xEnd, T);
    zBase = linspace(sim.zStart, sim.zEnd, T);
    alphaBase = ones(T, noUsers) / noUsers;

    baseFullParticle = [xBase(2:end-1), zBase(2:end-1), reshape(alphaBase.', 1, []), sim.xBS, sim.yBS];

    hasSeedFull = isfield(opts, 'seedFullParticle') &&  ~isempty(opts.seedFullParticle) && numel(opts.seedFullParticle) == D;

    %% Khoi tao bay dan
    for i = 1:numParticles
        if i == 1 && hasSeedFull
            particlesPos(i, :) = opts.seedFullParticle;
        elseif i == 1
            particlesPos(i, :) = baseFullParticle;
        else
            particlesPos(i, 1:nInternal) = sim.x_min + rand(1, nInternal) * (sim.x_max - sim.x_min);
            particlesPos(i, nInternal+1:2*nInternal) = sim.z_min + rand(1, nInternal) * (sim.z_max - sim.z_min);
            particlesPos(i, D_pos+1:D_pos+D_pow) = pMin + rand(1, D_pow) * (pMax - pMin);
            particlesPos(i, D_pos+D_pow+1:D_pos+D_pow+noBS) = sim.xBS_min + rand(1, noBS) .* (sim.xBS_max - sim.xBS_min);
            particlesPos(i, D_pos+D_pow+noBS+1:end) = sim.yBS_min + rand(1, noBS) .* (sim.yBS_max - sim.yBS_min);
        end

        particlesVel(i, :) = zeros(1, D);
        particlesPos(i, :) = repairFullParticle(particlesPos(i, :), sim, pMin, pMax);

        [fit_i, res_i] = evaluateTrajectory_JointBS_SWIPT_clean(particlesPos(i, :), sim);

        pbestPos(i, :) = particlesPos(i, :);
        pbestVal(i) = fit_i;

        if fit_i > gbestVal
            gbestVal = fit_i;
            gbestPos = particlesPos(i, :);
            gbestRes = res_i;
        end
    end

    bestHistory(1) = gbestVal;
    lastImproveIter = 0;
    
    %% IPSO loop
    for iter = 1:maxIter
        w_current = w_max - (w_max - w_min) * sqrt(iter / maxIter);
        for i = 1:numParticles
            r1 = rand(1, D);
            r2 = rand(1, D);

            particlesVel(i, :) = w_current * particlesVel(i, :) + c1 * r1 .* (pbestPos(i, :) - particlesPos(i, :)) + c2 * r2 .* (gbestPos - particlesPos(i, :));

            particlesPos(i, :) = particlesPos(i, :) + particlesVel(i, :);

            particlesPos(i, :) = repairFullParticle(particlesPos(i, :), sim, pMin, pMax);

            [fit_i, res_i] = evaluateTrajectory_JointBS_SWIPT_clean(particlesPos(i, :), sim);

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
                trialPos = repairFullParticle(trialPos, sim, pMin, pMax);
        
                % Evaluate trial
                [fitTrial, resTrial] = evaluateTrajectory_JointBS_SWIPT_clean(trialPos, sim);
        
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

        if mod(iter, 10) == 0 || iter == 1 || iter == maxIter
            fprintf('Full Joint+BS IPSO iter %3d/%3d | best fitness = %.4e bps\n', iter, maxIter, gbestVal);
        end
    end

    %% Dong goi ket qua
    best = gbestRes;

    best.bestParticle = gbestPos;
    best.bestFitness = gbestVal;
    best.bestHistory = bestHistory;

    best.mode = 'full-joint-bs-ipso-swipt-clean';

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

function particle = repairFullParticle(particle, sim, pMin, pMax)
    T = sim.numSteps; nInternal = T - 2; noUsers = sim.noUsers; noBS = sim.noBS;
    D_pos = 2 * nInternal; D_pow = T * noUsers;

    posBlock = particle(1:D_pos);
    posBlock = repairPositionBlock(posBlock, sim);

    rawP = real(particle(D_pos+1:D_pos+D_pow));
    rawP = min(max(rawP, pMin), pMax);
    rawP = reshape(rawP, noUsers, T).';   
    rowSum = sum(rawP, 2);
    bad = rowSum <= 0;
    if any(bad)
        rawP(bad, :) = 1 / noUsers;
        rowSum = sum(rawP, 2);
    end
    rawP = rawP ./ rowSum;
    powBlock = reshape(rawP.', 1, []);

    bsBlock = real(particle(D_pos+D_pow+1:end));
    xBS = bsBlock(1:noBS); yBS = bsBlock(noBS+1:end);
    xBS = min(max(xBS, sim.xBS_min), sim.xBS_max);
    yBS = min(max(yBS, sim.yBS_min), sim.yBS_max);
    bsBlock = [xBS, yBS];

    particle = [posBlock, powBlock, bsBlock];
end

function posBlock = repairPositionBlock(posBlock, sim)
    T = sim.numSteps; nInternal = T - 2;
    xInternal = real(posBlock(1:nInternal)); zInternal = real(posBlock(nInternal+1:end));
    xInternal = min(max(xInternal, sim.x_min), sim.x_max);
    zInternal = min(max(zInternal, sim.z_min), sim.z_max);

    xTraj = [sim.xStart, xInternal, sim.xEnd]; zTraj = [sim.zStart, zInternal, sim.zEnd];
    xTraj(1) = sim.xStart; xTraj(end) = sim.xEnd;
    zTraj(1) = sim.zStart; zTraj(end) = sim.zEnd;
    zTraj(2:end-1) = min(max(zTraj(2:end-1), sim.z_min), sim.z_max);

    for pass = 1:3
        for t = 2:(T-1)
            lo = max(sim.x_min, xTraj(t-1) - sim.dxMax); hi = min(sim.x_max, xTraj(t-1) + sim.dxMax);
            xTraj(t) = min(max(xTraj(t), lo), hi);
        end
        for t = (T-1):-1:2
            lo = max(sim.x_min, xTraj(t+1) - sim.dxMax); hi = min(sim.x_max, xTraj(t+1) + sim.dxMax);
            xTraj(t) = min(max(xTraj(t), lo), hi);
        end
    end

    if isfield(sim, 'dzMax') && ~isempty(sim.dzMax)
        for pass = 1:3
            for t = 2:(T-1)
                lo = max(sim.z_min, zTraj(t-1) - sim.dzMax); hi = min(sim.z_max, zTraj(t-1) + sim.dzMax);
                zTraj(t) = min(max(zTraj(t), lo), hi);
            end
            for t = (T-1):-1:2
                lo = max(sim.z_min, zTraj(t+1) - sim.dzMax); hi = min(sim.z_max, zTraj(t+1) + sim.dzMax);
                zTraj(t) = min(max(zTraj(t), lo), hi);
            end
        end
    end

    xTraj(2:end-1) = min(max(xTraj(2:end-1), sim.x_min), sim.x_max);
    zTraj(2:end-1) = min(max(zTraj(2:end-1), sim.z_min), sim.z_max);
    posBlock = [xTraj(2:end-1), zTraj(2:end-1)];
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