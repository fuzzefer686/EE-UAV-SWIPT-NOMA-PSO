function [fitness, result] = evaluateTrajectory_JointBS_SWIPT_clean(vars, sim)

% Particle:
%   vars = [xInternal, zInternal, rawPowerAllSteps, xBS_var, yBS_var]
%   xInternal        : 1 x (T-2)
%   zInternal        : 1 x (T-2)
%   rawPowerAllSteps : 1 x (T*noUsers)
%   xBS_var          : 1 x noBS
%   yBS_var          : 1 x noBS

    T = sim.numSteps;
    nInternal = T - 2;
    noUsers = sim.noUsers;
    noBS = sim.noBS;

    D_pos = 2 * nInternal;
    D_pow = T * noUsers;
    D_bs  = 2 * noBS;

    expectedDim = D_pos + D_pow + D_bs;

    if numel(vars) ~= expectedDim
        error('evaluateTrajectory_JointBS_SWIPT_clean: vars sai kich thuoc.');
    end

    %% Decode trajectory
    xInternal = real(vars(1:nInternal));
    zInternal = real(vars(nInternal+1:2*nInternal));

    xTraj = [sim.xStart, xInternal, sim.xEnd];
    yTraj = sim.stepsVec(:).';
    zTraj = [sim.zStart, zInternal, sim.zEnd];

    %% Decode raw alpha
    rawP_start = D_pos + 1;
    rawP_end   = D_pos + D_pow;

    rawP_vec = real(vars(rawP_start:rawP_end));
    rawP = reshape(rawP_vec, noUsers, T).';   % [T x noUsers]

    %% Decode BS positions
    bs_start = D_pos + D_pow + 1;

    xBS_var = real(vars(bs_start : bs_start + noBS - 1));
    yBS_var = real(vars(bs_start + noBS : bs_start + 2*noBS - 1));

    zBS_var = sim.zBS;

    %% Kiem tra rang buoc
    penalty = 0;
    bigPenalty = sim.bigPenalty;

    % UAV x,z bounds
    if any(xTraj < sim.x_min) || any(xTraj > sim.x_max)
        penalty = penalty + bigPenalty;
    end

    if any(zTraj < sim.z_min) || any(zTraj > sim.z_max)
        penalty = penalty + bigPenalty;
    end

    % UAV step constraint
    if any(abs(diff(xTraj)) > sim.dxMax)
        penalty = penalty + bigPenalty;
    end


    if any(abs(diff(zTraj)) > sim.dzMax)
        penalty = penalty + bigPenalty;
    end

    % BS bounds
    if isfield(sim, 'xBS_min') && isfield(sim, 'xBS_max')
        if any(xBS_var < sim.xBS_min) || any(xBS_var > sim.xBS_max)
            penalty = penalty + bigPenalty;
        end
    end

    if isfield(sim, 'yBS_min') && isfield(sim, 'yBS_max')
        if any(yBS_var < sim.yBS_min) || any(yBS_var > sim.yBS_max)
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

    alphaTrace = zeros(T, noUsers);
    alphaOrdTrace = zeros(T, noUsers);
    idxWeak2StrongTrace = zeros(T, noUsers);

    EH = zeros(T, 1);
    ptVec = zeros(T, 1);

    h2UserTrace = zeros(T, noUsers);
    h2BSTrace = zeros(T, noBS);

    distUserTrace = zeros(T, noUsers);
    distBSTrace = zeros(T, noBS);

    %% Tinh kenh, alpha, rate tung step
    for t = 1:T
        xU = xTraj(t);
        yU = yTraj(t);
        zU = zTraj(t);

        %% Kenh BS -> UAV voi bien BS
        h_UAV_BS = zeros(1, noBS);

        for bm = 1:noBS
            groundDisBS = sqrt((xU - xBS_var(bm))^2 + (yU - yBS_var(bm))^2);
            DisBS = sqrt(groundDisBS^2 + (zBS_var(bm) - zU)^2);

            angleBS = atan2(abs(zBS_var(bm) - zU), max(groundDisBS, eps)) * (180/pi);

            powLoSBS = sim.b0 * (DisBS^(-sim.etaPath));

            K_BS = sim.A1 * exp(sim.A2 * angleBS * (pi/180));

            g_BS = sqrt(K_BS/(1+K_BS)) * sim.gLoS + sqrt(1/(1+K_BS)) * sim.gNLoSBS(bm);

            h_UAV_BS(bm) = sqrt(powLoSBS) * g_BS;

            h2BSTrace(t, bm) = abs(h_UAV_BS(bm))^2;
            distBSTrace(t, bm) = DisBS;
        end

        %% Kenh UAV -> Users
        h_UAV_Users = zeros(1, noUsers);

        for m = 1:noUsers
            groundDisUs = sqrt((xU - sim.xUser(m))^2 + (yU - sim.yUser(m))^2);
            DisUs = sqrt(groundDisUs^2 + zU^2);

            angleUs = atan2(zU, max(groundDisUs, eps)) * (180/pi);

            powLoSUs = sim.b0 * (DisUs^(-sim.etaPath));

            K_Us = sim.A1 * exp(sim.A2 * angleUs * (pi/180));

            g_Us = sqrt(K_Us/(1+K_Us)) * sim.gLoS + ...
                   sqrt(1/(1+K_Us)) * sim.gNLoSUsers(m);

            h_UAV_Users(m) = sqrt(powLoSUs) * g_Us;

            h2UserTrace(t, m) = abs(h_UAV_Users(m))^2;
            distUserTrace(t, m) = DisUs;
        end

        %% Lay alpha tu particle
        raw_alpha = rawP(t, :);
        raw_alpha = max(raw_alpha, pMin);
        raw_alpha = raw_alpha / sum(raw_alpha);

        %% Repair alpha theo NOMA order
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

    if isfield(sim, 'fitnessStepMode')
        fitnessStepMode = sim.fitnessStepMode;
    else
        fitnessStepMode = 'internal';
    end

    if strcmpi(fitnessStepMode, 'all')
        fitIdx = 1:T;
    else
        fitIdx = 2:(T-1);
    end

    stepMinFit = stepMin(fitIdx);

    minFit = min(stepMinFit);
    meanFit = mean(stepMinFit);

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

    roughX = sum(abs(diff(xTraj, 2))) / (sim.x_max - sim.x_min + eps);
    roughZ = sum(abs(diff(zTraj, 2))) / (sim.z_max - sim.z_min + eps);
    roughNorm = roughX + roughZ;

    fitness = minFit + lambdaMean * meanFit - lambdaSmooth * roughNorm - penalty;

    %% Dong goi result
    result = struct();

    result.xTraj = xTraj;
    result.yTraj = yTraj;
    result.zTraj = zTraj;

    result.xBS = xBS_var;
    result.yBS = yBS_var;
    result.zBS = zBS_var;

    result.achRate = achRate;
    result.stepMin = stepMin;

    result.alphaTrace = alphaTrace;
    result.alphaOrdTrace = alphaOrdTrace;
    result.idxWeak2StrongTrace = idxWeak2StrongTrace;

    result.EH = EH;
    result.pt = ptVec;

    result.h2UserTrace = h2UserTrace;
    result.h2BSTrace = h2BSTrace;

    result.distUserTrace = distUserTrace;
    result.distBSTrace = distBSTrace;

    result.fitness = fitness;
    result.penalty = penalty;
    result.isFeasible = penalty == 0;

    result.fitIdx = fitIdx;
    result.fitnessStepMode = fitnessStepMode;

    result.minFit = minFit;
    result.meanFit = meanFit;

    result.roughX = roughX;
    result.roughZ = roughZ;
    result.roughNorm = roughNorm;

    result.lambdaMean = lambdaMean;
    result.lambdaSmooth = lambdaSmooth;

    result.jointAlphaRepair = jointAlphaRepair;
end