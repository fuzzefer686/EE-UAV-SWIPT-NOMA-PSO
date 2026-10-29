function layout = v10ParticleLayout(sim, optimizeBS)
%V10PARTICLELAYOUT V9 block order with fixed Z removed (A) or replaced by Y (B).
    n=sim.numSteps-2; layout.x=1:n; layout.y=[];
    if strcmp(sim.variant,'B')
        layout.y=n+(1:n);
    end
    layout.positionCount=n+numel(layout.y);
    layout.alpha=layout.positionCount+(1:sim.numSteps*sim.noUsers);
    next=layout.positionCount+sim.numSteps*sim.noUsers;
    layout.xBS=[]; layout.yBS=[];
    if optimizeBS
        layout.xBS=next+(1:sim.noBS);
        layout.yBS=next+sim.noBS+(1:sim.noBS);
        next=next+2*sim.noBS;
    end
    layout.dimension=next;
end
