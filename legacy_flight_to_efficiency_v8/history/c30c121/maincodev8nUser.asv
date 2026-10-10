clc;
clear variables;
close all;

%% Khoi tao moi truong
% Set useFixedSeed = true de lap lai y nguyen mot moi truong/random stream.
useFixedSeed = true;
mainSeed = 150459284;
if useFixedSeed
    rng(mainSeed, 'twister');
else
    rng('shuffle');
end


enWidth  = 300;
enLength = 300;
enHeight = 60;

noUsers = 5;
noBS = 3;

%% Diem dau / diem cuoi UAV
xUAV_S = 150;
yUAV_S = enLength;
zUAV_S = 30;

xUAV_E = 150;
yUAV_E = 0;
zUAV_E = 30;

%% Vi tri BS
xBS = [300,   0, 300];
yBS = [300, 150,   0];
zBS = [ 20,  30,  25];

%% Vi tri users
xUser = zeros(1, noUsers);
yUser = zeros(1, noUsers);
zUser = zeros(1, noUsers);

for i = 1:noUsers
    xUser(i) = randi([enWidth/4,  3*enWidth/4]);
    yUser(i) = randi([enLength/4, 3*enLength/4]);
    zUser(i) = 0;
end

fprintf('\n================ SCENARIO INFO ================\n');
fprintf('mainSeed = %d | noUsers = %d | noBS = %d\n', mainSeed, noUsers, noBS);
fprintf('xUser = '); disp(xUser);
fprintf('yUser = '); disp(yUser);


%% Chia step 
stepsVec = enLength:-15:0;
numSteps = numel(stepsVec);

%% Thong so SWIPT
Pr = 46;                         % dBm
pr = (10^-3) * db2pow(Pr);       % W

Tslot = 1e-6;
phy = 0.9;
neta = 0.9;

%% Thong so kenh
etaPath = 2.5;
b0 = db2pow(-30);

K_min = 4;
K_max = 12;

A1 = db2pow(K_min);
A2 = (2/pi) * log(db2pow(K_max) / A1);

gLoS = 1;

gNLoSUsers = sqrt(1/2) * (randn(1, noUsers) + 1i * randn(1, noUsers));
gNLoSBS    = sqrt(1/2) * (randn(1, noBS)    + 1i * randn(1, noBS));

%% Dong goi vao struct sim
sim = struct();

sim.numSteps = numSteps;
sim.stepsVec = stepsVec;

sim.xStart = xUAV_S;
sim.zStart = zUAV_S;
sim.xEnd   = xUAV_E;
sim.zEnd   = zUAV_E;

bsMargin = 50;

sim.xBS_min = max(0, xBS - bsMargin);
sim.xBS_max = min(enWidth, xBS + bsMargin);

sim.yBS_min = max(0, yBS - bsMargin);
sim.yBS_max = min(enLength, yBS + bsMargin);

% Giu endpoint UAV khong tham gia fitness
sim.fitnessStepMode = 'internal';

% Bien khong gian bay
sim.x_min = 75;
sim.x_max = 225;
sim.z_min = 15;
sim.z_max = 45;

% Gioi han moi step bay
sim.dxMax = 75;
sim.dzMax = 30;

sim.noUsers = noUsers;
sim.noBS = noBS;

sim.xUser = xUser;
sim.yUser = yUser;
sim.zUser = zUser;

sim.xBS = xBS;
sim.yBS = yBS;
sim.zBS = zBS;

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
sim.lambdaFair = 0.1;      % Jain/fairness penalty
sim.pMin = 1e-3;
sim.pMax = 1.0;
sim.jointAlphaRepair = 'noma';

%% Tao baseline
xBase = linspace(xUAV_S, xUAV_E, numSteps);
zBase = linspace(zUAV_S, zUAV_E, numSteps);

particleBase = [xBase(2:end-1), zBase(2:end-1)];

[fitBase, resBase] = evaluateTrajectory_SWIPT_clean(particleBase, sim);

%% Joint PSO-SWIPT toan quy dao
optsJoint = struct();

optsJoint.numParticles = 80;
optsJoint.maxIter = 450;

optsJoint.w = 0.7;
optsJoint.c1 = 1.5;
optsJoint.c2 = 1.5;

fprintf('\nGLOBAL JOINT PSO-SWIPT\n');

trajJoint = optimizeTrajectory_JointPSO_SWIPT_clean(sim, optsJoint);

%% Lay ket qua Joint
achRate_Joint = trajJoint.achRate;
minRate_Joint = trajJoint.stepMin;
pt_Joint = trajJoint.pt;
alpha_Joint = trajJoint.alphaTrace;
alphaOrd_Joint = trajJoint.alphaOrdTrace;


