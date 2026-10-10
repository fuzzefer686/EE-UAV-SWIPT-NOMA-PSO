function [minZ, z] = objective_function_positionUpdate_3D_SWIPT(x,xUAV,yUAV,zUAV,xBS,yBS,zBS,noUsers,xUser,yUser, g_NLoS_Users, g_NLoS_BS, noBS)
    %% Information for path loss model
    eta = 2.5;              % Path Loss Component
    b_0dB = -30;            % Reference Channel Gain in dB
    b_0 = db2pow(b_0dB);    % Reference Channel Gain in linear scale
    k = 0.01;               % Additional attenuation for NLoS
    
    %% Infromation for Rician Fading Model
    % Rician factor
    K_min = 4;      % K_min value in dB
    K_max = 12;     % K_max value in dB
    A1 = db2pow(K_min);
    A2 = (2/pi)*log((db2pow(K_max))/A1);

    % Khai báo tia Line of Sight
    g_LoS = 1; 
    %% 
    x_UAV = x(1) + xUAV;
    y_UAV = yUAV;
    z_UAV = x(2) + zUAV;
    
    for m=1:noUsers
        groundDisUAV_User(m) = sqrt((x_UAV-xUser(m))^2 + (y_UAV-yUser(m))^2);
        DisUAV_User(m) = sqrt(groundDisUAV_User(m)^2 + z_UAV^2);
        
        % Elavation Angle in radiant between UAVs and Users
        angleUAV_User(m) = atan(z_UAV/groundDisUAV_User(m))*(180/pi);
        
        pow_LoS = b_0*(DisUAV_User(m)^(-eta));
        
        % Angle depend rician factor
        K_UAV_User(m) = A1*exp(A2*angleUAV_User(m)*(pi/180));
 
        g_UAV_User(m) = sqrt(K_UAV_User(m)/(1+K_UAV_User(m)))*g_LoS + sqrt(1/(1+K_UAV_User(m)))*g_NLoS_Users(m);
        h_UAV_Users(m) = sqrt(pow_LoS)*g_UAV_User(m);
    end
    
    for bm=1:noBS
        groundDisUAV_BS(bm) = sqrt((x_UAV-xBS(bm))^2 + (y_UAV-yBS(bm))^2);
        DisUAV_BS(bm) = sqrt(groundDisUAV_BS(bm)^2 + (zBS(bm)-z_UAV)^2);
        
        % Elavation Angle in radiant between UAVs and BS
        angleUAV_BS(bm) = atan(abs(zBS(bm)-z_UAV)/groundDisUAV_BS(bm))*(180/pi);
        
        pow_LoS_BS = b_0*(DisUAV_BS(bm)^(-eta));
        
        % Angle depend rician factor
        K_UAV_BS(bm) = A1*exp(A2*angleUAV_BS(bm)*(pi/180));
        
        g_UAV_BS(bm) = sqrt(K_UAV_BS(bm)/(1+K_UAV_BS(bm)))*g_LoS + sqrt(1/(1+K_UAV_BS(bm)))*g_NLoS_BS(bm);
        h_UAV_BS(bm) = sqrt(pow_LoS_BS)*g_UAV_BS(bm);
    end
    
    [pow_coef_array_ch, pow_coef_array_fr] = findPowCoeff(abs(h_UAV_Users),noUsers);
    
    [achievableRate_ch, achievableRate_fr] = findAchievableRate_SWIPT(h_UAV_Users,h_UAV_BS,pow_coef_array_ch,pow_coef_array_fr,noUsers);
    
    minZ = min(achievableRate_ch);
    
    z = minZ;
end