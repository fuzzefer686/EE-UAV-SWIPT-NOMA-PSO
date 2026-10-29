function plotV9EEUserHistories(raw, final, names, colors)
% Histories of the best-EE solution, not data accumulated over PSO iterations.
% User columns always follow physical User ID. Slot n is waypoint n -> n+1.
    fields = {'totalBitsPerUserHistory', 'transmitPowerHistory', 'alphaUserHistory'};
    for k = 1:3
        for f = 1:numel(fields)
            if ~isfield(raw{k}, fields{f})
                warning('plotV9EEUserHistories:MissingHistory', ...
                    'Rerun maincodeV9_EE to record per-user bit, RF power and NOMA histories.');
                return;
            end
        end
    end

    noUsers = size(raw{1}.totalBitsPerUserHistory, 2);
    userColors = lines(noUsers);
    userNames = arrayfun(@(u) sprintf('User %d', u), 1:noUsers, 'UniformOutput', false);
    for k = 1:3
        r = raw{k};
        n = numel(r.bestHistory);
        slots = numel(r.slotIdx);
        bits = r.totalBitsPerUserHistory;
        power = r.transmitPowerHistory;
        alpha = r.alphaUserHistory;
        if ~isequal(size(bits), [n, noUsers]) || ~isequal(size(power), [n, slots]) ...
                || size(alpha, 1) ~= n || size(alpha, 2) ~= slots || size(alpha, 3) ~= noUsers
            error('plotV9EEUserHistories:HistorySize', 'User histories must match iteration, slot and user dimensions.');
        end
        % Check that these traces describe the same solution as mission totals.
        bitsDifference = abs(sum(bits, 2) - r.totalBitsHistory(:));
        energyDifference = abs(sum(power, 2)*r.downlinkTime - r.totalEnergyHistory(:));
        alphaSum = sum(alpha, 3);
        if any(~isfinite(bits(:))) || any(~isfinite(power(:))) || any(~isfinite(alpha(:))) ...
                || any(bitsDifference > 1e-10*max(1, abs(r.totalBitsHistory(:)))) ...
                || any(energyDifference > 1e-10*max(realmin, abs(r.totalEnergyHistory(:)))) ...
                || any(abs(alphaSum(:) - 1) > 1e-10)
            error('plotV9EEUserHistories:HistoryMismatch', 'Per-user/slot histories disagree with mission totals or normalized alpha.');
        end
    end

    % 11: total mission bits delivered to each physical user at each iteration.
    figure(11); clf;
    for k = 1:3
        subplot(3, 1, k); hold on;
        r = raw{k}; iteration = 0:(numel(r.bestHistory)-1);
        handles = gobjects(1, noUsers);
        for u = 1:noUsers
            handles(u) = plot(iteration, r.totalBitsPerUserHistory(:, u)/1e6, ...
                'Color', userColors(u, :), 'LineWidth', 1.4);
            if k > 1
                plot(iteration(end), final{k}.totalBitsPerUser(u)/1e6, 'o', ...
                    'Color', userColors(u, :), 'MarkerFaceColor', userColors(u, :), ...
                    'HandleVisibility', 'off');
            end
        end
        grid on; xlabel('Iteration'); ylabel('Bits per user (Mbit)');
        title({names{k}, 'Total over mission slots; circles: after alpha polishing'});
        legend(handles, userNames, 'Location', 'best');
    end

    % 12: downlink RF power; mean/min/max plus EVERY slot at EVERY iteration.
    figure(12); clf;
    for k = 1:3
        r = raw{k}; iteration = 0:(numel(r.bestHistory)-1);
        powerNanoW = r.transmitPowerHistory*1e9;
        subplot(3, 2, 2*k-1); hold on;
        plot(iteration, mean(powerNanoW, 2), 'Color', colors(k, :), 'LineWidth', 1.6);
        plot(iteration, min(powerNanoW, [], 2), 'k--');
        plot(iteration, max(powerNanoW, [], 2), 'k:');
        if k > 1
            plot(iteration(end), mean(final{k}.pt(final{k}.slotIdx))*1e9, 'o', ...
                'Color', colors(k, :), 'MarkerFaceColor', colors(k, :), 'HandleVisibility', 'off');
        end
        grid on; xlabel('Iteration'); ylabel('UAV RF power (nW)');
        title([names{k} ': power over mission slots']);
        legend({'Mean', 'Minimum', 'Maximum'}, 'Location', 'best');
        subplot(3, 2, 2*k);
        imagesc(iteration, r.slotIdx, powerNanoW.'); axis xy;
        xlabel('Iteration'); ylabel('Mission slot');
        title([names{k} ': RF power per slot']);
        cb = colorbar; cb.Label.String = 'UAV RF power (nW)';
    end
    % Shared scale makes the three power maps directly comparable.
    minPower = Inf; maxPower = -Inf;
    for k = 1:3
        minPower = min(minPower, min(raw{k}.transmitPowerHistory(:))*1e9);
        maxPower = max(maxPower, max(raw{k}.transmitPowerHistory(:))*1e9);
    end
    if maxPower > minPower
        for k = 1:3
            subplot(3, 2, 2*k); caxis([minPower, maxPower]);
        end
    end

    % 13: mean NOMA alpha over mission slots, keeping original User IDs.
    figure(13); clf;
    for k = 1:3
        subplot(3, 1, k); hold on;
        r = raw{k}; iteration = 0:(numel(r.bestHistory)-1);
        meanAlpha = reshape(mean(r.alphaUserHistory, 2), [], noUsers);
        handles = gobjects(1, noUsers);
        for u = 1:noUsers
            handles(u) = plot(iteration, meanAlpha(:, u), 'Color', userColors(u, :), 'LineWidth', 1.4);
            if k > 1
                plot(iteration(end), mean(final{k}.alphaTrace(final{k}.slotIdx, u)), 'o', ...
                    'Color', userColors(u, :), 'MarkerFaceColor', userColors(u, :), ...
                    'HandleVisibility', 'off');
            end
        end
        plot([iteration(1), iteration(end)], [1, 1]/noUsers, 'k--', 'HandleVisibility', 'off');
        grid on; xlabel('Iteration'); ylabel('Mean NOMA alpha');
        title({names{k}, 'Mean over slots; dashed: 1/N; circles: after polishing'});
        legend(handles, userNames, 'Location', 'best');
    end

    % 14/15/16: full alpha maps for EACH user of EACH algorithm (no averaging).
    for k = 1:3
        figure(13+k); clf;
        r = raw{k}; iteration = 0:(numel(r.bestHistory)-1);
        for u = 1:noUsers
            subplot(ceil(noUsers/2), 2, u);
            imagesc(iteration, r.slotIdx, r.alphaUserHistory(:, :, u).');
            axis xy; caxis([0, 1]);
            xlabel('Iteration'); ylabel('Mission slot');
            title(sprintf('%s - User %d NOMA alpha', names{k}, u));
            cb = colorbar; cb.Label.String = 'NOMA alpha';
        end
    end
end
