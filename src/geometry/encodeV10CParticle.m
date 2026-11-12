function particle = encodeV10CParticle(candidate,sim)
%ENCODEV10CPARTICLE Warm-start the reference search from a physical candidate.
    L=v10cSearchLayout(sim); values=L.lower;
    values(L.x)=candidate.waypoints(2:end-1,1).';
    values(L.y)=candidate.waypoints(2:end-1,2).';
    if ~isempty(L.xBS)
        values(L.xBS)=candidate.bsXY(:,1).'; values(L.yBS)=candidate.bsXY(:,2).';
    end
    % Search shares are rank-based; physical IDs are reconstructed by decoder.
    shares=sort(candidate.alpha,2,'descend');
    values(L.rawAlpha)=reshape(shares.',1,[]);
    h=candidate.uplinkTime+candidate.downlinkTime;
    if ~isempty(L.hover), values(L.hover)=h.'; end
    if ~isempty(L.fraction), values(L.fraction)=(candidate.uplinkTime./h).'; end
    width=L.upper-L.lower;
    particle=(values-L.lower)./max(width,realmin); particle(width==0)=0;
    particle=repairV10CParticle(particle,sim);
end
