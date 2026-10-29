function q = decodeV10Particle(particle, sim, optimizeBS)
%DECODEV10PARTICLE Decode without silently repairing candidate constraints.
    layout=v10ParticleLayout(sim,optimizeBS);
    validateattributes(particle,{'numeric'},{'real','vector','numel',layout.dimension});
    particle=particle(:).';
    q.xTraj=[sim.xStart,particle(layout.x),sim.xEnd];
    q.yTraj=sim.stepsVec;
    if ~isempty(layout.y)
        q.yTraj=[sim.yStart,particle(layout.y),sim.yEnd];
    end
    q.zTraj=sim.altitude*ones(1,sim.numSteps);
    q.rawAlpha=reshape(particle(layout.alpha),sim.noUsers,sim.numSteps).';
    % The final waypoint is an arrival point with no hover/RF slot. Its alpha
    % row is kept for trace compatibility but made inert; the last block of
    % particle weights therefore cannot affect bits, energy or fitness.
    q.rawAlpha(end,:)=1/sim.noUsers;
    q.xBS=sim.xBS; q.yBS=sim.yBS; q.zBS=sim.zBS;
    if optimizeBS
        q.xBS=particle(layout.xBS); q.yBS=particle(layout.yBS);
    end
end
