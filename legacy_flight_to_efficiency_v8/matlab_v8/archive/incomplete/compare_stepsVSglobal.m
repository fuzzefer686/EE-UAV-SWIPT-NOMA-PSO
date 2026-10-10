clc;
clear variables;
close all;

% Compare four approaches:
%   1) positionUpdate_PSO                 : stepwise PSO, one [dx, dz] per call
%   2) optimizeTrajectory_PSO_SWIPT_clean : global PSO, one particle is a full UAV trajectory
%   3) optimizeTrajectory_FA_SWIPT_fast   : global FA, one particle is a full UAV trajectory
%   4) optimizeBSPosition_JointSWIPT_clean: BS-only PSO, UAV trajectory/alpha are fixed
%
% Note: optimizeBSPosition_JointSWIPT_clean does not optimize a UAV
% trajectory by itself. In this comparison it uses the Global PSO
% trajectory and alpha as the fixed baseJointParticle, then optimizes BS
% x/y positions.

rng(1);

%% Environment
enWidth  = 300;
enLength = 300;
enHeight = 60;

noUsers = 3;
noBS = 3;

xUAV_S = 150;
yUAV_S = enLength;
zUAV_S = 30;

xUAV_E = 150;
yUAV_E = 0;
zUAV_E = 30;

xBS = [300,   0, 300];
yBS = [300, 150,   0];
zBS = [ 20,  30,  25];

xUser = zeros(1, noUsers);
yUser = zeros(1, noUsers);
zUser = zeros(1, noUsers);

for i = 1:noUsers
    xUser(i) = randi([enWidth/4,  3*enWidth/4]);
    yUser(i) = randi([enLength/4, 3*enLength/4]);
    zUser(i) = 0;
end

stepsVec = enLength:-15:0;
numSteps = numel(stepsVec);

%% SWIPT and channel parameters
Pr = 46;
pr = (10^-3) * db2pow(Pr);

Tslot = 1e-6;
phy = 0.9;
neta = 0.9;

etaPath = 2.5;
b0 = db2pow(-30);

K_min = 4;
K_max = 12;

A1 = db2pow(K_min);
A2 = (2/pi) * log(db2pow(K_max) / A1);

gLoS = 1;
gNLoSUsers = sqrt(1/2) * (randn(1, noUsers) + 1i * randn(1, noUsers));
gNLoSBS    = sqrt(1/2) * (randn(1, noBS)    + 1i * randn(1, noBS));

%% Simulation struct
sim = struct();

sim.numSteps = numSteps;
sim.stepsVec = stepsVec;

sim.xStart = xUAV_S;
sim.zStart = zUAV_S;
sim.xEnd   = xUAV_E;
sim.zEnd   = zUAV_E;

sim.x_min = 75;
sim.x_max = 225;
sim.z_min = 15;
sim.z_max = 45;

sim.dxMax = 75;
sim.dzMax = 10;

sim.noUsers = noUsers;
sim.noBS = noBS;

sim.xUser = xUser;
sim.yUser = yUser;
sim.zUser = zUser;

sim.xBS = xBS;
sim.yBS = yBS;
sim.zBS = zBS;

bsMargin = 50;
sim.xBS_min = max(0, xBS - bsMargin);
sim.xBS_max = min(enWidth, xBS + bsMargin);
sim.yBS_min = max(0, yBS - bsMargin);
sim.yBS_max = min(enLength, yBS + bsMargin);

sim.etaPath = etaPath;
sim.b0 = b0;
sim.A1 = A1;
sim.A2 = A2;
sim.gLoS = gLoS;
sim.gNLoSUsers = gNLoSUsers;
sim.gNLoSBS = gNLoSBS;

sim.pr = pr;
sim.phy = phy;
sim.neta = neta;
sim.Tslot = Tslot;

sim.bigPenalty = 1e12;
sim.lambdaMean = 0.05;
sim.lambdaSmooth = 0;
sim.pMin = 1e-3;
sim.pMax = 1.0;
sim.jointAlphaRepair = 'noma';
sim.fitnessStepMode = 'internal';

%% Baseline
xBase = linspace(xUAV_S, xUAV_E, numSteps);
zBase = linspace(zUAV_S, zUAV_E, numSteps);
particleBase = [xBase(2:end-1), zBase(2:end-1)];

[fitBase, resBase] = evaluateTrajectory_SWIPT_clean(particleBase, sim);
resBase.bestFitness = fitBase;
resBase.mode = 'straight-baseline';

%% 1) Stepwise PSO from positionUpdate_PSO
fprintf('\nSTEPWISE POSITIONUPDATE_PSO\n');
[fitStep, trajStep] = runStepwisePositionUpdatePSO(sim);

