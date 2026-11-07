function out = droneMotionEnergyV12(distance, flight, cruisePower)
%DRONEMOTIONENERGYV12 Segment flight time and propulsion energy for V12.
    validateattributes(distance, {'numeric'}, {'real', 'finite', 'nonnegative'});
    if nargin < 3 || isempty(cruisePower)
        cruisePower = dronePropulsionPower(flight.cruiseSpeed, flight);
    end
    d = distance(:);
    mode = 'quasi-steady-accel';
    if isfield(flight, 'motionMode') && ~isempty(flight.motionMode)
        mode = flight.motionMode;
    end

    if strcmpi(mode, 'steady-cruise')
        out.peakSpeed = repmat(flight.cruiseSpeed, size(d));
        out.peakSpeed(d == 0) = 0;
        out.rampTime = zeros(size(d));
        out.cruiseTime = d / flight.cruiseSpeed;
        out.flightTimePerSegment = out.cruiseTime;
        out.rampEnergyPerSlot = zeros(size(d));
        out.cruiseEnergyPerSlot = cruisePower * out.cruiseTime;
        out.flightEnergyPerSlot = out.cruiseEnergyPerSlot;
    elseif strcmpi(mode, 'quasi-steady-accel')
        a = flight.acceleration;
        vc = flight.cruiseSpeed;
        vp = min(vc, sqrt(a * d));
        rampTime = 2 * vp / a;
        cruiseDist = max(0, d - (vp.^2) / a);
        cruiseTime = zeros(size(d));
        nz = vp > 0;
        cruiseTime(nz) = cruiseDist(nz) ./ vp(nz);

        if isfield(flight, 'glNodes01') && isfield(flight, 'glWeights01')
            nodes01 = flight.glNodes01;
            weights01 = flight.glWeights01;
        else
            nNodes = 16;
            if isfield(flight, 'quadratureNodes') && ~isempty(flight.quadratureNodes)
                nNodes = flight.quadratureNodes;
            end
            [nodes01, weights01] = fallbackGaussLegendre01(nNodes);
        end

        V = vp * nodes01;
        pAccel = quasiSteadyPower(V, a, flight);
        pDecel = quasiSteadyPower(V, -a, flight);
        rampEnergyPerSlot = (vp / a) .* ((pAccel + pDecel) * weights01);
        cruiseEnergyPerSlot = cruisePower * cruiseTime;

        out.peakSpeed = vp;
        out.rampTime = rampTime;
        out.cruiseTime = cruiseTime;
        out.flightTimePerSegment = rampTime + cruiseTime;
        out.rampEnergyPerSlot = rampEnergyPerSlot;
        out.cruiseEnergyPerSlot = cruiseEnergyPerSlot;
        out.flightEnergyPerSlot = rampEnergyPerSlot + cruiseEnergyPerSlot;
    else
        error('droneMotionEnergyV12:MotionMode', ...
            'Unsupported motionMode: %s', char(mode));
    end
end

function P = quasiSteadyPower(V, a, flight)
    n = flight.numRotors;
    rho = flight.airDensity;
    A = flight.rotorArea;
    cT = flight.thrustCoefficient;
    cs = flight.rotorSolidity;
    drag = 0.5 * rho * flight.flatPlateArea .* (V.^2);
    thrust = hypot(flight.mass * flight.gravity, flight.mass * a + drag) / n;
    profile = n * flight.bladeDrag / 8 .* (thrust / (cT * rho * A) + 3 * (V.^2)) ...
        .* sqrt(thrust * rho * cs^2 * A / cT);
    u = thrust / (2 * rho * A);
    w = (V.^2) / 2;
    induced = n * (1 + flight.inducedCorrection) .* thrust .* sqrt((u.^2) ./ (hypot(u, w) + w));
    parasite = n * 0.5 * flight.fuselageDragRatio * rho * cs * A .* (V.^3);
    P = profile + induced + parasite;
end

function [nodes01, weights01] = fallbackGaussLegendre01(n)
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
