function layout = v11ParticleLayout(sim, optimizeBS)
%V11PARTICLELAYOUT V9 block order with fixed Z removed (A) or replaced by Y (B).
    n=sim.numSteps-2; layout.x=1:n; layout.y=[];
    if strcmp(sim.variant,'B')
        layout.y=n+(1:n);
    end
    layout.positionCount=n+numel(layout.y);
    mode=getSimField(sim,'alphaMode','particle');
    switch mode
        case 'particle'
            % Preserve all T*U weights, including the inert arrival row (V10 parity).
            layout.alpha=layout.positionCount+(1:sim.numSteps*sim.noUsers);
        case 'uniform'
            layout.alpha=[];
        otherwise
            error('v11ParticleLayout:AlphaMode','Unknown alpha mode.');
    end
    next=layout.positionCount+numel(layout.alpha);
    layout.xBS=[]; layout.yBS=[];
    if optimizeBS
        layout.xBS=next+(1:sim.noBS);
        layout.yBS=next+sim.noBS+(1:sim.noBS);
        next=next+2*sim.noBS;
    end
    layout.dimension=next;
end

function value = getSimField(s, name, fallback)
    if isfield(s,name) && ~isempty(s.(name))
        value=s.(name);
    else
        value=fallback;
    end
end
