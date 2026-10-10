function [fitness, result] = evaluateTrajectory_JointSWIPT_clean(vars, sim)

% Particle:
%   vars = [xInternal, zInternal, rawPowerAllSteps]
%   xTraj = [xStart, xInternal, xEnd]
%   yTraj = sim.stepsVec
%   zTraj = [zStart, zInternal, zEnd]
%
% rawPowerAllSteps reshape thanh rawP(t, user)

    T = sim.numSteps;
    nInternal = T - 2;
    noUsers = sim.noUsers;
    noBS = sim.noBS;

    expectedDim = 2*nInternal + T*noUsers;

    if numel(vars) ~= expectedDim
        error('evaluateTrajectory_JointSWIPT_clean: vars sai kich thuoc.');
    end

    %% Decode trajectory va raw power
    xInternal = real(vars(1:nInternal));
    zInternal = real(vars(nInternal+1:2*nInternal));

    rawP_vec = real(vars(2*nInternal+1:end));
    rawP = reshape(rawP_vec, noUsers, T).';   % [T x noUsers]

    xTraj = [sim.xStart, xInternal, sim.xEnd];
    yTraj = sim.stepsVec(:).';
    zTraj = [sim.zStart, zInternal, sim.zEnd];

    %% Kiem tra rang buoc
    penalty = 0;
    bigPenalty = sim.bigPenalty;

    if any(xTraj < sim.x_min) || any(xTraj > sim.x_max)
        penalty = penalty + bigPenalty;
    end

    if any(zTraj < sim.z_min) || any(zTraj > sim.z_max)
        penalty = penalty + bigPenalty;
    end

    if any(abs(diff(xTraj)) > sim.dxMax)
        penalty = penalty + bigPenalty;
    end

    if isfield(sim, 'dzMax') && ~isempty(sim.dzMax)
        if any(abs(diff(zTraj)) > sim.dzMax)
            penalty = penalty + bigPenalty;
        end
    end

    %% Thong so alpha
    if isfield(sim, 'pMin')
        pMin = sim.pMin;
    else
        pMin = 1e-3;
    end

    if isfield(sim, 'jointAlphaRepair')
        jointAlphaRepair = sim.jointAlphaRepair;
    else
        jointAlphaRepair = 'noma';
    end

    %% Pre-allocate
    achRate = zeros(T, noUsers);
    alphaTrace = zeros(T, noUsers);       % alpha theo user goc
    alphaOrdTrace = zeros(T, noUsers);    % alpha theo thu tu weak -> strong
    idxWeak2StrongTrace = zeros(T, noUsers);

    EH = zeros(T, 1);
    ptVec = zeros(T, 1);

    h2UserTrace = zeros(T, noUsers);
    h2BSTrace = zeros(T, noBS);

    %% Tinh kenh, alpha, rate tung step
    for t = 1:T
        xU = xTraj(t);
        yU = yTraj(t);
        zU = zTraj(t);

        %% Kenh BS -> UAV
        h_UAV_BS = zeros(1, noBS);

        for bm = 1:noBS
            groundDisBS = sqrt((xU - sim.xBS(bm))^2 + (yU - sim.yBS(bm))^2);
            DisBS = sqrt(groundDisBS^2 + (sim.zBS(bm) - zU)^2);

            angleBS = atan2(abs(sim.zBS(bm) - zU), max(groundDisBS, eps)) * (180/pi);

            powLoSBS = sim.b0 * (DisBS^(-sim.etaPath));

            K_BS = sim.A1 * exp(sim.A2 * angleBS * (pi/180));

            g_BS = sqrt(K_BS/(1+K_BS)) * sim.gLoS + sqrt(1/(1+K_BS)) * sim.gNLoSBS(bm);

            h_UAV_BS(bm) = sqrt(powLoSBS) * g_BS;
        end

        %% Kenh UAV -> Users
        h_UAV_Users = zeros(1, noUsers);

        for m = 1:noUsers
            groundDisUs = sqrt((xU - sim.xUser(m))^2 + (yU - sim.yUser(m))^2);
            DisUs = sqrt(groundDisUs^2 + zU^2);

            angleUs = atan2(zU, max(groundDisUs, eps)) * (180/pi);

            powLoSUs = sim.b0 * (DisUs^(-sim.etaPath));

            K_Us = sim.A1 * exp(sim.A2 * angleUs * (pi/180));

            g_Us = sqrt(K_Us/(1+K_Us)) * sim.gLoS + sqrt(1/(1+K_Us)) * sim.gNLoSUsers(m);

            h_UAV_Users(m) = sqrt(powLoSUs) * g_Us;
        end

        h2UserTrace(t, :) = abs(h_UAV_Users).^2;
        h2BSTrace(t, :) = abs(h_UAV_BS).^2;

        %% Lay alpha tu particle
        raw_alpha = rawP(t, :);
        raw_alpha = max(raw_alpha, pMin);
        raw_alpha = raw_alpha / sum(raw_alpha);

        %% Repair alpha theo NOMA order
        %   idxWeak2Strong: user yeu -> user manh theo |h|^2 tang dan
        %   weak user duoc alpha lon hon
    
        h2 = abs(h_UAV_Users).^2;
        [~, idxWeak2Strong_pre] = sort(h2, 'ascend');

        if strcmpi(jointAlphaRepair, 'noma')
            alpha_desc = sort(raw_alpha, 'descend');

            alpha_user = zeros(1, noUsers);
            alpha_user(idxWeak2Strong_pre) = alpha_desc;
        else
            alpha_user = raw_alpha;
        end

        %% Tinh achievable rate Joint
        [rate_t, alpha_ord, idxWeak2Strong, pt_t] = findAchievableRate_SWIPT_Joint(h_UAV_Users, h_UAV_BS, alpha_user);

        achRate(t, :) = rate_t;
        alphaTrace(t, :) = alpha_user;
        alphaOrdTrace(t, :) = alpha_ord;
        idxWeak2StrongTrace(t, :) = idxWeak2Strong;

        ptVec(t) = pt_t;
        EH(t) = pt_t * sim.Tslot;
    end

    %% Tinh fitness
    stepMin = min(achRate, [], 2);

    internalIdx = 2:(T-1);
    stepMinInternal = stepMin(internalIdx);

    minInternal = min(stepMinInternal);
    meanInternal = mean(stepMinInternal);

    if isfield(sim, 'lambdaMean')
        lambdaMean = sim.lambdaMean;
    else
        lambdaMean = 0.05;
    end

    if isfield(sim, 'lambdaSmooth')
        lambdaSmooth = sim.lambdaSmooth;
    else
        lambdaSmooth = 0;
    end
    rateFit = achRate(internalIdx, :);
    
    jainStep = (sum(rateFit, 2).^2) ./ (noUsers * sum(rateFit.^2, 2) + eps);
    
    jainMean = mean(jainStep);
    
    if isfield(sim, 'lambdaFair')
        lambdaFair = sim.lambdaFair;
    else
        lambdaFair = 0;
    end
    
    fairPenalty = lambdaFair * meanInternal * mean(1 - jainStep);
    roughX = sum(abs(diff(xTraj, 2))) / (sim.x_max - sim.x_min + eps);
    roughZ = sum(abs(diff(zTraj, 2))) / (sim.z_max - sim.z_min + eps);
    roughNorm = roughX + roughZ;

    fitness = minInternal + lambdaMean * meanInternal - lambdaSmooth * roughNorm - fairPenalty - penalty;

    %% Dong goi result
    result = struct();

    result.xTraj = xTraj;
    result.yTraj = yTraj;
    result.zTraj = zTraj;

    result.achRate = achRate;
    result.stepMin = stepMin;

    result.alphaTrace = alphaTrace;
    result.alphaOrdTrace = alphaOrdTrace;
    result.idxWeak2StrongTrace = idxWeak2StrongTrace;

    result.EH = EH;
    result.pt = ptVec;

    result.h2UserTrace = h2UserTrace;
    result.h2BSTrace = h2BSTrace;

    result.fitness = fitness;
    result.penalty = penalty;
    result.isFeasible = penalty == 0;

    result.minInternal = minInternal;
    result.meanInternal = meanInternal;

    result.roughX = roughX;
    result.roughZ = roughZ;
    result.roughNorm = roughNorm;

    result.lambdaMean = lambdaMean;
    result.lambdaSmooth = lambdaSmooth;
    result.lambdaFair = lambdaFair;
    result.fairPenalty = fairPenalty;
    result.jointAlphaRepair = jointAlphaRepair;
end