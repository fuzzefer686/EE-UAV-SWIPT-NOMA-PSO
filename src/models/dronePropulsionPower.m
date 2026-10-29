function [power, parts] = dronePropulsionPower(speed, flight)
%DRONEPROPULSIONPOWER Drones 10(4),238 Eq. (11), horizontal steady flight [W].
% Zero speed is hover. Manoeuvring, motor efficiency and climb are not added.
% Eq. (10) is interpreted as the magnitude of the rotor force vector.
    validateattributes(speed,{'numeric'},{'real','finite','nonnegative'});
    positive = {'numRotors','airDensity','mass','gravity','rotorSolidity', ...
        'thrustCoefficient','rotorArea'};
    for k=1:numel(positive)
        validateattributes(flight.(positive{k}),{'numeric'}, ...
            {'real','finite','scalar','positive'});
    end
    nonnegative = {'flatPlateArea','bladeDrag','inducedCorrection','fuselageDragRatio'};
    for k=1:numel(nonnegative)
        validateattributes(flight.(nonnegative{k}),{'numeric'}, ...
            {'real','finite','scalar','nonnegative'});
    end
    n=flight.numRotors; rho=flight.airDensity; A=flight.rotorArea;
    cT=flight.thrustCoefficient; cs=flight.rotorSolidity;
    drag = 0.5*rho*flight.flatPlateArea.*speed.^2;
    thrust = hypot(flight.mass*flight.gravity,drag)/n;
    parts.profile = n*flight.bladeDrag/8 .* (thrust/(cT*rho*A)+3*speed.^2) ...
        .* sqrt(thrust*rho*cs^2*A/cT);
    % Rationalized inner difference avoids cancellation at large speeds:
    % sqrt(T^2/(4*rho^2*A^2)+v^4/4)-v^2/2.
    u = thrust/(2*rho*A);
    w = speed.^2/2;
    inducedSpeed = sqrt(u.^2 ./ (hypot(u,w)+w));
    parts.induced = n*(1+flight.inducedCorrection).*thrust.*inducedSpeed;
    parts.parasite = n*0.5*flight.fuselageDragRatio*rho*cs*A.*speed.^3;
    parts.thrustPerRotor = thrust;
    power = parts.profile + parts.induced + parts.parasite;
end
