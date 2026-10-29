function cfg = v10Config()
%V10CONFIG Shared editable configuration for V10A and V10B only.
% V9 files and their defaults are deliberately independent of this file.
    cfg.version = 'V10-Drones-1';
    cfg.random.mainSeed = 2026;
    cfg.random.algorithmSeed = 151459287;
    cfg.random.polishSeed = 152459287;

    % Preserve V9 geometry; Z is fixed for the Drones horizontal-flight model.
    cfg.geometry.width = 300;
    cfg.geometry.length = 300;
    cfg.geometry.altitude = 30;
    cfg.geometry.startXY = [150,300];
    cfg.geometry.endXY = [150,0];
    cfg.geometry.numWaypoints = 21;
    cfg.geometry.xBounds = [75,225];
    cfg.geometry.minYProgress = 1; % metres/segment, B only, in direction of endXY
    cfg.geometry.noUsers = 5;
    cfg.geometry.bsXYZ = [300,300,20; 0,150,30; 300,0,25];
    cfg.geometry.bsMargin = 50;

    % V9 radio values (not a claim of reproducing Flight to Efficiency Table I).
    cfg.radio.bsPowerDbm = 46; % EACH BS; never used as motor or UAV RF power
    cfg.radio.bandwidthHz = 1e6;
    cfg.radio.noiseDensityDbmHz = -174;
    cfg.radio.powerSplit = 0.9; % phi
    cfg.radio.ehEfficiency = 0.9; % eta
    cfg.radio.pathLossExponent = 2.5;
    cfg.radio.referenceGainDb = -30;
    cfg.radio.ricianMinDb = 4;
    cfg.radio.ricianMaxDb = 12;
    cfg.radio.losAmplitude = 1;
    cfg.radio.pMin = 1e-3; % raw alpha weights, not RF watts
    cfg.radio.pMax = 1; % raw weight cap BEFORE normalization; NOT a cap on alpha

    cfg.mission.hoverTime = 1; % seconds at every waypoint except final arrival
    cfg.mission.ehFraction = 0.5; % EH/UL then RF/DL, same as V9 by default
    cfg.mission.minBitsPerUser = 3e6; % scalar or vector in physical User ID order
    % Per-slot QoS. Both are 0 (disabled) or bits per SERVING slot (1..numWaypoints-1).
    % Current default: 5 kbit/user/slot (chosen 2026-10-29).
    % Log analysis 2026-10-28: 10 kbit catches the 42-bit and 1-kbit starvation
    % slots at L=3 with only 47-73 kbit total shortfall (0.1-0.17%); 5 kbit is
    % a milder setting. Set both to 0 to reproduce the pre-constraint logs.
    cfg.mission.minBitsPerSlot = 0; % total bits over all users in one slot
    cfg.mission.minBitsPerUserPerSlot = 5e3; % per user in one slot (scalar or 1xN)
    cfg.mission.energyBudgetJ = 1.7e4; % Drones Eq. (12), gross load; Inf disables

    % Drones 10(4),238, Table 2 and Eq. (11). A is area of ONE rotor.
    cfg.flight.numRotors = 4;
    cfg.flight.airDensity = 1.293;
    cfg.flight.flatPlateArea = 0.01;
    cfg.flight.mass = 2;
    cfg.flight.gravity = 9.8;
    cfg.flight.cruiseSpeed = 15.521;
    cfg.flight.rotorSolidity = 0.0955;
    cfg.flight.bladeDrag = 0.012;
    cfg.flight.thrustCoefficient = 0.302;
    cfg.flight.inducedCorrection = 0.131;
    cfg.flight.fuselageDragRatio = 0.8333;
    cfg.flight.rotorArea = 0.0314;

    % Default = quick: 120 particles, 1000 iterations for all three optimizers.
    % Campaign profile 'full' keeps 120 particles and raises maxIter to 3000.
    % IPSO mutation adds evaluations; the particle budget is equal across PSO.
    cfg.optimizers.joint = struct('numParticles',120,'maxIter',1000, ...
        'w',0.7,'c1',1.5,'c2',1.5);
    cfg.optimizers.full = struct('numParticles',120,'maxIter',1000, ...
        'w',0.7,'c1',1.5,'c2',1.5);
    cfg.optimizers.ipso = struct('numParticles',120,'maxIter',1000, ...
        'w_max',0.9,'w_min',0.4,'c1',1.5,'c2',1.5, ...
        'mutRateLow',0.02,'mutParticleRateLow',0.05, ...
        'mutRateHigh',0.08,'mutParticleRateHigh',0.20, ...
        'stallIter',100,'eliteRate',0.05, ...
        'sigmaScaleLow',0.03,'sigmaScaleHigh',0.05);
    cfg.optimizers.alphaPolishSamplesPerUser = 250;
    cfg.optimizers.alphaPolishMinimumSamples = 500;

    projectRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
    cfg.output.root = fullfile(projectRoot,'results','v10');
    cfg.output.makePlots = true;
    % Group switches: true = draw, false = skip. makePlots is the master switch.
    cfg.output.figureGroups.base = true; % Figures 1-8 (Figure 3 is unused)
    cfg.output.figureGroups.EH_Alpha_config = true; % Figures 9-16
    cfg.output.figureGroups.flyingEnergy = true; % Figures 17-18
    cfg.output.saveFigures = true;
    cfg.output.saveResults = true;
end
