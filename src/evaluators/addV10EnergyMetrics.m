function result = addV10EnergyMetrics(result, sim)
%ADDV10ENERGYMETRICS Drones Eq.(11) cruise plus requested hover and V9 RF.
% Serve at the segment START for one hover interval, then fly to next point.
% Final arrival has no communication/hover, but its incoming flight is counted.
    slots=sim.numSteps-1; idx=1:slots;
    points=[result.xTraj(:),result.yTraj(:),result.zTraj(:)];
    if size(points,1)~=sim.numSteps || ~isequal(size(result.achRate),[sim.numSteps,sim.noUsers]) ...
            || numel(result.pt)~=sim.numSteps
        error('addV10EnergyMetrics:Size','Trajectory, rate and power dimensions must match sim.');
    end
    result.slotIdx=idx;
    result.segmentDistance=sqrt(sum(diff(points,1,1).^2,2));
    result.totalDistance=sum(result.segmentDistance);
    result.flightTimePerSegment=result.segmentDistance/sim.flight.cruiseSpeed;
    result.flightTime=sum(result.flightTimePerSegment);
    result.hoverTimePerSlot=sim.hoverTime*ones(slots,1);
    result.totalHoverTime=slots*sim.hoverTime;
    result.uplinkTime=sim.ehTime; result.downlinkTime=sim.rfTime;
    result.hoverTime=sim.hoverTime;
    result.missionTime=result.flightTime+result.totalHoverTime;
    result.timeSeconds=[0;cumsum(result.hoverTimePerSlot+result.flightTimePerSegment)].';
    result.cruisePower=sim.cruisePower; result.hoverPower=sim.hoverPower;
    result.flightEnergyPerSlot=sim.cruisePower*result.flightTimePerSegment;
    result.hoverEnergyPerSlot=sim.hoverPower*result.hoverTimePerSlot;
    power=result.pt(:);
    result.rfEnergyPerSlot=power(idx)*sim.rfTime;
    result.harvestedEnergyPerSlot=result.rfEnergyPerSlot; % ideal EH wholly used in RF
    result.flightEnergy=sum(result.flightEnergyPerSlot);
    result.hoverEnergy=sum(result.hoverEnergyPerSlot);
    result.rfEnergy=sum(result.rfEnergyPerSlot);
    result.totalHarvestedEnergy=sum(result.harvestedEnergyPerSlot);
    result.batteryEnergyIdeal=result.flightEnergy+result.hoverEnergy;
    result.energyPerSlot=result.flightEnergyPerSlot+result.hoverEnergyPerSlot+result.rfEnergyPerSlot;
    result.totalEnergy=sum(result.energyPerSlot);
    result.energyScope='uav-horizontal-cruise-plus-hover-plus-downlink-rf';
    result.bitsPerUserPerSlot=result.achRate(idx,:)*sim.rfTime;
    result.bitsPerSlot=sum(result.bitsPerUserPerSlot,2);
    result.totalBitsPerUser=sum(result.bitsPerUserPerSlot,1);
    result.totalBits=sum(result.bitsPerSlot);
    result.EH=power*sim.rfTime;
    result.bitsShortfallPerUser=max(0,sim.minBitsPerUser-result.totalBitsPerUser);
    result.minBitsPerSlot=sim.minBitsPerSlot;
    result.minBitsPerUserPerSlot=sim.minBitsPerUserPerSlot;
    result.slotShortfall=max(0,sim.minBitsPerSlot-result.bitsPerSlot);
    result.userSlotShortfall=max(0,sim.minBitsPerUserPerSlot-result.bitsPerUserPerSlot);
    result.slotBitsMin=min(result.bitsPerSlot);
    result.slotBitsMax=max(result.bitsPerSlot);
    result.numSlotsBelowMin=sum(result.slotShortfall>0);
    result.numUserSlotsBelowMin=sum(result.userSlotShortfall(:)>0);
    result.energyBudgetJ=sim.energyBudgetJ;
    result.energyShortfall=max(0,result.totalEnergy-sim.energyBudgetJ);
    valid=all(isfinite(points(:))) && all(isfinite(result.bitsPerUserPerSlot(:))) ...
        && all(result.bitsPerUserPerSlot(:)>=0) && all(isfinite(result.energyPerSlot)) ...
        && all(result.energyPerSlot>=0) && isfinite(result.totalBits) ...
        && isfinite(result.totalEnergy) && result.totalEnergy>0;
    result.isEEDefined=valid; result.eeUAV=NaN; result.eeRF=NaN;
    if valid
        result.eeUAV=result.totalBits/result.totalEnergy;
        if result.rfEnergy>0
            result.eeRF=result.totalBits/result.rfEnergy;
        end
    end
    result.slotQoSFeasible=valid && result.numSlotsBelowMin==0;
    result.userSlotQoSFeasible=valid && result.numUserSlotsBelowMin==0;
    result.missionQoSFeasible=valid && all(result.bitsShortfallPerUser==0);
    result.dataQoSFeasible=result.missionQoSFeasible && result.slotQoSFeasible ...
        && result.userSlotQoSFeasible;
    result.energyFeasible=valid && result.energyShortfall<=sim.feasibilityTolerance*max(1,sim.energyBudgetJ);
    result.isFeasible=result.geometryFeasible && result.dataQoSFeasible && result.energyFeasible;
    % eeComputed is the real ratio even when constraints fail; it is what the
    % console/summary show. result.fitness stays the internal PSO score.
    result.eeComputed=result.eeUAV;
    result.statusLabel=sprintf('L:%d slot:%d userSlot:%d energy:%d geom:%d', ...
        result.missionQoSFeasible,result.slotQoSFeasible,result.userSlotQoSFeasible, ...
        result.energyFeasible,result.geometryFeasible);
    result.fitness=-Inf;
    if valid && result.geometryFeasible
        if result.isFeasible
            result.fitness=result.eeUAV;
        else
            % Relative violations keep mission, slot, user-slot and energy on
            % comparable scales so PSO can trade them while seeking feasibility.
            dataViolation=sum(result.bitsShortfallPerUser./max(sim.minBitsPerUser,1));
            slotViolation=0;
            if sim.minBitsPerSlot>0
                slotViolation=mean(result.slotShortfall/max(sim.minBitsPerSlot,1));
            end
            userSlotViolation=0;
            if any(sim.minBitsPerUserPerSlot(:)>0)
                userSlotViolation=mean(mean( ...
                    result.userSlotShortfall./max(sim.minBitsPerUserPerSlot,1)));
            end
            energyViolation=0;
            if isfinite(sim.energyBudgetJ)
                energyViolation=result.energyShortfall/sim.energyBudgetJ;
            end
            result.fitness=-dataViolation-slotViolation-userSlotViolation-energyViolation;
        end
    end
end
