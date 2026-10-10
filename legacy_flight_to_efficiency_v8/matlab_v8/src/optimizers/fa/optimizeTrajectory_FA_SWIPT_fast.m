function best = optimizeTrajectory_FA_SWIPT_fast(sim, opts)
%   particle = [xInternal, zInternal]

    if nargin < 2
        opts = struct();
    end
    dx_length = sim.x_max-sim.x_min;
    dz_length = sim.z_max-sim.z_min;
    numParticles = getOptField(opts, 'numParticles', 40);
    maxIter      = getOptField(opts, 'maxIter', 100);
    % w            = getOptField(opts, 'w', 0.7);
    % c1           = getOptField(opts, 'c1', 1.5);
    % c2           = getOptField(opts, 'c2', 1.5);
    alpha        = getOptField(opts,'alpha', 0.2);
    alpha0       = alpha;
    beta0        = getOptField(opts,'beta0', 1);
    gamma        = getOptField(opts,'gamma', 1 / (dx_length^2 + dz_length^2));
    alphaDamp    = getOptField(opts,'alphaDamp', 0.98);
    topK         = getOptField(opts, 'topKAttractors', 10);
    %% Kich thuoc particle
    T = sim.numSteps;
    nInternal = T - 2;

    % particle = [x2 ... xT-1, z2 ... zT-1]
    D = 2 * nInternal;

    %% Khoi tao bo nho FA
    particlesPos = zeros(numParticles, D);
    % particlesVel = zeros(numParticles, D);
    particlesBrightness = -inf * ones(numParticles,1);
    particlesRes = cell(numParticles, 1);
    % pbestPos = zeros(numParticles, D);
    % pbestVal = -inf * ones(numParticles, 1);

    gbestPos = zeros(1, D);
    gbestVal = -inf;
    gbestRes = struct();

    bestHistory = zeros(maxIter + 1, 1);
    
    xBase = linspace(sim.xStart, sim.xEnd, T);
    zBase = linspace(sim.zStart, sim.zEnd, T);
    baseParticle = [xBase(2:end-1), zBase(2:end-1)];
    %% Khoi tao bay dan theo baseline
    for i = 1:numParticles

        if i == 1
            particlesPos(i, :) = baseParticle;
        else
            particlesPos(i, 1:nInternal) = sim.x_min + rand(1, nInternal) * (sim.x_max - sim.x_min);
    
            particlesPos(i, nInternal+1:end) = sim.z_min +rand(1, nInternal) * ...
                                   (sim.z_max - sim.z_min);
        end

        particlesPos(i, :) = repairPositionParticle(particlesPos(i, :), sim);
        [fit_i, res_i] = evaluateTrajectory_SWIPT_clean(particlesPos(i, :), sim);
        particlesBrightness(i) = fit_i;
        particlesRes{i} = res_i;

        if fit_i > gbestVal
            gbestVal = fit_i;
            gbestPos = particlesPos(i, :);
            gbestRes = res_i;
        end
    end

    bestHistory(1) = gbestVal;

    %% Vong lap FA chuan
    for iter = 1:maxIter
        for i = 1:numParticles
            % xi = particlesPos(i, :);
            % fi = particlesBrightness(i);
            % res_i = particlesRes{i};
            % moved = false;
            % 
            % % Top-K attractor: chi chon toi da topK firefly sang hon i
            % brighter = find(particlesBrightness > particlesBrightness(i));
            % 
            % if ~isempty(brighter)
            %     % Sap xep cac attractor sang hon theo brightness giam dan
            %     [~, order] = sort(particlesBrightness(brighter), 'descend');
            %     brighter = brighter(order);
            % 
            %     k = min(topK, numel(brighter));
            %     selected = brighter(1:k);
            % 
            %     for jj = 1:k
            %         j = selected(jj);
            % 
            %         distance = particlesPos(j, :) - xi;
            %         r_ij = norm(distance);
            %         beta = beta0 * exp(-gamma * r_ij * r_ij);
            %         random_vec = randn(1, D) - 0.5;
            % 
            %         xi = xi + beta * distance + alpha * random_vec*50;
            %         xi = repairPositionParticle(xi, sim);
            %         [fi, res_i] = evaluateTrajectory_SWIPT_clean(xi, sim);
            %         moved = true;
            %     end
            % end
            % 
            % % Firefly sang nhat random walk de tranh ket cuc bo
            % if ~moved
            %     xi = xi + alpha * (randn(1,D)-0.5)*50;
            %     xi = repairPositionParticle(xi, sim);
            %     [fi, res_i] = evaluateTrajectory_SWIPT_clean(xi, sim);
            % end
            % 
            % particlesPos(i, :) = xi;
            % particlesBrightness(i) = fi;
            % particlesRes{i} = res_i;
            % 
            % if fi > gbestVal
            %     gbestVal = fi;
            %     gbestPos = xi;
            %     gbestRes = res_i;
            % end
            xi = particlesPos(i, :);
fi = particlesBrightness(i);
res_i = particlesRes{i};

brighter = find(particlesBrightness > fi);