alphaPolishSamples = max(500, 250 * noUsers);
%%  JOINT + BS OPTIMIZATION
optsFull = struct();

optsFull.numParticles = 400;
optsFull.maxIter = 3000;

optsFull.w = 0.7;
optsFull.c1 = 1.5;
optsFull.c2 = 1.5;

seedAlgo   = 151459287;
seedPolish = 152459287;

fprintf('\nFULL JOINT+BS PSO\n');

rng(seedAlgo, 'twister');
trajFullRaw = optimizeTrajectory_JointBS_PSO_SWIPT_clean(sim, optsFull);

rng(seedPolish, 'twister');
trajFull = polishAlphaAllSteps_JointBS(trajFullRaw, sim, alphaPolishSamples);

%% FULL JOINT+BS IPSO OPTIMIZATION 
optsIPSO = struct();
optsIPSO.numParticles = 400;
optsIPSO.maxIter = 3000;

% Các tham số IPSO
optsIPSO.w_max = 0.9;
optsIPSO.w_min = 0.4;
% Adaptive mutation
optsIPSO.mutRateLow = 0.02;
optsIPSO.mutParticleRateLow = 0.05;

optsIPSO.mutRateHigh = 0.08;
optsIPSO.mutParticleRateHigh = 0.20;

optsIPSO.stallIter = 100;
optsIPSO.eliteRate = 0.05;

optsIPSO.sigmaScaleLow = 0.03;
optsIPSO.sigmaScaleHigh = 0.05;

optsIPSO.c1 = 1.5;
optsIPSO.c2 = 1.5;

fprintf('\nFULL JOINT+BS IPSO (Improved PSO)\n');

rng(seedAlgo, 'twister');
trajIPSORaw = optimizeTrajectory_JointBS_IPSO_SWIPT_clean(sim, optsIPSO);

rng(seedPolish, 'twister');
trajIPSO = polishAlphaAllSteps_JointBS(trajIPSORaw, sim, alphaPolishSamples);

%% Baseline vs Joint vs Full Joint+BS
fprintf('\nFINAL RESULT\n');
fprintf('V8 settings: noUsers = %d, noBS = %d, lambdaMean = %.4f, lambdaFair = %.4f, useFixedSeed = %d\n', noUsers, noBS, sim.lambdaMean, sim.lambdaFair, useFixedSeed);

fprintf('\nBaseline straight trajectory\n');
fprintf('Baseline fitness          = %.12e\n', fitBase);
fprintf('Baseline global minRate   = %.12e\n', min(resBase.stepMin));
fprintf('Baseline mean minRate     = %.12e\n', mean(resBase.stepMin));
fprintf('Baseline mean pt          = %.4e W, %.4f dBm\n', mean(resBase.pt), 10*log10(mean(resBase.pt)/1e-3));

fprintf('\nJoint PSO-SWIPT without BS optimization\n');
fprintf('Joint fitness             = %.12e\n', trajJoint.bestFitness);
fprintf('Joint minInternal         = %.12e\n', trajJoint.minInternal);
fprintf('Joint meanInternal        = %.12e\n', trajJoint.meanInternal);
fprintf('Joint global minRate      = %.12e\n', min(trajJoint.stepMin));
fprintf('Joint mean pt             = %.4e W, %.4f dBm\n', mean(trajJoint.pt), 10*log10(mean(trajJoint.pt)/1e-3));
fprintf('Joint penalty             = %.4e\n', trajJoint.penalty);
fprintf('Joint feasible            = %d\n', trajJoint.isFeasible);

fprintf('\nFull Joint PSO-SWIPT with BS optimization\n');
fprintf('Full fitness              = %.12e\n', trajFull.bestFitness);
fprintf('Full minFit               = %.12e\n', trajFull.minFit);
fprintf('Full meanFit              = %.12e\n', trajFull.meanFit);
fprintf('Full global minRate       = %.12e\n', min(trajFull.stepMin));
fprintf('Full mean pt              = %.4e W, %.4f dBm\n', mean(trajFull.pt), 10*log10(mean(trajFull.pt)/1e-3));
fprintf('Full penalty              = %.4e\n', trajFull.penalty);
fprintf('Full feasible             = %d\n', trajFull.isFeasible);
fprintf('Full roughNorm            = %.4f\n', trajFull.roughNorm);

