function result = evaluateV10CCandidate(candidate, sim)
%EVALUATEV10CCANDIDATE Evaluate supplied resource blocks without repairing them.
% A logical service slot contains UL/EH and DL at a fixed point. Flight to
% the next point is accounted separately. Arrival has no service resources.
    S=sim.numSlots; U=sim.noUsers; tol=sim.feasibilityTolerance;
    fields={'waypoints','bsXY','alpha','uplinkTime','downlinkTime'};
    shapes={[sim.numSteps,2],[sim.noBS,2],[S,U],[S,1],[S,1]};
    for k=1:numel(fields)
        name=fields{k};
        if ~isfield(candidate,name) || ~isnumeric(candidate.(name)) ...
                || ~isreal(candidate.(name)) || ~isequal(size(candidate.(name)),shapes{k}) ...
                || any(~isfinite(candidate.(name)(:)))
            error('V10C:CandidateShape','Invalid shape or values in candidate.%s.',name);
        end
    end
    alpha=candidate.alpha; ul=candidate.uplinkTime; dl=candidate.downlinkTime;
    if any(ul<=0) || any(dl<=0)
        error('V10C:CandidateTime','Every serving slot needs positive UL and DL times.');
    end
    if any(alpha(:)<0) || any(abs(sum(alpha,2)-1)>tol)
        error('V10C:CandidateAlpha','Alpha must be nonnegative and sum to one per slot.');
    end
    xy=candidate.waypoints; bs=candidate.bsXY;
    hover=ul+dl; fraction=ul./hover;
    result.geometryFeasible=all(xy(:,1)>=sim.x_min-tol & xy(:,1)<=sim.x_max+tol) ...
        && all(xy(:,2)>=sim.y_min-tol & xy(:,2)<=sim.y_max+tol) ...
        && all(abs(xy(1,:)-[sim.xStart,sim.yStart])<=tol) ...
        && all(abs(xy(end,:)-[sim.xEnd,sim.yEnd])<=tol) ...
        && all(sim.yDirection*diff(xy(:,2))>=sim.minYProgress-tol) ...
        && all(bs(:,1)>=sim.xBS_min(:)-tol & bs(:,1)<=sim.xBS_max(:)+tol) ...
        && all(bs(:,2)>=sim.yBS_min(:)-tol & bs(:,2)<=sim.yBS_max(:)+tol);
    hb=sim.time.hoverBounds; fb=sim.time.ehFractionBounds;
    result.timingFeasible=all(hover>=hb(1)-tol & hover<=hb(2)+tol) ...
        && sum(hover)<=sim.time.totalHoverMax+tol ...
        && all(fraction>=fb(1)-tol & fraction<=fb(2)+tol);
    if strcmp(sim.time.hoverMode,'fixed')
        result.timingFeasible=result.timingFeasible && all(abs(hover-sim.hoverTime)<=tol);
    end
    if strcmp(sim.time.splitMode,'fixed')
        result.timingFeasible=result.timingFeasible ...
            && all(abs(fraction-sim.ehTime/sim.hoverTime)<=tol);
    end
    result.numSlots=S; result.slotIdx=(1:S).';
    result.waypoints=xy; result.bsXY=bs;
    result.uplinkTime=ul; result.downlinkTime=dl;
    result.hoverTimePerSlot=hover; result.ehFraction=fraction;
    result.totalHoverTime=sum(hover);
    result.segmentDistance=sqrt(sum(diff(xy,1,1).^2,2));
    motion=v10cMotionEnergy(result.segmentDistance,sim.flight,sim.motion);
    result.motion=motion;
    result.movementTimePerSegment=motion.time;
    result.movementEnergyPerSegment=motion.energy;
    result.totalDistance=sum(result.segmentDistance);
    result.totalMovementTime=sum(motion.time);
    result.missionTime=result.totalMovementTime+result.totalHoverTime;
    result.timeSeconds=[0;cumsum(hover+motion.time)];
    % A nonzero transition, however small, is a movement. The final arrival
    % does not add a service visit. Do not merge logical slot QoS constraints.
    result.numPhysicalMovements=sum(result.segmentDistance>0);
    result.numServiceVisits=1+sum(result.segmentDistance(1:end-1)>0);
    result.achRate=zeros(S,U); result.pt=zeros(S,1);
    result.receivedPower=zeros(S,1); result.harvestedEnergyPerSlot=zeros(S,1);
    result.userGain=zeros(S,U); result.alphaTrace=alpha;
    result.idxWeak2StrongTrace=zeros(S,U); result.alphaFeasible=true;
    users=[sim.xUser(:),sim.yUser(:),sim.zUser(:)];
    stations=[bs,sim.zBS(:)]; r=sim.radio;
    for t=1:S
        point=[xy(t,:),sim.altitude];
        hu=v10Channel(point,users,sim.gNLoSUsers,r);
        hbChannel=v10Channel(point,stations,sim.gNLoSBS,r);
        gain=abs(hu).^2;
        [sortedGain,order]=sort(gain,'ascend');
        shares=alpha(t,order);
        result.alphaFeasible=result.alphaFeasible && all(diff(shares)<=tol);
        result.idxWeak2StrongTrace(t,:)=order;
        result.userGain(t,:)=gain;
        received=r.bsPowerW*sum(abs(hbChannel).^2);
        harvested=r.ehEfficiency*r.powerSplit*received*ul(t);
        power=harvested/dl(t);
        result.receivedPower(t)=received;
        result.harvestedEnergyPerSlot(t)=harvested; result.pt(t)=power;
        for u=1:U
            interference=sum(shares(u+1:end));
            sinr=power*shares(u)*sortedGain(u) ...
                /(r.noisePowerW+power*interference*sortedGain(u));
            result.achRate(t,order(u))=r.bandwidthHz*log2(1+sinr);
        end
    end
    result.bitsPerUserPerSlot=dl.*result.achRate;
    result.bitsPerSlot=sum(result.bitsPerUserPerSlot,2);
    result.totalBitsPerUser=sum(result.bitsPerUserPerSlot,1);
    result.totalBits=sum(result.bitsPerSlot);
    result.hoverEnergyPerSlot=sim.hoverPower*hover;
    result.rfEnergyPerSlot=result.pt.*dl;
    result.movementEnergy=sum(motion.energy);
    result.hoverEnergy=sum(result.hoverEnergyPerSlot);
    result.rfEnergy=sum(result.rfEnergyPerSlot);
    result.batteryEnergyIdeal=result.movementEnergy+result.hoverEnergy;
    result.totalEnergy=result.batteryEnergyIdeal+result.rfEnergy;
    result.energyScope=sim.energyScope;
    result.isDefined=isfinite(result.totalEnergy) && result.totalEnergy>0 ...
        && all(isfinite(result.bitsPerUserPerSlot(:))) ...
        && all(result.bitsPerUserPerSlot(:)>=0);
    L=sim.minBitsPerUser+zeros(1,U);
    q=sim.minBitsPerUserPerSlot+zeros(1,U);
    result.bitsShortfallPerUser=max(0,L-result.totalBitsPerUser);
    result.userSlotShortfall=max(0,q-result.bitsPerUserPerSlot);
    result.slotShortfall=max(0,sim.minBitsPerSlot-result.bitsPerSlot);
    result.missionQoSFeasible=all(result.bitsShortfallPerUser<=tol*max(1,L));
    result.userSlotQoSFeasible=all(all(result.userSlotShortfall<=tol*max(1,q)));
    result.slotQoSFeasible=all(result.slotShortfall<=tol*max(1,sim.minBitsPerSlot));
    result.energyFeasible=result.totalEnergy<=sim.energyBudgetJ*(1+tol);
    result.isFeasible=result.isDefined && result.geometryFeasible ...
        && result.timingFeasible && result.alphaFeasible && result.missionQoSFeasible ...
        && result.userSlotQoSFeasible && result.slotQoSFeasible && result.energyFeasible;
    result.eeComputed=NaN;
    if result.isDefined, result.eeComputed=result.totalBits/result.totalEnergy; end
    result.isOptimized=false;
    result.energyModelStatus=motion.modelStatus;
    result.fitness=-Inf; % only the future optimizer assigns search policy
    if result.isFeasible, result.fitness=result.eeComputed; end
end
