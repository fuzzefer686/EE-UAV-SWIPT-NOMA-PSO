function sim = buildV10CSimulation(cfg)
%BUILDV10CSIMULATION Validate V10C settings and preserve the caller RNG state.
    modes={'steady-drones','rest-to-rest-experimental'};
    if ~any(strcmp(cfg.motion.mode,modes))
        error('V10C:MotionMode','Unknown movement energy model.');
    end
    validateattributes(cfg.motion.allowExperimental,{'logical'},{'scalar'});
    if strcmp(cfg.motion.mode,'rest-to-rest-experimental') && ~cfg.motion.allowExperimental
        error('V10C:ExperimentalOptIn', ...
            'C5 is unvalidated research physics. Set motion.allowExperimental=true explicitly.');
    end
    validateattributes(cfg.motion.acceleration,{'numeric'},{'real','finite','scalar','positive'});
    validateattributes(cfg.motion.quadratureTolerance,{'numeric'}, ...
        {'real','finite','scalar','positive'});
    validateattributes(cfg.geometry.minYProgress,{'numeric'}, ...
        {'real','finite','scalar','nonnegative'});
    validateattributes(cfg.time.hoverBounds,{'numeric'}, ...
        {'real','finite','vector','numel',2,'positive'});
    hb=cfg.time.hoverBounds;
    if hb(2)<hb(1), error('V10C:TimeBounds','Hover bounds must be increasing.'); end
    validateattributes(cfg.time.totalHoverMax,{'numeric'}, ...
        {'real','finite','scalar','positive'});
    validateattributes(cfg.time.ehFractionBounds,{'numeric'}, ...
        {'real','finite','vector','numel',2,'>',0,'<',1});
    fb=cfg.time.ehFractionBounds;
    if fb(2)<fb(1), error('V10C:TimeBounds','Phase bounds must be increasing.'); end
    if ~any(strcmp(cfg.time.hoverMode,{'fixed','variable'})) ...
            || ~any(strcmp(cfg.time.splitMode,{'fixed','variable'}))
        error('V10C:TimeMode','Timing modes must be fixed or variable.');
    end
    slots=cfg.geometry.numWaypoints-1;
    if cfg.mission.hoverTime<hb(1) || cfg.mission.hoverTime>hb(2) ...
            || cfg.mission.ehFraction<fb(1) || cfg.mission.ehFraction>fb(2)
        error('V10C:TimeBounds','Initial times are outside the configured bounds.');
    end
    if slots*hb(1)>cfg.time.totalHoverMax ...
            || (strcmp(cfg.time.hoverMode,'fixed') ...
            && slots*cfg.mission.hoverTime>cfg.time.totalHoverMax)
        error('V10C:TimeBudget','Hover bounds cannot fit the total hover budget.');
    end
    % The inherited builder requires strictly positive progress; use it only
    % for scenario/channel constants, then install the V10C progress rule.
    base=cfg;
    span=abs(cfg.geometry.endXY(2)-cfg.geometry.startXY(2));
    if cfg.geometry.minYProgress==0
        base.geometry.minYProgress=min(1,span/(2*slots));
    end
    before=rng; cleanup=onCleanup(@() rng(before)); %#ok<NASGU>
    rng(cfg.random.mainSeed,'twister');
    sim=buildV10Simulation(base,'B');
    sim.variant='C'; sim.preset=cfg.preset;
    sim.minYProgress=cfg.geometry.minYProgress;
    sim.numSlots=sim.numSteps-1;
    sim.time=cfg.time; sim.motion=cfg.motion;
    sim.initializationOnly=strcmp(cfg.execution.mode,'initialize');
    sim.modelInherited=strcmp(cfg.motion.mode,'steady-drones');
    sim.energyScope='gross-uav-movement-hover-rf';
end
