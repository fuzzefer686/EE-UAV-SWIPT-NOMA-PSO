clc;
clear variables;
close all;

%% KHỞI TẠO MÔI TRƯỜNG VÀ THÔNG SỐ
enWidth  = 300;
enLength = 300;
enHeight = 60;

noUsers = 3;
noBS = 3;

% Điểm đầu / điểm cuối UAV
xUAV_S = 150; yUAV_S = enLength; zUAV_S = 30;
xUAV_E = 150; yUAV_E = 0;        zUAV_E = 30;

% Vị trí BS ban đầu
xBS = [300,   0, 300];
yBS = [300, 150,   0];
zBS = [ 20,  30,  25];

% Vị trí users 
rng(42); 
xUser = zeros(1, noUsers);
yUser = zeros(1, noUsers);
zUser = zeros(1, noUsers);
for i = 1:noUsers
    xUser(i) = randi([enWidth/4,  3*enWidth/4]);
    yUser(i) = randi([enLength/4, 3*enLength/4]);
    zUser(i) = 0;
end

% Chia step (Bay thẳng)
stepsVec = enLength:-15:0;
numSteps = numel(stepsVec);

% Đóng gói vào struct sim
sim = struct();
sim.numSteps = numSteps;
sim.stepsVec = stepsVec;
sim.xStart = xUAV_S; sim.zStart = zUAV_S;
sim.xEnd   = xUAV_E; sim.zEnd   = zUAV_E;

bsMargin = 50; % Giới hạn xê dịch của BS
sim.xBS_min = max(0, xBS - bsMargin);
sim.xBS_max = min(enWidth, xBS + bsMargin);
sim.yBS_min = max(0, yBS - bsMargin);
sim.yBS_max = min(enLength, yBS + bsMargin);

sim.fitnessStepMode = 'internal';
sim.noUsers = noUsers; sim.noBS = noBS;
sim.xUser = xUser; sim.yUser = yUser; sim.zUser = zUser;
sim.xBS = xBS; sim.yBS = yBS; sim.zBS = zBS;

% Thông số SWIPT và Kênh truyền
sim.pr = (10^-3) * db2pow(46); sim.phy = 0.9; sim.neta = 0.9; sim.Tslot = 1e-6;
sim.etaPath = 2.5; sim.b0 = db2pow(-30);
sim.A1 = db2pow(4); sim.A2 = (2/pi) * log(db2pow(12) / sim.A1);
sim.gLoS = 1;
sim.gNLoSUsers = sqrt(1/2) * (randn(1, noUsers) + 1i * randn(1, noUsers));
sim.gNLoSBS    = sqrt(1/2) * (randn(1, noBS)    + 1i * randn(1, noBS));
sim.bigPenalty = 1e12; sim.lambdaMean = 0.05;

% Tạo đường bay thẳng chuẩn (Base Trajectory)
sim.xBase = linspace(xUAV_S, xUAV_E, numSteps);
sim.zBase = linspace(zUAV_S, zUAV_E, numSteps);

%% BASELINE (Đường bay thẳng + BS cố định ban đầu)
fprintf('\n--- BASELINE (BS CỐ ĐỊNH) ---\n');
particleBaseBS = [sim.xBS, sim.yBS]; 
[fitBase, resBase] = evaluateBSOnly_BaselineSWIPT_clean(particleBaseBS, sim);

fprintf('Baseline Fitness        = %.4e\n', fitBase);
fprintf('Baseline Global MinRate = %.4e bps\n', min(resBase.stepMin));

%% TỐI ƯU BS THEO PHƯƠNG Y (Giữ nguyên X)
fprintf('\n--- TỐI ƯU BS (CHỈ PHƯƠNG Y) ---\n');
optsBS_Y = struct();
optsBS_Y.numParticles = 50;
optsBS_Y.maxIter = 150;
optsBS_Y.w = 0.7; optsBS_Y.c1 = 1.5; optsBS_Y.c2 = 1.5;
optsBS_Y.mode = 'yonly';

trajBS_Y = optimizeBSPosition_BaselineSWIPT_clean(sim, optsBS_Y);

%% TỐI ƯU BS THEO CẢ X VÀ Y
fprintf('\n--- TỐI ƯU BS (CẢ X VÀ Y) ---\n');
optsBS_XY = struct();
optsBS_XY.numParticles = 50;
optsBS_XY.maxIter = 150;
optsBS_XY.w = 0.7; optsBS_XY.c1 = 1.5; optsBS_XY.c2 = 1.5;
optsBS_XY.mode = 'xy';

trajBS_XY = optimizeBSPosition_BaselineSWIPT_clean(sim, optsBS_XY);

%% VẼ BIỂU ĐỒ 
colorBase = [0.0000 0.4470 0.7410]; % Xanh dương
colorY    = [0.8500 0.3250 0.0980]; % Cam
colorXY   = [0.4660 0.6740 0.1880]; % Xanh lá

% Biểu đồ 1: Không gian 3D bố trí BS và UAV
figure(1); clf; hold on;

% Users
hUser = plot3(xUser, yUser, zUser, 'k*', 'LineWidth', 2, 'MarkerSize', 8);
for u = 1:noUsers
    text(xUser(u)+3, yUser(u)+3, zUser(u)+3, ['GU', num2str(u)]);
end

