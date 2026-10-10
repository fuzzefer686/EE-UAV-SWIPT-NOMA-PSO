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

%% Chia step cho UAV
% UAV di theo truc y tu 300 ve 0, moi step giam 15m
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

%% Dong goi tat ca vao struct sim
sim = struct();

sim.numSteps = numSteps;
sim.stepsVec = stepsVec;

sim.xStart = xUAV_S;
sim.zStart = zUAV_S;
sim.xEnd   = xUAV_E;
sim.zEnd   = zUAV_E;

% Bien khong gian bay
sim.x_min = 75;
sim.x_max = 225;
sim.z_min = 15;
sim.z_max = 45;

% Moi step x khong duoc nhay qua xa
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

%% Tao duong bay thang baseline 
xBase = linspace(xUAV_S, xUAV_E, numSteps);
zBase = linspace(zUAV_S, zUAV_E, numSteps);

particleBase = [xBase(2:end-1), zBase(2:end-1)];

[fitBase, resBase] = evaluateTrajectory_SWIPT_clean(particleBase, sim);

%% Chay PSO-SWIPT toan quy dao
optsPSO = struct();

optsPSO.numParticles = 60;
optsPSO.maxIter = 500;

optsPSO.w = 0.7;
optsPSO.c1 = 1.5;
optsPSO.c2 = 1.5;

fprintf('\nGLOBAL PSO-SWIPT\n');

trajPSO = optimizeTrajectory_PSO_SWIPT_clean(sim, optsPSO);
%% Chay FA-SWIPT-FAST toan quy dao (khong Joint)nh
optsFA.numParticles = 100;
optsFA.maxIter = 200;
optsFA.alpha = 0.01;
% optsFA.alphaDamp = 0.99;
optsFA.beta0 = 0.8;
optsFA.gamma = 1.0;
% optsFA.eliteKeep = 4;
optsFA.topKAttractors = 6;
% optsFA.zRandomScale = 0.15;
% optsFA.zInitScale = 0.40;
% optsFA.lowAltitudeBias = 0.05;
% optsFA.greedyAccept = true;
optsFA.useSmoothRepair = false;
fprintf('\nGLOBAL FA-SWIPT\n');
trajFA = optimizeTrajectory_FA_SWIPT_fast(sim, optsFA);

%% Chay Joint PSO-SWIPT toan quy dao
optsJoint = struct();

optsJoint.numParticles = 80;
optsJoint.maxIter = 600;

optsJoint.w = 0.7;
optsJoint.c1 = 1.5;
optsJoint.c2 = 1.5;

fprintf('\nGLOBAL JOINT PSO-SWIPT\n');

trajJoint = optimizeTrajectory_JointPSO_SWIPT_clean(sim, optsJoint);
%% Lay ket qua PSO
up_xUAV_PSO = trajPSO.xTraj;
up_yUAV_PSO = trajPSO.yTraj;
up_zUAV_PSO = trajPSO.zTraj;

achRate_PSO = trajPSO.achRate;
minRate_PSO = trajPSO.stepMin;
EH_PSO = trajPSO.EH;
pt_PSO = trajPSO.pt;
%% Lay ket qua FA
up_xUAV_FA = trajFA.xTraj;
up_yUAV_FA = trajFA.yTraj;
up_zUAV_FA = trajFA.zTraj;

achRate_FA = trajFA.achRate;
minRate_FA = trajFA.stepMin;
EH_FA = trajFA.EH;
pt_FA = trajFA.pt;
%% Lay ket qua Joint
up_xUAV_Joint = trajJoint.xTraj;
up_yUAV_Joint = trajJoint.yTraj;
up_zUAV_Joint = trajJoint.zTraj;

achRate_Joint = trajJoint.achRate;
minRate_Joint = trajJoint.stepMin;
EH_Joint = trajJoint.EH;
pt_Joint = trajJoint.pt;
alpha_Joint = trajJoint.alphaTrace;
alphaOrd_Joint = trajJoint.alphaOrdTrace;

%test
%% Smooth test for Joint trajectory
xSmooth = movmean(trajJoint.xTraj, 3);
zSmooth = movmean(trajJoint.zTraj, 3);