%% 2) Global PSO-SWIPT
optsPSO = struct();
optsPSO.numParticles = 60;
optsPSO.maxIter = 300;
optsPSO.w = 0.7;
optsPSO.c1 = 1.5;
optsPSO.c2 = 1.5;

fprintf('\nGLOBAL PSO-SWIPT\n');
trajPSO = optimizeTrajectory_PSO_SWIPT_clean(sim, optsPSO);

%% 3) Global FA-SWIPT fast
optsFA = struct();
optsFA.numParticles = 60;
optsFA.maxIter = 300;
optsFA.alpha = 0.1;
optsFA.alphaDamp = 0.92;
optsFA.beta0 = 1.0;
optsFA.gamma = 5e-4;
optsFA.topKAttractors = 6;
optsFA.eliteKeep = 4;
optsFA.useParallel = false;

fprintf('\nGLOBAL FA-SWIPT-FAST\n');
trajFA = optimizeTrajectory_FA_SWIPT_fast(sim, optsFA);

%% 4) BS-only Joint-SWIPT, fixed trajectory and alpha from Global PSO
baseJointParticle = makeBaseJointParticle(trajPSO, sim);

optsBS = struct();
optsBS.numParticles = 60;
optsBS.maxIter = 300;
optsBS.w = 0.7;
optsBS.c1 = 1.5;
optsBS.c2 = 1.5;

fprintf('\nBS-ONLY JOINT-SWIPT USING GLOBAL PSO TRAJECTORY/ALPHA\n');
trajBS = optimizeBSPosition_JointSWIPT_clean(baseJointParticle, sim, optsBS);

%% Summary
algorithm = { ...
    'Baseline straight'; ...
    'Stepwise positionUpdate\_PSO'; ...
    'Global PSO-SWIPT'; ...
    'Global FA-SWIPT-fast'; ...
    'BS-only Joint-SWIPT on PSO traj' ...
};

particleModel = { ...
    'none'; ...
    '2 vars per step: [dx,dz]'; ...
    sprintf('%d vars: full [x,z] trajectory', 2*(numSteps-2)); ...
    sprintf('%d vars: full [x,z] trajectory', 2*(numSteps-2)); ...
    sprintf('%d vars: [xBS,yBS], trajectory fixed', 2*noBS) ...
};

results = {resBase, trajStep, trajPSO, trajFA, trajBS};
fitness = zeros(numel(results), 1);
globalMinRate = zeros(numel(results), 1);
meanMinRate = zeros(numel(results), 1);
meanPtW = zeros(numel(results), 1);
meanPtDbm = zeros(numel(results), 1);
penalty = zeros(numel(results), 1);
feasible = false(numel(results), 1);
roughNorm = zeros(numel(results), 1);

for k = 1:numel(results)
    m = extractMetrics(results{k});
    fitness(k) = m.fitness;
    globalMinRate(k) = m.globalMinRate;
    meanMinRate(k) = m.meanMinRate;
    meanPtW(k) = m.meanPtW;
    meanPtDbm(k) = m.meanPtDbm;
    penalty(k) = m.penalty;
    feasible(k) = m.feasible;
    roughNorm(k) = m.roughNorm;
end

summaryTable = table(algorithm, particleModel, fitness, globalMinRate, ...
    meanMinRate, meanPtW, meanPtDbm, penalty, feasible, roughNorm);

fprintf('\n========== SUMMARY ==========\n');
disp(summaryTable);

fprintf('\nUser positions [x; y; z]:\n');
disp([xUser; yUser; zUser]);

fprintf('Initial BS positions [x; y; z]:\n');
disp([sim.xBS; sim.yBS; sim.zBS]);

fprintf('Optimized BS positions from BS-only Joint-SWIPT [x; y; z]:\n');
disp([trajBS.xBS; trajBS.yBS; trajBS.zBS]);

fprintf('\nStepwise raw local objective is non-SWIPT NOMA min-rate.\n');
fprintf('Stepwise final row in the table is re-evaluated by evaluateTrajectory_SWIPT_clean.\n');
fprintf('BS-only row is evaluated by evaluateTrajectory_JointBS_SWIPT_clean with fixed PSO trajectory/alpha.\n');

%% Figures
plotTrajectoryComparison(sim, resBase, trajStep, trajPSO, trajFA, trajBS, enWidth, enLength, enHeight);
plotMinRateComparison(sim, resBase, trajStep, trajPSO, trajFA, trajBS);
plotConvergence(optsPSO, optsFA, optsBS, trajPSO, trajFA, trajBS);

