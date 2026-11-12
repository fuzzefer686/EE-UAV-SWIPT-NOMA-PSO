function candidate = initialV10CCandidate(sim)
%INITIALV10CCANDIDATE Separate geometry, physical-user shares and slot times.
    candidate.waypoints=[linspace(sim.xStart,sim.xEnd,sim.numSteps).', ...
        linspace(sim.yStart,sim.yEnd,sim.numSteps).'];
    candidate.bsXY=[sim.xBS(:),sim.yBS(:)];
    candidate.alpha=ones(sim.numSlots,sim.noUsers)/sim.noUsers;
    hover=sim.hoverTime;
    if strcmp(sim.time.hoverMode,'variable')
        hover=min(hover,sim.time.totalHoverMax/sim.numSlots);
    end
    candidate.uplinkTime=hover*(sim.ehTime/sim.hoverTime)*ones(sim.numSlots,1);
    candidate.downlinkTime=hover*(sim.rfTime/sim.hoverTime)*ones(sim.numSlots,1);
end
