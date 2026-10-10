function best = optimizeTrajectory_JointBS_CCPSO_SWIPT_clean(sim, opts)
% OPTIMIZETRAJECTORY_JOINTBS_CCPSO_SWIPT_CLEAN
% Cooperative Co-evolutionary Joint PSO (CC-JointPSO) for UAV SWIPT-NOMA.
%
% Architecture:
%   Decomposes the 149-D decision vector into 3 cooperative sub-swarms:
%     - Sub-swarm 1 (Trajectory): D_pos = 2 * nInternal (38 dimensions)
%     - Sub-swarm 2 (BS Placement): D_bs  = 2 * noBS (6 dimensions)
%     - Sub-swarm 3 (Power Allocation alpha): D_pow = T * noUsers (105 dimensions)
%
%   A shared Context Vector (best known global combination) is maintained.
%   In each iteration, the 3 sub-swarms evolve round-robin, evaluating their
%   candidate sub-particles by stitching them into the Context Vector.
%
% Reference:
%   F. van den Bergh and A. P. Engelbrecht, "A Cooperative Approach to
%   Particle Swarm Optimization," IEEE Trans. Evol. Comput., 8(3), 2004.

    if nargin < 2
        opts = struct();
    end

    maxIter = getOptField(opts, 'maxIter', 1000);

    % Sub-swarm sizes (V8-SNAPSHOT-CCPSO Top)
    numParticlesPos = getOptField(opts, 'numParticlesPos', 100);
    numParticlesBS  = getOptField(opts, 'numParticlesBS',  30);
    numParticlesPow = getOptField(opts, 'numParticlesPow', 80);

    % General PSO parameters (can be customized per sub-swarm)
    w_pos  = getOptField(opts, 'w_pos',  0.7);
    c1_pos = getOptField(opts, 'c1_pos', 1.5);
    c2_pos = getOptField(opts, 'c2_pos', 1.5);

    w_bs   = getOptField(opts, 'w_bs',   0.7);
    c1_bs  = getOptField(opts, 'c1_bs',  1.5);
    c2_bs  = getOptField(opts, 'c2_bs',  1.5);

    w_pow  = getOptField(opts, 'w_pow',  0.7);
    c1_pow = getOptField(opts, 'c1_pow', 1.5);
    c2_pow = getOptField(opts, 'c2_pow', 1.5);

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

    %% 1. Kiem tra rang buoc BS
    requiredFields = {'xBS_min', 'xBS_max', 'yBS_min', 'yBS_max'};
    for k = 1:numel(requiredFields)
        if ~isfield(sim, requiredFields{k})
            error('optimizeTrajectory_JointBS_CCPSO_SWIPT_clean: sim thieu field %s.', requiredFields{k});
        end
    end

    %% 2. Khoi tao baseline & Context Vector
    xBase = linspace(sim.xStart, sim.xEnd, T);
    zBase = linspace(sim.zStart, sim.zEnd, T);
    alphaBase = ones(T, noUsers) / noUsers;

    basePos = [xBase(2:end-1), zBase(2:end-1)];
    basePow = reshape(alphaBase.', 1, []);
    baseBS  = [sim.xBS, sim.yBS];

    hasSeedFull = isfield(opts, 'seedFullParticle') && ~isempty(opts.seedFullParticle) && numel(opts.seedFullParticle) == D;

    if hasSeedFull
        contextPos = opts.seedFullParticle(1:D_pos);
        contextPow = opts.seedFullParticle(D_pos+1 : D_pos+D_pow);
        contextBS  = opts.seedFullParticle(D_pos+D_pow+1 : end);
    else
        contextPos = basePos;
        contextPow = basePow;
        contextBS  = baseBS;
    end

    % Đánh giá nghiệm khởi tạo ban đầu cho Context Vector
    initFull = [contextPos, contextPow, contextBS];
    [gbestVal, gbestRes] = evaluateTrajectory_JointBS_SWIPT_clean(initFull, sim);
    gbestPos = contextPos;
    gbestPow = contextPow;
    gbestBS  = contextBS;

    %% 3. Khoi tao Sub-swarm 1: Trajectory voi 4 hanh lang cau truc
    swarmPos = zeros(numParticlesPos, D_pos);
    velPos   = zeros(numParticlesPos, D_pos);
    pbestPos = zeros(numParticlesPos, D_pos);
    pbestValPos = -inf * ones(numParticlesPos, 1);

    vMaxPos = [repmat(0.20 * (sim.x_max - sim.x_min), 1, nInternal), ...
               repmat(0.15 * (sim.z_max - sim.z_min), 1, nInternal)];

    uMeanX = mean(sim.xUser);

    for i = 1:numParticlesPos
        if i == 1
            swarmPos(i, :) = contextPos;
        elseif i <= floor(numParticlesPos / 4)
            % Hanh lang 1: Huong ve trong tam Users
            xC = linspace(sim.xStart, uMeanX, T);
            swarmPos(i, 1:nInternal) = xC(2:end-1) + randn(1, nInternal) * 8;
            swarmPos(i, nInternal+1:end) = 18.0 + rand(1, nInternal) * 4;
        elseif i <= floor(2 * numParticlesPos / 4)
            % Hanh lang 2: Bay sat suon Dong quet BS 1 va BS 3 (SWIPT cuc dai)
            swarmPos(i, 1:nInternal) = 210.0 + randn(1, nInternal) * 10;
            swarmPos(i, nInternal+1:end) = 16.0 + rand(1, nInternal) * 3;
        elseif i <= floor(3 * numParticlesPos / 4)
            % Hanh lang 3: Duong bay truc dien do cao thap
            xC = linspace(sim.xStart, sim.xEnd, T);
            swarmPos(i, 1:nInternal) = xC(2:end-1) + randn(1, nInternal) * 10;
            swarmPos(i, nInternal+1:end) = sim.z_min + 1.0 + rand(1, nInternal) * 4;
        else
            % Hanh lang 4: Tham do ngau nhien toan khong gian
            swarmPos(i, 1:nInternal) = sim.x_min + rand(1, nInternal) * (sim.x_max - sim.x_min);
            swarmPos(i, nInternal+1:end) = sim.z_min + rand(1, nInternal) * (sim.z_max - sim.z_min);
        end
        swarmPos(i, :) = repairPositionBlock(swarmPos(i, :), sim);
        velPos(i, :) = zeros(1, D_pos);

        % Đánh giá qua Context Vector
        testVec = [swarmPos(i, :), gbestPow, gbestBS];
        [fit_i, res_i] = evaluateTrajectory_JointBS_SWIPT_clean(testVec, sim);
        pbestPos(i, :) = swarmPos(i, :);
        pbestValPos(i) = fit_i;

        if fit_i > gbestVal
            gbestVal = fit_i;
            gbestPos = swarmPos(i, :);
            gbestRes = res_i;
        end
    end
    contextPos = gbestPos;

    %% 4. Khoi tao Sub-swarm 2: BS Placement (6-D)
    swarmBS = zeros(numParticlesBS, D_bs);
    velBS   = zeros(numParticlesBS, D_bs);
    pbestBS = zeros(numParticlesBS, D_bs);
    pbestValBS = -inf * ones(numParticlesBS, 1);

    vMaxBS = 0.2 * max(sim.enWidth, sim.enLength);

    for i = 1:numParticlesBS
        if i == 1
            swarmBS(i, :) = contextBS;
        else
            xRand = sim.xBS_min + rand(1, noBS) .* (sim.xBS_max - sim.xBS_min);
            yRand = sim.yBS_min + rand(1, noBS) .* (sim.yBS_max - sim.yBS_min);
            swarmBS(i, :) = [xRand, yRand];
        end
        swarmBS(i, :) = repairBSBlock(swarmBS(i, :), sim);
        velBS(i, :) = zeros(1, D_bs);

        testVec = [gbestPos, gbestPow, swarmBS(i, :)];
        [fit_i, res_i] = evaluateTrajectory_JointBS_SWIPT_clean(testVec, sim);
        pbestBS(i, :) = swarmBS(i, :);
        pbestValBS(i) = fit_i;

        if fit_i > gbestVal
            gbestVal = fit_i;
            gbestBS  = swarmBS(i, :);
            gbestRes = res_i;
        end
    end
    contextBS = gbestBS;

    %% 5. Khoi tao Sub-swarm 3: Power Allocation alpha (105-D)
    swarmPow = zeros(numParticlesPow, D_pow);
    velPow   = zeros(numParticlesPow, D_pow);
    pbestPow = zeros(numParticlesPow, D_pow);
    pbestValPow = -inf * ones(numParticlesPow, 1);

    vMaxPow = 0.1; % Bước nhảy công suất nhích nhẹ

    for i = 1:numParticlesPow
        if i == 1
            swarmPow(i, :) = contextPow;
        else
            swarmPow(i, :) = pMin + rand(1, D_pow) * (pMax - pMin);
        end
        swarmPow(i, :) = repairAlphaBlock(swarmPow(i, :), sim, pMin, pMax);
        velPow(i, :) = zeros(1, D_pow);

        testVec = [gbestPos, swarmPow(i, :), gbestBS];
        [fit_i, res_i] = evaluateTrajectory_JointBS_SWIPT_clean(testVec, sim);
        pbestPow(i, :) = swarmPow(i, :);
        pbestValPow(i) = fit_i;

        if fit_i > gbestVal
            gbestVal = fit_i;
            gbestPow = swarmPow(i, :);
            gbestRes = res_i;
        end
    end
    contextPow = gbestPow;

    bestHistory = zeros(maxIter + 1, 1);
    bestHistory(1) = gbestVal;

    %% 6. VONG LAP TIEN HOA HOP TAC CC-PSO (Round-Robin)
    for iter = 1:maxIter

        % -------------------------------------------------------------
        % LƯỢT 1: Cập nhật Sub-swarm 1 (Quỹ đạo UAV - 38 chiều)
        % -------------------------------------------------------------
        for i = 1:numParticlesPos
            r1 = rand(1, D_pos);
            r2 = rand(1, D_pos);

            velPos(i, :) = w_pos * velPos(i, :) ...
                + c1_pos * r1 .* (pbestPos(i, :) - swarmPos(i, :)) ...
                + c2_pos * r2 .* (gbestPos - swarmPos(i, :));

            % Kẹp vận tốc
            velPos(i, :) = min(max(velPos(i, :), -vMaxPos), vMaxPos);
            swarmPos(i, :) = swarmPos(i, :) + velPos(i, :);
            swarmPos(i, :) = repairPositionBlock(swarmPos(i, :), sim);

            % Ghép với Context Vector
            testVec = [swarmPos(i, :), contextPow, contextBS];
            [fit_i, res_i] = evaluateTrajectory_JointBS_SWIPT_clean(testVec, sim);

            if fit_i > pbestValPos(i)
                pbestValPos(i) = fit_i;
                pbestPos(i, :) = swarmPos(i, :);
            end

            if fit_i > gbestVal
                gbestVal = fit_i;
                gbestPos = swarmPos(i, :);
                gbestRes = res_i;
            end
        end
        contextPos = gbestPos; % Đồng bộ bối cảnh quỹ đạo mới nhất

        % -------------------------------------------------------------
        % LƯỢT 2: Cập nhật Sub-swarm 2 (Vị trí trạm BS - 6 chiều)
        % -------------------------------------------------------------
        for i = 1:numParticlesBS
            r1 = rand(1, D_bs);
            r2 = rand(1, D_bs);

            velBS(i, :) = w_bs * velBS(i, :) ...
                + c1_bs * r1 .* (pbestBS(i, :) - swarmBS(i, :)) ...
                + c2_bs * r2 .* (gbestBS - swarmBS(i, :));

            velBS(i, :) = min(max(velBS(i, :), -vMaxBS), vMaxBS);
            swarmBS(i, :) = swarmBS(i, :) + velBS(i, :);
            swarmBS(i, :) = repairBSBlock(swarmBS(i, :), sim);

            % Ghép với Context Vector
            testVec = [contextPos, contextPow, swarmBS(i, :)];
            [fit_i, res_i] = evaluateTrajectory_JointBS_SWIPT_clean(testVec, sim);

            if fit_i > pbestValBS(i)
                pbestValBS(i) = fit_i;
                pbestBS(i, :) = swarmBS(i, :);
            end

            if fit_i > gbestVal
                gbestVal = fit_i;
                gbestBS  = swarmBS(i, :);
                gbestRes = res_i;
            end
        end
        contextBS = gbestBS; % Đồng bộ bối cảnh BS mới nhất

        % -------------------------------------------------------------
        % LƯỢT 3: Cập nhật Sub-swarm 3 (Công suất NOMA alpha - 105 chiều)
        % -------------------------------------------------------------
        for i = 1:numParticlesPow
            r1 = rand(1, D_pow);
            r2 = rand(1, D_pow);

            velPow(i, :) = w_pow * velPow(i, :) ...
                + c1_pow * r1 .* (pbestPow(i, :) - swarmPow(i, :)) ...
                + c2_pow * r2 .* (gbestPow - swarmPow(i, :));

            velPow(i, :) = min(max(velPow(i, :), -vMaxPow), vMaxPow);
            swarmPow(i, :) = swarmPow(i, :) + velPow(i, :);
            swarmPow(i, :) = repairAlphaBlock(swarmPow(i, :), sim, pMin, pMax);

            % Ghép với Context Vector
            testVec = [contextPos, swarmPow(i, :), contextBS];
            [fit_i, res_i] = evaluateTrajectory_JointBS_SWIPT_clean(testVec, sim);

            if fit_i > pbestValPow(i)
                pbestValPow(i) = fit_i;
                pbestPow(i, :) = swarmPow(i, :);
            end

            if fit_i > gbestVal
                gbestVal = fit_i;
                gbestPow = swarmPow(i, :);
                gbestRes = res_i;
            end
        end
        contextPow = gbestPow; % Đồng bộ bối cảnh công suất mới nhất

        bestHistory(iter + 1) = gbestVal;

        if mod(iter, 50) == 0 || iter == 1 || iter == maxIter
            fprintf('CC-JointPSO iter %3d/%3d | best fitness = %.4e bps\n', ...
                iter, maxIter, gbestVal);
        end
    end

    %% 7. Dong goi ket qua
    best = gbestRes;
    best.bestParticle = [gbestPos, gbestPow, gbestBS];
    best.bestFitness = gbestVal;
    best.bestHistory = bestHistory;
    best.mode = 'full-joint-bs-ccpso-swipt-clean';

    best.numParticlesPos = numParticlesPos;
    best.numParticlesBS  = numParticlesBS;
    best.numParticlesPow = numParticlesPow;
    best.totalEvalsPerIter = numParticlesPos + numParticlesBS + numParticlesPow;
    best.maxIter = maxIter;
end

%% ================= HELPER FUNCTIONS =================

function val = getOptField(s, f, defaultVal)
    if isfield(s, f) && ~isempty(s.(f))
        val = s.(f);
    else
        val = defaultVal;
    end
end

function val = getSimField(s, f, defaultVal)
    if isfield(s, f) && ~isempty(s.(f))
        val = s.(f);
    else
        val = defaultVal;
    end
end

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

    for pass = 1:3
        for t = 2:(T-1)
            lo = max(sim.x_min, xTraj(t-1) - sim.dxMax);
            hi = min(sim.x_max, xTraj(t-1) + sim.dxMax);
            xTraj(t) = min(max(xTraj(t), lo), hi);
        end
        for t = (T-1):-1:2
            lo = max(sim.x_min, xTraj(t+1) - sim.dxMax);
            hi = min(sim.x_max, xTraj(t+1) + sim.dxMax);
            xTraj(t) = min(max(xTraj(t), lo), hi);
        end
    end

    if isfield(sim, 'dzMax') && ~isempty(sim.dzMax)
        for pass = 1:3
            for t = 2:(T-1)
                lo = max(sim.z_min, zTraj(t-1) - sim.dzMax);
                hi = min(sim.z_max, zTraj(t-1) + sim.dzMax);
                zTraj(t) = min(max(zTraj(t), lo), hi);
            end
            for t = (T-1):-1:2
                lo = max(sim.z_min, zTraj(t+1) - sim.dzMax);
                hi = min(sim.z_max, zTraj(t+1) + sim.dzMax);
                zTraj(t) = min(max(zTraj(t), lo), hi);
            end
        end
    end

    posBlock = [xTraj(2:end-1), zTraj(2:end-1)];
end

function bsBlock = repairBSBlock(bsBlock, sim)
    noBS = sim.noBS;
    xBS = real(bsBlock(1:noBS));
    yBS = real(bsBlock(noBS+1:end));

    xBS = min(max(xBS, sim.xBS_min), sim.xBS_max);
    yBS = min(max(yBS, sim.yBS_min), sim.yBS_max);

    bsBlock = [xBS, yBS];
end

function powBlock = repairAlphaBlock(powBlock, sim, pMin, pMax)
    T = sim.numSteps;
    noUsers = sim.noUsers;

    rawP = real(powBlock);
    rawP = min(max(rawP, pMin), pMax);
    rawP = reshape(rawP, noUsers, T).'; % [T x noUsers]

    rowSum = sum(rawP, 2);
    bad = rowSum <= 0;
    if any(bad)
        rawP(bad, :) = 1 / noUsers;
        rowSum = sum(rawP, 2);
    end
    rawP = rawP ./ rowSum;

    powBlock = reshape(rawP.', 1, []);
end
