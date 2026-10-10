clc;
clear variables;
close all;

%% Khoi tao moi truong
%rng(1);  

enWidth  = 300;
enLength = 300;
enHeight = 60;

noUsers = 3;
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
optsJoint.maxIter = 400;

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

%%  JOINT + BS OPTIMIZATION
optsFull = struct();

optsFull.numParticles = 120;
optsFull.maxIter = 450;

optsFull.w = 0.7;
optsFull.c1 = 1.5;
optsFull.c2 = 1.5;

% Seed: Joint trajectory/alpha cu + vi tri BS ban dau
optsFull.seedFullParticle = [trajJoint.bestParticle, sim.xBS, sim.yBS];

fprintf('\nFULL JOINT+BS PSO\n');

trajFull = optimizeTrajectory_JointBS_PSO_SWIPT_clean(sim, optsFull);

%% Baseline vs Joint vs Full Joint+BS
fprintf('\nFINAL RESULT\n');

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

%% FIGURE 1: Trajectory comparison
figure; clf; hold on;

colorBaseline = [0.0000 0.4470 0.7410];   % blue
colorJoint    = [0.8500 0.3250 0.0980];   % orange
colorFull     = [0.4660 0.6740 0.1880];   % green
colorOptBS    = [0.4940 0.1840 0.5560];   % purple

% Users
hUser = plot3(xUser, yUser, zUser, 'k*', ...
    'LineWidth', 2, 'MarkerSize', 8);

for u = 1:noUsers
    text(xUser(u)+3, yUser(u)+3, zUser(u)+3, ['GU', num2str(u)]);
end

% Initial BS
hInitBS = plot3(sim.xBS, sim.yBS, sim.zBS, 'k^', ...
    'LineWidth', 2, 'MarkerSize', 9);

% Optimized BS
hOptBS = plot3(trajFull.xBS, trajFull.yBS, trajFull.zBS, 'p', ...
    'Color', colorOptBS, ...
    'MarkerFaceColor', colorOptBS, ...
    'LineWidth', 2, 'MarkerSize', 12);

% BS vertical lines and movement lines: hide from legend
for b = 1:noBS
    plot3([sim.xBS(b) sim.xBS(b)], ...
          [sim.yBS(b) sim.yBS(b)], ...
          [0 sim.zBS(b)], ...
          'k-', 'LineWidth', 1, ...
          'HandleVisibility', 'off');

    plot3([trajFull.xBS(b) trajFull.xBS(b)], ...
          [trajFull.yBS(b) trajFull.yBS(b)], ...
          [0 trajFull.zBS(b)], ...
          '-', 'Color', colorOptBS, 'LineWidth', 1.2, ...
          'HandleVisibility', 'off');

    plot3([sim.xBS(b) trajFull.xBS(b)], ...
          [sim.yBS(b) trajFull.yBS(b)], ...
          [sim.zBS(b) trajFull.zBS(b)], ...
          '--', 'Color', colorOptBS, 'LineWidth', 1.2, ...
          'HandleVisibility', 'off');

    text(sim.xBS(b)+3, sim.yBS(b)+3, sim.zBS(b)+3, ...
        ['Initial BS', num2str(b)]);

    text(trajFull.xBS(b)+3, trajFull.yBS(b)+3, trajFull.zBS(b)+3, ...
        ['Optimized BS', num2str(b)]);
end

% Start / End UAV
hStart = plot3(xUAV_S, yUAV_S, zUAV_S, 'ko', ...
    'LineWidth', 2, 'MarkerSize', 8);

hEnd = plot3(xUAV_E, yUAV_E, zUAV_E, 'ks', ...
    'LineWidth', 2, 'MarkerSize', 8);

% Trajectories
hBaseline = plot3(resBase.xTraj, resBase.yTraj, resBase.zTraj, '--o', ...
    'Color', colorBaseline, ...
    'LineWidth', 1.3, 'MarkerSize', 4);

hJoint = plot3(trajJoint.xTraj, trajJoint.yTraj, trajJoint.zTraj, '-o', ...
    'Color', colorJoint, ...
    'LineWidth', 1.5, 'MarkerSize', 5);

hFull = plot3(trajFull.xTraj, trajFull.yTraj, trajFull.zTraj, '-o', ...
    'Color', colorFull, ...
    'LineWidth', 1.8, 'MarkerSize', 5);

grid on;
xlabel('x / Width (m)');
ylabel('y / Length (m)');
zlabel('z / Height (m)');
title('Trajectory: Baseline vs Joint SWIPT vs Full Joint SWIPT+BS');

legend([hUser, hInitBS, hOptBS, hStart, hEnd, hBaseline, hJoint, hFull], ...
    {'Ground Users', ...
     'Initial BS', ...
     'Optimized BS', ...
     'UAV Start', ...
     'UAV End', ...
     'Baseline trajectory', ...
     'Joint SWIPT', ...
     'Full Joint SWIPT+BS'}, ...
     'Location', 'best');

