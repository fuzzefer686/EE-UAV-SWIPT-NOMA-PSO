function [rate, alphaOrdered, order, rfPower, harvestedEnergy] = findAchievableRateV10(hUsers, hBS, alphaUser, sim)
%FINDACHIEVABLERATEV10 V9 ideal-SIC NOMA with configured EH and phase times.
% EH supplies RF only; PA/circuit costs are outside the inherited RF model.
    r=sim.radio;
    % Same tiny numerical guard as V9. pMin bounds raw optimizer weights only.
    alphaUser=max(real(alphaUser(:)).',1e-12);
    alphaUser=alphaUser/sum(alphaUser);
    receivedPower=r.bsPowerW*sum(abs(hBS).^2);
    harvestedEnergy=r.powerSplit*r.ehEfficiency*receivedPower*sim.ehTime;
    rfPower=harvestedEnergy/sim.rfTime;
    [gain,order]=sort(abs(hUsers).^2,'ascend');
    alphaOrdered=alphaUser(order);
    count=numel(alphaUser); rate=zeros(1,count);
    for u=1:count
        interference=sum(alphaOrdered(u+1:end));
        sinr=rfPower*alphaOrdered(u)*gain(u)/(r.noisePowerW+rfPower*interference*gain(u));
        rate(order(u))=r.bandwidthHz*log2(1+sinr);
    end
end
