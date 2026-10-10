function best = optimizeBSPosition_JointSWIPT_clean(baseJointParticle, sim, opts)
%   Toi uu rieng vi tri 3 BS, giu nguyen:
%       - UAV trajectory
%       - alpha theo tung step
% Trong evaluator Joint+BS full particle la fullParticle = [baseJointParticle, particleBS]

    if nargin < 3
        opts = struct();
    end

    numParticles = getOptField(opts, 'numParticles', 40);
    maxIter      = getOptField(opts, 'maxIter', 100);
    w            = getOptField(opts, 'w', 0.7);
    c1           = getOptField(opts, 'c1', 1.5);
    c2           = getOptField(opts, 'c2', 1.5);

    %% Kiem tra kich thuoc baseJointParticle
    T = sim.numSteps;
    nInternal = T - 2;
    noUsers = sim.noUsers;
    noBS = sim.noBS;

    D_base_expected = 2*nInternal + T*noUsers;

    if numel(baseJointParticle) ~= D_base_expected
        error('optimizeBSPosition_JointSWIPT_clean: baseJointParticle sai kich thuoc.');
    end

    %% Kich thuoc particle BS
    D = 2 * noBS;   % [xBS1..xBS_M, yBS1..yBS_M]

    %% Kiem tra bien BS
    requiredFields = {'xBS_min', 'xBS_max', 'yBS_min', 'yBS_max'};

    for k = 1:numel(requiredFields)
        if ~isfield(sim, requiredFields{k})
            error('optimizeBSPosition_JointSWIPT_clean: sim thieu field %s.', requiredFields{k});
        end
    end

    %% Bo nho PSO
    particlesPos = zeros(numParticles, D);
    particlesVel = zeros(numParticles, D);

    pbestPos = zeros(numParticles, D);
    pbestVal = -inf * ones(numParticles, 1);

    gbestPos = zeros(1, D);
    gbestVal = -inf;
    gbestRes = struct();

    bestHistory = zeros(maxIter + 1, 1);

    %% Particle baseline BS hien tai
    baseBSParticle = [sim.xBS, sim.yBS];

    %% Khoi tao bay dan
    for i = 1:numParticles

        if i == 1
            % Particle dau tien la vi tri BS hien tai
            particlesPos(i, :) = baseBSParticle;
        else
            % Random xBS trong vung rieng cua tung BS
            particlesPos(i, 1:noBS) = sim.xBS_min + rand(1, noBS) .* (sim.xBS_max - sim.xBS_min);

            % Random yBS trong vung rieng cua tung BS
            particlesPos(i, noBS+1:end) = sim.yBS_min + rand(1, noBS) .* (sim.yBS_max - sim.yBS_min);
        end

        particlesVel(i, :) = zeros(1, D);

        particlesPos(i, :) = repairBSParticle(particlesPos(i, :), sim);

        fullParticle = [baseJointParticle, particlesPos(i, :)];

        [fit_i, res_i] = evaluateTrajectory_JointBS_SWIPT_clean(fullParticle, sim);

        pbestPos(i, :) = particlesPos(i, :);
        pbestVal(i) = fit_i;

        if fit_i > gbestVal
            gbestVal = fit_i;
            gbestPos = particlesPos(i, :);
            gbestRes = res_i;
        end
    end

    bestHistory(1) = gbestVal;

    %% Vong lap PSO
    for iter = 1:maxIter

        for i = 1:numParticles

            r1 = rand(1, D);
            r2 = rand(1, D);

            particlesVel(i, :) = w * particlesVel(i, :) + c1 * r1 .* (pbestPos(i, :) - particlesPos(i, :)) + c2 * r2 .* (gbestPos - particlesPos(i, :));

            particlesPos(i, :) = particlesPos(i, :) + particlesVel(i, :);

            particlesPos(i, :) = repairBSParticle(particlesPos(i, :), sim);

            fullParticle = [baseJointParticle, particlesPos(i, :)];

            [fit_i, res_i] = evaluateTrajectory_JointBS_SWIPT_clean(fullParticle, sim);

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

        if mod(iter, 10) == 0 || iter == 1 || iter == maxIter
            fprintf('BS-only PSO iter %3d/%3d | best fitness = %.4e bps\n', ...
                iter, maxIter, gbestVal);
        end
    end

    %% Dong goi ket qua
    best = gbestRes;

    best.bestBSParticle = gbestPos;
    best.bestFullParticle = [baseJointParticle, gbestPos];
    best.bestFitness = gbestVal;
    best.bestHistory = bestHistory;

    best.mode = 'bs-only-joint-swipt-clean';

    best.numParticles = numParticles;
    best.maxIter = maxIter;
    best.w = w;
    best.c1 = c1;
    best.c2 = c2;

    best.fixedBaseJointParticle = baseJointParticle;
end

%  Repair BS particle
function particleBS = repairBSParticle(particleBS, sim)

    noBS = sim.noBS;

    xBS = real(particleBS(1:noBS));
    yBS = real(particleBS(noBS+1:end));

    xBS = min(max(xBS, sim.xBS_min), sim.xBS_max);
    yBS = min(max(yBS, sim.yBS_min), sim.yBS_max);

    particleBS = [xBS, yBS];
end

%  Helper
function val = getOptField(opts, fieldName, defaultVal)

    if isfield(opts, fieldName) && ~isempty(opts.(fieldName))
        val = opts.(fieldName);
    else
        val = defaultVal;
    end
end