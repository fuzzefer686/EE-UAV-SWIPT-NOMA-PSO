function particle = repairV10CParticle(particle,sim)
%REPAIRV10CPARTICLE Repair normalized search coordinates, not raw evaluator inputs.
    L=v10cSearchLayout(sim);
    validateattributes(particle,{'numeric'},{'real','finite','vector','numel',L.dimension});
    particle=min(max(particle(:).',0),1);
    values=L.lower+particle.*(L.upper-L.lower);
    k=1:numel(L.y); gap=sim.minYProgress;
    slack=abs(sim.yEnd-sim.yStart)-(sim.numSteps-1)*gap;
    residual=sim.yDirection*(values(L.y)-sim.yStart)-k*gap;
    residual=sort(min(max(residual,0),slack));
    values(L.y)=sim.yStart+sim.yDirection*(k*gap+residual);
    if ~isempty(L.hover)
        h=values(L.hover); hmin=sim.time.hoverBounds(1);
        budget=sim.time.totalHoverMax;
        if budget<=sim.numSlots*hmin
            h(:)=hmin;
        elseif sum(h)>budget
            extra=h-hmin;
            if sum(extra)>0
                h=hmin+extra*((budget-sim.numSlots*hmin)/sum(extra));
            else
                h(:)=hmin;
            end
        end
        values(L.hover)=h;
    end
    width=L.upper-L.lower;
    particle=(values-L.lower)./max(width,realmin);
    particle(width==0)=0;
    particle=min(max(particle,0),1);
end
