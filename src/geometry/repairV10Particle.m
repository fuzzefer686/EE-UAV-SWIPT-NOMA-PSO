function particle = repairV10Particle(particle, sim, optimizeBS)
%REPAIRV10PARTICLE Clip V9-style blocks and enforce directed progress in B.
    layout=v10ParticleLayout(sim,optimizeBS);
    validateattributes(particle,{'numeric'},{'real','finite','vector','numel',layout.dimension});
    particle=particle(:).';
    particle(layout.x)=min(max(particle(layout.x),sim.x_min),sim.x_max);
    if ~isempty(layout.y)
        k=1:numel(layout.y); slack=abs(sim.yEnd-sim.yStart)-(sim.numSteps-1)*sim.minYProgress;
        % Residual progress is monotone in [0,slack]; restore compulsory gaps.
        residual=sim.yDirection*(particle(layout.y)-sim.yStart)-k*sim.minYProgress;
        residual=sort(min(max(residual,0),slack));
        particle(layout.y)=sim.yStart+sim.yDirection*(k*sim.minYProgress+residual);
    end
    alpha=reshape(particle(layout.alpha),sim.noUsers,sim.numSteps).';
    alpha=min(max(alpha,sim.pMin),sim.pMax);
    alpha=alpha./sum(alpha,2);
    particle(layout.alpha)=reshape(alpha.',1,[]);
    if optimizeBS
        particle(layout.xBS)=min(max(particle(layout.xBS),sim.xBS_min),sim.xBS_max);
        particle(layout.yBS)=min(max(particle(layout.yBS),sim.yBS_min),sim.yBS_max);
    end
end