fprintf('\nFull Joint IPSO-SWIPT with BS optimization\n');
fprintf('IPSO fitness              = %.12e\n', trajIPSO.bestFitness);
fprintf('IPSO minFit               = %.12e\n', trajIPSO.minFit);
fprintf('IPSO meanFit              = %.12e\n', trajIPSO.meanFit);
fprintf('IPSO global minRate       = %.12e\n', min(trajIPSO.stepMin));
fprintf('IPSO mean pt              = %.4e W, %.4f dBm\n', mean(trajIPSO.pt), 10*log10(mean(trajIPSO.pt)/1e-3));
fprintf('IPSO penalty              = %.4e\n', trajIPSO.penalty);

fprintf('\nImprovement\n');
fprintf('Full - Baseline global minRate gain = %.12e\n', min(trajFull.stepMin) - min(resBase.stepMin));
fprintf('Full - Joint fitness gain           = %.12e\n', trajFull.bestFitness - trajJoint.bestFitness);
fprintf('Full - Joint minInternal gain       = %.12e\n', trajFull.minFit - trajJoint.minInternal);
fprintf('Full - Joint meanInternal gain      = %.12e\n', trajFull.meanFit - trajJoint.meanInternal);

fprintf('\nInitial BS positions [x; y; z]:\n');
disp([sim.xBS; sim.yBS; sim.zBS]);

fprintf('Optimized BS positions [x; y; z]:\n');
disp([trajFull.xBS; trajFull.yBS; trajFull.zBS]);

fprintf('BS movement distance from initial:\n');
bsMoveFull = sqrt((trajFull.xBS - sim.xBS).^2 + (trajFull.yBS - sim.yBS).^2);
disp(bsMoveFull);


%% Internal objective check: dung fitIdx noi bo
idx = 2:(sim.numSteps-1);
joint_min = min(trajJoint.stepMin(idx));
joint_mean = mean(trajJoint.stepMin(idx));
joint_raw = joint_min + sim.lambdaMean * joint_mean;

pso_min = min(trajFull.stepMin(idx));
pso_mean = mean(trajFull.stepMin(idx));
pso_raw = pso_min + sim.lambdaMean * pso_mean;

ipso_min = min(trajIPSO.stepMin(idx));
ipso_mean = mean(trajIPSO.stepMin(idx));
ipso_raw = ipso_min + sim.lambdaMean * ipso_mean;

fprintf('\n=== INTERNAL OBJECTIVE CHECK ===\n');
fprintf('Joint no-BS | min %.4e | mean %.4e | rawObj %.4e | fitness %.4e | meanPt %.4e\n', ...
    joint_min, joint_mean, joint_raw, trajJoint.bestFitness, mean(trajJoint.pt));
fprintf('Full PSO    | min %.4e | mean %.4e | rawObj %.4e | fitness %.4e | meanPt %.4e\n', ...
    pso_min, pso_mean, pso_raw, trajFull.bestFitness, mean(trajFull.pt));
fprintf('Full IPSO   | min %.4e | mean %.4e | rawObj %.4e | fitness %.4e | meanPt %.4e\n', ...
    ipso_min, ipso_mean, ipso_raw, trajIPSO.bestFitness, mean(trajIPSO.pt));

fprintf('\n=== FAIRNESS CHECK ON INTERNAL STEPS ===\n');
printFairnessMetric('Joint no-BS', trajJoint.achRate(idx, :));
printFairnessMetric('Full PSO', trajFull.achRate(idx, :));
printFairnessMetric('Full IPSO', trajIPSO.achRate(idx, :));

colorBaseline = [0.0000 0.4470 0.7410];   % Xanh biển
colorJoint    = [0.8500 0.3250 0.0980];   % Cam
colorFull     = [0.4660 0.6740 0.1880];   % Xanh lá (PSO thường)
colorIPSO     = [0.6350 0.0780 0.1840];   % Đỏ mận (IPSO)

stepAxis = 1:numSteps;

%% FIGURE 1: Trajectory comparison
figure(1); clf; hold on;

% Users
hUser = plot3(xUser, yUser, zUser, 'k*', 'LineWidth', 2, 'MarkerSize', 8);
for u = 1:noUsers
    text(xUser(u)+3, yUser(u)+3, zUser(u)+3, ['GU', num2str(u)]);
end

% Initial BS
hInitBS = plot3(sim.xBS, sim.yBS, sim.zBS, 'k^', 'LineWidth', 2, 'MarkerSize', 9);

% Optimized BS (PSO)
hOptBS_PSO = plot3(trajFull.xBS, trajFull.yBS, trajFull.zBS, 'p', ...
    'Color', colorFull, 'MarkerFaceColor', colorFull, 'LineWidth', 2, 'MarkerSize', 10);

