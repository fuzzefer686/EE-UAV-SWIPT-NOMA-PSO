function [minZ, z] = objective_function_Joint_SWIPT(vars, xUAV, yUAV, zUAV, xBS, yBS, zBS, noUsers, xUser, yUser, g_NLoS_Users, g_NLoS_BS, noBS)

    %% BIẾN TỐI ƯU
    dx = vars(1);
    dz = vars(2);
    raw_p = vars(3:noUsers+2);

    % Alpha theo user gốc: [alpha_U1, alpha_U2, alpha_U3]
    raw_p = max(raw_p, 1e-12);
    alpha_user = raw_p / sum(raw_p);

    %% THÔNG SỐ KÊNH
    eta = 2.5;
    b_0 = db2pow(-30);

    A1 = db2pow(4);
    A2 = (2/pi) * log(db2pow(12) / A1);

    g_LoS = 1;

    % Tọa độ UAV mới
    x_UAV = xUAV + dx;
    y_UAV = yUAV;
    z_UAV = zUAV + dz;

    %% KÊNH BS -> UAV
    h_UAV_BS = zeros(1, noBS);
    for bm = 1:noBS
        groundDisUAV_BS = sqrt((x_UAV - xBS(bm))^2 + (y_UAV - yBS(bm))^2);
        DisUAV_BS = sqrt(groundDisUAV_BS^2 + (zBS(bm) - z_UAV)^2);
        angleUAV_BS = atan2(abs(zBS(bm) - z_UAV),groundDisUAV_BS) * (180/pi);

        pow_LoS_BS = b_0 * (DisUAV_BS^(-eta));
        K_UAV_BS = A1 * exp(A2 * angleUAV_BS * (pi/180));

        g_UAV_BS = sqrt(K_UAV_BS/(1+K_UAV_BS)) * g_LoS + sqrt(1/(1+K_UAV_BS)) * g_NLoS_BS(bm);

        h_UAV_BS(bm) = sqrt(pow_LoS_BS) * g_UAV_BS;
    end

    %% KÊNH UAV -> USERS
    h_UAV_Users = zeros(1, noUsers);
    for m = 1:noUsers
        groundDisUAV_User = sqrt((x_UAV - xUser(m))^2 + (y_UAV - yUser(m))^2);
        DisUAV_User = sqrt(groundDisUAV_User^2 + z_UAV^2);
        angleUAV_User = atan2(z_UAV, groundDisUAV_User) * (180/pi);

        pow_LoS = b_0 * (DisUAV_User^(-eta));
        K_UAV_User = A1 * exp(A2 * angleUAV_User * (pi/180));

        g_UAV_User = sqrt(K_UAV_User/(1+K_UAV_User)) * g_LoS + sqrt(1/(1+K_UAV_User)) * g_NLoS_Users(m);

        h_UAV_Users(m) = sqrt(pow_LoS) * g_UAV_User;
    end

    %% TÍNH RATE JOINT
    [achRate, alpha_ord, ~, ~] = findAchievableRate_SWIPT_Joint(h_UAV_Users, h_UAV_BS, alpha_user);

    trueMinRate = min(achRate);

    %% PENALTY NOMA
    % SIC order ở đây là weak -> strong
    % alpha phải giảm dần theo thứ tự:
    % alpha_ord(1) >= alpha_ord(2) >= ... >= alpha_ord(noUsers)
    tol = 1e-12;
    if any(diff(alpha_ord) > tol)
        penalty = 1e12;
    else
        penalty = 0;
    end

    %% FITNESS CHO PSO
    minZ = trueMinRate - penalty;   % fitness có penalty
    z = trueMinRate;                % giá trị min-rate thật
end