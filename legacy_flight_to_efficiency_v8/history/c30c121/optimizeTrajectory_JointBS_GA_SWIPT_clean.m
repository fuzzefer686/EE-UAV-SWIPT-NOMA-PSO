function best = optimizeTrajectory_JointBS_GA_SWIPT_clean(sim, opts)

    if nargin < 2
        opts = struct();
    end

    numParticles = getOptField(opts, 'numParticles', 100);
    maxIter      = getOptField(opts, 'maxIter', 250);
    
    % Tham số của GA
    crossRate    = getOptField(opts, 'crossRate', 0.8); % Tỷ lệ lai ghép 80%
    mutRate      = getOptField(opts, 'mutRate', 0.1);   % Tỷ lệ đột biến 10%

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

    %% Bộ nhớ GA
    popPos = zeros(numParticles, D);
    popFit = -inf * ones(numParticles, 1);
    popRes = cell(numParticles, 1);

    gbestPos = zeros(1, D);
    gbestVal = -inf;
    gbestRes = struct();

    bestHistory = zeros(maxIter + 1, 1);

    %% Khởi tạo Baseline & Seed
    xBase = linspace(sim.xStart, sim.xEnd, T);
    zBase = linspace(sim.zStart, sim.zEnd, T);
    alphaBase = ones(T, noUsers) / noUsers;

    baseFullParticle = [xBase(2:end-1), zBase(2:end-1), reshape(alphaBase.', 1, []), sim.xBS, sim.yBS];
    hasSeedFull = isfield(opts, 'seedFullParticle') &&  ~isempty(opts.seedFullParticle) && numel(opts.seedFullParticle) == D;

    %% Khởi tạo Quần thể ban đầu
    for i = 1:numParticles
        if i == 1 && hasSeedFull
            popPos(i, :) = opts.seedFullParticle;
        elseif i == 1
            popPos(i, :) = baseFullParticle;
        else
            popPos(i, 1:nInternal) = sim.x_min + rand(1, nInternal) * (sim.x_max - sim.x_min);
            popPos(i, nInternal+1:2*nInternal) = sim.z_min + rand(1, nInternal) * (sim.z_max - sim.z_min);
            popPos(i, D_pos+1:D_pos+D_pow) = pMin + rand(1, D_pow) * (pMax - pMin);
            popPos(i, D_pos+D_pow+1:D_pos+D_pow+noBS) = sim.xBS_min + rand(1, noBS) .* (sim.xBS_max - sim.xBS_min);
            popPos(i, D_pos+D_pow+noBS+1:end) = sim.yBS_min + rand(1, noBS) .* (sim.yBS_max - sim.yBS_min);
        end

        popPos(i, :) = repairFullParticle(popPos(i, :), sim, pMin, pMax);
        [fit_i, res_i] = evaluateTrajectory_JointBS_SWIPT_clean(popPos(i, :), sim);
        
        popFit(i) = fit_i;
        popRes{i} = res_i;

        if fit_i > gbestVal
            gbestVal = fit_i;
            gbestPos = popPos(i, :);
            gbestRes = res_i;
        end
    end

    bestHistory(1) = gbestVal;

    %% GA Loop
    for iter = 1:maxIter
        
        newPopPos = zeros(numParticles, D);
        newPopFit = zeros(numParticles, 1);
        newPopRes = cell(numParticles, 1);
        
        % Đảm bảo số lượng cá thể chẵn để lai ghép
        numPairs = floor(numParticles / 2);
        
        idxCount = 1;
        for pair = 1:numPairs
            % Tournament selection ra 2 cha mẹ
            p1_idx = tournamentSelection(popFit, 3);
            p2_idx = tournamentSelection(popFit, 3);
            
            parent1 = popPos(p1_idx, :);
            parent2 = popPos(p2_idx, :);
            
            % Lai ghép số học
            if rand() < crossRate
                phi = rand(1, D); % Trọng số lai ghép ngẫu nhiên cho từng gene
                child1 = phi .* parent1 + (1 - phi) .* parent2;
                child2 = phi .* parent2 + (1 - phi) .* parent1;
            else
                child1 = parent1;
                child2 = parent2;
            end
            
            newPopPos(idxCount, :) = child1;
            newPopPos(idxCount+1, :) = child2;
            idxCount = idxCount + 2;
        end
        
        % Đột biến Gaussian
        for i = 1:numParticles
            mutMask = rand(1, D) < mutRate; 
            if any(mutMask)
                sigma = 0.05 * abs(newPopPos(i, mutMask)) + 1e-3; 
                newPopPos(i, mutMask) = newPopPos(i, mutMask) + randn(1, sum(mutMask)) .* sigma;
            end
            
            newPopPos(i, :) = repairFullParticle(newPopPos(i, :), sim, pMin, pMax);
            
            % Đánh giá lại fitness
            [fit_i, res_i] = evaluateTrajectory_JointBS_SWIPT_clean(newPopPos(i, :), sim);
            newPopFit(i) = fit_i;
            newPopRes{i} = res_i;
        end
        
        % Bảo tồn tinh hoa
        % Tìm cá thể tệ nhất trong thế hệ mới và thay bằng cá thể tốt nhất của thế hệ cũ
        [~, worstIdx] = min(newPopFit);
        newPopPos(worstIdx, :) = gbestPos;
        newPopFit(worstIdx) = gbestVal;
        newPopRes{worstIdx} = gbestRes;
        
        % Cập nhật Quần thể
        popPos = newPopPos;
        popFit = newPopFit;
        popRes = newPopRes;
        
        % Cập nhật Global Best
        [currentBestFit, bestIdx] = max(popFit);
        if currentBestFit > gbestVal
            gbestVal = currentBestFit;
            gbestPos = popPos(bestIdx, :);
            gbestRes = popRes{bestIdx};
        end

        bestHistory(iter + 1) = gbestVal;

        if mod(iter, 10) == 0 || iter == 1 || iter == maxIter
            fprintf('Full Joint+BS GA iter %3d/%3d | best fitness = %.4e bps\n', iter, maxIter, gbestVal);
        end
    end

    %% Đóng gói kết quả
    best = gbestRes;

    best.bestParticle = gbestPos;
    best.bestFitness = gbestVal;
    best.bestHistory = bestHistory;

    best.mode = 'full-joint-bs-ga-swipt-clean';

    best.numParticles = numParticles;
    best.maxIter = maxIter;
    best.crossRate = crossRate;
    best.mutRate = mutRate;
end

function idx = tournamentSelection(popFit, k)
    % Chọn k cá thể ngẫu nhiên, lấy người giỏi nhất
    pool = randi(length(popFit), k, 1);
    [~, bestPoolIdx] = max(popFit(pool));
    idx = pool(bestPoolIdx);
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