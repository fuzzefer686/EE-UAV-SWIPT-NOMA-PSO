function rates = evaluateUAVRates(hUsers, hBS)
%EVALUATEUAVRATES Calculate all rates used by the paper workflow.

    noUsers = numel(hUsers);
    noBS = numel(hBS);

    [rates.coeffChannel, rates.coeffFraction] = ...
        findPowCoeff(abs(hUsers).^2, noUsers);

    [rates.userChannel, rates.userFraction] = ...
        findAchievableRate(hUsers, rates.coeffChannel, rates.coeffFraction, noUsers);

    rates.bs = findAchievableRate_BS(hBS, noBS);

    [rates.userChannelSWIPT, rates.userFractionSWIPT] = ...
        findAchievableRate_SWIPT(hUsers, hBS, ...
        rates.coeffChannel, rates.coeffFraction, noUsers);

    rates.minUser = min(rates.userChannel);
    rates.minUserSWIPT = min(rates.userChannelSWIPT);
end