% Optimized BS (IPSO)
hOptBS_IPSO = plot3(trajIPSO.xBS, trajIPSO.yBS, trajIPSO.zBS, 'h', ...
    'Color', colorIPSO, 'MarkerFaceColor', colorIPSO, 'LineWidth', 2, 'MarkerSize', 12);
%% BS vertical columns

for b = 1:noBS
    plot3([sim.xBS(b), sim.xBS(b)], ...
          [sim.yBS(b), sim.yBS(b)], ...
          [0, sim.zBS(b)], ...
          'k-', 'LineWidth', 1.2);
end

for b = 1:noBS
    plot3([trajFull.xBS(b), trajFull.xBS(b)], ...
          [trajFull.yBS(b), trajFull.yBS(b)], ...
          [0, trajFull.zBS(b)], ...
          '-', 'Color', colorFull, 'LineWidth', 1.5);
end

for b = 1:noBS
    plot3([trajIPSO.xBS(b), trajIPSO.xBS(b)], ...
          [trajIPSO.yBS(b), trajIPSO.yBS(b)], ...
          [0, trajIPSO.zBS(b)], ...
          '-', 'Color', colorIPSO, 'LineWidth', 1.5);
end

% Start / End UAV
hStart = plot3(xUAV_S, yUAV_S, zUAV_S, 'ko', 'LineWidth', 2, 'MarkerSize', 8);
hEnd = plot3(xUAV_E, yUAV_E, zUAV_E, 'ks', 'LineWidth', 2, 'MarkerSize', 8);

% Trajectories
hBaseline = plot3(resBase.xTraj, resBase.yTraj, resBase.zTraj, '--o', ...
    'Color', colorBaseline, 'LineWidth', 1.3, 'MarkerSize', 4);

% hJoint = plot3(trajJoint.xTraj, trajJoint.yTraj, trajJoint.zTraj, '-o', ...
%     'Color', colorJoint, 'LineWidth', 1.5, 'MarkerSize', 5);

hFull = plot3(trajFull.xTraj, trajFull.yTraj, trajFull.zTraj, '-^', ...
    'Color', colorFull, 'LineWidth', 1.8, 'MarkerSize', 5);

hIPSO = plot3(trajIPSO.xTraj, trajIPSO.yTraj, trajIPSO.zTraj, '-d', ...
    'Color', colorIPSO, 'LineWidth', 2.0, 'MarkerSize', 6);

grid on;
xlabel('x / Width (m)'); ylabel('y / Length (m)'); zlabel('z / Height (m)');
title('Trajectory: Baseline vs Full PSO vs Full IPSO');

legend([hUser, hInitBS, hOptBS_PSO, hOptBS_IPSO, hStart, hEnd, hBaseline, hFull, hIPSO], ...
    {'Ground Users', 'Initial BS', 'Opt BS (PSO)', 'Opt BS (IPSO)', 'UAV Start', 'UAV End', ...
     'Baseline', 'Full Joint (PSO)', 'Full Joint (IPSO)'}, ...
     'Location', 'best');

xlim([0 enWidth]); ylim([0 enLength]); zlim([0 enHeight]); view(3);

%% FIGURE 2: MinRate comparison 
figure(2); clf; hold on;

plot(stepAxis, resBase.stepMin, '--o', ...
    'Color', colorBaseline, ...
    'LineWidth', 1.3, ...
    'MarkerSize', 4);

% plot(stepAxis, trajJoint.stepMin, '-s', 'Color', colorJoint, 'LineWidth', 1.5, 'MarkerSize', 5);

plot(stepAxis, trajFull.stepMin, '-^', ...
    'Color', colorFull, ...
    'LineWidth', 1.8, ...
    'MarkerSize', 5);

plot(stepAxis, trajIPSO.stepMin, '-d', ...
    'Color', colorIPSO, ...
    'LineWidth', 2.0, ...
    'MarkerSize', 6);

grid on;
xlabel('Mission step');
ylabel('Minimum achievable rate among users (bps)');
title('MinRate: Baseline vs Full PSO vs Full IPSO');

legend('Baseline', 'Full Joint (PSO)', 'Full Joint (IPSO)', 'Location', 'best');

xlim([1 numSteps]);
xticks(1:numSteps);

