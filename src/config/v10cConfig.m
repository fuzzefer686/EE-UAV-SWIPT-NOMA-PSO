function cfg = v10cConfig(preset,profile)
%V10CCONFIG Runnable reference PSO/IPSO presets; no search starts here.
    if nargin<1, preset='C4'; end
    if nargin<2, profile='quick'; end
    preset=upper(char(preset));
    cfg=v10Config();
    cfg.version='V10C-reference-search-3'; cfg.preset=preset;
    cfg.geometry.minYProgress=0;
    cfg.time.hoverMode='variable'; cfg.time.splitMode='variable';
    cfg.time.hoverBounds=[0.1,3];
    cfg.time.totalHoverMax=20;
    cfg.time.ehFractionBounds=[0.05,0.95];
    cfg.motion.mode='steady-drones';
    cfg.motion.allowExperimental=false;
    cfg.motion.acceleration=2; % hypothetical m/s^2, not measured UAV data
    cfg.motion.quadratureTolerance=1e-7;
    cfg.execution.mode='optimize';
    cfg.execution.algorithms={'JOINT_PSO','FULL_PSO','FULL_IPSO'};
    cfg.solvers.geometry='joint-reference-pso';
    cfg.solvers.alpha='joint-reference-pso';
    cfg.solvers.time='joint-reference-pso';
    cfg.search=struct('numParticles',40,'maxIter',300,'w',0.7,'c1',1.5,'c2',1.5, ...
        'velocityLimit',0.2,'seed',cfg.random.algorithmSeed,'mutationRate',0.15, ...
        'stallIter',25,'stayProposalRate',0.15,'verbose',true,'seedCandidate',[]);
    switch lower(char(profile))
        case 'smoke'
            cfg.search.numParticles=4; cfg.search.maxIter=3; cfg.search.verbose=false;
        case 'quick'
        case 'trial'
            cfg.search.numParticles=20; cfg.search.maxIter=100;
        case 'full'
            cfg.search.numParticles=120; cfg.search.maxIter=1000;
        otherwise
            error('V10C:Profile','Use smoke, trial, quick or full.');
    end
    cfg.search.profile=lower(char(profile));
    switch preset
        case 'C0'
            cfg.geometry.minYProgress=1;
            cfg.time.hoverMode='fixed'; cfg.time.splitMode='fixed';
            cfg.description='V10B-compatible model, fixed hover and phase split';
        case 'C1'
            cfg.time.hoverMode='fixed'; cfg.time.splitMode='fixed';
            cfg.description='Stay allowed, fixed hover and phase split';
        case 'C2'
            cfg.time.splitMode='fixed';
            cfg.description='Stay allowed, variable hover, fixed phase split';
        case 'C3'
            cfg.time.hoverMode='fixed';
            cfg.description='Stay allowed, fixed hover, variable phase split';
        case 'C4'
            cfg.description='Stay allowed, variable hover and phase split';
        case 'C5'
            cfg.description='C4 with experimental rest-to-rest motion energy';
            cfg.motion.mode='rest-to-rest-experimental';
        otherwise
            error('V10C:Preset','Use C0, C1, C2, C3, C4 or C5.');
    end
    projectRoot=fileparts(fileparts(fileparts(mfilename('fullpath'))));
    cfg.output.root=fullfile(projectRoot,'results','v10c');
    cfg.output.makePlots=true; cfg.output.saveFigures=true;
    cfg.output.saveResults=true;
end
