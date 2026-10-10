clc;
clear variables;
close all;

%% ============================================================
%  Batch test for maincodeV8_nUsers
%  Purpose:
%    - Run the same V8 setting over multiple random seeds.
%    - Compare Full Joint+BS PSO vs Full Joint+BS IPSO.
%    - Keep PSO/IPSO initial swarm comparable by using the same algo seed.
%    - Keep PSO/IPSO alpha polishing comparable by using the same polish seed.
%
%  NOTE:
%    This script does not modify maincodeV8nUser.m.
%    It calls existing project functions:
%      evaluateTrajectory_SWIPT_clean
%      optimizeTrajectory_JointPSO_SWIPT_clean
%      optimizeTrajectory_JointBS_PSO_SWIPT_clean
%      optimizeTrajectory_JointBS_IPSO_SWIPT_clean
%      polishAlphaAllSteps_JointBS
%% ============================================================

%% ================= USER CONFIG =================
numRuns = 30;

% Test setting
noUsers = 5;       % thu 4, 5, 6
noBS = 3;

% Lambda setting from V8
lambdaMean = 0.05;
lambdaFair = 0.10;
lambdaSmooth = 0;

% Optimizer setting from V8
numParticlesJoint = 80;
maxIterJoint = 450;

numParticlesFull = 400;
maxIterFull = 3000;
% IPSO improvement setting
ipsoMutRate = 0.4;          % Tỷ lệ gene bị mutation trong mỗi hạt được chọn
ipsoMutParticleRate = 0.4;  % Tỷ lệ số hạt được đem đi mutation mỗi iteration
% Alpha polish setting
alphaPolishSamples = max(500, 250 * noUsers);

% Random seed policy
% If true: generate a new random list of seeds each time this script starts.
% If false: use fixed seed list for reproducible batch.
useRandomSeedList = true;
seedListBase = 20260609;

% Save file name
timeTag = datestr(now, 'yyyymmdd_HHMMSS');
saveFileName = sprintf('batch_v8_%dusers_%druns_mr%.2f_mpr%.2f_%s.mat', noUsers, numRuns, ipsoMutRate, ipsoMutParticleRate, timeTag);

%% ================= COLORS =================
colorFull = [0.4660 0.6740 0.1880];   % green PSO
colorIPSO = [0.6350 0.0780 0.1840];   % dark red IPSO

%% ================= SEED LIST =================
if useRandomSeedList
    rng('shuffle');
    runSeeds = randi(1e9, numRuns, 1);
else
    rng(seedListBase, 'twister');
    runSeeds = randi(1e9, numRuns, 1);
end

fprintf('\n================ BATCH V8 PSO vs IPSO ================\n');
fprintf('numRuns = %d | noUsers = %d | noBS = %d\n', numRuns, noUsers, noBS);
fprintf('lambdaMean = %.4f | lambdaFair = %.4f | lambdaSmooth = %.4f\n', ...
    lambdaMean, lambdaFair, lambdaSmooth);
fprintf('Full particles = %d | Full iter = %d | alpha polish samples = %d\n', ...
    numParticlesFull, maxIterFull, alphaPolishSamples);
fprintf('IPSO mutRate = %.4f | IPSO mutParticleRate = %.4f\n', ...
    ipsoMutRate, ipsoMutParticleRate);
fprintf('Save file: %s\n', saveFileName);

%% ================= STORAGE =================
psoHistAll = nan(numRuns, maxIterFull + 1);
ipsoHistAll = nan(numRuns, maxIterFull + 1);

psoRawFinal = nan(numRuns, 1);
ipsoRawFinal = nan(numRuns, 1);

psoFinal = nan(numRuns, 1);
ipsoFinal = nan(numRuns, 1);

psoMinFit = nan(numRuns, 1);
ipsoMinFit = nan(numRuns, 1);

psoMeanFit = nan(numRuns, 1);
ipsoMeanFit = nan(numRuns, 1);

