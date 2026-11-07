function [rate, alphaOrdered, order, rfPower, harvestedEnergy, phi, ulRate, dlRate] = findAchievableRateV12(hUsers, hBS, alphaUser, sim)
%FINDACHIEVABLERATEV12 Causal DF NOMA with optimal or fixed power splitting.
    r = sim.radio;
    alphaUser = max(real(alphaUser(:)).', 1e-12);
    alphaUser = alphaUser / sum(alphaUser);
    receivedPower = r.bsPowerW * sum(abs(hBS).^2);
    [gain, order] = sort(abs(hUsers).^2, 'ascend');
    alphaOrdered = alphaUser(order);
    count = numel(alphaUser);

    if ~isfield(r, 'powerSplitMode') || strcmpi(r.powerSplitMode, 'fixed')
        phi = r.powerSplit;
        oneMinusPhi = 1 - phi;
    else
        if receivedPower <= 0 || max(gain) <= 0
            phiStar = r.powerSplit;
            oneMinusPhiStar = 1 - phiStar;
        elseif abs(sim.ehTime - sim.rfTime) <= 1e-12 * max(sim.ehTime, sim.rfTime)
            denom = 1 + r.ehEfficiency * gain(end);
            phiStar = 1 / denom;
            oneMinusPhiStar = (r.ehEfficiency * gain(end)) / denom;
        else
            % Bisection on log10(q) where q = (1 - phi) / phi > 0 avoids
            % floating-point cancellation near phi = 1.
            interVec = zeros(1, count);
            for u = 1:count
                interVec(u) = sum(alphaOrdered(u+1:end));
            end
            lo = -30;
            hi = 30;
            for iter = 1:80
                mid = 0.5 * (lo + hi);
                qMid = 10^mid;
                phiMid = 1 / (1 + qMid);
                oneMinusMid = qMid / (1 + qMid);
                ehMid = phiMid * r.ehEfficiency * receivedPower * sim.ehTime;
                rfMid = ehMid / sim.rfTime;
                idMid = oneMinusMid * receivedPower;
                sinrDL = (rfMid .* alphaOrdered .* gain) ./ (r.noisePowerW + rfMid .* interVec .* gain);
                sinrUL = (idMid .* alphaOrdered) ./ (r.noisePowerW + idMid .* interVec);
                dlBits = sim.rfTime * r.bandwidthHz * log2(1 + sinrDL);
                ulBits = sim.ehTime * r.bandwidthHz * log2(1 + sinrUL);
                if min(ulBits - dlBits) >= 0
                    hi = mid; % q too large -> phi too small -> decrease q
                else
                    lo = mid; % q too small -> phi too large -> increase q
                end
            end
            qStar = 10^(0.5 * (lo + hi));
            phiStar = 1 / (1 + qStar);
            oneMinusPhiStar = qStar / (1 + qStar);
        end
        phiMin = 0;
        phiMax = 1 - 1e-12;
        if isfield(r, 'phiMin') && ~isempty(r.phiMin)
            phiMin = r.phiMin;
        end
        if isfield(r, 'phiMax') && ~isempty(r.phiMax)
            phiMax = r.phiMax;
        end
        if phiStar < phiMin
            phi = phiMin;
            oneMinusPhi = 1 - phiMin;
        elseif phiStar > phiMax
            phi = phiMax;
            oneMinusPhi = max(1 - phiMax, oneMinusPhiStar);
        else
            phi = phiStar;
            oneMinusPhi = oneMinusPhiStar;
        end
    end

    harvestedEnergy = phi * r.ehEfficiency * receivedPower * sim.ehTime;
    rfPower = harvestedEnergy / sim.rfTime;
    idPower = oneMinusPhi * receivedPower;

    dlRate = zeros(1, count);
    ulRate = zeros(1, count);
    for u = 1:count
        interference = sum(alphaOrdered(u+1:end));
        sinrDL = rfPower * alphaOrdered(u) * gain(u) / (r.noisePowerW + rfPower * interference * gain(u));
        dlRate(order(u)) = r.bandwidthHz * log2(1 + sinrDL);
        sinrUL = idPower * alphaOrdered(u) / (r.noisePowerW + idPower * interference);
        ulRate(order(u)) = r.bandwidthHz * log2(1 + sinrUL);
    end

    if ~isfield(r, 'enforceUlDlCausality') || r.enforceUlDlCausality
        rate = min(dlRate, ulRate * (sim.ehTime / sim.rfTime));
    else
        rate = dlRate;
    end
end