%% Local helper functions
function [fitness, result] = runStepwisePositionUpdatePSO(sim)
    T = sim.numSteps;
    xRaw = zeros(1, T);
    zRaw = zeros(1, T);
    yTraj = sim.stepsVec(:).';
    localMinNoSwipt = nan(T, 1);

    xRaw(1) = sim.xStart;
    zRaw(1) = sim.zStart;

    for t = 2:(T-1)
        upd = positionUpdate_PSO( ...
            xRaw(t-1), yTraj(t), zRaw(t-1), ...
            sim.noUsers, sim.xUser, sim.yUser, sim.gNLoSUsers);

        xRaw(t) = xRaw(t-1) + upd.position(1);
        zRaw(t) = zRaw(t-1) + upd.position(2);
        localMinNoSwipt(t) = upd.minRate;
    end

    xRaw(T) = sim.xEnd;
    zRaw(T) = sim.zEnd;

    particle = repairTrajectoryToParticle(xRaw, zRaw, sim);
    [fitness, result] = evaluateTrajectory_SWIPT_clean(particle, sim);

    result.bestParticle = particle;
    result.bestFitness = fitness;
    result.bestHistory = [];
    result.mode = 'stepwise-positionUpdate-pso';
    result.rawXTraj = xRaw;
    result.rawYTraj = yTraj;
    result.rawZTraj = zRaw;
    result.localMinNoSwipt = localMinNoSwipt;
end