% Initial BS
hInitBS = plot3(sim.xBS, sim.yBS, sim.zBS, 'k^', 'LineWidth', 2, 'MarkerSize', 9);

% BS Y-only
hOptBS_Y = plot3(trajBS_Y.xBS, trajBS_Y.yBS, trajBS_Y.zBS, 's', ...
    'Color', colorY, 'MarkerFaceColor', colorY, 'LineWidth', 2, 'MarkerSize', 10);
    
% BS XY
hOptBS_XY = plot3(trajBS_XY.xBS, trajBS_XY.yBS, trajBS_XY.zBS, 'p', ...
    'Color', colorXY, 'MarkerFaceColor', colorXY, 'LineWidth', 2, 'MarkerSize', 12);

for b = 1:noBS
    % BS ban đầu (màu đen)
    plot3([sim.xBS(b) sim.xBS(b)], [sim.yBS(b) sim.yBS(b)], [0 sim.zBS(b)], 'k-', 'LineWidth', 1, 'HandleVisibility', 'off');
      
    % BS tối ưu Y-only (màu cam)
    plot3([trajBS_Y.xBS(b) trajBS_Y.xBS(b)], [trajBS_Y.yBS(b) trajBS_Y.yBS(b)], [0 trajBS_Y.zBS(b)], '-', 'Color', colorY, 'LineWidth', 1.2, 'HandleVisibility', 'off');
      
    % BS tối ưu X-Y (màu xanh lá)
    plot3([trajBS_XY.xBS(b) trajBS_XY.xBS(b)], [trajBS_XY.yBS(b) trajBS_XY.yBS(b)], [0 trajBS_XY.zBS(b)], '-', 'Color', colorXY, 'LineWidth', 1.2, 'HandleVisibility', 'off');
      
    % Đường nối di chuyển: Initial BS -> Opt BS Y-only
    plot3([sim.xBS(b) trajBS_Y.xBS(b)], [sim.yBS(b) trajBS_Y.yBS(b)], [sim.zBS(b) trajBS_Y.zBS(b)], '--', 'Color', colorY, 'LineWidth', 1.2, 'HandleVisibility', 'off');
      
    % Đường nối di chuyển: Initial BS -> Opt BS X-Y
    plot3([sim.xBS(b) trajBS_XY.xBS(b)], [sim.yBS(b) trajBS_XY.yBS(b)], [sim.zBS(b) trajBS_XY.zBS(b)], '--', 'Color', colorXY, 'LineWidth', 1.2, 'HandleVisibility', 'off');
      
    text(sim.xBS(b)+3, sim.yBS(b)+3, sim.zBS(b)+3, ['Init BS', num2str(b)]);
end
    
% Start / End UAV
hStart = plot3(xUAV_S, yUAV_S, zUAV_S, 'ko', 'LineWidth', 2, 'MarkerSize', 8);
hEnd = plot3(xUAV_E, yUAV_E, zUAV_E, 'ks', 'LineWidth', 2, 'MarkerSize', 8);

% Baseline Trajectory
hBaseline = plot3(sim.xBase, sim.stepsVec, sim.zBase, '--o', 'Color', colorBase, 'LineWidth', 1.3, 'MarkerSize', 4);

grid on;
xlabel('x / Width (m)');
ylabel('y / Length (m)');
zlabel('z / Height (m)');
title('BS Deployment & UAV Trajectory');

legend([hUser, hInitBS, hOptBS_Y, hOptBS_XY, hStart, hEnd, hBaseline], ...
    {'Ground Users', 'Initial BS', 'Optimized BS (Y-only)', 'Optimized BS (X-Y)', ...
     'UAV Start', 'UAV End', 'UAV Straight Trajectory'}, ...
     'Location', 'best');

xlim([0 enWidth]); ylim([0 enLength]); zlim([0 enHeight]);
view(3);

% Biểu đồ 2: Min Rate
figure(2); clf; hold on;
stepAxis = 1:numSteps;

plot(stepAxis, resBase.stepMin, '--o', 'Color', colorBase, 'LineWidth', 1.3, 'MarkerSize', 5);
plot(stepAxis, trajBS_Y.stepMin, '-s', 'Color', colorY, 'LineWidth', 1.5, 'MarkerSize', 5);
plot(stepAxis, trajBS_XY.stepMin, '-^', 'Color', colorXY, 'LineWidth', 1.8, 'MarkerSize', 5);

grid on;
xlabel('Mission step');
ylabel('Minimum achievable rate among users (bps)');
title('MinRate: Baseline vs Y-only vs X-Y');
legend('Baseline', 'Optimized BS (Y-only)', 'Optimized BS (X-Y)', 'Location', 'best');

xlim([1 numSteps]);
xticks(1:numSteps);

% Biểu đồ 3: PSO Convergence
figure(3); clf; hold on;

plot(0:optsBS_Y.maxIter, trajBS_Y.bestHistory, '-s', 'Color', colorY, 'LineWidth', 1.2, 'MarkerSize', 4);
plot(0:optsBS_XY.maxIter, trajBS_XY.bestHistory, '-^', 'Color', colorXY, 'LineWidth', 1.3, 'MarkerSize', 4);

grid on;
xlabel('PSO iteration');
ylabel('Best fitness (bps)');
title('Convergence: BS Optimization');
legend('Optimized BS (Y-only)', 'Optimized BS (X-Y)', 'Location', 'best');

xlim([0 optsBS_XY.maxIter]);