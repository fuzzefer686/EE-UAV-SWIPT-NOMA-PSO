function [minZ, z] = objective_function_positionUpdate_3D(x, xUAV, yUAV, ...
        zUAV, noUsers, xUser, yUser, minRate, fading)
%OBJECTIVE_FUNCTION_POSITIONUPDATE_3D Non-SWIPT PSO objective.

    % minRate is retained for call compatibility. The paper's objective is
    % simply the minimum achievable rate at the candidate position.
    %#ok<INUSD>
    candidateX = xUAV + x(1);
    candidateZ = zUAV + x(2);

    [hUsers, ~] = computeUAVChannels(candidateX, yUAV, candidateZ, ...
        [], [], [], xUser, yUser, fading);
    [coeffChannel, ~] = findPowCoeff(abs(hUsers).^2, noUsers);
    [achievableRate, ~] = findAchievableRate(...
        hUsers, coeffChannel, coeffChannel, noUsers);

    minZ = min(achievableRate);
    z = minZ;
end
