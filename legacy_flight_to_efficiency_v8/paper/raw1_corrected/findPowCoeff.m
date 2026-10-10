function [coefArr_ch, coefArr_fr] = findPowCoeff(h, noUsers)
%FINDPOWCOEFF Implement the two power-allocation algorithms in the paper.

    h = reshape(real(h), 1, []);
    h = h(1:noUsers);
    hSum = sum(h);
    if hSum <= 0
        error('findPowCoeff:InvalidChannelGain', ...
            'Channel gains must contain at least one positive value.');
    end

    if noUsers == 1
        coefArr_ch = 1;
        coefArr_fr = 1;
        return;
    end

    % Algorithm 2: channel-gain based allocation.
    inCoeff = 1 - h / hSum;
    coefArr_ch = inCoeff / sum(inCoeff);

    % Algorithm 1: weakest channel receives the largest coefficient.
    [~, sortedIndex] = sort(h, 'ascend');
    p = paperParameters();
    delta = p.initialPowerFactor;
    coefArr_fr = zeros(1, noUsers);
    remaining = 1;
    for i = 1:noUsers
        index = sortedIndex(i);
        if i < noUsers
            coefArr_fr(index) = delta * remaining;
        else
            coefArr_fr(index) = remaining;
        end
        remaining = remaining - coefArr_fr(index);
    end
end
