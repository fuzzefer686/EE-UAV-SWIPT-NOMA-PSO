function particle = initialV12Particle(sim, optimizeBS, randomize)
%INITIALV12PARTICLE Kinematics-aware clustered particle seed for V12 accel mode.
% Generates 1-3 contiguous hover/serving clusters connected by transit hops so
% intra-cluster legs shorten to compulsory minYProgress steps (Variant B) or
% zero-length hovers (Variant A), reducing rest-to-rest ramp energy.
% When randomize == false, produces a single deterministic cluster with 0 RNG draws.
    layout = v10ParticleLayout(sim, optimizeBS);
    particle = zeros(1, layout.dimension);
    n = numel(layout.x);

    cProjX = min(max(mean(sim.xUser), sim.x_min), sim.x_max);
    cProjY = min(max(mean(sim.yUser), sim.y_min), sim.y_max);

    if ~randomize
        particle(layout.x) = repmat(cProjX, 1, n);
        if ~isempty(layout.y)
            slack = abs(sim.yEnd - sim.yStart) - (sim.numSteps - 1) * sim.minYProgress;
            prog = sim.yDirection * (cProjY - sim.yStart);
            r0 = min(max(prog - 0.5 * (n + 1) * sim.minYProgress, 0), slack);
            particle(layout.y) = sim.yStart + sim.yDirection * ((1:n) * sim.minYProgress + r0);
        end
        particle(layout.alpha) = 1 / sim.noUsers;
        if optimizeBS
            particle(layout.xBS) = min(max(mean(sim.xUser), sim.xBS_min), sim.xBS_max);
            particle(layout.yBS) = min(max(mean(sim.yUser), sim.yBS_min), sim.yBS_max);
        end
        particle = repairV10Particle(particle, sim, optimizeBS);
        return;
    end

    bsProjX = min(max(sim.xBS(:).', sim.x_min), sim.x_max);
    bsProjY = min(max(sim.yBS(:).', sim.y_min), sim.y_max);
    uProjX  = min(max(sim.xUser(:).', sim.x_min), sim.x_max);
    uProjY  = min(max(sim.yUser(:).', sim.y_min), sim.y_max);
    anchorsX = [bsProjX, uProjX, cProjX];
    anchorsY = [bsProjY, uProjY, cProjY];

    K = randi(min(3, n));
    if K == 1
        m = n;
    else
        cuts = sort(randperm(n - 1, K - 1));
        m = diff([0, cuts, n]);
    end

    if rand < 0.7
        pick = randi(numel(anchorsX), 1, K);
        X  = anchorsX(pick) + 15 * randn(1, K);
        Yc = anchorsY(pick) + 25 * randn(1, K);
    else
        X  = sim.x_min + rand(1, K) * (sim.x_max - sim.x_min);
        Yc = sim.y_min + rand(1, K) * (sim.y_max - sim.y_min);
    end
    X  = min(max(X, sim.x_min), sim.x_max);
    Yc = min(max(Yc, sim.y_min), sim.y_max);

    prog = sim.yDirection * (Yc - sim.yStart);
    [prog, ord] = sort(prog, 'ascend');
    X = X(ord);

    xInt = zeros(1, n);
    res  = zeros(1, n);
    slack = abs(sim.yEnd - sim.yStart) - (sim.numSteps - 1) * sim.minYProgress;
    idx = 0;
    for c = 1:K
        seg = (idx + 1):(idx + m(c));
        xInt(seg) = X(c);
        if ~isempty(layout.y)
            midStep = 0.5 * (seg(1) + seg(end));
            rc = min(max(prog(c) - midStep * sim.minYProgress, 0), slack);
            res(seg) = rc;
        end
        idx = idx + m(c);
    end
    particle(layout.x) = xInt;
    if ~isempty(layout.y)
        res = cummax(res);
        particle(layout.y) = sim.yStart + sim.yDirection * ((1:n) * sim.minYProgress + res);
    end

    particle(layout.alpha) = sim.pMin + rand(1, numel(layout.alpha)) * (sim.pMax - sim.pMin);
    if optimizeBS
        if rand < 0.7
            tx = mean(sim.xUser) + 25 * randn(1, sim.noBS);
            ty = mean(sim.yUser) + 45 * randn(1, sim.noBS);
            particle(layout.xBS) = min(max(tx, sim.xBS_min), sim.xBS_max);
            particle(layout.yBS) = min(max(ty, sim.yBS_min), sim.yBS_max);
        else
            particle(layout.xBS) = sim.xBS_min + rand(1, sim.noBS) .* (sim.xBS_max - sim.xBS_min);
            particle(layout.yBS) = sim.yBS_min + rand(1, sim.noBS) .* (sim.yBS_max - sim.yBS_min);
        end
    end
    particle = repairV10Particle(particle, sim, optimizeBS);
end