psoJainMean = nan(numRuns, 1);
ipsoJainMean = nan(numRuns, 1);

psoGapRelMean = nan(numRuns, 1);
ipsoGapRelMean = nan(numRuns, 1);

psoGapRelMax = nan(numRuns, 1);
ipsoGapRelMax = nan(numRuns, 1);

psoMeanPt = nan(numRuns, 1);
ipsoMeanPt = nan(numRuns, 1);

jointFinal = nan(numRuns, 1);
jointMinFit = nan(numRuns, 1);
jointMeanFit = nan(numRuns, 1);

seedAlgoList = nan(numRuns, 1);
seedPolishList = nan(numRuns, 1);

runTime = nan(numRuns, 1);

%% ================= MAIN LOOP =================
for run = 1:numRuns
    fprintf('\n================ RUN %d/%d ================\n', run, numRuns);
    fprintf('runSeed = %d\n', runSeeds(run));

    tStart = tic;

    %% 1) Build one random environment for this run
    rng(runSeeds(run), 'twister');

    sim = buildSimV8(noUsers, noBS, lambdaMean, lambdaFair, lambdaSmooth);

    fprintf('xUser = '); disp(sim.xUser);
    fprintf('yUser = '); disp(sim.yUser);

    %% 2) Baseline
    xBase = linspace(sim.xStart, sim.xEnd, sim.numSteps);
    zBase = linspace(sim.zStart, sim.zEnd, sim.numSteps);
    particleBase = [xBase(2:end-1), zBase(2:end-1)];
    [fitBase, resBase] = evaluateTrajectory_SWIPT_clean(particleBase, sim); %#ok<ASGLU>

    %% 3) Joint no-BS, kept for reference
    optsJoint = struct();
    optsJoint.numParticles = numParticlesJoint;
    optsJoint.maxIter = maxIterJoint;
    optsJoint.w = 0.7;
    optsJoint.c1 = 1.5;
    optsJoint.c2 = 1.5;

    fprintf('Running Joint no-BS...\n');
    evalc('trajJoint = optimizeTrajectory_JointPSO_SWIPT_clean(sim, optsJoint);');

    %% 4) Full Joint+BS PSO and IPSO
    optsFull = struct();
    optsFull.numParticles = numParticlesFull;
    optsFull.maxIter = maxIterFull;
    optsFull.w = 0.7;
    optsFull.c1 = 1.5;
    optsFull.c2 = 1.5;

    optsIPSO = struct();
    optsIPSO.numParticles = numParticlesFull;
    optsIPSO.maxIter = maxIterFull;
    optsIPSO.w_max = 0.9;
    optsIPSO.w_min = 0.4;
    % Adaptive mutation
    optsIPSO.mutRateLow = 0.03;
    optsIPSO.mutParticleRateLow = 0.08;
    
    optsIPSO.mutRateHigh = 0.1;
    optsIPSO.mutParticleRateHigh = 0.25;
    
    optsIPSO.stallIter = 80;
    optsIPSO.eliteRate = 0.05;
    
    optsIPSO.sigmaScaleLow = 0.03;
    optsIPSO.sigmaScaleHigh = 0.05;
    optsIPSO.c1 = 1.5;
    optsIPSO.c2 = 1.5;

    % Use explicit comparable seeds for optimizer and polish
    seedAlgo = runSeeds(run) + 1000003;
    seedPolish = runSeeds(run) + 2000003;

    seedAlgoList(run) = seedAlgo;
    seedPolishList(run) = seedPolish;

    fprintf('Running Full PSO...\n');
    rng(seedAlgo, 'twister');
    evalc('trajFullRaw = optimizeTrajectory_JointBS_PSO_SWIPT_clean(sim, optsFull);');

    fprintf('Polishing Full PSO alpha...\n');
    rng(seedPolish, 'twister');
    evalc('trajFull = polishAlphaAllSteps_JointBS(trajFullRaw, sim, alphaPolishSamples);');

    fprintf('Running Full IPSO...\n');
    rng(seedAlgo, 'twister');
    evalc('trajIPSORaw = optimizeTrajectory_JointBS_IPSO_SWIPT_clean(sim, optsIPSO);');

    fprintf('Polishing Full IPSO alpha...\n');
    rng(seedPolish, 'twister');
    evalc('trajIPSO = polishAlphaAllSteps_JointBS(trajIPSORaw, sim, alphaPolishSamples);');

    %% 5) Store histories and metrics
    psoHistAll(run, :) = trajFullRaw.bestHistory(:).';
    ipsoHistAll(run, :) = trajIPSORaw.bestHistory(:).';

    psoRawFinal(run) = trajFullRaw.bestFitness;
    ipsoRawFinal(run) = trajIPSORaw.bestFitness;

    psoFinal(run) = trajFull.bestFitness;
    ipsoFinal(run) = trajIPSO.bestFitness;

    psoMinFit(run) = trajFull.minFit;
    ipsoMinFit(run) = trajIPSO.minFit;

    psoMeanFit(run) = trajFull.meanFit;
    ipsoMeanFit(run) = trajIPSO.meanFit;

    Mps = calcFairnessMetrics(trajFull, sim);
    Mis = calcFairnessMetrics(trajIPSO, sim);
    Mj = calcJointMetrics(trajJoint, sim);

    psoJainMean(run) = Mps.jainMean;
    ipsoJainMean(run) = Mis.jainMean;

    psoGapRelMean(run) = Mps.gapRelMean;
    ipsoGapRelMean(run) = Mis.gapRelMean;

    psoGapRelMax(run) = Mps.gapRelMax;
    ipsoGapRelMax(run) = Mis.gapRelMax;

    psoMeanPt(run) = mean(trajFull.pt);
    ipsoMeanPt(run) = mean(trajIPSO.pt);

    jointFinal(run) = trajJoint.bestFitness;
    jointMinFit(run) = Mj.minFit;
    jointMeanFit(run) = Mj.meanFit;

    runTime(run) = toc(tStart);

    fprintf('Run %d done | PSO %.4e | IPSO %.4e | IPSO-PSO %.4e | time %.1f s\n', ...
        run, psoFinal(run), ipsoFinal(run), ipsoFinal(run)-psoFinal(run), runTime(run));

    fprintf('Raw before polish | PSO %.4e | IPSO %.4e | IPSO-PSO %.4e\n', ...
        psoRawFinal(run), ipsoRawFinal(run), ipsoRawFinal(run)-psoRawFinal(run));

    %% Save after each run to avoid losing data
    save(saveFileName);
