function [rate, alphaOrdered, order, rfPower, harvestedEnergy, phi, ulRate, dlRate] = findAchievableRateV12(hUsers, hBS, alphaUser, sim)
%FINDACHIEVABLERATEV12 Causal DF NOMA with sum-rate-optimal or fixed power splitting.
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
        phiMin = r.phiMin;
        phiMax = r.phiMax;
        enforceCausal = ~isfield(r, 'enforceUlDlCausality') || logical(r.enforceUlDlCausality);

        if ~enforceCausal
            phi = phiMax;
            oneMinusPhi = 1 - phiMax;
        elseif receivedPower <= 0 || max(gain) <= 0 || sim.ehTime <= 0 ...
                || sim.rfTime <= 0 || r.noisePowerW <= 0
            phi = min(max(r.powerSplit, phiMin), phiMax);
            oneMinusPhi = 1 - phi;
        elseif phiMin >= phiMax
            phi = phiMin;
            oneMinusPhi = 1 - phiMin;
        else
            kappa = sim.ehTime / sim.rfTime;
            interVec = zeros(1, count);
            for u = 1:count
                interVec(u) = sum(alphaOrdered(u+1:end));
            end
            totVec = interVec + alphaOrdered;
            mNorm = (r.ehEfficiency * receivedPower * kappa / r.noisePowerW) .* gain;
            pNorm = receivedPower / r.noisePowerW;
            derivScale = r.bandwidthHz / log(2);

            [sMinusMax, ~] = evalCausalSupergrad(phiMax, 1 - phiMax, alphaOrdered, ...
                interVec, totVec, gain, mNorm, pNorm, derivScale, kappa, ...
                receivedPower, r, sim.ehTime, sim.rfTime);
            if sMinusMax >= 0
                phi = phiMax;
                oneMinusPhi = 1 - phiMax;
            else
                [~, sPlusMin] = evalCausalSupergrad(phiMin, 1 - phiMin, alphaOrdered, ...
                    interVec, totVec, gain, mNorm, pNorm, derivScale, kappa, ...
                    receivedPower, r, sim.ehTime, sim.rfTime);
                if sPlusMin <= 0
                    phi = phiMin;
                    oneMinusPhi = 1 - phiMin;
                else
                    kinkPhi = zeros(1, 0);
                    kinkPsi = zeros(1, 0);
                    foundExactKink = false;
                    if sim.ehTime == sim.rfTime && r.ehEfficiency > 0
                        uGains = unique(gain(gain > 0), 'stable');
                        for k = 1:numel(uGains)
                            gk = uGains(k);
                            denom = 1 + r.ehEfficiency * gk;
                            pk = 1 / denom;
                            qk = (r.ehEfficiency * gk) / denom;
                            if pk > phiMin && pk < phiMax
                                kinkPhi(end+1) = pk; %#ok<AGROW>
                                kinkPsi(end+1) = qk; %#ok<AGROW>
                                dDLk = derivScale .* (mNorm .* alphaOrdered) ...
                                    ./ ((1 + pk .* mNorm .* totVec) .* (1 + pk .* mNorm .* interVec));
                                dULk = -derivScale .* (pNorm .* alphaOrdered) ...
                                    ./ ((1 + qk .* pNorm .* totVec) .* (1 + qk .* pNorm .* interVec));
                                sMinusK = sum(dDLk(gain <= gk)) + sum(dULk(gain > gk));
                                sPlusK = sum(dDLk(gain < gk)) + sum(dULk(gain >= gk));
                                if sMinusK >= 0 && sPlusK <= 0
                                    phi = pk;
                                    oneMinusPhi = qk;
                                    foundExactKink = true;
                                    break;
                                end
                            end
                        end
                    end

                    if ~foundExactKink
                        if phiMax >= 1
                            zLo = -30;
                        else
                            zLo = max(-300, log10((1 - phiMax) / phiMax));
                        end
                        if phiMin <= 0
                            zHi = 30;
                        else
                            zHi = min(300, log10((1 - phiMin) / phiMin));
                        end

                        for iter = 1:80
                            zMid = 0.5 * (zLo + zHi);
                            qMid = 10^zMid;
                            phiMid = 1 / (1 + qMid);
                            psiMid = qMid / (1 + qMid);
                            [sMinus, sPlus] = evalCausalSupergrad(phiMid, psiMid, alphaOrdered, ...
                                interVec, totVec, gain, mNorm, pNorm, derivScale, kappa, ...
                                receivedPower, r, sim.ehTime, sim.rfTime);
                            if sMinus >= 0 && sPlus <= 0
                                zLo = zMid;
                                zHi = zMid;
                                break;
                            elseif sPlus > 0
                                zHi = zMid;
                            else
                                zLo = zMid;
                            end
                        end

                        qBis = 10^(0.5 * (zLo + zHi));
                        phiBis = 1 / (1 + qBis);
                        psiBis = qBis / (1 + qBis);
                        if phiBis < phiMin
                            phiBis = phiMin;
                            psiBis = 1 - phiMin;
                        elseif phiBis > phiMax
                            phiBis = phiMax;
                            psiBis = 1 - phiMax;
                        end

                        candPhi = [kinkPhi, phiBis, phiMin, phiMax];
                        candPsi = [kinkPsi, psiBis, 1 - phiMin, 1 - phiMax];
                        bestSum = -inf;
                        phi = phiBis;
                        oneMinusPhi = psiBis;
                        for k = 1:numel(candPhi)
                            sVal = evalCausalSumRate(candPhi(k), candPsi(k), alphaOrdered, ...
                                interVec, gain, kappa, receivedPower, r, sim.ehTime, sim.rfTime);
                            if sVal > bestSum
                                bestSum = sVal;
                                phi = candPhi(k);
                                oneMinusPhi = candPsi(k);
                            end
                        end
                    end
                end
            end
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

