function audit = rescoreV12LegacyO1ToO4(outputRoot)
%RESCOREV12LEGACYO1TOO4 Re-score saved V10B O1 solutions under O4 physics.
% No optimization or polishing is run. Missing legacy stages stay unavailable.
    if nargin < 1 || isempty(outputRoot)
        projectRoot = fileparts(fileparts(mfilename('fullpath')));
        outputRoot = fullfile(projectRoot, 'results', 'v12', ...
            'cross_model_O1_to_O4_phi0999_20261108');
    else
        projectRoot = fileparts(fileparts(mfilename('fullpath')));
    end
    addpath(projectRoot);
    setup_project();

    legacyCsv = fullfile(projectRoot, 'results', 'v10', ...
        'campaign_20261029_125559', 'campaign_summary.csv');
    legacy = readtable(legacyCsv, 'TextType', 'string');
    legacy = legacy(legacy.variant == "B" & legacy.group == "L", :);
    folders = unique(legacy.folder, 'stable');
    assert(numel(folders) == 9, 'Expected nine V10B O1 L-group runs.');
    if exist(outputRoot, 'dir')
        error('rescoreV12LegacyO1ToO4:OutputExists', ...
            'Refusing to overwrite existing output folder: %s', outputRoot);
    end
    [ok, msg] = mkdir(outputRoot);
    assert(ok, '%s', msg);

    rows = repmat(blankRow(), 0, 1);
    for j = 1:numel(folders)
        sourceFolder = localizeLegacyFolder(folders(j), projectRoot);
        sourceMat = fullfile(sourceFolder, 'results.mat');
        saved = load(sourceMat, 'data');
        data = saved.data;
        assert(~isfield(data, 'trajJointRaw'), ...
            'Unexpected Joint raw payload in %s.', sourceMat);
        specs = stageSpecs(data);
        for k = 1:numel(specs)
            spec = specs(k);
            row = blankRow();
            row.seed = data.cfg.random.mainSeed;
            row.algorithmSeed = data.cfg.random.algorithmSeed;
            row.polishSeed = data.cfg.random.polishSeed;
            row.L = data.sim.minBitsPerUser;
            row.algorithm = spec.algorithm;
            row.stage = spec.stage;
            row.sourceField = spec.field;
            row.optimizeBS = double(spec.optimizeBS);
            row.sourceResultsMat = sourceMat;
            row.available = double(spec.available);
            if ~spec.available
                row.missingReason = 'trajJointRaw was not saved in the legacy V10B results.mat';
                rows(end+1) = row; %#ok<AGROW>
                continue;
            end

            legacyResult = data.(spec.field);
            if spec.isBaseline
                particle = initialV10Particle(data.sim, false, false);
            else
                particle = legacyResult.bestParticle;
            end
            simO1 = physicsSim(data.sim, 1);
            simO4 = physicsSim(data.sim, 4);
            [~, resultO1] = evaluateTrajectoryV12(particle, simO1, ...
                spec.optimizeBS, spec.isBaseline);
            [~, resultO4] = evaluateTrajectoryV12(particle, simO4, ...
                spec.optimizeBS, spec.isBaseline);
            assertO1Parity(legacyResult, resultO1, spec.field, sourceMat);
            row = fillMeasuredRow(row, legacyResult, resultO1, resultO4);
            rows(end+1) = row; %#ok<AGROW>
        end
        fprintf('Re-scored O1/O4: seed=%.0f, L=%.0f bit/user\n', ...
            data.cfg.random.mainSeed, data.sim.minBitsPerUser);
    end

    details = struct2table(rows);
    details = sortrows(details, {'seed', 'L', 'algorithm', 'stage'});
    assert(height(details) == 63);
    assert(sum(details.available == 1) == 54);
    unavailable = details.available == 0;
    assert(sum(unavailable) == 9);
    assert(all(strcmp(details.algorithm(unavailable), 'Joint PSO')));
    assert(all(strcmp(details.stage(unavailable), 'raw')));
    measured = details.available == 1;
    assert(max(details.o1ParityMaxAbsDiff(measured)) == 0);
    assert(all(details.o4UlDlFeasible(measured) == 1));
    assert(all(details.o4MinPhi(measured) >= 0));
    assert(all(details.o4MaxPhi(measured) <= 0.999));

    aggregate = aggregateRows(details(measured, :));
    audit = struct();
    audit.details = details;
    audit.aggregate = aggregate;
    audit.parameters = struct('sourceOption', 1, 'targetOption', 4, ...
        'phiMax', 0.999, 'acceleration', 3, 'quadratureNodes', 16, ...
        'optimizationRun', false, 'polishingRun', false, ...
        'availableRows', 54, 'unavailableJointRawRows', 9, ...
        'o1ExactParityRows', 54, 'legacyCsv', legacyCsv);
    writetable(details, fullfile(outputRoot, 'cross_model_rescore.csv'));
    writetable(aggregate, fullfile(outputRoot, 'aggregate.csv'));
    save(fullfile(outputRoot, 'rescore.mat'), 'audit');
    fprintf(['CROSS-MODEL RESCORE PASS: 54 measured rows, 9 unavailable Joint raw rows; ', ...
        'O1 parity exact for 54/54 rows.\nOutput: %s\n'], outputRoot);
