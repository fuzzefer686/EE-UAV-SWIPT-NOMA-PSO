function [distanceSummary, segmentDistances] = measureV9FlightDistance(trajJoint, trajFull, trajIPSO)
% Sum 3D Euclidean distances along existing waypoint trajectories, in metres.
% Straight segment between consecutive waypoints; no optimizer or energy model.
    names = {'Joint PSO'; 'Full PSO'; 'Full IPSO'};
    results = {trajJoint, trajFull, trajIPSO};
    totalDistanceM = zeros(3, 1);
    segmentDistances = cell(3, 1);
    for k = 1:3
        r = results{k};
        if numel(r.xTraj) ~= numel(r.yTraj) || numel(r.xTraj) ~= numel(r.zTraj)
            error('measureV9FlightDistance:InvalidSize', 'x/y/z must have equal numbers of waypoints.');
        end
        q = [r.xTraj(:), r.yTraj(:), r.zTraj(:)];
        if size(q, 1) < 2 || any(~isfinite(q(:)))
            error('measureV9FlightDistance:InvalidTrajectory', 'Need at least two finite 3D waypoints.');
        end
        displacement = diff(q, 1, 1);
        segmentDistances{k} = sqrt(sum(displacement.^2, 2));
        totalDistanceM(k) = sum(segmentDistances{k});
    end
    distanceSummary = table(names, totalDistanceM, ...
        'VariableNames', {'Algorithm', 'TotalDistance_m'});
    fprintf('\n=== UAV FLIGHT DISTANCE: 3D EUCLIDEAN (m) ===\n');
    for k = 1:3
        fprintf('%-10s | total distance = %.6f m | segments = %d\n', ...
            names{k}, totalDistanceM(k), numel(segmentDistances{k}));
    end
end
