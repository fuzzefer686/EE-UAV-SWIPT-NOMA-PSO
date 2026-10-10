function [minZ, z] = objective_function_positionUpdate_3D_SWIPT(x, ...
        xUAV, yUAV, zUAV, xBS, yBS, zBS, noUsers, xUser, yUser, ...
        minRate, fading, noBS)
%OBJECTIVE_FUNCTION_POSITIONUPDATE_3D_SWIPT SWIPT PSO objective.

    %#ok<INUSD>
    candidateX = xUAV + x(1);
    candidateZ = zUAV + x(2);

    [hUsers, hBS] = computeUAVChannels(candidateX, yUAV, candidateZ, ...
        xBS, yBS, zBS, xUser, yUser, fading);
    [coeffChannel, ~] = findPowCoeff(abs(hUsers).^2, noUsers);
    [achievableRate, ~] = findAchievableRate_SWIPT(...
        hUsers, hBS, coeffChannel, coeffChannel, noUsers);

    minZ = min(achievableRate);
    z = minZ;
end