end

function specs = stageSpecs(data)
    specs = repmat(struct('algorithm', '', 'stage', '', 'field', '', ...
        'optimizeBS', false, 'isBaseline', false, 'available', false), 7, 1);
    specs(1) = makeSpec('Baseline', 'baseline', 'resBase', false, true, true);
    specs(2) = makeSpec('Joint PSO', 'raw', 'trajJointRaw', false, false, ...
        isfield(data, 'trajJointRaw'));
    specs(3) = makeSpec('Joint PSO', 'polished', 'trajJoint', false, false, true);
    specs(4) = makeSpec('Full PSO', 'raw', 'trajFullRaw', true, false, true);
    specs(5) = makeSpec('Full PSO', 'polished', 'trajFull', true, false, true);
    specs(6) = makeSpec('Full IPSO', 'raw', 'trajIPSORaw', true, false, true);
    specs(7) = makeSpec('Full IPSO', 'polished', 'trajIPSO', true, false, true);
end

function spec = makeSpec(algorithm, stage, field, optimizeBS, isBaseline, available)
    spec = struct('algorithm', algorithm, 'stage', stage, 'field', field, ...
        'optimizeBS', optimizeBS, 'isBaseline', isBaseline, 'available', available);
end

function sim = physicsSim(sim, option)
    sim.radio.powerSplitMode = 'fixed';
    sim.radio.enforceUlDlCausality = false;
    sim.radio.phiMin = 0;
    sim.radio.phiMax = 0.999;
    sim.flight.motionMode = 'steady-cruise';
    sim.flight.acceleration = 3;
    sim.flight.quadratureNodes = 16;
    if option == 4
        sim.radio.powerSplitMode = 'optimal-causal';
        sim.radio.enforceUlDlCausality = true;
        sim.flight.motionMode = 'quasi-steady-accel';
    else
        assert(option == 1);
    end
end

function assertO1Parity(legacy, current, field, sourceMat)
    names = {'totalBits', 'totalEnergy', 'flightEnergy', 'hoverEnergy', ...
        'rfEnergy', 'totalDistance', 'missionTime', 'eeComputed', 'isFeasible'};
    differences = zeros(size(names));
    for k = 1:numel(names)
        differences(k) = abs(double(current.(names{k})) - double(legacy.(names{k})));
    end
    assert(all(differences == 0), 'O1 parity failed for %s in %s.', field, sourceMat);
end

function row = fillMeasuredRow(row, legacy, o1, o4)
    row.legacyEE = legacy.eeComputed;
    row.legacyFeasible = double(legacy.isFeasible);
    row.o1EE = o1.eeComputed;
    row.o1Bits = o1.totalBits;
    row.o1EnergyJ = o1.totalEnergy;
    row.o1ParityMaxAbsDiff = maxAbsDifference(legacy, o1);
    row.o4EE = o4.eeComputed;
    row.o4Feasible = double(o4.isFeasible);
    row.o4QosL = double(o4.missionQoSFeasible);
    row.o4QosSlot = double(o4.slotQoSFeasible);
    row.o4QosUserSlot = double(o4.userSlotQoSFeasible);
    row.o4UlDlFeasible = double(o4.ulDlFeasible);
    row.o4QosWithoutEnergy = double(o4.dataQoSFeasible && o4.ulDlFeasible ...
        && o4.geometryFeasible);
    row.o4EnergyFeasible = double(o4.energyFeasible);
    row.o4GeometryFeasible = double(o4.geometryFeasible);
    row.o4Bits = o4.totalBits;
    row.o4EnergyJ = o4.totalEnergy;
    row.o4FlightEnergyJ = o4.flightEnergy;
    row.o4HoverEnergyJ = o4.hoverEnergy;
    row.o4RfEnergyJ = o4.rfEnergy;
    row.o4EnergyShortfallJ = o4.energyShortfall;
    row.o4DistanceM = o4.totalDistance;
    row.o4FlightTimeS = o4.flightTime;
    row.o4MissionTimeS = o4.missionTime;
    row.o4MinPhi = o4.minPhi;
    row.o4MaxPhi = o4.maxPhi;
    row.o4MeanPhi = o4.meanPhi;
    row.o4MaxUlDlShortfallBits = max(o4.ulDlShortfall(:));
    row.o4MinUserBits = min(o4.totalBitsPerUser);
    row.o4MaxUserBits = max(o4.totalBitsPerUser);
    row.o4UserSlotsBelow = o4.numUserSlotsBelowMin;
    row.eeChangePct = 100 * (o4.eeComputed / o1.eeComputed - 1);
    row.energyChangePct = 100 * (o4.totalEnergy / o1.totalEnergy - 1);
