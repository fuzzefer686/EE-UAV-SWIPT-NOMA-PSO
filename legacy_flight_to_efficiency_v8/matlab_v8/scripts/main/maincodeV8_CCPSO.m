clc;
close all;

%% ============================================================
%  MAIN SCRIPT: V8-SNAPSHOT-CCPSO
%  Phát triển mở rộng từ V8: Tích hợp Cooperative Co-evolutionary JointPSO (CC-JointPSO)
%  Đồng tối ưu: Quỹ đạo UAV (38D) + Vị trí trạm BS (6D) + Công suất NOMA alpha (105D)
% ============================================================

%% 1. Khởi tạo môi trường và Random Seed
if ~exist('useFixedSeed', 'var')
    useFixedSeed = true;
end
if ~exist('mainSeed', 'var')
    mainSeed = 2026;
end

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

%% 2. Điểm đầu / điểm cuối UAV
xUAV_S = 150;
yUAV_S = enLength;
zUAV_S = 30;

xUAV_E = 150;
yUAV_E = 0;
zUAV_E = 30;

%% 3. Vị trí BS ban đầu
xBS = [300,   0, 300];
yBS = [300, 150,   0];
zBS = [ 20,  30,  25];

%% 4. Vị trí Users (Ngẫu nhiên theo mainSeed)
xUser = zeros(1, noUsers);
yUser = zeros(1, noUsers);
zUser = zeros(1, noUsers);

for i = 1:noUsers
    xUser(i) = randi([enWidth/4,  3*enWidth/4]);
    yUser(i) = randi([enLength/4, 3*enLength/4]);
    zUser(i) = 0;
end

fprintf('\n================ SCENARIO INFO (V8-SNAPSHOT-CCPSO) ================\n');
fprintf('mainSeed = %d | noUsers = %d | noBS = %d\n', mainSeed, noUsers, noBS);
fprintf('xUser = '); disp(xUser);
fprintf('yUser = '); disp(yUser);

%% 5. Chia steps
stepsVec = enLength:-15:0;
numSteps = numel(stepsVec);

%% 6. Thông số SWIPT & Kênh truyền
Pr = 46;                         % dBm
pr = (10^-3) * db2pow(Pr);       % W

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

%% 7. Đóng gói vào struct sim
sim = struct();
sim.numSteps = numSteps;
sim.stepsVec = stepsVec;
sim.xStart = xUAV_S; sim.zStart = zUAV_S;
sim.xEnd   = xUAV_E; sim.zEnd   = zUAV_E;

bsMargin = 50;
sim.xBS_min = max(0, xBS - bsMargin);
sim.xBS_max = min(enWidth, xBS + bsMargin);
sim.yBS_min = max(0, yBS - bsMargin);
sim.yBS_max = min(enLength, yBS + bsMargin);

sim.fitnessStepMode = 'internal';
sim.x_min = 75;  sim.x_max = 225;
sim.z_min = 15;  sim.z_max = 45;
sim.dxMax = 75;  sim.dzMax = 30;

sim.noUsers = noUsers;
sim.noBS = noBS;
sim.enWidth = enWidth;
sim.enLength = enLength;

sim.xUser = xUser; sim.yUser = yUser; sim.zUser = zUser;
sim.xBS = xBS;     sim.yBS = yBS;     sim.zBS = zBS;

sim.etaPath = etaPath; sim.b0 = b0;
sim.A1 = A1; sim.A2 = A2;
sim.gLoS = gLoS;
sim.gNLoSUsers = gNLoSUsers;
sim.gNLoSBS = gNLoSBS;

sim.pr = pr; sim.phy = phy; sim.neta = neta; sim.Tslot = Tslot;
sim.bigPenalty = 1e12;
sim.lambdaMean = 0.05;
sim.lambdaSmooth = 0;
sim.lambdaFair = 0.1;
sim.pMin = 1e-3;
sim.pMax = 1.0;
sim.jointAlphaRepair = 'noma';

%% 8. Baseline: Đường bay thẳng
xBase = linspace(xUAV_S, xUAV_E, numSteps);
zBase = linspace(zUAV_S, zUAV_E, numSteps);
particleBase = [xBase(2:end-1), zBase(2:end-1)];
[fitBase, resBase] = evaluateTrajectory_SWIPT_clean(particleBase, sim);

