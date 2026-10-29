function didPlot = plotV10Diagnostics(data)
%PLOTV10DIAGNOSTICS V9-style figures with total-energy and RF kept distinct.
% Raw histories never include polishing; only feasible final points show EE.
    % Older saved V10 configurations without these fields still draw all groups.
    groups=struct('base',true,'EH_Alpha_config',true,'flyingEnergy',true);
    if isfield(data.cfg.output,'figureGroups')
        fields=fieldnames(groups);
        for k=1:numel(fields)
            name=fields{k};
            if isfield(data.cfg.output.figureGroups,name)
                value=data.cfg.output.figureGroups.(name);
                validateattributes(value,{'logical','numeric'},{'scalar','binary'});
                groups.(name)=logical(value);
            end
        end
    end
    didPlot=groups.base || groups.EH_Alpha_config || groups.flyingEnergy;
    if ~didPlot
        return;
    end
    sim=data.sim;
    names={'Joint PSO','Full PSO','Full IPSO'};
    colors=[0.8500,0.3250,0.0980;0.4660,0.6740,0.1880;0.6350,0.0780,0.1840];
    raw={data.trajJoint,data.trajFullRaw,data.trajIPSORaw};
    final={data.trajJoint,data.trajFull,data.trajIPSO};
    styles={'-','--',':'};
    userColors=lines(sim.noUsers);
    noUsers=sim.noUsers;
    userNames=arrayfun(@(u) sprintf('User %d',u),1:noUsers,'UniformOutput',false);
    for k=1:3
        r=raw{k};
        diffEnergy=r.totalEnergyHistory-r.flightEnergyHistory-r.hoverEnergyHistory-r.rfEnergyHistory;
        diffRF=sum(r.transmitPowerHistory,2)*r.downlinkTime-r.rfEnergyHistory;
        valid=isfinite(r.totalEnergyHistory);
        if any(abs(diffEnergy(valid))>1e-10*max(1,abs(r.totalEnergyHistory(valid)))) ...
                || any(abs(diffRF(valid))>1e-10*max(realmin,abs(r.rfEnergyHistory(valid))))
            error('plotV10Diagnostics:EnergyHistory','Total and RF histories disagree with their energy scope.');
        end
    end
    % Keep V9 plotting blocks/markers/legend ordering, with V10 data aliases.
    trajFull=data.trajFull; trajIPSO=data.trajIPSO; resBase=data.resBase;
    trajJoint=data.trajJoint;
    xUser=sim.xUser; yUser=sim.yUser; zUser=sim.zUser;
    xUAV_S=sim.xStart; yUAV_S=sim.yStart; zUAV_S=sim.altitude;
    xUAV_E=sim.xEnd; yUAV_E=sim.yEnd; zUAV_E=sim.altitude;
    numSteps=sim.numSteps;
    enWidth=data.cfg.geometry.width; enLength=data.cfg.geometry.length;
    enHeight=max(60,1.2*max([sim.altitude,sim.zBS]));
    colorBaseline=[0.0000,0.4470,0.7410];
    colorJoint=colors(1,:);
    colorFull=colors(2,:); colorIPSO=colors(3,:);

    if groups.base

        %% FIGURE 1: Trajectory comparison
        figure(1); clf; hold on;

        % Users
        hUser = plot3(xUser, yUser, zUser, 'k*', 'LineWidth', 2, 'MarkerSize', 8);
        for u = 1:noUsers
            text(xUser(u)+3, yUser(u)+3, zUser(u)+3, ['GU', num2str(u)]);
        end

        % Initial BS
        hInitBS = plot3(sim.xBS, sim.yBS, sim.zBS, 'k^', 'LineWidth', 2, 'MarkerSize', 9);

        % Optimized BS (PSO)
        hOptBS_PSO = plot3(trajFull.xBS, trajFull.yBS, trajFull.zBS, 'p', ...
            'Color', colorFull, 'MarkerFaceColor', colorFull, 'LineWidth', 2, 'MarkerSize', 10);

        % Optimized BS (IPSO)
        hOptBS_IPSO = plot3(trajIPSO.xBS, trajIPSO.yBS, trajIPSO.zBS, 'h', ...
            'Color', colorIPSO, 'MarkerFaceColor', colorIPSO, 'LineWidth', 2, 'MarkerSize', 12);
        %% BS vertical columns

        for b = 1:sim.noBS
            plot3([sim.xBS(b), sim.xBS(b)], ...
                  [sim.yBS(b), sim.yBS(b)], ...
                  [0, sim.zBS(b)], ...
                  'k-', 'LineWidth', 1.2);
        end

        for b = 1:sim.noBS
            plot3([trajFull.xBS(b), trajFull.xBS(b)], ...
                  [trajFull.yBS(b), trajFull.yBS(b)], ...
                  [0, trajFull.zBS(b)], ...
                  '-', 'Color', colorFull, 'LineWidth', 1.5);
        end

        for b = 1:sim.noBS
            plot3([trajIPSO.xBS(b), trajIPSO.xBS(b)], ...
                  [trajIPSO.yBS(b), trajIPSO.yBS(b)], ...
                  [0, trajIPSO.zBS(b)], ...
                  '-', 'Color', colorIPSO, 'LineWidth', 1.5);
        end

        % Start / End UAV
        hStart = plot3(xUAV_S, yUAV_S, zUAV_S, 'ko', 'LineWidth', 2, 'MarkerSize', 8);
        hEnd = plot3(xUAV_E, yUAV_E, zUAV_E, 'ks', 'LineWidth', 2, 'MarkerSize', 8);

        % Trajectories
        hBaseline = plot3(resBase.xTraj, resBase.yTraj, resBase.zTraj, '--o', ...
            'Color', colorBaseline, 'LineWidth', 1.3, 'MarkerSize', 4);

        hJoint = plot3(trajJoint.xTraj, trajJoint.yTraj, trajJoint.zTraj, '-o', ...
            'Color', colorJoint, 'LineWidth', 1.5, 'MarkerSize', 5);

        hFull = plot3(trajFull.xTraj, trajFull.yTraj, trajFull.zTraj, '-^', ...
            'Color', colorFull, 'LineWidth', 1.8, 'MarkerSize', 5);

        hIPSO = plot3(trajIPSO.xTraj, trajIPSO.yTraj, trajIPSO.zTraj, '-d', ...
            'Color', colorIPSO, 'LineWidth', 2.0, 'MarkerSize', 6);

        grid on;
        xlabel('x / Width (m)'); ylabel('y / Length (m)'); zlabel('z / Height (m)');
        title('Trajectory: Baseline vs Joint PSO vs Full PSO vs Full IPSO');

        legend([hUser, hInitBS, hOptBS_PSO, hOptBS_IPSO, hStart, hEnd, hBaseline, hJoint, hFull, hIPSO], ...
            {'Ground Users', 'Initial BS', 'Opt BS (PSO)', 'Opt BS (IPSO)', 'UAV Start', 'UAV End', ...
             'Baseline', 'Joint PSO', 'Full PSO', 'Full IPSO'}, ...
             'Location', 'best');

        xlim([0 enWidth]); ylim([0 enLength]); zlim([0 enHeight]); view(3);
        rotate3d on; % drag Figure 1 to orbit the 3D view

        %% FIGURE 2: MinRate comparison (serving slots only)
        figure(2); clf; hold on;

        % Slot n serves at its start waypoint. The final waypoint is an
        % arrival point with no hover/DL, so it must not appear here.
        slotAxis = 1:(numSteps-1);

        hBase = plot(slotAxis, resBase.stepMin(slotAxis), '--o', ...
            'Color', colorBaseline, ...
            'LineWidth', 1.3, ...
            'MarkerSize', 4);

        hJoint = plot(slotAxis, trajJoint.stepMin(slotAxis), '-s', ...
            'Color', colorJoint, ...
            'LineWidth', 1.5, ...
            'MarkerSize', 5);

        hFull = plot(slotAxis, trajFull.stepMin(slotAxis), '-^', ...
            'Color', colorFull, ...
            'LineWidth', 1.8, ...
            'MarkerSize', 5);

        hIPSO = plot(slotAxis, trajIPSO.stepMin(slotAxis), '-d', ...
            'Color', colorIPSO, ...
            'LineWidth', 2.0, ...
            'MarkerSize', 6);

        grid on;
        xlabel('Mission slot');
        ylabel('Minimum achievable rate among users (bps)');
        title('MinRate per serving slot: Baseline vs Joint PSO vs Full PSO vs Full IPSO');

        if resBase.isFeasible
            baseName = 'Baseline';
        else
            baseName = 'Baseline (infeasible)';
        end
        legend([hBase,hJoint,hFull,hIPSO], ...
            {baseName,'Joint PSO','Full PSO','Full IPSO'}, 'Location', 'best');

        xlim([1 numSteps-1]);
        xticks(1:numSteps-1);


        %% FIGURE 4: Per-user achievable rate - Full PSO vs Full IPSO
        figure(4); clf; hold on;

        userColors = lines(noUsers);
        h = gobjects(2 * noUsers, 1);
        leg = cell(2 * noUsers, 1);

        for u = 1:noUsers
            h(u) = plot(slotAxis, trajFull.achRate(slotAxis,u), '--o', ...
                'Color', userColors(u,:), ...
                'LineWidth', 1.3, ...
                'MarkerSize', 4);

            leg{u} = sprintf('User %d - Full PSO', u);
        end

        for u = 1:noUsers
            h(noUsers + u) = plot(slotAxis, trajIPSO.achRate(slotAxis,u), '-s', ...
                'Color', userColors(u,:), ...
                'LineWidth', 1.8, ...
                'MarkerSize', 5);

            leg{noUsers + u} = sprintf('User %d - Full IPSO', u);
        end

        grid on;
        xlabel('Mission slot');
        ylabel('Achievable rate (bps)');
        title(sprintf('Per-user achievable rate: Full PSO vs Full IPSO, N = %d', noUsers));
        legend(h, leg, 'Location', 'best');
        xlim([1 numSteps-1]);
        xticks(1:numSteps-1);

        %% FIGURE 5: UAV transmit power comparison
        % ptJoint_dBm = 10 * log10(trajJoint.pt / 1e-3);
        ptFull_dBm  = 10 * log10(trajFull.pt(slotAxis) / 1e-3);
        ptIPSO_dBm  = 10 * log10(trajIPSO.pt(slotAxis) / 1e-3);

        figure(5); clf; hold on;
        %plot(slotAxis, ptJoint_dBm, '-s', 'Color', colorJoint, 'LineWidth', 1.5, 'MarkerSize', 5);
        plot(slotAxis, ptFull_dBm, '-^', 'Color', colorFull, 'LineWidth', 1.8, 'MarkerSize', 5);
        plot(slotAxis, ptIPSO_dBm, '-d', 'Color', colorIPSO, 'LineWidth', 2.0, 'MarkerSize', 6);

        grid on;
        xlabel('Mission slot'); ylabel('UAV transmit power (dBm)');
        title('UAV Transmit Power: Full PSO vs Full IPSO');
        legend('Full PSO', 'Full IPSO', 'Location', 'best');
        xlim([1 numSteps-1]); xticks(1:numSteps-1);

    % 6-8: same best-fitness particle; negative fitness never shown as EE.
    fields={'bestHistory','totalBitsHistory','totalEnergyHistory'};
    labels={'Feasible UAV EE (bit/J)','Total mission bits (Mbit)','Total UAV energy (J)'};
    factors=[1,1e-6,1];
    for panel=1:3
        figure(5+panel); clf; hold on;
        for k=1:3
            r=raw{k}; it=0:(numel(r.bestHistory)-1); values=r.(fields{panel})*factors(panel);
            if panel==1
                values(~logical(r.feasibleHistory) | ~isfinite(values))=NaN;
                endpoint=final{k}.eeUAV;
            elseif panel==2
                endpoint=final{k}.totalBits*1e-6;
            else
                endpoint=final{k}.totalEnergy;
            end
            plot(it,values,'Color',colors(k,:),'LineStyle',styles{k}, ...
                'LineWidth',1.6,'DisplayName',names{k});
            if k>1
                if panel==1
                    if final{k}.isFeasible
                        plot(it(end),endpoint,'o','Color',colors(k,:), ...
                            'MarkerFaceColor',colors(k,:),'MarkerSize',7, ...
                            'HandleVisibility','off');
                    end
                elseif final{k}.isFeasible
                    plot(it(end),endpoint,'o','Color',colors(k,:), ...
                        'MarkerFaceColor',colors(k,:),'MarkerSize',7, ...
                        'HandleVisibility','off');
                else
                    plot(it(end),endpoint,'x','Color',colors(k,:), ...
                        'LineWidth',1.2,'HandleVisibility','off');
                end
            end
        end
        grid on; xlabel('Iteration'); ylabel(labels{panel});
        if panel==1
            title({'EE convergence of all three algorithms', ...
                'Gaps: infeasible; lines: optimization; circles: after alpha polishing'});
        else
            title({labels{panel}, ...
                'Same best-fitness particle (pre-polish); circles: feasible; x: infeasible'});
        end
        legend('Location','best');
    end

    end

    if groups.EH_Alpha_config
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
                    values = r.energyPerSlot;
                    axisLabel = 'UAV energy per slot (J)';
                case 3
                    values = NaN(size(r.energyPerSlot));
                    valid = r.energyPerSlot > 0;
                    values(valid) = r.bitsPerSlot(valid) ./ r.energyPerSlot(valid);
                    axisLabel = 'Slot UAV EE (bit/J)';
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
    infeasFinal = names(~cellfun(@(r) r.isFeasible, final));
    if ~isempty(infeasFinal)
        sgtitle(['Final solutions; infeasible: ', strjoin(infeasFinal, ', ')]);
    end

    % 10: V9 filled final points and reference-EE line, using TOTAL joules.
    figure(10); clf; hold on;
    finalEnergy=cellfun(@(r) r.totalEnergy,final);
    finalBits=cellfun(@(r) r.totalBits,final);
    feasible=cellfun(@(r) r.isFeasible,final);
    finalEE=cellfun(@(r) r.eeUAV,final);
    handles=gobjects(1,3); legendNames=names;
    for k=1:3
        marker='o'; face=colors(k,:);
        if ~feasible(k), marker='x'; face='none'; end
        handles(k)=plot(finalEnergy(k),finalBits(k)/1e6,marker, ...
            'Color',colors(k,:),'MarkerFaceColor',face,'MarkerSize',9,'LineWidth',1.2);
    end
    validReference=feasible & isfinite(finalEE) & isfinite(finalEnergy);
    if any(validReference)
        referenceEE=mean(finalEE(validReference));
        energyAxis=linspace(0.95*min(finalEnergy(validReference)), ...
            1.05*max(finalEnergy(validReference)),100);
        handles(4)=plot(energyAxis,referenceEE*1e-6*energyAxis,'k--','LineWidth',1.2);
        legendNames{4}='Reference EE (mean of feasible final EE values)';
        title({'Final bits versus total UAV energy', ...
            sprintf('Dashed line: reference EE = %.6e bit/J; x: infeasible',referenceEE)});
    else
        title({'Final bits versus total UAV energy','No feasible reference EE; x: infeasible'});
    end
    grid on; xlabel('Total UAV energy (J)'); ylabel('Total mission bits (Mbit)');
    legend(handles,legendNames,'Location','best');
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
                if final{k}.isFeasible
                    plot(iteration(end), final{k}.totalBitsPerUser(u)/1e6, 'o', ...
                        'Color', userColors(u, :), 'MarkerFaceColor', userColors(u, :), ...
                        'HandleVisibility', 'off');
                else
                    plot(iteration(end), final{k}.totalBitsPerUser(u)/1e6, 'x', ...
                        'Color', userColors(u, :), 'LineWidth', 1.2, ...
                        'HandleVisibility', 'off');
                end
            end
        end
        for u=1:noUsers
            target=sim.minBitsPerUser(min(u,numel(sim.minBitsPerUser)))/1e6;
            yline(target,':','Color',userColors(u,:),'HandleVisibility','off');
        end
        grid on; xlabel('Iteration'); ylabel('Bits per user (Mbit)');
        title({names{k}, ...
            'Total over mission slots (pre-polish gbest); circles: feasible; x: infeasible'});
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
        title([names{k} ': power over mission slots (pre-polish gbest)']);
        legend({'Mean', 'Minimum', 'Maximum'}, 'Location', 'best');
        subplot(3, 2, 2*k);
        imagesc(iteration, r.slotIdx, powerNanoW.'); axis xy;
        xlabel('Iteration'); ylabel('Mission slot');
        title([names{k} ': RF power per slot (pre-polish gbest)']);
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
                alphaFinal = mean(final{k}.alphaTrace(final{k}.slotIdx, u));
                if final{k}.isFeasible
                    plot(iteration(end), alphaFinal, 'o', ...
                        'Color', userColors(u, :), 'MarkerFaceColor', userColors(u, :), ...
                        'HandleVisibility', 'off');
                else
                    plot(iteration(end), alphaFinal, 'x', ...
                        'Color', userColors(u, :), 'LineWidth', 1.2, ...
                        'HandleVisibility', 'off');
                end
            end
        end
        plot([iteration(1), iteration(end)], [1, 1]/noUsers, 'k--', 'HandleVisibility', 'off');
        grid on; xlabel('Iteration'); ylabel('Mean NOMA alpha');
        title({names{k}, ...
            'Mean over slots (pre-polish gbest); dashed: 1/N; circles: feasible; x: infeasible'});
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
            title(sprintf('%s - User %d NOMA alpha (pre-polish gbest)', names{k}, u));
            cb = colorbar; cb.Label.String = 'NOMA alpha';
        end
    end
    end

    if groups.flyingEnergy
    figure(17); clf;
    components=zeros(3,3); rf=zeros(3,1);
    for k=1:3
        components(k,:)=[final{k}.flightEnergy,final{k}.hoverEnergy,final{k}.rfEnergy];
        rf(k)=final{k}.rfEnergy*1e6;
    end
    subplot(1,2,1); bar(components,'stacked','LineWidth',1.2); xticks(1:3); xticklabels(names);
    ylabel('Energy (J)'); legend('Cruise','Hover','RF','Location','best'); grid on;
    title('UAV energy components');
    subplot(1,2,2); bars=bar(rf,'FaceColor','flat'); bars.CData=colors; xticks(1:3); xticklabels(names); ylabel('RF transmit energy (\muJ)'); title('RF energy detail'); grid on;
    infeasFinal = names(~cellfun(@(r) r.isFeasible, final));
    if ~isempty(infeasFinal)
        sgtitle(['Final solutions; infeasible: ', strjoin(infeasFinal, ', ')]);
    end
    figure(18); clf;
    for k=1:3
        subplot(3,1,k); r=final{k};
        [tSched,ySched]=v10YSchedule(r);
        plot(tSched,ySched,'-','Color',colors(k,:), ...
            'LineStyle',styles{k},'LineWidth',1.4); hold on;
        plot(r.timeSeconds,r.yTraj,'o','Color',colors(k,:), ...
            'MarkerFaceColor',colors(k,:),'MarkerSize',4, ...
            'HandleVisibility','off');
        grid on;
        xlabel('Mission time (s), including hover'); ylabel('Y (m)'); title(names{k});
    end
    if ~isempty(infeasFinal)
        sgtitle(['Final solutions; infeasible: ', strjoin(infeasFinal, ', ')]);
    end
    end
end

function [t,y]=v10YSchedule(r)
% Staircase schedule: hover at the start waypoint, then fly to the next one.
    t=0; y=r.yTraj(1);
    for n=1:numel(r.slotIdx)
        t(end+1,1)=t(end)+r.hoverTime;
        y(end+1,1)=r.yTraj(n);
        t(end+1,1)=t(end)+r.flightTimePerSegment(n);
        y(end+1,1)=r.yTraj(n+1);
    end
end
