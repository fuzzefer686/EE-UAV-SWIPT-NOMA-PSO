function [achRate, alpha_ord, idxWeak2Strong, pt] = findAchievableRate_SWIPT_Joint(h_UAV_Users, h_UAV_BS, alpha_user)

    B = 1e6;

    No = -174 + 10*log10(B);
    no_pow = (10^-3) * db2pow(No);
    
    Pr = 46;                      % transmit power BS in dBm
    pr = (10^-3) * db2pow(Pr);    % linear scale
    
    T = 1e-6;
    phy = 0.9;
    neta = 0.9;
    
    % Normalize alpha
    alpha_user = real(alpha_user(:)).';
    alpha_user = max(alpha_user, 1e-12);
    alpha_user = alpha_user / sum(alpha_user);
    
    % SWIPT harvested transmit power
    E_h = phy * neta * pr * sum(abs(h_UAV_BS).^2) * T;
    pt = E_h / T;
    % SIC order: weak user -> strong user
    h2 = abs(h_UAV_Users).^2;
    [h2_ord, idxWeak2Strong] = sort(h2, 'ascend');

    % Only reorder alpha into SIC order, not sort alpha by value
    alpha_ord = alpha_user(idxWeak2Strong);

    % Achievable rate
    noUsers = numel(alpha_user);
    achRate = zeros(1, noUsers);

    for u = 1:noUsers
        if u < noUsers
            % weaker user sees interference from stronger users
            interf = sum(alpha_ord(u+1:end));
        else
            % strongest user
            interf = 0;
        end

        SINR = (pt * alpha_ord(u) * h2_ord(u)) / (no_pow + pt * interf * h2_ord(u));

        % map back to original user index
        achRate(idxWeak2Strong(u)) = B * log2(1 + SINR);
    end
end