end

%% ================= SUMMARY =================
validRuns = ~isnan(psoFinal) & ~isnan(ipsoFinal);
diffFinal = ipsoFinal(validRuns) - psoFinal(validRuns);
diffRaw = ipsoRawFinal(validRuns) - psoRawFinal(validRuns);

fprintf('\n================ FINAL SUMMARY ================\n');
fprintf('Valid runs = %d/%d\n', sum(validRuns), numRuns);

fprintf('\n--- Polished final fitness ---\n');
fprintf('IPSO win count      = %d/%d\n', sum(diffFinal > 0), sum(validRuns));
fprintf('PSO win count       = %d/%d\n', sum(diffFinal < 0), sum(validRuns));
fprintf('Mean diff IPSO-PSO  = %.6e\n', mean(diffFinal));
fprintf('Median diff         = %.6e\n', median(diffFinal));
fprintf('Std diff            = %.6e\n', std(diffFinal));
fprintf('Best IPSO gain      = %.6e\n', max(diffFinal));
fprintf('Worst IPSO loss     = %.6e\n', min(diffFinal));
fprintf('Mean PSO final      = %.6e\n', mean(psoFinal(validRuns)));
fprintf('Mean IPSO final     = %.6e\n', mean(ipsoFinal(validRuns)));

fprintf('\n--- Raw final fitness before polish ---\n');
fprintf('IPSO raw win count      = %d/%d\n', sum(diffRaw > 0), sum(validRuns));
fprintf('PSO raw win count       = %d/%d\n', sum(diffRaw < 0), sum(validRuns));
fprintf('Mean raw diff IPSO-PSO  = %.6e\n', mean(diffRaw));
fprintf('Mean PSO raw            = %.6e\n', mean(psoRawFinal(validRuns)));
fprintf('Mean IPSO raw           = %.6e\n', mean(ipsoRawFinal(validRuns)));

