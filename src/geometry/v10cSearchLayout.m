function layout = v10cSearchLayout(sim)
%V10CSEARCHLAYOUT Joint reference PSO blocks; all coordinates normalized to [0,1].
    optimizeBS=true;
    if isfield(sim,'searchOptimizeBS'), optimizeBS=sim.searchOptimizeBS; end
    layout=v10cGeometryLayout(sim,optimizeBS);
    next=layout.dimension;
    layout.rawAlpha=next+(1:sim.numSlots*sim.noUsers); next=next+numel(layout.rawAlpha);
    layout.hover=[]; layout.fraction=[];
    if strcmp(sim.time.hoverMode,'variable')
        layout.hover=next+(1:sim.numSlots); next=next+sim.numSlots;
    end
    if strcmp(sim.time.splitMode,'variable')
        layout.fraction=next+(1:sim.numSlots); next=next+sim.numSlots;
    end
    layout.dimension=next; lo=zeros(1,next); hi=ones(1,next);
    lo(layout.x)=sim.x_min; hi(layout.x)=sim.x_max;
    lo(layout.y)=sim.y_min; hi(layout.y)=sim.y_max;
    if optimizeBS
        lo(layout.xBS)=sim.xBS_min; hi(layout.xBS)=sim.xBS_max;
        lo(layout.yBS)=sim.yBS_min; hi(layout.yBS)=sim.yBS_max;
    end
    lo(layout.rawAlpha)=sim.pMin; hi(layout.rawAlpha)=sim.pMax;
    if ~isempty(layout.hover)
        lo(layout.hover)=sim.time.hoverBounds(1); hi(layout.hover)=sim.time.hoverBounds(2);
    end
    if ~isempty(layout.fraction)
        lo(layout.fraction)=sim.time.ehFractionBounds(1);
        hi(layout.fraction)=sim.time.ehFractionBounds(2);
    end
    layout.lower=lo; layout.upper=hi;
end
