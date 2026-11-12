function fig = plotV10CResults(data)
%PLOTV10CRESULTS Searched trajectory, times, feasibility, payload and energy.
    fig=figure('Name',['V10C ',data.cfg.preset,' reference search'],'Color','w');
    tiledlayout(2,3,'TileSpacing','compact');
    nexttile; hold on;
    initial=data.initialCandidate.waypoints;
    plot(initial(:,1),initial(:,2),'k--','DisplayName','Initial');
    names=fieldnames(data.searches);
    for k=1:numel(names)
        s=data.searches.(names{k}); xy=s.candidate.waypoints;
        label=s.algorithm;
        if ~s.result.isFeasible, label=[label,' (infeasible)']; end
        plot(xy(:,1),xy(:,2),'-o','MarkerSize',3,'DisplayName',label);
    end
    scatter(data.sim.xUser,data.sim.yUser,35,'k','filled','DisplayName','Users');
    scatter(data.candidate.bsXY(:,1),data.candidate.bsXY(:,2),45,'s', ...
        'filled','DisplayName','Selected BSs');
    xlabel('X (m)'); ylabel('Y (m)'); grid on; axis equal; legend('Location','best');
    title('Trajectories');
    nexttile; hold on;
    for k=1:numel(names)
        s=data.searches.(names{k}); ee=s.history.eeComputed;
        ee(~s.history.feasible)=NaN;
        plot(0:numel(ee)-1,ee,'DisplayName',s.algorithm);
    end
    xlabel('Iteration'); ylabel('Feasible EE (bit/J)'); grid on;
    title('EE after feasibility');
    nexttile; hold on;
    for k=1:numel(names)
        s=data.searches.(names{k});
        plot(0:numel(s.history.bestFitness)-1,s.history.bestFitness,'DisplayName',s.algorithm);
    end
    xlabel('Iteration'); ylabel('Search score'); grid on;
    title('Negative: QoS deficit; positive: feasible EE');
    nexttile;
    bar([data.candidate.uplinkTime,data.candidate.downlinkTime],'stacked');
    xlabel('Service slot'); ylabel('Seconds'); legend('UL/EH','DL');
    title(['Slot times: ',data.selectedAlgorithm]);
    nexttile;
    bar(data.result.totalBitsPerUser/1e6); hold on;
    target=data.sim.minBitsPerUser+zeros(1,data.sim.noUsers);
    plot(1:data.sim.noUsers,target/1e6,'r--o');
    xlabel('Physical user'); ylabel('Mbit'); legend('Delivered','Required L');
    title('Mission payload');
    nexttile;
    bar([data.result.movementEnergy,data.result.hoverEnergy,data.result.rfEnergy]);
    xticks(1:3); xticklabels({'Move','Hover','RF'}); ylabel('J');
    title(sprintf('Selected feasible=%d; total %.3f J', ...
        data.result.isFeasible,data.result.totalEnergy));
    sgtitle([data.cfg.preset,' | ',data.result.energyModelStatus], 'Interpreter','none');
    if data.cfg.output.saveFigures && ~isempty(data.outputFolder)
        savefig(fig,fullfile(data.outputFolder,'diagnostics.fig'));
        exportgraphics(fig,fullfile(data.outputFolder,'diagnostics.png'),'Resolution',180);
    end
end
