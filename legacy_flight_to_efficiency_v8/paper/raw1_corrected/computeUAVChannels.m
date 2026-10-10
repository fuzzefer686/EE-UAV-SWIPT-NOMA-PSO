function [hUsers, hBS, metrics] = computeUAVChannels(xUAV, yUAV, zUAV, ...
        xBS, yBS, zBS, xUser, yUser, fading)
%COMPUTEUAVCHANNELS Calculate BS-UAV and UAV-user Rician channels.
%
% This is the common channel model used by the main simulation and both
% PSO objective functions. Distances follow the paper's 3-D geometry,
% while the fading realization is kept fixed during one optimization run.

    p = paperParameters();
    eta = p.pathLossExponent;
    b0 = db2pow(p.referenceGaindB);
    Kmin = db2pow(p.KminDB);
    Kmax = db2pow(p.KmaxDB);
    A1 = Kmin;
    A2 = (2/pi) * log(Kmax / A1);

    noUsers = numel(xUser);
    noBS = numel(xBS);
    hUsers = zeros(1, noUsers);
    hBS = zeros(1, noBS);

    metrics.userDistance = zeros(1, noUsers);
    metrics.bsDistance = zeros(1, noBS);
    metrics.userElevationDeg = zeros(1, noUsers);
    metrics.bsElevationDeg = zeros(1, noBS);
    metrics.userPLoS = zeros(1, noUsers);
    metrics.bsPLoS = zeros(1, noBS);

    if nargin < 9 || isempty(fading)
        fading = makeRicianFadingState(noUsers, noBS);
    end

    for m = 1:noUsers
        groundDistance = hypot(xUAV - xUser(m), yUAV - yUser(m));
        distance = hypot(groundDistance, zUAV);
        elevationDeg = atan2(zUAV, max(groundDistance, eps)) * (180/pi);
        K = A1 * exp(A2 * elevationDeg * (pi/180));

        % Eq. (3) in the paper repeats K in the printed NLoS numerator;
        % the normalized Rician interpretation uses 1/(K+1) here.
        rician = sqrt(K/(1+K)) * fading.userLOS(m) + ...
                 sqrt(1/(1+K)) * fading.userNLOS(m);
        hUsers(m) = sqrt(b0 * distance^(-eta)) * rician;

        metrics.userDistance(m) = distance;
        metrics.userElevationDeg(m) = elevationDeg;
        metrics.userPLoS(m) = 1 / (1 + 10 * exp(-0.6 * (elevationDeg - 10)));
    end

    for m = 1:noBS
        groundDistance = hypot(xUAV - xBS(m), yUAV - yBS(m));
        distance = sqrt(groundDistance^2 + (zUAV - zBS(m))^2);
        elevationDeg = atan2(abs(zUAV - zBS(m)), max(groundDistance, eps)) * (180/pi);
        K = A1 * exp(A2 * elevationDeg * (pi/180));

        rician = sqrt(K/(1+K)) * fading.bsLOS(m) + ...
                 sqrt(1/(1+K)) * fading.bsNLOS(m);
        hBS(m) = sqrt(b0 * distance^(-eta)) * rician;

        metrics.bsDistance(m) = distance;
        metrics.bsElevationDeg(m) = elevationDeg;
        metrics.bsPLoS(m) = 1 / (1 + 10 * exp(-0.6 * (elevationDeg - 10)));
    end
end