%% 9. Joint PSO không tối ưu BS (Baseline V8)
optsJoint = struct();
optsJoint.numParticles = 120;
optsJoint.maxIter = 450;
optsJoint.w = 0.7; optsJoint.c1 = 1.5; optsJoint.c2 = 1.5;

fprintf('\nGLOBAL JOINT PSO-SWIPT (without BS)\n');
trajJoint = optimizeTrajectory_JointPSO_SWIPT_clean(sim, optsJoint);

%% 10. Cấu hình chung cho các bộ tối ưu Full
seedAlgo   = 151459287;
seedPolish = 152459287;
alphaPolishSamples = max(500, 250 * noUsers);

if ~exist('maxIterFull', 'var')
    maxIterFull = 1000;
end
if ~exist('runAlphaPolish', 'var')
    runAlphaPolish = true;
end
if ~exist('generatePlots', 'var')
    generatePlots = true;
end

%% 11. Full Joint PSO (Standard V8)
optsFull = struct();
optsFull.numParticles = 400;
optsFull.maxIter = maxIterFull;
optsFull.w = 0.7; optsFull.c1 = 1.5; optsFull.c2 = 1.5;

fprintf('\nFULL JOINT+BS PSO (Standard 149D)\n');
rng(seedAlgo, 'twister');
tFullStart = tic;
trajFullRaw = optimizeTrajectory_JointBS_PSO_SWIPT_clean(sim, optsFull);
timeFull = toc(tFullStart);

if runAlphaPolish
    rng(seedPolish, 'twister');
    trajFull = polishAlphaAllSteps_JointBS(trajFullRaw, sim, alphaPolishSamples);
else
    trajFull = trajFullRaw;
end

%% 12. FULL JOINT+BS CC-PSO (V8-SNAPSHOT-CCPSO)
optsCC = struct();
optsCC.maxIter = maxIterFull;
optsCC.numParticlesPos = 60;   % Phân đàn Quỹ đạo (38D)
optsCC.numParticlesBS  = 20;   % Phân đàn Vị trí BS (6D)
optsCC.numParticlesPow = 80;   % Phân đàn Công suất NOMA alpha (105D)
optsCC.w_pos = 0.7; optsCC.c1_pos = 1.5; optsCC.c2_pos = 1.5;
optsCC.w_bs  = 0.7; optsCC.c1_bs  = 1.5; optsCC.c2_bs  = 1.5;
optsCC.w_pow = 0.7; optsCC.c1_pow = 1.5; optsCC.c2_pow = 1.5;

fprintf('\nFULL JOINT+BS CC-PSO (Cooperative Co-evolutionary 38D+6D+105D)\n');
rng(seedAlgo, 'twister');
tCCStart = tic;
trajCCRaw = optimizeTrajectory_JointBS_CCPSO_SWIPT_clean(sim, optsCC);
timeCC = toc(tCCStart);

if runAlphaPolish
    rng(seedPolish, 'twister');
    trajCC = polishAlphaAllSteps_JointBS(trajCCRaw, sim, alphaPolishSamples);
else
    trajCC = trajCCRaw;
end

%% 13. FULL JOINT+BS IPSO (Improved PSO V8)
optsIPSO = struct();
optsIPSO.numParticles = 400;
optsIPSO.maxIter = maxIterFull;
optsIPSO.w_max = 0.9; optsIPSO.w_min = 0.4;
optsIPSO.mutRateLow = 0.02; optsIPSO.mutParticleRateLow = 0.05;
optsIPSO.mutRateHigh = 0.08; optsIPSO.mutParticleRateHigh = 0.20;
optsIPSO.stallIter = 100; optsIPSO.eliteRate = 0.05;
optsIPSO.sigmaScaleLow = 0.03; optsIPSO.sigmaScaleHigh = 0.05;
optsIPSO.c1 = 1.5; optsIPSO.c2 = 1.5;

fprintf('\nFULL JOINT+BS IPSO (Improved PSO 149D)\n');
rng(seedAlgo, 'twister');
tIPSOStart = tic;
trajIPSORaw = optimizeTrajectory_JointBS_IPSO_SWIPT_clean(sim, optsIPSO);
timeIPSO = toc(tIPSOStart);

if runAlphaPolish
    rng(seedPolish, 'twister');
    trajIPSO = polishAlphaAllSteps_JointBS(trajIPSORaw, sim, alphaPolishSamples);
else
    trajIPSO = trajIPSORaw;
end