fprintf('\n--- Quality metrics after polish ---\n');
fprintf('Mean PSO minFit      = %.6e\n', mean(psoMinFit(validRuns)));
fprintf('Mean IPSO minFit     = %.6e\n', mean(ipsoMinFit(validRuns)));
fprintf('Mean PSO meanFit     = %.6e\n', mean(psoMeanFit(validRuns)));
fprintf('Mean IPSO meanFit    = %.6e\n', mean(ipsoMeanFit(validRuns)));
fprintf('Mean PSO Jain        = %.6f\n', mean(psoJainMean(validRuns)));
fprintf('Mean IPSO Jain       = %.6f\n', mean(ipsoJainMean(validRuns)));
fprintf('Mean PSO gapRelMean  = %.6f\n', mean(psoGapRelMean(validRuns)));
fprintf('Mean IPSO gapRelMean = %.6f\n', mean(ipsoGapRelMean(validRuns)));
fprintf('Mean PSO gapRelMax   = %.6f\n', mean(psoGapRelMax(validRuns)));
fprintf('Mean IPSO gapRelMax  = %.6f\n', mean(ipsoGapRelMax(validRuns)));

%% ================= FIGURES =================
iterAxis = 0:maxIterFull;

psoMeanHist = mean(psoHistAll(validRuns, :), 1, 'omitnan');
ipsoMeanHist = mean(ipsoHistAll(validRuns, :), 1, 'omitnan');

figure(1); clf; hold on;
plot(iterAxis, psoMeanHist, '-^', ...
    'Color', colorFull, ...
    'LineWidth', 1.8, ...
    'MarkerSize', 4, ...
    'MarkerIndices', 1:50:(maxIterFull+1));

plot(iterAxis, ipsoMeanHist, '-d', ...
    'Color', colorIPSO, ...
    'LineWidth', 2.0, ...
    'MarkerSize', 4, ...
    'MarkerIndices', 1:50:(maxIterFull+1));

grid on;
xlabel('Iteration');
ylabel('Average best fitness before polish (bps)');
title(sprintf('Average convergence over %d random seeds, N = %d users', sum(validRuns), noUsers));
legend('Full Joint+BS PSO', 'Full Joint+BS IPSO', 'Location', 'best');
xlim([0 maxIterFull]);

figure(2); clf; hold on;
bar([mean(psoFinal(validRuns)), mean(ipsoFinal(validRuns)); ...
     mean(psoMinFit(validRuns)), mean(ipsoMinFit(validRuns)); ...
     mean(psoMeanFit(validRuns)), mean(ipsoMeanFit(validRuns))]);

grid on;
xticklabels({'Fitness','minFit','meanFit'});
ylabel('bps');
title(sprintf('Average quality metrics after polish, N = %d users', noUsers));
legend('PSO', 'IPSO', 'Location', 'best');

figure(3); clf; hold on;
plot(1:sum(validRuns), diffFinal, '-o', 'LineWidth', 1.8, 'MarkerSize', 6);
yline(0, '--');
grid on;
xlabel('Valid run index');
ylabel('IPSO - PSO final fitness (bps)');
title(sprintf('Per-run difference after polish, N = %d users', noUsers));

