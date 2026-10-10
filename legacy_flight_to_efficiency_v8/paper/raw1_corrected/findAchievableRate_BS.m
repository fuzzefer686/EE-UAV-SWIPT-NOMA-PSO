function ach_BS = findAchievableRate_BS(h_UAV_BS,noBS)

    % System Parameters
    p = paperParameters();
    B = p.bandwidth;
    Pt = p.PBSdBm;     % in dBm
    pt = (10^-3)*db2pow(Pt);	%in linear scale
    
    No = p.noiseDensitydBmHz + 10*log10(B);
    no = (10^-3)*db2pow(No);
    
    abh_h_UAV_BS = (abs(h_UAV_BS)).^2;
    
    % The paper numbers BSs in ascending channel strength. At SIC stage i,
    % the remaining stronger BSs (i+1:end) are interference.
    [abh_h_UAV_BS_sort, order] = sort(abh_h_UAV_BS, 'ascend');
    
    ach_BS = zeros(1,noBS);
    
    for i=1:noBS
        index = order(i);
        interference = sum(abh_h_UAV_BS_sort(i+1:end));
        ach_BS(index) = B*log2(1 + pt*abh_h_UAV_BS_sort(i) / ...
            (no + pt * interference));
    end

end
