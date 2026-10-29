function result = addRFSlotMetrics(result, sim)
%ADDRFSLOTMETRICS Temporary EE using only UAV downlink RF transmit energy.
% Slot n spans waypoint n -> n+1; use channels/rates at waypoint n.
% Each slot has equal UL/DL halves. Assume sufficient data from the uplink.
% The final waypoint is an arrival point, not an extra communication slot.

    validateattributes(sim.Tslot, {'numeric'}, {'scalar', 'real', 'finite', 'positive'});
    numSlots = size(result.achRate, 1) - 1;
    if numSlots < 1 || numel(result.pt) ~= numSlots + 1
        error('addRFSlotMetrics:InvalidSize', 'Need one power value per trajectory waypoint.');
    end

    result.slotIdx = 1:numSlots;
    result.timeSeconds = (0:numSlots) * sim.Tslot;
    result.uplinkTime = sim.Tslot / 2;
    result.downlinkTime = sim.Tslot / 2;
    result.missionTime = numSlots * sim.Tslot;

    % R is in-phase downlink rate (bit/s), not the rate over the whole slot.
    result.bitsPerUserPerSlot = result.achRate(result.slotIdx, :) * result.downlinkTime;
    result.bitsPerSlot = sum(result.bitsPerUserPerSlot, 2);
    result.totalBitsPerUser = sum(result.bitsPerUserPerSlot, 1);
    result.totalBits = sum(result.bitsPerSlot);

    pt = result.pt(:);
    result.energyPerSlot = pt(result.slotIdx) * result.downlinkTime;
    result.totalEnergy = sum(result.energyPerSlot);
    result.energyScope = 'uav-downlink-rf-only';

    % Equal UL/DL durations and ideal use of all harvested energy: E_H = E_RF.
    % EH remains a waypoint diagnostic; only slotIdx enters mission totals.
    result.EH = pt * result.uplinkTime;
    result.harvestedEnergyPerSlot = result.EH(result.slotIdx);

    result.isEEDefined = all(isfinite(result.bitsPerUserPerSlot(:))) ...
        && all(result.bitsPerUserPerSlot(:) >= 0) ...
        && all(isfinite(result.energyPerSlot)) && all(result.energyPerSlot >= 0) ...
        && isfinite(result.totalBits) && isfinite(result.totalEnergy) ...
        && result.totalEnergy > 0;

    result.rateFitness = result.fitness; % Keep the previous V8 score for inspection.
    result.eeRF = NaN;
    if result.isEEDefined
        result.eeRF = result.totalBits / result.totalEnergy;
    end

    % Invalid/constraint-violating particles cannot win by having a huge EE.
    result.isFeasible = result.isFeasible && result.isEEDefined;
    if result.isFeasible
        result.fitness = result.totalBits / result.totalEnergy;
    else
        result.fitness = -Inf;
    end

    % Mission-wide minimum data per physical user; absent/empty means disabled.
    L = 0;
    if isfield(sim, 'minBitsPerUser') && ~isempty(sim.minBitsPerUser)
        validateattributes(sim.minBitsPerUser, {'numeric'}, ...
            {'real', 'vector', 'finite', 'nonnegative'}, mfilename, 'sim.minBitsPerUser');
        L = sim.minBitsPerUser(:).';
        if ~isscalar(L) && numel(L) ~= numel(result.totalBitsPerUser)
            error('addRFSlotMetrics:InvalidMinBitsSize', ...
                'minBitsPerUser must be scalar or have one entry per user.');
        end
    end
    result.bitsShortfallPerUser = max(0, L - result.totalBitsPerUser);
    result.dataQoSFeasible = result.isEEDefined && all(result.bitsShortfallPerUser == 0);
    if result.isFeasible && ~result.dataQoSFeasible
        % Feasible EE >= 0 always wins; among data-infeasible particles,
        % prefer less normalized shortfall so PSO can seek feasibility.
        result.fitness = -sum(result.bitsShortfallPerUser ./ max(L, 1));
    end
    result.isFeasible = result.isFeasible && result.dataQoSFeasible;
end
