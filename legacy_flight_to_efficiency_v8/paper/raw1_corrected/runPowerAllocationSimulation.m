function results = runPowerAllocationSimulation()
%RUNPOWERALLOCATIONSIMULATION Reproduce the paper's Fig. 2 experiment.
%
% The UAV is held at one position while the total downlink transmit power
% is swept from 0 to 60 dBm. The three methods are the paper's Algorithm 2,
% Algorithm 1, and a fixed [0.7, 0.2, 0.1] allocation from weakest to
% strongest channel. The paper does not list the fixed values in Table I;
% this convention follows the existing repository's NOMA scripts.

    p = paperParameters();
    rng(1, 'twister');

    xUser = randi([p.environmentWidth/4, 3*p.environmentWidth/4], 1, p.noUsers);
    yUser = randi([p.environmentLength/4, 3*p.environmentLength/4], 1, p.noUsers);
    xBS = [2000, 0, 2000];
    yBS = [2000, 1000, 0];
    zBS = [20, 30, 25];
    fading = makeRicianFadingState(p.noUsers, p.noBS);

    [hUsers, ~] = computeUAVChannels(...
        p.startPosition(1), p.startPosition(2), p.startPosition(3), ...
        xBS, yBS, zBS, xUser, yUser, fading);
    channelPower = abs(hUsers).^2;

    [coeffChannel, coeffFraction] = findPowCoeff(channelPower, p.noUsers);
    [~, weakestToStrongest] = sort(channelPower, 'ascend');
    coeffFixed = zeros(1, p.noUsers);
    coeffFixed(weakestToStrongest) = p.fixedPowerCoefficients;

    powerSweep = p.powerSweepdBm;
    channelRate = zeros(numel(powerSweep), p.noUsers);
    fractionRate = zeros(numel(powerSweep), p.noUsers);
    fixedRate = zeros(numel(powerSweep), p.noUsers);

    for k = 1:numel(powerSweep)
        channelRate(k, :) = findAchievableRate(...
            hUsers, coeffChannel, coeffChannel, p.noUsers, powerSweep(k));
        fractionRate(k, :) = findAchievableRate(...
            hUsers, coeffFraction, coeffFraction, p.noUsers, powerSweep(k));
        fixedRate(k, :) = findAchievableRate(...
            hUsers, coeffFixed, coeffFixed, p.noUsers, powerSweep(k));
    end

    figure;
    plot(powerSweep, channelRate, 'LineWidth', 1.1); hold on;
    plot(powerSweep, fractionRate, '--', 'LineWidth', 1.1);
    plot(powerSweep, fixedRate, ':', 'LineWidth', 1.1);
    xlabel('Transmit power (dBm)');
    ylabel('Achievable rate (bps)');
    title('Power allocation methods - paper Fig. 2');
    grid on;
    legend('Channel gain - User 1', 'Channel gain - User 2', ...
        'Channel gain - User 3', 'Fractional - User 1', ...
        'Fractional - User 2', 'Fractional - User 3', ...
        'Fixed - User 1', 'Fixed - User 2', 'Fixed - User 3', ...
        'Location', 'northwest');

    results = struct();
    results.powerSweepdBm = powerSweep;
    results.channelRate = channelRate;
    results.fractionRate = fractionRate;
    results.fixedRate = fixedRate;
    results.coeffChannel = coeffChannel;
    results.coeffFraction = coeffFraction;
    results.coeffFixed = coeffFixed;
    results.userPositions = [xUser(:), yUser(:), zeros(p.noUsers, 1)];
end