%% 14. IN KẾT QUẢ TỔNG HỢP (FINAL RESULT)
fprintf('\n============================================================\n');
fprintf('FINAL RESULT (V8-SNAPSHOT-CCPSO)\n');
fprintf('============================================================\n');
fprintf('Settings: noUsers = %d, noBS = %d, lambdaMean = %.4f, lambdaFair = %.4f, mainSeed = %d\n', ...
    noUsers, noBS, sim.lambdaMean, sim.lambdaFair, mainSeed);

fprintf('\nBaseline straight trajectory:\n');
fprintf('  Fitness        = %.12e bps\n', fitBase);
fprintf('  Global minRate = %.12e bps\n', min(resBase.stepMin));

fprintf('\nJoint PSO (no BS):\n');
fprintf('  Fitness        = %.12e bps\n', trajJoint.bestFitness);
fprintf('  Global minRate = %.12e bps\n', min(trajJoint.stepMin));

fprintf('\nFull Standard JointPSO (149D):\n');
fprintf('  Fitness        = %.12e bps\n', trajFull.bestFitness);
fprintf('  Global minRate = %.12e bps\n', min(trajFull.stepMin));
fprintf('  RoughNorm      = %.4f\n', trajFull.roughNorm);
fprintf('  Runtime        = %.2f s\n', timeFull);

fprintf('\nFull CC-JointPSO (V8-SNAPSHOT-CCPSO):\n');
fprintf('  Fitness        = %.12e bps\n', trajCC.bestFitness);
fprintf('  Global minRate = %.12e bps\n', min(trajCC.stepMin));
fprintf('  RoughNorm      = %.4f\n', trajCC.roughNorm);
fprintf('  Runtime        = %.2f s (%.1fx vs Standard)\n', timeCC, timeFull / max(timeCC, eps));

fprintf('\nFull IPSO (149D):\n');
fprintf('  Fitness        = %.12e bps\n', trajIPSO.bestFitness);
fprintf('  Global minRate = %.12e bps\n', min(trajIPSO.stepMin));
fprintf('  Runtime        = %.2f s\n', timeIPSO);

fprintf('\nImprovement of CC-JointPSO over Standard JointPSO:\n');
fprintf('  Delta Fitness        = %+.2f %%\n', (trajCC.bestFitness - trajFull.bestFitness) / trajFull.bestFitness * 100);
fprintf('  Delta Global minRate = %+.2f %%\n', (min(trajCC.stepMin) - min(trajFull.stepMin)) / min(trajFull.stepMin) * 100);
fprintf('  Speedup factor       = %.2fx faster\n', timeFull / max(timeCC, eps));

%% 15. Kiểm tra tính công bằng (Fairness Check)
idx = 2:(sim.numSteps-1);
fprintf('\n=== FAIRNESS CHECK ON INTERNAL STEPS ===\n');
printFairnessMetric('Full Standard PSO', trajFull.achRate(idx, :));
printFairnessMetric('Full CC-JointPSO ', trajCC.achRate(idx, :));
printFairnessMetric('Full IPSO        ', trajIPSO.achRate(idx, :));

%% 16. Vẽ biểu đồ hội tụ nếu bật generatePlots
if generatePlots
    figure(1); clf;
    plot(trajFullRaw.bestHistory / 1e3, 'g-', 'LineWidth', 1.8, 'DisplayName', 'Standard JointPSO (149D)'); hold on;
    plot(trajCCRaw.bestHistory / 1e3,   'b-', 'LineWidth', 2.0, 'DisplayName', 'CC-JointPSO (38D+6D+105D)');
    plot(trajIPSORaw.bestHistory / 1e3,  'r--', 'LineWidth', 1.8, 'DisplayName', 'IPSO (149D)');
    grid on; xlabel('Iteration'); ylabel('Best Fitness (kbps)');
    title(sprintf('Convergence Comparison: Standard vs CC-JointPSO (Seed %d)', mainSeed));
    legend('Location', 'southeast');
end

function printFairnessMetric(name, rateMat)
    jainStep = (sum(rateMat, 2).^2) ./ (size(rateMat, 2) * sum(rateMat.^2, 2) + eps);
    gapRel = (max(rateMat, [], 2) - min(rateMat, [], 2)) ./ (mean(rateMat, 2) + eps);
    fprintf('%s | Jain mean: %.6f | rel gap mean: %.6f | rel gap max: %.6f\n', ...
        name, mean(jainStep), mean(gapRel), max(gapRel));
end
