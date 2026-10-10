function [fitness, result] = evaluateTrajectory_SWIPT_clean(vars, sim)
% Particle đầu vào:
%   vars = [xInternal, zInternal]
%   xTraj = [xStart, xInternal, xEnd]
%   yTraj = sim.stepsVec
%   zTraj = [zStart, zInternal, zEnd]
%
% Output:
%   fitness = min(stepMin) - penalty
%   result  = struct chứa trajectory, achRate, minRate, EH, pt, alphaTrace

    T = sim.numSteps;
    nInternal = T - 2;
    noUsers = sim.noUsers;
    noBS = sim.noBS;

    expectedDim = 2 * nInternal;

    if numel(vars) ~= expectedDim
        error('evaluateTrajectory_SWIPT_clean: vars phải có kích thước 2*(numSteps-2).');
    end

    xInternal = vars(1:nInternal);
    zInternal = vars(nInternal+1:end);

    xTraj = [sim.xStart, xInternal, sim.xEnd];
    yTraj = sim.stepsVec(:).';
    zTraj = [sim.zStart, zInternal, sim.zEnd];

    %% Kiểm tra ràng buộc
    penalty = 0;
    bigPenalty = sim.bigPenalty;

    % Ràng buộc biên x, z
    if any(xTraj < sim.x_min) || any(xTraj > sim.x_max)
        penalty = penalty + bigPenalty;
    end

    if any(zTraj < sim.z_min) || any(zTraj > sim.z_max)
        penalty = penalty + bigPenalty;
    end

    % Ràng buộc bước nhảy theo x: |x_i - x_{i-1}| <= dxMax
    if any(abs(diff(xTraj)) > sim.dxMax)
        penalty = penalty + bigPenalty;
    end

    %% Pre-allocate kết quả
    achRate = zeros(T, noUsers);
    alphaTrace = zeros(T, noUsers);
    EH = zeros(T, 1);
    ptVec = zeros(T, 1);

    %% Tính kênh, EH, achievable rate tại từng step
    for t = 1:T
        xU = xTraj(t);
        yU = yTraj(t);
        zU = zTraj(t);

        %% Kênh BS -> UAV
        h_UAV_BS = zeros(1, noBS);

        for bm = 1:noBS
            groundDisBS = sqrt((xU - sim.xBS(bm))^2 + (yU - sim.yBS(bm))^2);
            DisBS = sqrt(groundDisBS^2 + (sim.zBS(bm) - zU)^2);

            angleBS = atan2(abs(sim.zBS(bm) - zU), max(groundDisBS, eps)) * (180/pi);

            powLoSBS = sim.b0 * (DisBS^(-sim.etaPath));

            K_BS = sim.A1 * exp(sim.A2 * angleBS * (pi/180));

            g_BS = sqrt(K_BS/(1+K_BS)) * sim.gLoS + ...
                   sqrt(1/(1+K_BS)) * sim.gNLoSBS(bm);

            h_UAV_BS(bm) = sqrt(powLoSBS) * g_BS;
        end

        %% Kênh UAV -> Users
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
        end

        %% Tính harvested energy và transmit power UAV
        EH(t) = sim.phy * sim.neta * sim.pr * sum(abs(h_UAV_BS).^2) * sim.Tslot;
        ptVec(t) = EH(t) / sim.Tslot;

        %% Power allocation theo Algorithm 2 / channel gain
        [pow_coef_ch, pow_coef_fr] = findPowCoeff(abs(h_UAV_Users), noUsers);

        alphaTrace(t, :) = pow_coef_ch;

        %% Achievable rate SWIPT
        [ach_ch, ~] = findAchievableRate_SWIPT(h_UAV_Users, h_UAV_BS, pow_coef_ch, pow_coef_fr, noUsers);
        achRate(t, :) = ach_ch;
    end

    %% Tính minRate mỗi step và fitness toàn quỹ đạo
    stepMin = min(achRate, [], 2);
    
    internalIdx = 2:(T-1);
    
    stepMinInternal = stepMin(internalIdx);
    
    minInternal  = min(stepMinInternal);
    meanInternal = mean(stepMinInternal);
    
    % Lay trong so tu sim
    if isfield(sim, 'lambdaMean')
        lambdaMean = sim.lambdaMean;
    else
        lambdaMean = 0.05;
    end
    
    if isfield(sim, 'lambdaSmooth')
        lambdaSmooth = sim.lambdaSmooth;
    else
        lambdaSmooth = 100;
    end
    
    % Smoothness penalty: phat quy dao gap khuc
    roughX = sum(abs(diff(xTraj, 2))) / (sim.x_max - sim.x_min + eps);
    roughZ = sum(abs(diff(zTraj, 2))) / (sim.z_max - sim.z_min + eps);
    roughNorm = roughX + roughZ;
    
    fitness = minInternal + lambdaMean * meanInternal - lambdaSmooth * roughNorm - penalty;

    %% Đóng gói kết quả
    result = struct();

    result.xTraj = xTraj;
    result.yTraj = yTraj;
    result.zTraj = zTraj;

    result.achRate = achRate;
    result.stepMin = stepMin;

    result.alphaTrace = alphaTrace;

    result.EH = EH;
    result.pt = ptVec;

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
end