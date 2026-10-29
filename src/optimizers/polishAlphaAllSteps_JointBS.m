function bestOut = polishAlphaAllSteps_JointBS(bestIn, sim, nSamples)
% Polish alpha per step after PSO/IPSO (EE in ee-rf mode, min-rate in V8).
% Keeps trajectory and BS fixed, only changes alpha block of bestParticle.
%
% nSamples: number of random alpha candidates per step.
% For 3 users, 300-800 is usually okay.
% For more users, use 500-1500 depending on runtime.

    if nargin < 3
        nSamples = 500;
    end

    p = bestIn.bestParticle;

    T = sim.numSteps;
    nInternal = T - 2;
    noUsers = sim.noUsers;

    D_pos = 2 * nInternal;

    isEERF = isfield(sim, 'objectiveMode') && strcmpi(sim.objectiveMode, 'ee-rf');
    fitnessUnit = 'bit/s';
    if isEERF
        fitnessUnit = 'bit/J';
        fitIdx = 1:(T-1); % One slot per segment; no slot after arrival.
    elseif isfield(sim, 'fitnessStepMode') && strcmpi(sim.fitnessStepMode, 'all')
        fitIdx = 1:T;
    else
        fitIdx = 2:(T-1);
    end

    [fitCur, resCur] = evaluateTrajectory_JointBS_SWIPT_clean(p, sim);

    fprintf('\nAlpha polishing started | initial fitness = %.6e %s\n', fitCur, fitnessUnit);

    for t = fitIdx
        idxAlpha = D_pos + (t-1)*noUsers + (1:noUsers);

        curRates = resCur.achRate(t, :);
        curStepMin = min(curRates);
        curGapRel = (max(curRates) - min(curRates)) / (mean(curRates) + eps);

        bestLocalP = p;
        bestLocalStepMin = curStepMin;
        bestLocalGapRel = curGapRel;
        bestLocalRes = resCur;
        bestLocalFitness = resCur.fitness;

        for s = 1:nSamples
            if s == 1
                % Equal alpha candidate
                alpha = ones(1, noUsers) / noUsers;
            elseif s == 2
                % Current alpha candidate
                alpha = p(idxAlpha);
                alpha = max(alpha, sim.pMin);
                alpha = alpha / sum(alpha);
            else
                % Random simplex alpha
                alpha = rand(1, noUsers);
                alpha = max(alpha, sim.pMin);
                alpha = alpha / sum(alpha);
            end

            pTest = p;
            pTest(idxAlpha) = alpha;

            [fitTest, resTest] = evaluateTrajectory_JointBS_SWIPT_clean(pTest, sim);

            testRates = resTest.achRate(t, :);
            testStepMin = min(testRates);
            testGapRel = (max(testRates) - min(testRates)) / (mean(testRates) + eps);

            % EE mode: improve mission EE. V8: improve min-rate, then imbalance.
            if isEERF
                accept = fitTest > bestLocalFitness;
            else
                accept = testStepMin > bestLocalStepMin * (1 + 1e-10) ...
                    || (abs(testStepMin - bestLocalStepMin) <= 1e-8 && testGapRel < bestLocalGapRel);
            end
            if accept

                bestLocalStepMin = testStepMin;
                bestLocalGapRel = testGapRel;
                bestLocalP = pTest;
                bestLocalRes = resTest;
                bestLocalFitness = fitTest;
            end
        end

        if isEERF
            acceptStep = bestLocalFitness > resCur.fitness;
        else
            acceptStep = bestLocalStepMin > curStepMin * (1 + 1e-10) || bestLocalGapRel < curGapRel;
        end
        if acceptStep
            if isEERF
                fprintf('Slot %2d polished | EE %.4e -> %.4e bit/J\n', t, resCur.fitness, bestLocalFitness);
            else
                fprintf('Step %2d polished | min %.4e -> %.4e bit/s | gapRel %.4f -> %.4f\n', t, curStepMin, bestLocalStepMin, curGapRel, bestLocalGapRel);
            end

            p = bestLocalP;
            resCur = bestLocalRes;
        end
    end

    [fitFinal, resFinal] = evaluateTrajectory_JointBS_SWIPT_clean(p, sim);

    bestOut = resFinal;
    bestOut.bestParticle = p;
    bestOut.bestFitness = fitFinal;

    if isfield(bestIn, 'bestHistory')
        bestOut.bestHistory = bestIn.bestHistory;
        if ~isEERF
            bestOut.bestHistory(end) = fitFinal;
        end
    end
    if isEERF && isfield(bestIn, 'totalBitsHistory') && isfield(bestIn, 'totalEnergyHistory')
        % Keep optimization histories intact; polishing is a separate event.
        bestOut.totalBitsHistory = bestIn.totalBitsHistory;
        bestOut.totalEnergyHistory = bestIn.totalEnergyHistory;
        userHistoryFields = {'totalBitsPerUserHistory', 'transmitPowerHistory', 'alphaUserHistory'};
        for historyIndex = 1:numel(userHistoryFields)
            historyField = userHistoryFields{historyIndex};
            if isfield(bestIn, historyField)
                bestOut.(historyField) = bestIn.(historyField);
            end
        end
    end

    bestOut.mode = [bestIn.mode, '-alpha-polished'];
    bestOut.alphaPolished = true;
    bestOut.alphaPolishSamples = nSamples;

    fprintf('Alpha polishing finished | final fitness = %.6e %s | gain = %.6e %s\n', fitFinal, fitnessUnit, fitFinal - fitCur, fitnessUnit);
end
