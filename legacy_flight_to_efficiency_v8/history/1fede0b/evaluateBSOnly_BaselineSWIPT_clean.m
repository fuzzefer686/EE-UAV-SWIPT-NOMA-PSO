function [fitness, result] = evaluateBSOnly_BaselineSWIPT_clean(particleBS, sim)

    T = sim.numSteps;
    noUsers = sim.noUsers;
    noBS = sim.noBS;

    expectedDim = 2 * noBS;
    if numel(particleBS) ~= expectedDim
        error('evaluateBSOnly_BaselineSWIPT_clean: particleBS phai co kich thuoc 2*noBS.');
    end

    %% Decode BS
    particleBS = real(particleBS(:)).';

    xBS_var = particleBS(1:noBS);
    yBS_var = particleBS(noBS+1:end);
    zBS_var = sim.zBS;

    %% Fixed baseline UAV trajectory
    if isfield(sim, 'xBase') && numel(sim.xBase) == T
        xTraj = sim.xBase(:).';
    else
        xTraj = linspace(sim.xStart, sim.xEnd, T);
    end

    yTraj = sim.stepsVec(:).';

    if isfield(sim, 'zBase') && numel(sim.zBase) == T
        zTraj = sim.zBase(:).';
    else
        zTraj = linspace(sim.zStart, sim.zEnd, T);
    end

    %% Penalty for BS bounds
    penalty = 0;
    bigPenalty = getSimField_local(sim, 'bigPenalty', 1e12);

    if any(xBS_var < sim.xBS_min) || any(xBS_var > sim.xBS_max)
        penalty = penalty + bigPenalty;
    end

    if any(yBS_var < sim.yBS_min) || any(yBS_var > sim.yBS_max)
        penalty = penalty + bigPenalty;
    end

    %% Pre-allocate
    achRate = zeros(T, noUsers);
    stepMin = zeros(T, 1);

    alphaTrace = zeros(T, noUsers);

    EH = zeros(T, 1);
    ptVec = zeros(T, 1);

    h2UserTrace = zeros(T, noUsers);
    h2BSTrace = zeros(T, noBS);

    distUserTrace = zeros(T, noUsers);
    distBSTrace = zeros(T, noBS);

    %% Evaluate each step
    for t = 1:T
        xU = xTraj(t);
        yU = yTraj(t);
        zU = zTraj(t);

        %% BS -> UAV channel with optimized BS positions
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

        %% UAV -> Users channel, unchanged by BS optimization
        h_UAV_Users = zeros(1, noUsers);

        for m = 1:noUsers
            groundDisUs = sqrt((xU - sim.xUser(m))^2 + (yU - sim.yUser(m))^2);

            DisUs = sqrt(groundDisUs^2 + zU^2);

            angleUs = atan2(zU, max(groundDisUs, eps)) * (180/pi);

            powLoSUs = sim.b0 * (DisUs^(-sim.etaPath));

            K_Us = sim.A1 * exp(sim.A2 * angleUs * (pi/180));

            g_Us = sqrt(K_Us/(1+K_Us)) * sim.gLoS + sqrt(1/(1+K_Us)) * sim.gNLoSUsers(m);

            h_UAV_Users(m) = sqrt(powLoSUs) * g_Us;

            h2UserTrace(t, m) = abs(h_UAV_Users(m))^2;
            distUserTrace(t, m) = DisUs;
        end

        %% EH and UAV transmit power
        EH(t) = sim.phy * sim.neta * sim.pr * sum(abs(h_UAV_BS).^2) * sim.Tslot;
        ptVec(t) = EH(t) / sim.Tslot;

        %% Alpha use channel-gain based allocation
        [pow_coef_ch, pow_coef_fr] = findPowCoeff(abs(h_UAV_Users), noUsers);

        alphaTrace(t, :) = pow_coef_ch;

        %% Achievable rate with SWIPT
        [ach_ch, ~] = findAchievableRate_SWIPT(h_UAV_Users, h_UAV_BS, pow_coef_ch, pow_coef_fr, noUsers);

        achRate(t, :) = ach_ch;
        stepMin(t) = min(ach_ch);
    end

    %% Fitness index
    if isfield(sim, 'fitnessStepMode') && strcmpi(sim.fitnessStepMode, 'internal') && T > 2
        fitIdx = 2:T-1;
    else
        fitIdx = 1:T;
    end

    minFit = min(stepMin(fitIdx));
    meanFit = mean(stepMin(fitIdx));

    lambdaMean = getSimField_local(sim, 'lambdaMean', 0);

    fitness = minFit + lambdaMean * meanFit - penalty;

    %% Package result
    result = struct();

    result.xTraj = xTraj;
    result.yTraj = yTraj;
    result.zTraj = zTraj;

    result.xBS = xBS_var;
    result.yBS = yBS_var;
    result.zBS = zBS_var;

    result.achRate = achRate;
    result.stepMin = stepMin;

    result.minFit = minFit;
    result.meanFit = meanFit;
    result.penalty = penalty;
    result.isFeasible = penalty == 0;

    result.EH = EH;
    result.pt = ptVec;

    result.alphaTrace = alphaTrace;

    result.h2UserTrace = h2UserTrace;
    result.h2BSTrace = h2BSTrace;

    result.distUserTrace = distUserTrace;
    result.distBSTrace = distBSTrace;

    result.fitness = fitness;
end

function val = getSimField_local(sim, fieldName, defaultVal)
    if isfield(sim, fieldName) && ~isempty(sim.(fieldName))
        val = sim.(fieldName);
    else
        val = defaultVal;
    end
end