% Giữ start/end cố định
xSmooth(1) = sim.xStart;
xSmooth(end) = sim.xEnd;
zSmooth(1) = sim.zStart;
zSmooth(end) = sim.zEnd;

% Tạo particle smooth bằng cách giữ alpha Joint cũ
T = sim.numSteps;
nInternal = T - 2;
rawP = trajJoint.alphaTrace;  % [T x noUsers]

particleSmoothJoint = [ ...
    xSmooth(2:end-1), ...
    zSmooth(2:end-1), ...
    reshape(rawP.', 1, []) ...
];

[fitSmoothJoint, resSmoothJoint] = evaluateTrajectory_JointSWIPT_clean( ...
    particleSmoothJoint, sim);

fprintf('\n===== JOINT SMOOTH TEST =====\n');
fprintf('Original Joint fitness       = %.4e\n', trajJoint.bestFitness);
fprintf('Smoothed Joint fitness       = %.4e\n', fitSmoothJoint);
fprintf('Original Joint minInternal   = %.4e\n', trajJoint.minInternal);
fprintf('Smoothed Joint minInternal   = %.4e\n', resSmoothJoint.minInternal);
fprintf('Original Joint meanInternal  = %.4e\n', trajJoint.meanInternal);
fprintf('Smoothed Joint meanInternal  = %.4e\n', resSmoothJoint.meanInternal);
fprintf('Original roughNorm           = %.4f\n', trajJoint.roughNorm);
fprintf('Smoothed roughNorm           = %.4f\n', resSmoothJoint.roughNorm);
%-----
%% baseline va PSO
fprintf('\n========== BASELINE STRAIGHT TRAJECTORY ==========\n');
fprintf('Feasible baseline      = %d\n', resBase.isFeasible);
fprintf('Baseline penalty       = %.4e\n', resBase.penalty);
fprintf('Baseline fitness       = %.4e bps\n', fitBase);
fprintf('Baseline global minRate= %.4e bps\n', min(resBase.stepMin));
fprintf('Baseline mean minRate  = %.4e bps\n', mean(resBase.stepMin));
fprintf('Baseline mean pt       = %.4e W\n', mean(resBase.pt));
fprintf('Baseline mean pt       = %.4f dBm\n', 10*log10(mean(resBase.pt)/1e-3));

fprintf('\n========== PSO-SWIPT GLOBAL TRAJECTORY ==========\n');
fprintf('Feasible PSO           = %d\n', trajPSO.isFeasible);
fprintf('PSO penalty            = %.4e\n', trajPSO.penalty);
fprintf('PSO best fitness       = %.4e bps\n', trajPSO.bestFitness);
fprintf('PSO global minRate     = %.4e bps\n', min(minRate_PSO));
fprintf('PSO mean minRate       = %.4e bps\n', mean(minRate_PSO));
fprintf('PSO mean pt            = %.4e W\n', mean(pt_PSO));
fprintf('PSO mean pt            = %.4f dBm\n', 10*log10(mean(pt_PSO)/1e-3));

fprintf('\n========== FA-SWIPT-FAST GLOBAL TRAJECTORY ==========\n');
fprintf('Feasible FA            = %d\n', trajFA.isFeasible);
fprintf('FA penalty             = %.4e\n', trajFA.penalty);
fprintf('FA best fitness        = %.4e bps\n', trajFA.bestFitness);
fprintf('FA global minRate      = %.4e bps\n', min(minRate_FA));
fprintf('FA mean minRate        = %.4e bps\n', mean(minRate_FA));
fprintf('FA mean pt             = %.4e W\n', mean(pt_FA));
fprintf('FA mean pt             = %.4f dBm\n', 10*log10(mean(pt_FA)/1e-3));

fprintf('\n========== IMPROVEMENT ==========\n');
fprintf('Global minRate gain    = %.4e bps\n', min(minRate_PSO) - min(resBase.stepMin));
fprintf('Mean minRate gain      = %.4e bps\n', mean(minRate_PSO) - mean(resBase.stepMin));
fprintf('Global minRate gain FA = %.4e bps\n', min(minRate_FA) - min(resBase.stepMin));
fprintf('Mean minRate gain FA   = %.4e bps\n', mean(minRate_FA) - mean(resBase.stepMin));

disp('User positions [xUser; yUser; zUser]:');
disp([xUser; yUser; zUser]);

disp('BS positions [xBS; yBS; zBS]:');
disp([xBS; yBS; zBS]);

disp('First 5 rows of PSO achievable rate:');
disp(achRate_PSO(1:min(5,numSteps), :));

disp('First 5 rows of PSO alphaTrace:');
disp(trajPSO.alphaTrace(1:min(5,numSteps), :));

fprintf('\n========== JOINT PSO-SWIPT GLOBAL TRAJECTORY ==========\n');
fprintf('Feasible Joint          = %d\n', trajJoint.isFeasible);
fprintf('Joint penalty           = %.4e\n', trajJoint.penalty);
fprintf('Joint best fitness      = %.4e bps\n', trajJoint.bestFitness);
fprintf('Joint global minRate    = %.4e bps\n', min(minRate_Joint));
fprintf('Joint mean minRate      = %.4e bps\n', mean(minRate_Joint));
fprintf('Joint mean pt           = %.4e W\n', mean(pt_Joint));
fprintf('Joint mean pt           = %.4f dBm\n', 10*log10(mean(pt_Joint)/1e-3));
fprintf('Joint roughNorm         = %.4f\n', trajJoint.roughNorm);
fprintf('Joint alpha repair mode = %s\n', trajJoint.jointAlphaRepair);

fprintf('\n========== JOINT VS PSO ==========\n');
fprintf('Global minRate gain Joint-PSO = %.4e bps\n', ...
    min(minRate_Joint) - min(minRate_PSO));
fprintf('Mean minRate gain Joint-PSO   = %.4e bps\n', ...
    mean(minRate_Joint) - mean(minRate_PSO));
fprintf('Best fitness gain Joint-PSO   = %.4e bps\n', ...
    trajJoint.bestFitness - trajPSO.bestFitness);
fprintf('Global minRate gain FA-PSO    = %.4e bps\n', ...
    min(minRate_FA) - min(minRate_PSO));
fprintf('Mean minRate gain FA-PSO      = %.4e bps\n', ...
    mean(minRate_FA) - mean(minRate_PSO));

disp('First 5 rows of Joint achievable rate:');
disp(achRate_Joint(1:min(5,numSteps), :));

disp('First 5 rows of Joint alphaTrace by original user index:');
disp(alpha_Joint(1:min(5,numSteps), :));

disp('First 5 rows of Joint alphaOrdTrace weak -> strong:');
disp(alphaOrd_Joint(1:min(5,numSteps), :));
%% Ve trajectory 3D: baseline vs PSO
figure;
plot3(xUser, yUser, zUser, 'k*', 'LineWidth', 2, 'MarkerSize', 8); hold on;
for u = 1:noUsers
    text(xUser(u)+3, yUser(u)+3, zUser(u)+3, ['GU', num2str(u)]);
end

plot3(xBS, yBS, zBS, 'k^', 'LineWidth', 2, 'MarkerSize', 8);
for b = 1:noBS
    plot3([xBS(b) xBS(b)], [yBS(b) yBS(b)], [0 zBS(b)], 'k-', 'LineWidth', 1);
    text(xBS(b)+3, yBS(b)+3, zBS(b)+3, ['BS', num2str(b)]);
end

plot3(resBase.xTraj, resBase.yTraj, resBase.zTraj, 'b--o', ...
    'LineWidth', 1.2, 'MarkerSize', 4);

plot3(up_xUAV_PSO, up_yUAV_PSO, up_zUAV_PSO, 'r-o', ...
    'LineWidth', 1.6, 'MarkerSize', 5);

plot3(xUAV_S, yUAV_S, zUAV_S, 'go', 'LineWidth', 2, 'MarkerSize', 9);
plot3(xUAV_E, yUAV_E, zUAV_E, 'ro', 'LineWidth', 2, 'MarkerSize', 9);

grid on;
xlabel('x / Width (m)');
ylabel('y / Length (m)');
zlabel('z / Height (m)');
title('Step 2 - Straight trajectory vs Global PSO-SWIPT trajectory');
legend('Ground Users', 'Base Stations', 'BS height', ...
       'Straight baseline', 'Global PSO-SWIPT', ...
       'UAV Start', 'UAV End', 'Location', 'best');

xlim([0 enWidth]);
ylim([0 enLength]);
zlim([0 enHeight]);

%% Ve minRate theo step
figure;
plot(1:numSteps, resBase.stepMin, 'b--o', 'LineWidth', 1.4, 'MarkerSize', 5); hold on;
plot(1:numSteps, minRate_PSO, 'r-o', 'LineWidth', 1.6, 'MarkerSize', 5);
grid on;
xlabel('Mission step');
ylabel('Minimum achievable rate among users (bps)');
title('Step 2 - MinRate: Straight baseline vs Global PSO-SWIPT');
legend('Straight baseline', 'Global PSO-SWIPT', 'Location', 'best');

%% Ve achievable rate tung user cua PSO
figure;
plot(1:numSteps, achRate_PSO(:,1), 'r-o', 'LineWidth', 1.5); hold on;
plot(1:numSteps, achRate_PSO(:,2), 'g-s', 'LineWidth', 1.5);
plot(1:numSteps, achRate_PSO(:,3), 'b-^', 'LineWidth', 1.5);
grid on;
xlabel('Mission step');
ylabel('Achievable rate (bps)');
title('Step 2 - Per-user achievable rate of Global PSO-SWIPT');
legend('User 1 - PSO', 'User 2 - PSO', 'User 3 - PSO', 'Location', 'best');

%% Ve achievable rate baseline vs PSO cho tung user
figure;
plot(1:numSteps, resBase.achRate(:,1), 'r--o', 'LineWidth', 1.2); hold on;
plot(1:numSteps, resBase.achRate(:,2), 'g--s', 'LineWidth', 1.2);
plot(1:numSteps, resBase.achRate(:,3), 'b--^', 'LineWidth', 1.2);

plot(1:numSteps, achRate_PSO(:,1), 'r-o', 'LineWidth', 1.6);
plot(1:numSteps, achRate_PSO(:,2), 'g-s', 'LineWidth', 1.6);
plot(1:numSteps, achRate_PSO(:,3), 'b-^', 'LineWidth', 1.6);

grid on;
xlabel('Mission step');
ylabel('Achievable rate (bps)');
title('Step 2 - Per-user rate: baseline vs Global PSO-SWIPT');
legend( ...
    'User 1 - baseline', ...
    'User 2 - baseline', ...
    'User 3 - baseline', ...
    'User 1 - PSO', ...
    'User 2 - PSO', ...
    'User 3 - PSO', ...
    'Location', 'best');

%% Ve transmit power UAV theo dBm
ptBase_dBm = 10 * log10(resBase.pt / 1e-3);
ptPSO_dBm  = 10 * log10(pt_PSO / 1e-3);

figure;
plot(1:numSteps, ptBase_dBm, 'b--o', 'LineWidth', 1.4, 'MarkerSize', 5); hold on;
plot(1:numSteps, ptPSO_dBm, 'r-o', 'LineWidth', 1.6, 'MarkerSize', 5);
grid on;
xlabel('Mission step');
ylabel('UAV transmit power from harvested energy (dBm)');
title('Step 2 - UAV transmit power: baseline vs Global PSO-SWIPT');
legend('Straight baseline', 'Global PSO-SWIPT', 'Location', 'best');

%% Ve duong hoi tu PSO
figure;
plot(0:optsPSO.maxIter, trajPSO.bestHistory, 'k-o', ...
    'LineWidth', 1.5, 'MarkerSize', 4);
grid on;
xlabel('PSO iteration');
ylabel('Best fitness (bps)');
title('Step 2 - PSO convergence history');


%% Trajectory baseline vs PSO vs Joint
%% Trajectory baseline vs PSO vs FA vs Joint
figure;
hold on;

% Plot users, BS, BS height lines, 3 optimized trajectories, start/end.
% Use explicit handles so the legend is correct even when noUsers/noBS > 1.

hGU = plot3(xUser, yUser, zUser, 'k*', ...
    'LineWidth', 2, 'MarkerSize', 8, ...
    'DisplayName', 'Ground Users');

for u = 1:noUsers
    text(xUser(u)+3, yUser(u)+3, zUser(u)+3, ['GU', num2str(u)], ...
        'HandleVisibility', 'off');
end

hBS = plot3(xBS, yBS, zBS, 'k^', ...
    'LineWidth', 2, 'MarkerSize', 8, ...
    'DisplayName', 'Base Stations');

hBSHeight = gobjects(1,1);

for b = 1:noBS
    if b == 1
        hBSHeight = plot3([xBS(b) xBS(b)], ...
                          [yBS(b) yBS(b)], ...
                          [0 zBS(b)], ...
                          'k-', ...
                          'LineWidth', 1, ...
                          'DisplayName', 'BS height');
    else
        plot3([xBS(b) xBS(b)], ...
              [yBS(b) yBS(b)], ...
              [0 zBS(b)], ...
              'k-', ...
              'LineWidth', 1, ...
              'HandleVisibility', 'off');
    end

    text(xBS(b)+3, yBS(b)+3, zBS(b)+3, ['BS', num2str(b)], ...
        'HandleVisibility', 'off');
end

hBase = plot3(resBase.xTraj, resBase.yTraj, resBase.zTraj, ...
    'b--o', ...
    'LineWidth', 1.2, 'MarkerSize', 4, ...
    'DisplayName', 'Straight baseline');

hPSO = plot3(up_xUAV_PSO, up_yUAV_PSO, up_zUAV_PSO, ...
    'r-o', ...
    'LineWidth', 1.5, 'MarkerSize', 5, ...
    'DisplayName', 'PSO-SWIPT');

hFA = plot3(up_xUAV_FA, up_yUAV_FA, up_zUAV_FA, ...
    'c-o', ...
    'LineWidth', 1.5, 'MarkerSize', 5, ...
    'DisplayName', 'FA-SWIPT-FAST');

hJoint = plot3(up_xUAV_Joint, up_yUAV_Joint, up_zUAV_Joint, ...
    'm-o', ...
    'LineWidth', 1.7, 'MarkerSize', 5, ...
    'DisplayName', 'Joint PSO-SWIPT');

hStart = plot3(xUAV_S, yUAV_S, zUAV_S, ...
    'go', ...
    'LineWidth', 2, 'MarkerSize', 9, ...
    'DisplayName', 'UAV Start');

hEnd = plot3(xUAV_E, yUAV_E, zUAV_E, ...
    'ro', ...
    'LineWidth', 2, 'MarkerSize', 9, ...
    'DisplayName', 'UAV End');

grid on;
xlabel('x / Width (m)');
ylabel('y / Length (m)');
zlabel('z / Height (m)');

title('Step 3 - Trajectory: baseline vs PSO-SWIPT vs FA-SWIPT-FAST vs Joint PSO-SWIPT');

legend([hGU, hBS, hBSHeight, hBase, hPSO, hFA, hJoint, hStart, hEnd], ...
    {'Ground Users', ...
     'Base Stations', ...
     'BS height', ...
     'Straight baseline', ...
     'PSO-SWIPT', ...
     'FA-SWIPT-FAST', ...
     'Joint PSO-SWIPT', ...
     'UAV Start', ...
     'UAV End'}, ...
    'Location', 'best');

xlim([0 enWidth]);
ylim([0 enLength]);
zlim([0 enHeight]);
view(3);
%% MinRate comparison
figure;
plot(1:numSteps, resBase.stepMin, 'b--o', 'LineWidth', 1.3, 'MarkerSize', 5); hold on;
plot(1:numSteps, minRate_PSO, 'r-o', 'LineWidth', 1.5, 'MarkerSize', 5);
plot(1:numSteps, minRate_FA, 'c-o', 'LineWidth', 1.5, 'MarkerSize', 5);
plot(1:numSteps, minRate_Joint, 'm-o', 'LineWidth', 1.7, 'MarkerSize', 5);

grid on;
xlabel('Mission step');
ylabel('Minimum achievable rate among users (bps)');
title('Step 3 - MinRate: baseline vs PSO-SWIPT vs FA-SWIPT-FAST vs Joint PSO-SWIPT');
legend('Sxtraight baseline', 'PSO-SWIPT', 'FA-SWIPT-FAST', 'Joint PSO-SWIPT', 'Location', 'best');

%% Per-user rate PSO vs Joint
if exist('plotUserRateComparison6', 'file') == 2
    plotUserRateComparison6(1:numSteps, achRate_PSO, achRate_Joint);
else
    warning('plotUserRateComparison6 not found. Using inline comparison plot.');
    figure;
    for u = 1:noUsers
        plot(1:numSteps, achRate_PSO(:,u), '--', 'LineWidth', 1.2); hold on;
        plot(1:numSteps, achRate_Joint(:,u), '-', 'LineWidth', 1.5);
    end
    grid on;
    xlabel('Mission step');
    ylabel('Achievable rate (bps)');
    title('Per-user achievable rate: PSO-SWIPT vs Joint PSO-SWIPT');
end

%% UAV transmit power comparison
ptBase_dBm  = 10 * log10(resBase.pt / 1e-3);
ptPSO_dBm   = 10 * log10(pt_PSO / 1e-3);
ptFA_dBm    = 10 * log10(pt_FA / 1e-3);
ptJoint_dBm = 10 * log10(pt_Joint / 1e-3);

figure;
plot(1:numSteps, ptBase_dBm, 'b--o', 'LineWidth', 1.3, 'MarkerSize', 5); hold on;
plot(1:numSteps, ptPSO_dBm, 'r-o', 'LineWidth', 1.5, 'MarkerSize', 5);
plot(1:numSteps, ptFA_dBm, 'c-o', 'LineWidth', 1.5, 'MarkerSize', 5);
plot(1:numSteps, ptJoint_dBm, 'm-o', 'LineWidth', 1.7, 'MarkerSize', 5);

grid on;
xlabel('Mission step');
ylabel('UAV transmit power from harvested energy (dBm)');
title('Step 3 - UAV transmit power: baseline vs PSO vs FA vs Joint');
legend('Straight baseline', 'PSO-SWIPT', 'FA-SWIPT-FAST', 'Joint PSO-SWIPT', 'Location', 'best');

%% Joint alpha by original user index
figure;
plot(1:numSteps, alpha_Joint(:,1), 'r-o', 'LineWidth', 1.5); hold on;
plot(1:numSteps, alpha_Joint(:,2), 'g-s', 'LineWidth', 1.5);
plot(1:numSteps, alpha_Joint(:,3), 'b-^', 'LineWidth', 1.5);

grid on;
xlabel('Mission step');
ylabel('Power coefficient alpha');
title('Step 3 - Joint optimized alpha by original user index');
legend('alpha User 1', 'alpha User 2', 'alpha User 3', 'Location', 'best');

%% PSO convergence comparison
figure;
plot(0:optsPSO.maxIter, trajPSO.bestHistory, 'r-o', ...
    'LineWidth', 1.3, 'MarkerSize', 4); hold on;

plot(0:optsFA.maxIter, trajFA.bestHistory, 'c-o', ...
    'LineWidth', 1.3, 'MarkerSize', 4);

plot(0:optsJoint.maxIter, trajJoint.bestHistory, 'm-o', ...
    'LineWidth', 1.3, 'MarkerSize', 4);

grid on;
xlabel('PSO iteration');
ylabel('Best fitness (bps)');
title('Step 3 - Convergence: PSO-SWIPT vs FA-SWIPT-FAST vs Joint PSO-SWIPT');
legend('PSO-SWIPT', 'FA-SWIPT-FAST', 'Joint PSO-SWIPT', 'Location', 'best');




%testfigure
figure;
plot3(trajJoint.xTraj, trajJoint.yTraj, trajJoint.zTraj, 'm-o', ...
    'LineWidth', 1.5); hold on;
plot3(resSmoothJoint.xTraj, resSmoothJoint.yTraj, resSmoothJoint.zTraj, 'c-o', ...
    'LineWidth', 1.5);

grid on;
xlabel('x');
ylabel('y');
zlabel('z');
title('Joint original vs smoothed test trajectory');
legend('Original Joint', 'Smoothed Joint', 'Location', 'best');


