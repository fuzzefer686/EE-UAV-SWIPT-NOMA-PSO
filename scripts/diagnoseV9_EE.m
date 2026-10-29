% Read existing V9 EE workspace results; do not run an optimizer or change them.
% Run this script yourself after maincodeV9_EE, if you want trace diagnostics.
if ~exist('trajJoint', 'var') || ~exist('trajFull', 'var') || ~exist('trajIPSO', 'var')
    error('diagnoseV9_EE:MissingResults', 'Need trajJoint, trajFull and trajIPSO in the workspace.');
end

eeDiagNames = {'Joint PSO', 'Full PSO', 'Full IPSO'};
eeDiagResults = {trajJoint, trajFull, trajIPSO};
% Match the current constants in findAchievableRate_SWIPT_Joint.
eeDiagB = 1e6;
eeDiagNoise = 1e-3 * 10^((-174 + 10*log10(eeDiagB))/10);
fprintf('\n=== V9 RF EE DIAGNOSIS (existing results only) ===\n');
if exist('mainSeed', 'var')
    fprintf('Workspace mainSeed = %d\n', mainSeed);
end

for eeDiagK = 1:3
    eeDiagR = eeDiagResults{eeDiagK};
    if ~isfield(eeDiagR, 'eeRF')
        error('diagnoseV9_EE:WrongMode', 'Need EE results from maincodeV9_EE, not rate-only V8.');
    end
    eeDiagIdx = eeDiagR.slotIdx;
    eeDiagN = size(eeDiagR.achRate, 2);
    eeDiagAlpha = eeDiagR.alphaOrdTrace(eeDiagIdx, :);
    eeDiagAlphaDeviation = max(abs(eeDiagAlpha(:) - 1/eeDiagN));
    eeDiagSNR = bsxfun(@times, eeDiagR.h2UserTrace(eeDiagIdx, :), ...
        eeDiagR.pt(eeDiagIdx)) / eeDiagNoise;

    % Recalculate rates at the SAME trajectory, BS positions and RF powers,
    % changing only alpha to the sum-rate optimum allowed by descending alpha.
    eeDiagUniformSumRate = zeros(numel(eeDiagIdx), 1);
    for eeDiagSlot = 1:numel(eeDiagIdx)
        eeDiagG = sort(eeDiagR.h2UserTrace(eeDiagIdx(eeDiagSlot), :), 'ascend');
        eeDiagP = eeDiagR.pt(eeDiagIdx(eeDiagSlot));
        eeDiagInterference = (eeDiagN-1:-1:0) / eeDiagN;
        eeDiagSINR = (eeDiagP / eeDiagN * eeDiagG) ...
            ./ (eeDiagNoise + eeDiagP * eeDiagInterference .* eeDiagG);
        eeDiagUniformSumRate(eeDiagSlot) = eeDiagB * sum(log2(1 + eeDiagSINR));
    end
    eeDiagUniformEE = sum(eeDiagUniformSumRate) * eeDiagR.downlinkTime / eeDiagR.totalEnergy;
    fprintf('%s: EE %.12e bit/J | uniform-alpha EE %.12e bit/J | gain %.8f %%\n', ...
        eeDiagNames{eeDiagK}, eeDiagR.eeRF, eeDiagUniformEE, ...
        100 * (eeDiagUniformEE / eeDiagR.eeRF - 1));
    fprintf('  max alpha deviation from 1/%d: %.6e | RF energy %.9e J | bits %.9e\n', ...
        eeDiagN, eeDiagAlphaDeviation, eeDiagR.totalEnergy, eeDiagR.totalBits);
    fprintf('  RF power range: %.6e to %.6e W | altitude range: %.3f to %.3f m\n', ...
        min(eeDiagR.pt(eeDiagIdx)), max(eeDiagR.pt(eeDiagIdx)), ...
        min(eeDiagR.zTraj(eeDiagIdx)), max(eeDiagR.zTraj(eeDiagIdx)));
    fprintf('  P*|h|^2/noise range: %.6e to %.6e | fraction below 0.1: %.2f %%\n', ...
        min(eeDiagSNR(:)), max(eeDiagSNR(:)), 100 * mean(eeDiagSNR(:) < 0.1));
end

for eeDiagPair = [1, 2; 1, 3; 2, 3].'
    eeDiagA = eeDiagResults{eeDiagPair(1)};
    eeDiagC = eeDiagResults{eeDiagPair(2)};
    fprintf('%s vs %s: max |dx| %.6f m | max |dz| %.6f m\n', ...
        eeDiagNames{eeDiagPair(1)}, eeDiagNames{eeDiagPair(2)}, ...
        max(abs(eeDiagA.xTraj - eeDiagC.xTraj)), max(abs(eeDiagA.zTraj - eeDiagC.zTraj)));
end