function [sMinus, sPlus] = evalCausalSupergrad(phiVal, psiVal, alphaOrd, interVec, totVec, ...
        gain, mNorm, pNorm, derivScale, kappa, receivedPower, r, ehTime, rfTime)
    ehVal = phiVal * r.ehEfficiency * receivedPower * ehTime;
    rfVal = ehVal / rfTime;
    idVal = psiVal * receivedPower;
    sinrDL = (rfVal .* alphaOrd .* gain) ./ (r.noisePowerW + rfVal .* interVec .* gain);
    sinrUL = (idVal .* alphaOrd) ./ (r.noisePowerW + idVal .* interVec);
    dlR = r.bandwidthHz * log2(1 + sinrDL);
    ulScaled = kappa * (r.bandwidthHz * log2(1 + sinrUL));
    dDL = derivScale .* (mNorm .* alphaOrd) ...
        ./ ((1 + phiVal .* mNorm .* totVec) .* (1 + phiVal .* mNorm .* interVec));
    dUL = -derivScale .* (pNorm .* alphaOrd) ...
        ./ ((1 + psiVal .* pNorm .* totVec) .* (1 + psiVal .* pNorm .* interVec));
    maskMinus = (dlR <= ulScaled);
    maskPlus = (dlR < ulScaled);
    sMinus = sum(dDL(maskMinus)) + kappa * sum(dUL(~maskMinus));
    sPlus = sum(dDL(maskPlus)) + kappa * sum(dUL(~maskPlus));
end

function sVal = evalCausalSumRate(phiVal, psiVal, alphaOrd, interVec, gain, kappa, ...
        receivedPower, r, ehTime, rfTime)
    ehVal = phiVal * r.ehEfficiency * receivedPower * ehTime;
    rfVal = ehVal / rfTime;
    idVal = psiVal * receivedPower;
    sinrDL = (rfVal .* alphaOrd .* gain) ./ (r.noisePowerW + rfVal .* interVec .* gain);
    sinrUL = (idVal .* alphaOrd) ./ (r.noisePowerW + idVal .* interVec);
    dlR = r.bandwidthHz * log2(1 + sinrDL);
    ulR = r.bandwidthHz * log2(1 + sinrUL);
    sVal = sum(min(dlR, kappa * ulR));
end
