function results = runTrajectorySimulation()
%RUNTRAJECTORYSIMULATION Reproduce the paper's UAV trajectory workflow.
%
% At every Y step, two independent PSO runs are performed: one maximizes
% the minimum downlink rate without SWIPT, and the other does so with
% harvested energy included. Each PSO starts from the previous optimized
% point, so the generated path obeys the per-step X displacement limit.

    p = paperParameters();
    rng(1, 'twister');
    enWidth = p.environmentWidth;
    enLength = p.environmentLength;
    enHeight = p.environmentHeight;
    noUsers = p.noUsers;
    noBS = p.noBS;

    xStart = p.startPosition(1);
    yStart = p.startPosition(2);
    zStart = p.startPosition(3);
    xEnd = p.endPosition(1);
    yEnd = p.endPosition(2);
    zEnd = p.endPosition(3);

    xBS = [2000, 0, 2000];
    yBS = [2000, 1000, 0];
    zBS = [20, 30, 25];

    % Keep users in the central area, as in the original main script.
    xUser = randi([enWidth/4, 3*enWidth/4], 1, noUsers);
    yUser = randi([enLength/4, 3*enLength/4], 1, noUsers);
    zUser = zeros(1, noUsers); %#ok<NASGU>

    fading = makeRicianFadingState(noUsers, noBS);
    ySteps = yStart:-p.yStep:yEnd;
    noSteps = numel(ySteps);

    defaultPosition = zeros(noSteps, 3);
    optimizedPosition = zeros(noSteps, 3);
    optimizedPositionSWIPT = zeros(noSteps, 3);
    userRate = zeros(noSteps, noUsers);
    userRateOptimized = zeros(noSteps, noUsers);
    userRateSWIPT = zeros(noSteps, noUsers);
    userRateSWIPTOptimized = zeros(noSteps, noUsers);
    minRate = zeros(noSteps, 1);
    minRateOptimized = zeros(noSteps, 1);
    minRateSWIPT = zeros(noSteps, 1);
    minRateSWIPTOptimized = zeros(noSteps, 1);
    userPLoS = zeros(noSteps, noUsers);
    bsPLoS = zeros(noSteps, noBS);

    previousOptimized = [xStart, zStart];
    previousOptimizedSWIPT = [xStart, zStart];

    for step = 1:noSteps
        yUAV = ySteps(step);
        defaultPosition(step, :) = [xStart, yUAV, zStart];

        [hUsers, hBS, channelInfo] = computeUAVChannels(...
            xStart, yUAV, zStart, xBS, yBS, zBS, xUser, yUser, fading);
        defaultRates = evaluateUAVRates(hUsers, hBS);
        userRate(step, :) = defaultRates.userChannel;
        userRateSWIPT(step, :) = defaultRates.userChannelSWIPT;
        minRate(step) = defaultRates.minUser;
        minRateSWIPT(step) = defaultRates.minUserSWIPT;
        userPLoS(step, :) = channelInfo.userPLoS;
        bsPLoS(step, :) = channelInfo.bsPLoS;

        if step == 1
            optimizedPosition(step, :) = [xStart, yUAV, zStart];
            optimizedPositionSWIPT(step, :) = [xStart, yUAV, zStart];
        elseif step == noSteps
            optimizedPosition(step, :) = [xEnd, yUAV, zEnd];
            optimizedPositionSWIPT(step, :) = [xEnd, yUAV, zEnd];
        else
            % The final interior point also has to be within 500 m of the
            % fixed end point, so the next-X constraint is passed to PSO.
            nextX = [];
            if step == noSteps - 1
                nextX = xEnd;
            end

            update = positionUpdate_PSO(...
                previousOptimized(1), yUAV, previousOptimized(2), ...
                0, noUsers, xUser, yUser, fading, nextX);
            optimizedPosition(step, :) = [previousOptimized(1) + update.position(1), ...
                yUAV, previousOptimized(2) + update.position(2)];

            updateSWIPT = positionUpdate_PSO_SWIPT(...
                previousOptimizedSWIPT(1), yUAV, previousOptimizedSWIPT(2), ...
                xBS, yBS, zBS, 0, noUsers, xUser, yUser, fading, noBS, nextX);
            optimizedPositionSWIPT(step, :) = [previousOptimizedSWIPT(1) + updateSWIPT.position(1), ...
                yUAV, previousOptimizedSWIPT(2) + updateSWIPT.position(2)];
        end

        previousOptimized = optimizedPosition(step, [1, 3]);
        previousOptimizedSWIPT = optimizedPositionSWIPT(step, [1, 3]);

        [hUsersOpt, hBSOpt] = computeUAVChannels(...
            optimizedPosition(step, 1), optimizedPosition(step, 2), optimizedPosition(step, 3), ...
            xBS, yBS, zBS, xUser, yUser, fading);
        optimizedRates = evaluateUAVRates(hUsersOpt, hBSOpt);
        userRateOptimized(step, :) = optimizedRates.userChannel;
        minRateOptimized(step) = optimizedRates.minUser;

        [hUsersOptSWIPT, hBSOptSWIPT] = computeUAVChannels(...
            optimizedPositionSWIPT(step, 1), optimizedPositionSWIPT(step, 2), optimizedPositionSWIPT(step, 3), ...
            xBS, yBS, zBS, xUser, yUser, fading);
        optimizedRatesSWIPT = evaluateUAVRates(hUsersOptSWIPT, hBSOptSWIPT);
        userRateSWIPTOptimized(step, :) = optimizedRatesSWIPT.userChannelSWIPT;
        minRateSWIPTOptimized(step) = optimizedRatesSWIPT.minUserSWIPT;
    end

    % 3-D trajectory plot.
    figure;
    plot3(defaultPosition(:,1), defaultPosition(:,2), defaultPosition(:,3), ...
        'r--o', 'LineWidth', 1); hold on;
    plot3(optimizedPosition(:,1), optimizedPosition(:,2), optimizedPosition(:,3), ...
        'g-o', 'LineWidth', 1);
    plot3(optimizedPositionSWIPT(:,1), optimizedPositionSWIPT(:,2), optimizedPositionSWIPT(:,3), ...
        'b-o', 'LineWidth', 1);
    plot3(xUser, yUser, zUser, 'k*', 'LineWidth', 2);
    plot3(xBS, yBS, zBS, 'k^', 'LineWidth', 2);
    xlim([0 enWidth]); ylim([0 enLength]); zlim([0 enHeight]);
    xlabel('X (m)'); ylabel('Y (m)'); zlabel('Height (m)');
    legend('Predefined', 'PSO without SWIPT', 'PSO with SWIPT', 'Users', 'BSs', ...
        'Location', 'best');
    grid on; title('UAV trajectories');

    figure;
    plot(ySteps, userRate, '--', 'LineWidth', 1); hold on;
    plot(ySteps, userRateOptimized, '-', 'LineWidth', 1);
    xlabel('UAV Y position (m)'); ylabel('Rate (bps)');
    title('Downlink NOMA rate without SWIPT'); grid on;

    figure;
    plot(ySteps, userRateSWIPT, '--', 'LineWidth', 1); hold on;
    plot(ySteps, userRateSWIPTOptimized, '-', 'LineWidth', 1);
    xlabel('UAV Y position (m)'); ylabel('Rate (bps)');
    title('Downlink NOMA rate with SWIPT'); grid on;

    figure;
    plot(ySteps, minRate, 'r--', 'LineWidth', 1); hold on;
    plot(ySteps, minRateOptimized, 'g-', 'LineWidth', 1);
    plot(ySteps, minRateSWIPT, 'b--', 'LineWidth', 1);
    plot(ySteps, minRateSWIPTOptimized, 'k-', 'LineWidth', 1);
    xlabel('UAV Y position (m)'); ylabel('Minimum user rate (bps)');
    legend('Default', 'Optimized', 'Default SWIPT', 'Optimized SWIPT', ...
        'Location', 'best');
    title('Minimum achievable rate'); grid on;

    results = struct();
    results.userPositions = [xUser(:), yUser(:), zUser(:)];
    results.bsPositions = [xBS(:), yBS(:), zBS(:)];
    results.ySteps = ySteps;
    results.defaultPosition = defaultPosition;
    results.optimizedPosition = optimizedPosition;
    results.optimizedPositionSWIPT = optimizedPositionSWIPT;
    results.userRate = userRate;
    results.userRateOptimized = userRateOptimized;
    results.userRateSWIPT = userRateSWIPT;
    results.userRateSWIPTOptimized = userRateSWIPTOptimized;
    results.minRate = minRate;
    results.minRateOptimized = minRateOptimized;
    results.minRateSWIPT = minRateSWIPT;
    results.minRateSWIPTOptimized = minRateSWIPTOptimized;
    results.userPLoS = userPLoS;
    results.bsPLoS = bsPLoS;
end