saveas(figure(1), sprintf('batch_v8_%dusers_avg_convergence.png', noUsers));
saveas(figure(2), sprintf('batch_v8_%dusers_avg_metrics.png', noUsers));
saveas(figure(3), sprintf('batch_v8_%dusers_diff.png', noUsers));

save(saveFileName);

fprintf('\nSaved MAT result to: %s\n', saveFileName);
fprintf('Saved figures: batch_v8_%dusers_avg_convergence.png, batch_v8_%dusers_avg_metrics.png, batch_v8_%dusers_diff.png\n', ...
    noUsers, noUsers, noUsers);

%% ============================================================
%% LOCAL FUNCTIONS
%% ============================================================

function sim = buildSimV8(noUsers, noBS, lambdaMean, lambdaFair, lambdaSmooth)

    enWidth  = 300;
    enLength = 300;
    enHeight = 60; %#ok<NASGU>

    %% UAV start/end
    xUAV_S = 150;
    zUAV_S = 30;

    xUAV_E = 150;
    zUAV_E = 30;

    %% BS positions, fixed noBS = 3 for now
    if noBS ~= 3
        error('This batch script currently keeps noBS = 3, matching maincodeV8.');
    end

    xBS = [300,   0, 300];
    yBS = [300, 150,   0];
    zBS = [ 20,  30,  25];

    %% Random users
    xUser = zeros(1, noUsers);
    yUser = zeros(1, noUsers);
    zUser = zeros(1, noUsers);

    for i = 1:noUsers
        xUser(i) = randi([enWidth/4,  3*enWidth/4]);
        yUser(i) = randi([enLength/4, 3*enLength/4]);
        zUser(i) = 0;
    end

    %% Mission steps
    stepsVec = enLength:-15:0;
    numSteps = numel(stepsVec);

    %% SWIPT parameters
    Pr = 46;
    pr = (10^-3) * db2pow(Pr);

    Tslot = 1e-6;
    phy = 0.9;
    neta = 0.9;

    %% Channel parameters
    etaPath = 2.5;
    b0 = db2pow(-30);

    K_min = 4;
    K_max = 12;

    A1 = db2pow(K_min);
    A2 = (2/pi) * log(db2pow(K_max) / A1);

    gLoS = 1;

    gNLoSUsers = sqrt(1/2) * (randn(1, noUsers) + 1i * randn(1, noUsers));
    gNLoSBS    = sqrt(1/2) * (randn(1, noBS)    + 1i * randn(1, noBS));

    %% sim struct
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

    sim.fitnessStepMode = 'internal';

    sim.x_min = 75;
    sim.x_max = 225;
    sim.z_min = 15;
    sim.z_max = 45;

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
    sim.lambdaMean = lambdaMean;
    sim.lambdaSmooth = lambdaSmooth;
    sim.lambdaFair = lambdaFair;
    sim.pMin = 1e-3;
    sim.pMax = 1.0;
    sim.jointAlphaRepair = 'noma';
end

function M = calcFairnessMetrics(res, sim)
    idx = 2:(sim.numSteps-1);

    rateFit = res.achRate(idx, :);
    stepMinFit = min(rateFit, [], 2);

    noUsersLocal = size(rateFit, 2);

    jainStep = (sum(rateFit, 2).^2) ./ ...
               (noUsersLocal * sum(rateFit.^2, 2) + eps);

    gapRelStep = (max(rateFit, [], 2) - min(rateFit, [], 2)) ./ ...
                 (mean(rateFit, 2) + eps);

    M = struct();
    M.minFit = min(stepMinFit);
    M.meanFit = mean(stepMinFit);
    M.jainMean = mean(jainStep);
    M.gapRelMean = mean(gapRelStep);
    M.gapRelMax = max(gapRelStep);
end

function M = calcJointMetrics(res, sim)
    idx = 2:(sim.numSteps-1);
    stepMinFit = res.stepMin(idx);

    M = struct();
    M.minFit = min(stepMinFit);
    M.meanFit = mean(stepMinFit);
end