xlim([0 enWidth]);
ylim([0 enLength]);
zlim([0 enHeight]);
view(3);

stepAxis = 1:numSteps;
%% FIGURE 2: MinRate comparison
figure; clf;
plot(stepAxis, resBase.stepMin, '--o', ...
    'Color', colorBaseline, 'LineWidth', 1.3, 'MarkerSize', 5); hold on;

plot(stepAxis, trajJoint.stepMin, '-s', ...
    'Color', colorJoint, 'LineWidth', 1.5, 'MarkerSize', 5);

plot(stepAxis, trajFull.stepMin, '-^', ...
    'Color', colorFull, 'LineWidth', 1.8, 'MarkerSize', 5);

grid on;
xlabel('Mission step');
ylabel('Minimum achievable rate among users (bps)');
title('MinRate: Baseline vs Joint SWIPT vs Full Joint SWIPT+BS');
legend('Baseline', 'Joint SWIPT', 'Full Joint SWIPT+BS', 'Location', 'best');

xlim([1 numSteps]);
xticks(1:numSteps);

%% FIGURE 3: Per-user achievable rate, Joint vs Full
figure; clf;

plot(stepAxis, trajJoint.achRate(:,1), '--o', ...
    'Color', [0.0000 0.4470 0.7410], 'LineWidth', 1.2); hold on;
plot(stepAxis, trajJoint.achRate(:,2), '--s', ...
    'Color', [0.8500 0.3250 0.0980], 'LineWidth', 1.2);
plot(stepAxis, trajJoint.achRate(:,3), '--^', ...
    'Color', [0.4660 0.6740 0.1880], 'LineWidth', 1.2);

plot(stepAxis, trajFull.achRate(:,1), '-o', ...
    'Color', [0.0000 0.4470 0.7410], 'LineWidth', 1.6);
plot(stepAxis, trajFull.achRate(:,2), '-s', ...
    'Color', [0.8500 0.3250 0.0980], 'LineWidth', 1.6);
plot(stepAxis, trajFull.achRate(:,3), '-^', ...
    'Color', [0.4660 0.6740 0.1880], 'LineWidth', 1.6);

grid on;
xlabel('Mission step');
ylabel('Achievable rate (bps)');
title('Per-user achievable rate: Joint SWIPT vs Full Joint SWIPT+BS');

legend( ...
    'User 1 - Joint SWIPT', ...
    'User 2 - Joint SWIPT', ...
    'User 3 - Joint SWIPT', ...
    'User 1 - Full Joint SWIPT+BS', ...
    'User 2 - Full Joint SWIPT+BS', ...
    'User 3 - Full Joint SWIPT+BS', ...
    'Location', 'best');

xlim([1 numSteps]);
xticks(1:numSteps);

%% FIGURE 4: UAV transmit power comparison
ptBase_dBm  = 10 * log10(resBase.pt / 1e-3);
ptJoint_dBm = 10 * log10(trajJoint.pt / 1e-3);
ptFull_dBm  = 10 * log10(trajFull.pt / 1e-3);

figure; clf;
plot(stepAxis, ptBase_dBm, '--o', ...
    'Color', colorBaseline, 'LineWidth', 1.3, 'MarkerSize', 5); hold on;

plot(stepAxis, ptJoint_dBm, '-s', ...
    'Color', colorJoint, 'LineWidth', 1.5, 'MarkerSize', 5);

plot(stepAxis, ptFull_dBm, '-^', ...
    'Color', colorFull, 'LineWidth', 1.8, 'MarkerSize', 5);

grid on;
xlabel('Mission step');
ylabel('UAV transmit power from harvested energy (dBm)');
title('UAV transmit power: Baseline vs Joint SWIPT vs Full Joint SWIPT+BS');
legend('Baseline', 'Joint SWIPT', 'Full Joint SWIPT+BS', 'Location', 'best');

xlim([1 numSteps]);
xticks(1:numSteps);
%% FIGURE 5: Convergence comparison
figure; clf;

plot(0:optsJoint.maxIter, trajJoint.bestHistory, '-s', ...
    'Color', colorJoint, 'LineWidth', 1.2, 'MarkerSize', 4); hold on;

plot(0:optsFull.maxIter, trajFull.bestHistory, '-^', ...
    'Color', colorFull, 'LineWidth', 1.3, 'MarkerSize', 4);

grid on;
xlabel('PSO iteration');
ylabel('Best fitness (bps)');
title('Convergence: Joint SWIPT vs Full Joint SWIPT+BS');
legend('Joint SWIPT', 'Full Joint SWIPT+BS', 'Location', 'best');

xlim([0 optsFull.maxIter]);