function block = v10cTimeBlockData(candidate, sim)
%V10CTIMEBLOCKDATA Fixed-geometry/alpha coefficients, NOT a time optimizer.
% D(t,n)=B*v(t)*log2(1+a(t,n)*u(t)/(v(t)+b(t,n)*u(t))).
% E=fixedEnergy + cUL'*u + cDL'*v. The numerator is concave in
% positive (u,v); Dinkelbach subproblems are convex with the current QoS.
    r=evaluateV10CCandidate(candidate,sim);
    if ~r.geometryFeasible || ~r.alphaFeasible || ~r.isDefined
        error('V10C:TimeBlockGeometry','Time block requires valid geometry and ordered alpha.');
    end
    S=sim.numSlots; U=sim.noUsers;
    harvestedPower=sim.radio.ehEfficiency*sim.radio.powerSplit*r.receivedPower;
    block.signalCoefficient=zeros(S,U);
    block.interferenceCoefficient=zeros(S,U);
    for t=1:S
        order=r.idxWeak2StrongTrace(t,:);
        shares=candidate.alpha(t,order);
        tail=fliplr(cumsum(fliplr(shares)))-shares;
        coefficient=harvestedPower(t)*r.userGain(t,order)/sim.radio.noisePowerW;
        block.signalCoefficient(t,order)=coefficient.*shares;
        block.interferenceCoefficient(t,order)=coefficient.*tail;
    end
    block.fixedEnergy=r.movementEnergy;
    block.uplinkEnergyCoefficient=sim.hoverPower+harvestedPower;
    block.downlinkEnergyCoefficient=sim.hoverPower*ones(S,1);
    block.bandwidthHz=sim.radio.bandwidthHz;
    block.timeConstraints=sim.time;
    block.minBitsPerUser=sim.minBitsPerUser;
    block.minBitsPerUserPerSlot=sim.minBitsPerUserPerSlot;
    block.minBitsPerSlot=sim.minBitsPerSlot;
    block.energyBudgetJ=sim.energyBudgetJ;
    block.fixedHoverTime=sim.hoverTime;
    block.fixedEHFraction=sim.ehTime/sim.hoverTime;
    block.solverImplemented=false;
end
