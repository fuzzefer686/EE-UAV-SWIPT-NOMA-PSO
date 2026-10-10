function p = paperParameters()
%PAPERPARAMETERS Parameters taken from Table I of the paper.

    p.environmentWidth = 2000;
    p.environmentLength = 2000;
    p.environmentHeight = 320;
    p.noUsers = 3;
    p.noBS = 3;
    p.noUAV = 1;

    p.pathLossExponent = 2.5;
    p.referenceGaindB = -50;
    p.KminDB = 4;
    p.KmaxDB = 12;

    p.energyEfficiency = 0.7;
    p.powerSplit = 0.7;
    p.PBSdBm = 46;
    p.PGUdBm = 20;
    p.initialPowerFactor = 0.8;

    p.startPosition = [1000, 2000, 200];
    p.endPosition = [1000, 0, 200];
    p.zMin = 100;
    p.zMax = 300;
    p.xStepMax = 500;
    p.yStep = 100;

    p.bandwidth = 1e6;
    p.noiseDensitydBmHz = -174;
    p.uplinkTime = 1e-6;
    p.downlinkTime = 1e-6;
    p.powerSweepdBm = 0:2:60;

    % The paper does not tabulate the fixed coefficients; this is the
    % [0.7, 0.2, 0.1] convention used for the comparison figure.
    p.fixedPowerCoefficients = [0.7, 0.2, 0.1];
end