if ~isempty(brighter)
    [~, order] = sort(particlesBrightness(brighter), 'descend');
    brighter = brighter(order);

    k = min(topK, numel(brighter));
    selected = brighter(1:k);

    for jj = 1:k
        j = selected(jj);

        xi_old = xi;
        fi_old = fi;
        res_old = res_i;

        distance = particlesPos(j, :) - xi_old;

        r_ij = norm(distance) / sqrt(D);
        beta = beta0 * exp(-gamma * r_ij * r_ij);

        random_vec = randn(1, D);

        xi_new = xi_old + beta * distance + alpha * random_vec;
        xi_new = repairPositionParticle(xi_new, sim);

        [fi_new, res_new] = evaluateTrajectory_SWIPT_clean(xi_new, sim);

        if fi_new > fi_old
            xi = xi_new;
            fi = fi_new;
            res_i = res_new;
        else
            xi = xi_old;
            fi = fi_old;
            res_i = res_old;
        end
    end
else
    xi_old = xi;
    fi_old = fi;
    res_old = res_i;

    random_vec = randn(1, D);
    xi_new = xi_old + alpha * random_vec;
    xi_new = repairPositionParticle(xi_new, sim);

    [fi_new, res_new] = evaluateTrajectory_SWIPT_clean(xi_new, sim);

    if fi_new > fi_old
        xi = xi_new;
        fi = fi_new;
        res_i = res_new;
    else
        xi = xi_old;
        fi = fi_old;
        res_i = res_old;
    end
end

particlesPos(i, :) = xi;
particlesBrightness(i) = fi;
particlesRes{i} = res_i;

if fi > gbestVal
    gbestVal = fi;
    gbestPos = xi;
    gbestRes = res_i;
end
        end

        bestHistory(iter + 1) = gbestVal;
        alpha = alpha * alphaDamp;

        if mod(iter, 10) == 0 || iter == 1 || iter == maxIter
            fprintf('FA iter %3d/%3d | best fitness = %.4e bps\n', ...
                iter, maxIter, gbestVal);
        end
    end

    %% Dong goi ket qua tot nhat
    best = gbestRes;

    best.bestParticle = gbestPos;
    best.bestFitness = gbestVal;
    best.bestHistory = bestHistory;
    best.mode = 'fa-swipt-fast';

    best.numParticles = numParticles;
    best.maxIter = maxIter;
    % best.w = w;
    % best.c1 = c1;
    % best.c2 = c2;
    best.alpha = alpha;
    best.alpha0 = alpha0;
    best.beta0 = beta0;
    best.gamma = gamma;
    best.alphaDamp = alphaDamp;
    best.topKAttractors = topK;
end

function particle = repairPositionParticle(particle, sim)

    T = sim.numSteps;
    nInternal = T - 2;

    xInternal = real(particle(1:nInternal));
    zInternal = real(particle(nInternal+1:end));

    % Khoa bien x, z truoc
    xInternal = min(max(xInternal, sim.x_min), sim.x_max);
    zInternal = min(max(zInternal, sim.z_min), sim.z_max);

    xTraj = [sim.xStart, xInternal, sim.xEnd];
    zTraj = [sim.zStart, zInternal, sim.zEnd];

    xTraj(1) = sim.xStart;
    xTraj(end) = sim.xEnd;

    zTraj(1) = sim.zStart;
    zTraj(end) = sim.zEnd;

    % Khoa bien z 
    zTraj(2:end-1) = min(max(zTraj(2:end-1), sim.z_min), sim.z_max);

    for pass = 1:3

        % Forward pass
        for t = 2:(T-1)
            lo = max(sim.x_min, xTraj(t-1) - sim.dxMax);
            hi = min(sim.x_max, xTraj(t-1) + sim.dxMax);
            xTraj(t) = min(max(xTraj(t), lo), hi);
        end

        % Backward pass
        for t = (T-1):-1:2
            lo = max(sim.x_min, xTraj(t+1) - sim.dxMax);
            hi = min(sim.x_max, xTraj(t+1) + sim.dxMax);
            xTraj(t) = min(max(xTraj(t), lo), hi);
        end
    end
    for pass = 1:3

        % Forward pass cho z
        for t = 2:(T-1)
            lo = max(sim.z_min, zTraj(t-1) - sim.dzMax);
            hi = min(sim.z_max, zTraj(t-1) + sim.dzMax);
            zTraj(t) = min(max(zTraj(t), lo), hi);
        end

        % Backward pass cho z
        for t = (T-1):-1:2
            lo = max(sim.z_min, zTraj(t+1) - sim.dzMax);
            hi = min(sim.z_max, zTraj(t+1) + sim.dzMax);
            zTraj(t) = min(max(zTraj(t), lo), hi);
        end
    end

    xTraj(2:end-1) = min(max(xTraj(2:end-1), sim.x_min), sim.x_max);
    zTraj(2:end-1) = min(max(zTraj(2:end-1), sim.z_min), sim.z_max);

    particle = [xTraj(2:end-1), zTraj(2:end-1)];
end

function val = getOptField(opts, fieldName, defaultVal)

    if isfield(opts, fieldName) && ~isempty(opts.(fieldName))
        val = opts.(fieldName);
    else
        val = defaultVal;
    end
end
