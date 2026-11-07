function sim = buildV12Simulation(cfg, variant)
%BUILDV12SIMULATION Validate V12 configuration and draw identical V10/V9 scenario.
% Preserves exact RNG draw order from buildV10Simulation.
    sim = buildV10Simulation(cfg, variant);

    r = cfg.radio;
    f = cfg.flight;

    if ~isfield(r, 'powerSplitMode') || isempty(r.powerSplitMode)
        r.powerSplitMode = 'optimal-causal';
    end
    r.powerSplitMode = lower(char(r.powerSplitMode));
    if ~any(strcmp(r.powerSplitMode, {'optimal-causal', 'fixed'}))
        error('buildV12Simulation:PowerSplitMode', ...
            'powerSplitMode must be ''optimal-causal'' or ''fixed''.');
    end

    if ~isfield(r, 'enforceUlDlCausality') || isempty(r.enforceUlDlCausality)
        r.enforceUlDlCausality = true;
    end
    validateattributes(r.enforceUlDlCausality, {'logical', 'numeric'}, {'scalar', 'binary'});
    r.enforceUlDlCausality = logical(r.enforceUlDlCausality);

    if ~isfield(r, 'phiMin') || isempty(r.phiMin)
        r.phiMin = 0;
    end
    if ~isfield(r, 'phiMax') || isempty(r.phiMax)
        r.phiMax = 1 - 1e-12;
    end
    validateattributes(r.phiMin, {'numeric'}, {'real', 'finite', 'scalar', '>=', 0, '<=', 1});
    validateattributes(r.phiMax, {'numeric'}, {'real', 'finite', 'scalar', '>=', r.phiMin, '<=', 1});

    if ~isfield(f, 'motionMode') || isempty(f.motionMode)
        f.motionMode = 'quasi-steady-accel';
    end
    f.motionMode = lower(char(f.motionMode));
    if ~any(strcmp(f.motionMode, {'quasi-steady-accel', 'steady-cruise'}))
        error('buildV12Simulation:MotionMode', ...
            'motionMode must be ''quasi-steady-accel'' or ''steady-cruise''.');
    end

    if ~isfield(f, 'acceleration') || isempty(f.acceleration)
        f.acceleration = 3.0;
    end
    validateattributes(f.acceleration, {'numeric'}, {'real', 'finite', 'scalar', 'positive'});

    if ~isfield(f, 'quadratureNodes') || isempty(f.quadratureNodes)
        f.quadratureNodes = 16;
    end
    validateattributes(f.quadratureNodes, {'numeric'}, {'integer', 'scalar', '>=', 4});

    sim.radio.powerSplitMode = r.powerSplitMode;
    sim.radio.enforceUlDlCausality = r.enforceUlDlCausality;
    sim.radio.phiMin = r.phiMin;
    sim.radio.phiMax = r.phiMax;

    sim.flight.motionMode = f.motionMode;
    sim.flight.acceleration = f.acceleration;
    sim.flight.quadratureNodes = f.quadratureNodes;
    [sim.flight.glNodes01, sim.flight.glWeights01] = gaussLegendre01(f.quadratureNodes);
end

function [nodes01, weights01] = gaussLegendre01(n)
    idx = (1:n-1).';
    beta = idx ./ sqrt(4 * idx.^2 - 1);
    J = diag(beta, 1) + diag(beta, -1);
    [V, D] = eig(J);
    [x, order] = sort(diag(D), 'ascend');
    V = V(:, order);
    w = 2 * (V(1, :).').^2;
    nodes01 = 0.5 * (x.' + 1);
    weights01 = 0.5 * w;
end
