function rawAlpha = alphaPolicyV11(sim)
%ALPHAPOLICYV11 Deterministic T-by-U uniform policy, without random draws.
    mode=getSimField(sim,'alphaMode','uniform');
    if ~strcmp(mode,'uniform')
        error('alphaPolicyV11:Mode','Policy requires alphaMode=uniform.');
    end
    rawAlpha=ones(sim.numSteps,sim.noUsers)/sim.noUsers;
end

function value = getSimField(s, name, fallback)
    if isfield(s,name) && ~isempty(s.(name))
        value=s.(name);
    else
        value=fallback;
    end
end
