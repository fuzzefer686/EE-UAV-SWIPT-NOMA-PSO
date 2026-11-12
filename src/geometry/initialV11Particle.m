function particle = initialV11Particle(sim, optimizeBS, randomize)
%INITIALV11PARTICLE Straight/equal-alpha seed or V9-style uniform random draw.
    layout=v11ParticleLayout(sim,optimizeBS);
    particle=zeros(1,layout.dimension);
    x=linspace(sim.xStart,sim.xEnd,sim.numSteps);
    particle(layout.x)=x(2:end-1);
    if ~isempty(layout.y)
        particle(layout.y)=sim.stepsVec(2:end-1);
    end
    if ~isempty(layout.alpha)
        particle(layout.alpha)=1/sim.noUsers;
    end
    if optimizeBS
        particle(layout.xBS)=sim.xBS; particle(layout.yBS)=sim.yBS;
    end
    if randomize
        particle(layout.x)=sim.x_min+rand(1,numel(layout.x))*(sim.x_max-sim.x_min);
        if ~isempty(layout.y)
            particle(layout.y)=sim.y_min+rand(1,numel(layout.y))*(sim.y_max-sim.y_min);
        end
        if ~isempty(layout.alpha)
            particle(layout.alpha)=sim.pMin+rand(1,numel(layout.alpha))*(sim.pMax-sim.pMin);
        end
        if optimizeBS
            particle(layout.xBS)=sim.xBS_min+rand(1,sim.noBS).*(sim.xBS_max-sim.xBS_min);
            particle(layout.yBS)=sim.yBS_min+rand(1,sim.noBS).*(sim.yBS_max-sim.yBS_min);
        end
    end
    particle=repairV11Particle(particle,sim,optimizeBS);
end
