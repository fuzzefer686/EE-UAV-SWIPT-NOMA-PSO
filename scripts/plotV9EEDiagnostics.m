function plotV9EEDiagnostics(trajJoint, trajFullRaw, trajIPSORaw, trajFull, trajIPSO)
% Plot existing results only. Old results can show EE/slot/final comparisons;
% new runs additionally have bit/energy histories for every optimization step.
    names = {'Joint PSO', 'Full PSO', 'Full IPSO'};
    colors = [0.8500 0.3250 0.0980; 0.4660 0.6740 0.1880; 0.6350 0.0780 0.1840];
    styles = {'-', '--', ':'};
    raw = {trajJoint, trajFullRaw, trajIPSORaw};
    final = {trajJoint, trajFull, trajIPSO};
    finalBits = zeros(1, 3);
    finalEnergy = zeros(1, 3);
    finalEE = zeros(1, 3);
    hasHistories = true;
    for k = 1:3
        if ~isfield(final{k}, 'eeRF')
            error('plotV9EEDiagnostics:WrongMode', 'Need V9 EE results, not rate-only V8.');
        end
        finalBits(k) = final{k}.totalBits;
        finalEnergy(k) = final{k}.totalEnergy;
        finalEE(k) = final{k}.eeRF;
        hasHistories = hasHistories && isfield(raw{k}, 'totalBitsHistory') ...
            && isfield(raw{k}, 'totalEnergyHistory');
    end
    if hasHistories
        for k = 1:3
            if numel(raw{k}.totalBitsHistory) ~= numel(raw{k}.bestHistory) ...
                    || numel(raw{k}.totalEnergyHistory) ~= numel(raw{k}.bestHistory)
                error('plotV9EEDiagnostics:HistorySize', 'EE, bit and energy histories must have equal lengths.');
            end
            bits = raw{k}.totalBitsHistory(:);
            energy = raw{k}.totalEnergyHistory(:);
            ee = raw{k}.bestHistory(:);
            % Negative fitness ranks data shortfall; it is not an EE value.
            valid = isfinite(ee) & ee >= 0 & energy > 0;
            if any(~isfinite(bits(valid))) || any(~isfinite(energy(valid))) ...
                    || any(abs(bits(valid)./energy(valid) - ee(valid)) > 1e-10*max(1, abs(ee(valid))))
                error('plotV9EEDiagnostics:HistoryMismatch', 'EE history must equal bit history divided by RF energy history.');
            end
        end
    else
        warning('plotV9EEDiagnostics:MissingHistory', ...
            ['Old results have no per-iteration bit/energy histories. Figures 7/8 show final totals; ' ...
             'rerun maincodeV9_EE to obtain those two iteration curves.']);
    end

    % 6: feasible EE convergence; gaps mark infeasible fitness values.
    % Raw histories exclude polishing, including any negative iteration 0.
    figure(6); clf; hold on;
    handles = gobjects(1, 3);
    for k = 1:3
        iteration = 0:(numel(raw{k}.bestHistory)-1);
        ee = raw{k}.bestHistory;
        ee(~isfinite(ee) | ee < 0) = NaN;
        handles(k) = plot(iteration, ee, 'Color', colors(k, :), ...
            'LineStyle', styles{k}, 'LineWidth', 1.6);
        if k > 1
            plot(iteration(end), finalEE(k), 'o', 'Color', colors(k, :), ...
                'MarkerFaceColor', colors(k, :), 'MarkerSize', 7, 'HandleVisibility', 'off');
        end
    end
    grid on; xlabel('Iteration'); ylabel('Best RF EE (bit/J)');
    title({'EE convergence of all three algorithms', ...
        'Gaps: infeasible; lines: optimization; circles: after alpha polishing'});
    legend(handles, names, 'Location', 'best');

    % 7/8: metrics of the SAME best-fitness particle at each iteration.
    for metric = 1:2
        figure(6 + metric); clf; hold on;
        if metric == 1
            field = 'totalBitsHistory'; values = finalBits / 1e6;
            scale = 1e-6; axisLabel = 'Total mission bits (Mbit)';
        else
            field = 'totalEnergyHistory'; values = finalEnergy * 1e6;
            scale = 1e6; axisLabel = 'Total RF transmit energy (\muJ)';
        end
        if hasHistories
            handles = gobjects(1, 3);
            for k = 1:3
                iteration = 0:(numel(raw{k}.bestHistory)-1);
                handles(k) = plot(iteration, raw{k}.(field) * scale, ...
                    'Color', colors(k, :), 'LineStyle', styles{k}, 'LineWidth', 1.6);
                if k > 1
                    plot(iteration(end), values(k), 'o', 'Color', colors(k, :), ...
                        'MarkerFaceColor', colors(k, :), 'MarkerSize', 7, 'HandleVisibility', 'off');
                end
            end
            xlabel('Iteration'); legend(handles, names, 'Location', 'best');
            title({axisLabel, 'Same best-fitness particle; circles: after alpha polishing'});
        else
            b = bar(1:3, values, 'FaceColor', 'flat'); b.CData = colors;
            xticks(1:3); xticklabels(names);
            title({['Final comparison: ' axisLabel], 'Iteration history unavailable in these old results'});
        end
        grid on; ylabel(axisLabel);
    end

    % 9: slot-level differences behind the final mission EE.
    figure(9); clf;
    for panel = 1:4
        subplot(2, 2, panel); hold on;
        for k = 1:3
            r = final{k};
            switch panel
                case 1
                    values = r.bitsPerSlot / 1e6;
                    axisLabel = 'Bits per slot (Mbit)';
                case 2
                    values = r.energyPerSlot * 1e6;
                    axisLabel = 'RF energy per slot (\muJ)';
                case 3
                    values = NaN(size(r.energyPerSlot));
                    valid = r.energyPerSlot > 0;
                    values(valid) = r.bitsPerSlot(valid) ./ r.energyPerSlot(valid);
                    axisLabel = 'Slot RF EE (bit/J)';
                case 4
                    alpha = r.alphaOrdTrace(r.slotIdx, :);
                    values = max(abs(alpha - 1/size(alpha, 2)), [], 2);
                    axisLabel = 'Max alpha deviation from equal allocation';
            end
            plot(r.slotIdx, values, 'Color', colors(k, :), 'LineStyle', styles{k}, 'LineWidth', 1.4);
        end
        grid on; xlabel('Mission slot'); ylabel(axisLabel);
        title(axisLabel); legend(names, 'Location', 'best');
    end

    % 10: equal-EE solutions lie on the same bits-versus-energy line.
    figure(10); clf; hold on;
    energyMicroJ = finalEnergy * 1e6;
    bitsMbit = finalBits / 1e6;
    handles = gobjects(1, 4);
    for k = 1:3
        handles(k) = plot(energyMicroJ(k), bitsMbit(k), 'o', ...
            'Color', colors(k, :), 'MarkerFaceColor', colors(k, :), 'MarkerSize', 9);
    end
    referenceEE = mean(finalEE);
    energyAxis = linspace(0.95*min(energyMicroJ), 1.05*max(energyMicroJ), 100);
    handles(4) = plot(energyAxis, referenceEE * 1e-12 * energyAxis, 'k--', 'LineWidth', 1.2);
    grid on; xlabel('Total RF transmit energy (\muJ)'); ylabel('Total mission bits (Mbit)');
    title({'Final bits versus RF energy', sprintf('Dashed line: reference EE = %.6e bit/J', referenceEE)});
    legend(handles, [names, {'Reference EE (mean of final EE values)'}], 'Location', 'best');

    % 11-16: per-user bits and full slot histories of power/NOMA coefficients.
    plotV9EEUserHistories(raw, final, names, colors);

end
