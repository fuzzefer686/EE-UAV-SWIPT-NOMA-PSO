function candidate = decodeV10CParticle(particle,sim)
%DECODEV10CPARTICLE Search decoder repairs geometry/times and assigns NOMA ranks.
% Direct evaluateV10CCandidate remains a strict, non-repairing API.
    L=v10cSearchLayout(sim); particle=repairV10CParticle(particle,sim);
    values=L.lower+particle.*(L.upper-L.lower);
    candidate=initialV10CCandidate(sim);
    candidate.waypoints(2:end-1,:)=[values(L.x).',values(L.y).'];
    if ~isempty(L.xBS)
        candidate.bsXY=[values(L.xBS).',values(L.yBS).'];
    end
    if isempty(L.hover)
        h=sim.hoverTime*ones(sim.numSlots,1);
    else
        h=values(L.hover).';
    end
    if isempty(L.fraction)
        f=(sim.ehTime/sim.hoverTime)*ones(sim.numSlots,1);
    else
        f=values(L.fraction).';
    end
    candidate.uplinkTime=h.*f; candidate.downlinkTime=h.*(1-f);
    raw=reshape(values(L.rawAlpha),sim.noUsers,sim.numSlots).';
    shares=sort(raw./sum(raw,2),2,'descend');
    users=[sim.xUser(:),sim.yUser(:),sim.zUser(:)];
    for t=1:sim.numSlots
        hUser=v10Channel([candidate.waypoints(t,:),sim.altitude], ...
            users,sim.gNLoSUsers,sim.radio);
        [~,order]=sort(abs(hUser).^2,'ascend');
        candidate.alpha(t,order)=shares(t,:);
    end
end
