function candidate = decodeV10CGeometry(particle, resources, sim, optimizeBS)
%DECODEV10CGEOMETRY Decode without repair; preserve resource block values.
    if nargin<4, optimizeBS=true; end
    layout=v10cGeometryLayout(sim,optimizeBS);
    validateattributes(particle,{'numeric'}, ...
        {'real','finite','vector','numel',layout.dimension});
    particle=particle(:).'; candidate=resources;
    candidate.waypoints=[sim.xStart,sim.yStart; ...
        particle(layout.x).',particle(layout.y).';sim.xEnd,sim.yEnd];
    if optimizeBS
        candidate.bsXY=[particle(layout.xBS).',particle(layout.yBS).'];
    end
end