%% FIGURE 3: Per-user achievable rate - Joint no-BS vs Full PSO
% figure(3); clf; hold on;
% 
% userColors = lines(noUsers);
% h = gobjects(2 * noUsers, 1);
% leg = cell(2 * noUsers, 1);
% 
% for u = 1:noUsers
%     h(u) = plot(stepAxis, trajJoint.achRate(:,u), '--o', ...
%         'Color', userColors(u,:), ...
%         'LineWidth', 1.3, ...
%         'MarkerSize', 4);
% 
%     leg{u} = sprintf('User %d - Joint SWIPT', u);
% end
% 
% for u = 1:noUsers
%     h(noUsers + u) = plot(stepAxis, trajFull.achRate(:,u), '-s', ...
%         'Color', userColors(u,:), ...
%         'LineWidth', 1.8, ...
%         'MarkerSize', 5);
% 
%     leg{noUsers + u} = sprintf('User %d - Full Joint SWIPT+BS (PSO)', u);
% end
% 
% grid on;
% xlabel('Mission step');
% ylabel('Achievable rate (bps)');
% title(sprintf('Per-user achievable rate: Joint SWIPT vs Full Joint SWIPT+BS (PSO), N = %d', noUsers));
% legend(h, leg, 'Location', 'best');
% xlim([1 numSteps]);
% xticks(1:numSteps);

%% FIGURE 4: Per-user achievable rate - Full PSO vs Full IPSO
figure(4); clf; hold on;

userColors = lines(noUsers);
h = gobjects(2 * noUsers, 1);
leg = cell(2 * noUsers, 1);

for u = 1:noUsers
    h(u) = plot(stepAxis, trajFull.achRate(:,u), '--o', ...
        'Color', userColors(u,:), ...
        'LineWidth', 1.3, ...
        'MarkerSize', 4);

    leg{u} = sprintf('User %d - Full PSO', u);
end

for u = 1:noUsers
    h(noUsers + u) = plot(stepAxis, trajIPSO.achRate(:,u), '-s', ...
        'Color', userColors(u,:), ...
        'LineWidth', 1.8, ...
        'MarkerSize', 5);

    leg{noUsers + u} = sprintf('User %d - Full IPSO', u);
end

grid on;
xlabel('Mission step');
ylabel('Achievable rate (bps)');
title(sprintf('Per-user achievable rate: Full PSO Joint SWIPT vs Full IPSO Joint SWIPT, N = %d', noUsers));
legend(h, leg, 'Location', 'best');
xlim([1 numSteps]);
xticks(1:numSteps);

%% FIGURE 5: UAV transmit power comparison 
% ptJoint_dBm = 10 * log10(trajJoint.pt / 1e-3);
ptFull_dBm  = 10 * log10(trajFull.pt / 1e-3);
ptIPSO_dBm  = 10 * log10(trajIPSO.pt / 1e-3);

figure(5); clf; hold on;
%plot(stepAxis, ptJoint_dBm, '-s', 'Color', colorJoint, 'LineWidth', 1.5, 'MarkerSize', 5);
plot(stepAxis, ptFull_dBm, '-^', 'Color', colorFull, 'LineWidth', 1.8, 'MarkerSize', 5);
plot(stepAxis, ptIPSO_dBm, '-d', 'Color', colorIPSO, 'LineWidth', 2.0, 'MarkerSize', 6);

grid on;
xlabel('Mission step'); ylabel('UAV transmit power (dBm)');
title('UAV Transmit Power: Full PSO vs Full IPSO');
legend('Full Joint (PSO)', 'Full Joint (IPSO)', 'Location', 'best');
xlim([1 numSteps]); xticks(1:numSteps);

%% FIGURE 6: Convergence comparison
figure(6); clf; hold on;

%plot(0:optsJoint.maxIter, trajJoint.bestHistory, '-s', 'Color', colorJoint, 'LineWidth', 1.2, 'MarkerSize', 4);
plot(0:optsFull.maxIter, trajFull.bestHistory, '-^', 'Color', colorFull, 'LineWidth', 1.3, 'MarkerSize', 4);
plot(0:optsIPSO.maxIter, trajIPSO.bestHistory, '-d', 'Color', colorIPSO, 'LineWidth', 1.5, 'MarkerSize', 4);

grid on;
xlabel('Iteration'); ylabel('Best fitness (bps)');
title('Convergence: Full PSO vs Full IPSO');
legend('Full Joint (PSO)', 'Full Joint (IPSO)', 'Location', 'best');
xlim([0 optsIPSO.maxIter]);

% Local helper: fairness metrics for per-user rate
function printFairnessMetric(name, rateFit)
    noUsersLocal = size(rateFit, 2);
    jainStep = (sum(rateFit, 2).^2) ./ (noUsersLocal * sum(rateFit.^2, 2) + eps);
    gapRelStep = (max(rateFit, [], 2) - min(rateFit, [], 2)) ./ (mean(rateFit, 2) + eps);

    fprintf('%-12s | Jain mean %.6f | rel gap mean %.6f | rel gap max %.6f\n', ...
        name, mean(jainStep), mean(gapRelStep), max(gapRelStep));
end