end

function value = maxAbsDifference(a, b)
    names = {'totalBits', 'totalEnergy', 'flightEnergy', 'hoverEnergy', ...
        'rfEnergy', 'totalDistance', 'missionTime', 'eeComputed', 'isFeasible'};
    value = 0;
    for k = 1:numel(names)
        value = max(value, abs(double(a.(names{k})) - double(b.(names{k}))));
    end
end

function row = blankRow()
    numericFields = {'seed', 'algorithmSeed', 'polishSeed', 'L', 'optimizeBS', ...
        'available', 'legacyEE', 'legacyFeasible', 'o1EE', 'o1Bits', ...
        'o1EnergyJ', 'o1ParityMaxAbsDiff', 'o4EE', 'o4Feasible', 'o4QosL', ...
        'o4QosSlot', 'o4QosUserSlot', 'o4UlDlFeasible', 'o4QosWithoutEnergy', ...
        'o4EnergyFeasible', 'o4GeometryFeasible', 'o4Bits', 'o4EnergyJ', ...
        'o4FlightEnergyJ', 'o4HoverEnergyJ', 'o4RfEnergyJ', ...
        'o4EnergyShortfallJ', 'o4DistanceM', 'o4FlightTimeS', 'o4MissionTimeS', ...
        'o4MinPhi', 'o4MaxPhi', 'o4MeanPhi', 'o4MaxUlDlShortfallBits', ...
        'o4MinUserBits', 'o4MaxUserBits', 'o4UserSlotsBelow', ...
        'eeChangePct', 'energyChangePct'};
    row = struct('algorithm', '', 'stage', '', 'sourceField', '', ...
        'sourceResultsMat', '', 'missingReason', '');
    for k = 1:numel(numericFields)
        row.(numericFields{k}) = NaN;
    end
end

function aggregate = aggregateRows(details)
    keys = unique(details(:, {'algorithm', 'stage', 'L'}), 'rows', 'sorted');
    rows = repmat(struct(), 0, 1);
    for k = 1:height(keys)
        key = keys(k, :);
        mask = strcmp(details.algorithm, key.algorithm) ...
            & strcmp(details.stage, key.stage) & details.L == key.L;
        group = details(mask, :);
        row = struct();
        row.algorithm = key.algorithm{1};
        row.stage = key.stage{1};
        row.L = key.L;
        row.n = height(group);
        row.meanO1EE = mean(group.o1EE);
        row.meanO4EE = mean(group.o4EE);
        row.stdO4EE = std(group.o4EE, 0);
        row.nO4Feasible = sum(group.o4Feasible);
        row.meanO4FeasibleEE = maskedMean(group.o4EE, group.o4Feasible == 1);
        row.nO4QosWithoutEnergy = sum(group.o4QosWithoutEnergy);
        row.nO4EnergyFeasible = sum(group.o4EnergyFeasible);
        row.meanEEChangePct = mean(group.eeChangePct);
        row.meanEnergyChangePct = mean(group.energyChangePct);
        row.meanO4EnergyJ = mean(group.o4EnergyJ);
        row.meanO4MissionTimeS = mean(group.o4MissionTimeS);
        row.meanO4MinPhi = mean(group.o4MinPhi);
        row.meanO4MaxPhi = mean(group.o4MaxPhi);
        if isempty(rows)
            rows = row;
        else
            rows(end+1) = row; %#ok<AGROW>
        end
    end
    aggregate = struct2table(rows);
end

function value = maskedMean(x, mask)
    if any(mask)
        value = mean(x(mask));
    else
        value = NaN;
    end
end

function folder = localizeLegacyFolder(value, projectRoot)
    folder = char(value);
    if startsWith(folder, 'D:')
        relative = extractAfter(string(folder), 'EE-UAV-SWIPT-NOMA-PSO-git\');
        folder = fullfile(projectRoot, strrep(char(relative), '\', filesep));
    end
end
