function [ach_ch, ach_fr] = findAchievableRate_SWIPT(h_UAV_Users,h_UAV_BS,coefArr_ch,coefArr_fr,noUsers)
    
    % System Parameters
    B = 10^6;
        
    No = -174 + 10*log10(B);
    no = (10^-3)*db2pow(No);
    
    Pr = 46;     % trainsmit power BS in dBm
    pr = (10^-3)*db2pow(Pr);	%in linear scale
    
    T_uplink = 1*10^-6;
    T_downlink = 1*10^-6;
    eta = 0.7;       % Energy-harvesting efficiency from the paper.
    phi = 0.7;       % Power-splitting coefficient from the paper.

    % P_r = P_BS * sum_m |h_BS,m|^2, then P_GU,e = eta*phi*P_r.
    receivedPower = pr * sum(abs(h_UAV_BS).^2);
    harvestedEnergy = eta * phi * receivedPower * T_uplink;
    pt = harvestedEnergy / T_downlink;
    
    
    abh_h_UAV_Users = (abs(h_UAV_Users)).^2;

    
    [coefArr_ch_sort, order_ch] = sort(coefArr_ch, 'ascend');
    [coefArr_fr_sort, order_fr] = sort(coefArr_fr, 'ascend');
    ach_ch = zeros(1,noUsers);
    ach_fr = zeros(1,noUsers);
    
    for i = 1:noUsers
        if i == 1
            index = order_ch(i);
            index_fr = order_fr(i);
            ach_ch(index) = B*log2(1 + pt*coefArr_ch_sort(i)*abh_h_UAV_Users(index)/(no));
            ach_fr(index_fr) = B*log2(1 + pt*coefArr_fr_sort(i)*abh_h_UAV_Users(index_fr)/(no));
        else
            index = order_ch(i);
            index_fr = order_fr(i);
            ach_ch(index) = B*log2(1 + pt*coefArr_ch_sort(i)*abh_h_UAV_Users(index)/(no + pt*sum(coefArr_ch_sort(1:i-1))*abh_h_UAV_Users(index)));
            ach_fr(index_fr) = B*log2(1 + pt*coefArr_fr_sort(i)*abh_h_UAV_Users(index_fr)/(no + pt*sum(coefArr_fr_sort(1:i-1))*abh_h_UAV_Users(index_fr)));
        end
    end
   
end