function particle = makeBaseJointParticle(result, sim)
    T = sim.numSteps;
    nInternal = T - 2;

    alphaTrace = result.alphaTrace;
    alphaTrace = max(real(alphaTrace), sim.pMin);
    alphaTrace = alphaTrace ./ sum(alphaTrace, 2);

    particle = [ ...
        result.xTraj(2:end-1), ...
        result.zTraj(2:end-1), ...
        reshape(alphaTrace.', 1, []) ...
    ];

    expectedDim = 2*nInternal + T*sim.noUsers;
    if numel(particle) ~= expectedDim
        error('makeBaseJointParticle: invalid particle dimension.');
    end
end

function particle = repairTrajectoryToParticle(xTraj, zTraj, sim)
    T = sim.numSteps;

    xTraj = real(xTraj(:).');
    zTraj = real(zTraj(:).');

    if numel(xTraj) ~= T || numel(zTraj) ~= T
        error('repairTrajectoryToParticle: trajectory length must equal sim.numSteps.');
    end

    xTraj(1) = sim.xStart;
    xTraj(end) = sim.xEnd;
    zTraj(1) = sim.zStart;
    zTraj(end) = sim.zEnd;

    xTraj(2:end-1) = min(max(xTraj(2:end-1), sim.x_min), sim.x_max);
    zTraj(2:end-1) = min(max(zTraj(2:end-1), sim.z_min), sim.z_max);

    for pass = 1:3
        for t = 2:(T-1)
            lo = max(sim.x_min, xTraj(t-1) - sim.dxMax);
            hi = min(sim.x_max, xTraj(t-1) + sim.dxMax);
            xTraj(t) = min(max(xTraj(t), lo), hi);
        end

        for t = (T-1):-1:2
            lo = max(sim.x_min, xTraj(t+1) - sim.dxMax);
            hi = min(sim.x_max, xTraj(t+1) + sim.dxMax);
            xTraj(t) = min(max(xTraj(t), lo), hi);
        end
    end

    for pass = 1:3
        for t = 2:(T-1)
            lo = max(sim.z_min, zTraj(t-1) - sim.dzMax);
            hi = min(sim.z_max, zTraj(t-1) + sim.dzMax);
            zTraj(t) = min(max(zTraj(t), lo), hi);
        end

        for t = (T-1):-1:2
            lo = max(sim.z_min, zTraj(t+1) - sim.dzMax);
            hi = min(sim.z_max, zTraj(t+1) + sim.dzMax);
            zTraj(t) = min(max(zTraj(t), lo), hi);
        end
    end

    xTraj(2:end-1) = min(max(xTraj(2:end-1), sim.x_min), sim.x_max);
    zTraj(2:end-1) = min(max(zTraj(2:end-1), sim.z_min), sim.z_max);

    particle = [xTraj(2:end-1), zTraj(2:end-1)];
end

function metrics = extractMetrics(result)
    metrics = struct();

    if isfield(result, 'bestFitness')
        metrics.fitness = result.bestFitness;
    else
        metrics.fitness = result.fitness;
    end

    metrics.globalMinRate = min(result.stepMin);
    metrics.meanMinRate = mean(result.stepMin);
    metrics.meanPtW = mean(result.pt);

    if metrics.meanPtW > 0
        metrics.meanPtDbm = 10 * log10(metrics.meanPtW / 1e-3);
    else
        metrics.meanPtDbm = -inf;
    end

    if isfield(result, 'penalty')
        metrics.penalty = result.penalty;
    else
        metrics.penalty = NaN;
    end

    if isfield(result, 'isFeasible')
        metrics.feasible = logical(result.isFeasible);
    else
        metrics.feasible = false;
    end

    if isfield(result, 'roughNorm')
        metrics.roughNorm = result.roughNorm;
    else
        metrics.roughNorm = NaN;
    end
end

function plotTrajectoryComparison(sim, resBase, trajStep, trajPSO, trajFA, trajBS, enWidth, enLength, enHeight)
    figure;
    hold on;

    plot3(sim.xUser, sim.yUser, sim.zUser, 'k*', 'LineWidth', 2, 'MarkerSize', 8);
    for u = 1:sim.noUsers
        text(sim.xUser(u)+3, sim.yUser(u)+3, sim.zUser(u)+3, ['GU', num2str(u)]);
    end

    plot3(sim.xBS, sim.yBS, sim.zBS, 'k^', 'LineWidth', 2, 'MarkerSize', 8);
    plot3(trajBS.xBS, trajBS.yBS, trajBS.zBS, 'md', 'LineWidth', 2, 'MarkerSize', 8);

    plot3(resBase.xTraj, resBase.yTraj, resBase.zTraj, 'b--o', 'LineWidth', 1.2, 'MarkerSize', 4);
    plot3(trajStep.xTraj, trajStep.yTraj, trajStep.zTraj, 'g-o', 'LineWidth', 1.5, 'MarkerSize', 5);
    plot3(trajPSO.xTraj, trajPSO.yTraj, trajPSO.zTraj, 'r-o', 'LineWidth', 1.5, 'MarkerSize', 5);
    plot3(trajFA.xTraj, trajFA.yTraj, trajFA.zTraj, 'c-o', 'LineWidth', 1.5, 'MarkerSize', 5);
    plot3(trajBS.xTraj, trajBS.yTraj, trajBS.zTraj, 'm--s', 'LineWidth', 1.3, 'MarkerSize', 4);

    plot3(sim.xStart, sim.stepsVec(1), sim.zStart, 'go', 'LineWidth', 2, 'MarkerSize', 9);
    plot3(sim.xEnd, sim.stepsVec(end), sim.zEnd, 'ro', 'LineWidth', 2, 'MarkerSize', 9);

    grid on;
    xlabel('x / Width (m)');
    ylabel('y / Length (m)');
    zlabel('z / Height (m)');
    title('Trajectory comparison: stepwise PSO vs global optimizers');
    legend('Ground Users', 'Initial BS', 'Optimized BS', ...
        'Baseline', 'Stepwise positionUpdate\_PSO', 'Global PSO-SWIPT', ...
        'Global FA-SWIPT-fast', 'BS-only fixed PSO trajectory', ...
        'UAV Start', 'UAV End', 'Location', 'best');

    xlim([0 enWidth]);
    ylim([0 enLength]);
    zlim([0 enHeight]);
end

function plotMinRateComparison(sim, resBase, trajStep, trajPSO, trajFA, trajBS)
    figure;
    hold on;

    plot(1:sim.numSteps, resBase.stepMin, 'b--o', 'LineWidth', 1.2, 'MarkerSize', 4);
    plot(1:sim.numSteps, trajStep.stepMin, 'g-o', 'LineWidth', 1.4, 'MarkerSize', 5);
    plot(1:sim.numSteps, trajPSO.stepMin, 'r-o', 'LineWidth', 1.4, 'MarkerSize', 5);
    plot(1:sim.numSteps, trajFA.stepMin, 'c-o', 'LineWidth', 1.4, 'MarkerSize', 5);
    plot(1:sim.numSteps, trajBS.stepMin, 'm-s', 'LineWidth', 1.4, 'MarkerSize', 5);

    grid on;
    xlabel('Mission step');
    ylabel('Minimum achievable rate among users (bps)');
    title('Min-rate by mission step');
    legend('Baseline', 'Stepwise positionUpdate\_PSO', 'Global PSO-SWIPT', ...
        'Global FA-SWIPT-fast', 'BS-only Joint-SWIPT', 'Location', 'best');
end

function plotConvergence(optsPSO, optsFA, optsBS, trajPSO, trajFA, trajBS)
    figure;
    hold on;

    plot(0:optsPSO.maxIter, trajPSO.bestHistory, 'r-', 'LineWidth', 1.5);
    plot(0:optsFA.maxIter, trajFA.bestHistory, 'c-', 'LineWidth', 1.5);
    plot(0:optsBS.maxIter, trajBS.bestHistory, 'm-', 'LineWidth', 1.5);

    grid on;
    xlabel('Iteration');
    ylabel('Best fitness (bps)');
    title('Convergence history');
    legend('Global PSO-SWIPT', 'Global FA-SWIPT-fast', ...
        'BS-only Joint-SWIPT', 'Location', 'best');
end
