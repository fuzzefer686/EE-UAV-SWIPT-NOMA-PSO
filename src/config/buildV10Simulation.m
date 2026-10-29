function sim = buildV10Simulation(cfg, variant)
%BUILDV10SIMULATION Validate common configuration and draw a V9-style scenario.
% Caller sets rng explicitly. User/fading draw ordering matches V9.
    variant=upper(char(variant));
    if ~any(strcmp(variant,{'A','B'}))
        error('buildV10Simulation:Variant','Variant must be A or B.');
    end
    g=cfg.geometry; r=cfg.radio; mission=cfg.mission;
    validateattributes(g.numWaypoints,{'numeric'},{'integer','scalar','>=',3});
    validateattributes(g.noUsers,{'numeric'},{'integer','scalar','>=',2});
    validateattributes(g.width,{'numeric'},{'scalar','real','finite','positive'});
    validateattributes(g.length,{'numeric'},{'scalar','real','finite','positive'});
    validateattributes(g.altitude,{'numeric'},{'scalar','real','finite','positive'});
    validateattributes(g.xBounds,{'numeric'},{'real','finite','vector','numel',2});
    validateattributes(g.startXY,{'numeric'},{'real','finite','vector','numel',2});
    validateattributes(g.endXY,{'numeric'},{'real','finite','vector','numel',2});
    validateattributes(g.bsXYZ,{'numeric'},{'real','finite','2d','nonempty'});
    if size(g.bsXYZ,2)~=3
        error('buildV10Simulation:BSSize','bsXYZ must have one [X,Y,Z] row per BS.');
    end
    validateattributes(g.bsMargin,{'numeric'},{'real','finite','scalar','nonnegative'});
    if g.xBounds(1)>=g.xBounds(2) || g.xBounds(1)<0 || g.xBounds(2)>g.width ...
            || any([g.startXY(1),g.endXY(1)]<g.xBounds(1)) ...
            || any([g.startXY(1),g.endXY(1)]>g.xBounds(2)) ...
            || any([g.startXY(2),g.endXY(2)]<0) ...
            || any([g.startXY(2),g.endXY(2)]>g.length)
        error('buildV10Simulation:Bounds','Endpoints and X bounds must be inside the region.');
    end
    validateattributes(g.minYProgress,{'numeric'},{'real','finite','scalar','positive'});
    span=abs(g.endXY(2)-g.startXY(2)); segments=g.numWaypoints-1;
    if span==0 || (strcmp(variant,'B') && segments*g.minYProgress>span)
        error('buildV10Simulation:YProgress','Endpoints cannot support the requested Y progress.');
    end
    validateattributes(mission.hoverTime,{'numeric'},{'real','finite','scalar','positive'});
    validateattributes(mission.ehFraction,{'numeric'}, ...
        {'real','finite','scalar','>',0,'<',1});
    validateattributes(mission.energyBudgetJ,{'numeric'},{'real','scalar','positive'});
    validateattributes(mission.minBitsPerUser,{'numeric'}, ...
        {'real','finite','nonnegative','vector','nonempty'});
    if ~isscalar(mission.minBitsPerUser) && numel(mission.minBitsPerUser)~=g.noUsers
        error('buildV10Simulation:DataTarget','L needs one entry per physical user or a scalar.');
    end
    validateattributes(mission.minBitsPerSlot,{'numeric'}, ...
        {'real','finite','nonnegative','scalar'});
    validateattributes(mission.minBitsPerUserPerSlot,{'numeric'}, ...
        {'real','finite','nonnegative','nonempty'});
    if ~isscalar(mission.minBitsPerUserPerSlot) ...
            && numel(mission.minBitsPerUserPerSlot)~=g.noUsers
        error('buildV10Simulation:SlotTarget', ...
            'minBitsPerUserPerSlot needs one entry per physical user or a scalar.');
    end
    validateattributes(r.bsPowerDbm,{'numeric'},{'real','finite','scalar'});
    validateattributes(r.bandwidthHz,{'numeric'},{'real','finite','scalar','positive'});
    validateattributes(r.noiseDensityDbmHz,{'numeric'},{'real','finite','scalar'});
    validateattributes(r.powerSplit,{'numeric'},{'real','finite','scalar','>=',0,'<=',1});
    validateattributes(r.ehEfficiency,{'numeric'},{'real','finite','scalar','>=',0,'<=',1});
    validateattributes(r.pathLossExponent,{'numeric'},{'real','finite','scalar','positive'});
    validateattributes(r.referenceGainDb,{'numeric'},{'real','finite','scalar'});
    validateattributes(r.ricianMinDb,{'numeric'},{'real','finite','scalar'});
    validateattributes(r.ricianMaxDb,{'numeric'},{'real','finite','scalar','>=',r.ricianMinDb});
    validateattributes(r.losAmplitude,{'numeric'},{'real','finite','scalar','nonnegative'});
    validateattributes(r.pMin,{'numeric'},{'real','finite','scalar','positive'});
    validateattributes(r.pMax,{'numeric'},{'real','finite','scalar','>=',r.pMin});
    if r.pMax<1
        warning('V10:pMaxRawOnly', ...
            ['pMax bounds raw alpha weights before row normalization; ', ...
             'the normalized alpha can still exceed pMax.']);
    end
    validateattributes(cfg.flight.cruiseSpeed,{'numeric'},{'real','finite','scalar','positive'});
    sim.variant=variant; sim.objectiveMode='ee-uav-drones';
    sim.numSteps=g.numWaypoints; sim.noUsers=g.noUsers; sim.noBS=size(g.bsXYZ,1);
    sim.xStart=g.startXY(1); sim.yStart=g.startXY(2);
    sim.xEnd=g.endXY(1); sim.yEnd=g.endXY(2); sim.altitude=g.altitude;
    sim.stepsVec=linspace(sim.yStart,sim.yEnd,sim.numSteps);
    sim.yDirection=sign(sim.yEnd-sim.yStart); sim.minYProgress=g.minYProgress;
    sim.x_min=g.xBounds(1); sim.x_max=g.xBounds(2);
    sim.y_min=min(sim.yStart,sim.yEnd); sim.y_max=max(sim.yStart,sim.yEnd);
    sim.xBS=g.bsXYZ(:,1).'; sim.yBS=g.bsXYZ(:,2).'; sim.zBS=g.bsXYZ(:,3).';
    sim.xBS_min=max(0,sim.xBS-g.bsMargin); sim.xBS_max=min(g.width,sim.xBS+g.bsMargin);
    sim.yBS_min=max(0,sim.yBS-g.bsMargin); sim.yBS_max=min(g.length,sim.yBS+g.bsMargin);
    if any(sim.xBS<0 | sim.xBS>g.width | sim.yBS<0 | sim.yBS>g.length)
        error('buildV10Simulation:BSBounds','Initial BS positions must be inside the region.');
    end
    sim.xUser=zeros(1,sim.noUsers); sim.yUser=zeros(1,sim.noUsers);
    sim.zUser=zeros(1,sim.noUsers);
    for k=1:sim.noUsers
        sim.xUser(k)=randi([ceil(g.width/4),floor(3*g.width/4)]);
        sim.yUser(k)=randi([ceil(g.length/4),floor(3*g.length/4)]);
    end
    sim.gNLoSUsers=sqrt(1/2)*(randn(1,sim.noUsers)+1i*randn(1,sim.noUsers));
    sim.gNLoSBS=sqrt(1/2)*(randn(1,sim.noBS)+1i*randn(1,sim.noBS));
    sim.radio=r; sim.radio.bsPowerW=1e-3*10^(r.bsPowerDbm/10);
    sim.radio.noisePowerW=1e-3*10^((r.noiseDensityDbmHz+10*log10(r.bandwidthHz))/10);
    sim.radio.referenceGain=10^(r.referenceGainDb/10);
    sim.radio.A1=10^(r.ricianMinDb/10);
    sim.radio.A2=(2/pi)*log(10^(r.ricianMaxDb/10)/sim.radio.A1);
    sim.hoverTime=mission.hoverTime; sim.ehTime=mission.hoverTime*mission.ehFraction;
    sim.rfTime=mission.hoverTime*(1-mission.ehFraction);
    sim.minBitsPerUser=mission.minBitsPerUser(:).';
    sim.minBitsPerSlot=mission.minBitsPerSlot;
    sim.minBitsPerUserPerSlot=mission.minBitsPerUserPerSlot(:).';
    sim.energyBudgetJ=mission.energyBudgetJ;
    sim.flight=cfg.flight;
    [sim.cruisePower,sim.cruisePowerParts]=dronePropulsionPower(cfg.flight.cruiseSpeed,cfg.flight);
    [sim.hoverPower,sim.hoverPowerParts]=dronePropulsionPower(0,cfg.flight);
    sim.pMin=r.pMin; sim.pMax=r.pMax;
    sim.feasibilityTolerance=1e-10;
end
