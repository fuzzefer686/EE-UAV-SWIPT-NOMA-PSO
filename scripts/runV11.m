function data = runV11(variant, cfg)
%RUNV11 Same V9 optimization sequence for A/B, using one common configuration.
% This function executes optimizers only when explicitly called in MATLAB.
    if nargin<1, variant='B'; end
    if nargin<2
        cfg=v11Config();
    end
    rng(cfg.random.mainSeed,'twister');
    sim=buildV11Simulation(cfg,variant);
    cfg.alpha.mode=sim.alphaMode; cfg.alpha.repair=sim.alphaRepair;
    cfg.alpha.finalSolver=sim.alphaFinalSolver;
    cfg.alpha.presetName=sim.alphaPresetName;
    cfg.alpha.finalizeJoint=sim.alphaFinalizeJoint;
    validateattributes(cfg.optimizers.alphaPolishSamplesPerUser,{'numeric'}, ...
        {'real','finite','scalar','integer','nonnegative'});
    validateattributes(cfg.optimizers.alphaPolishMinimumSamples,{'numeric'}, ...
        {'real','finite','scalar','integer','nonnegative'});
    fprintf('\n=== V11%s | mainSeed=%.0f | L (bit/user): ',sim.variant,cfg.random.mainSeed);
    fprintf('%.9g ',sim.minBitsPerUser); fprintf('===\n');
    fprintf('UAV Z=%.3f m | cruise=%.3f m/s | hover=%.3f s (EH %.3f/RF %.3f)\n', ...
        sim.altitude,sim.flight.cruiseSpeed,sim.hoverTime,sim.ehTime,sim.rfTime);
    fprintf('Drones Eq.(11): cruise=%.9f W | hover=%.9f W | gross budget=%.9g J\n', ...
        sim.cruisePower,sim.hoverPower,sim.energyBudgetJ);
    fprintf('Scope: horizontal cruise + requested hover + RF; EH supplies RF only.\n');
    fprintf('User X: '); disp(sim.xUser); fprintf('User Y: '); disp(sim.yUser);

    p=initialV11Particle(sim,false,false);
    [~,resBase]=evaluateTrajectoryV11(p,sim,false,true);
    % Controlled comparison: all three optimizers start from algorithmSeed.
    % V9 let Joint continue the post-scenario RNG stream; that made Joint and
    % Full/IPSO use different random draws for the same seed.
    rng(cfg.random.algorithmSeed,'twister');
    trajJointRaw=optimizeTrajectoryV11JointPSO(sim,cfg.optimizers.joint);
    samples=max(cfg.optimizers.alphaPolishMinimumSamples, ...
        cfg.optimizers.alphaPolishSamplesPerUser*sim.noUsers);
    trajJoint=trajJointRaw;
    if sim.alphaFinalizeJoint
        trajJoint=finalizeAlpha(trajJointRaw,sim,cfg,samples);
    end
    rng(cfg.random.algorithmSeed,'twister');
    trajFullRaw=optimizeTrajectoryV11FullPSO(sim,cfg.optimizers.full);
    trajFull=finalizeAlpha(trajFullRaw,sim,cfg,samples);
    rng(cfg.random.algorithmSeed,'twister');
    trajIPSORaw=optimizeTrajectoryV11FullIPSO(sim,cfg.optimizers.ipso);
    trajIPSO=finalizeAlpha(trajIPSORaw,sim,cfg,samples);

    data=struct('cfg',cfg,'sim',sim,'resBase',resBase,'trajJoint',trajJoint, ...
        'trajJointRaw',trajJointRaw,'trajFullRaw',trajFullRaw,'trajIPSORaw',trajIPSORaw, ...
        'trajFull',trajFull,'trajIPSO',trajIPSO,'outputFolder','');
    data.alphaPresetName=sim.alphaPresetName;
    data.alphaFinalizeJoint=sim.alphaFinalizeJoint;
    data.particleLayout=v11ParticleLayout(sim,true);
    data.numFitnessEvals=1+trajJoint.numFitnessEvals+trajFull.numFitnessEvals+trajIPSO.numFitnessEvals;
    printSummary(1,data);
    if cfg.output.saveResults || (cfg.output.makePlots && cfg.output.saveFigures)
        stamp=char(datetime('now','Format','yyyyMMdd_HHmmss_SSS'));
        if isscalar(sim.minBitsPerUser)
            lLabel=strrep(sprintf('%.9g',sim.minBitsPerUser/1e6),'.','p');
        else
            lLabel='perUser';
        end
        label=sim.alphaPresetName;
        if isempty(label), label=[sim.alphaMode,'_',sim.alphaRepair,'_',sim.alphaFinalSolver]; end
        label=regexprep(label,'[^a-zA-Z0-9_-]','_');
        root=fullfile(cfg.output.root,['V11',sim.variant],label);
        stem=sprintf('seed%.0f_L%sMbit_%s',cfg.random.mainSeed,lLabel,stamp);
        folder=fullfile(root,stem); suffix=1;
        while exist(folder,'file') || exist(folder,'dir')
            folder=fullfile(root,sprintf('%s_%02d',stem,suffix)); suffix=suffix+1;
        end
        [ok,message]=mkdir(folder);
        if ~ok
            error('runV11:OutputFolder','Cannot create output folder: %s',message);
        end
        data.outputFolder=folder;
    end
    % Save numerical/configuration provenance before optional graphics can fail.
    if cfg.output.saveResults
        save(fullfile(data.outputFolder,'results.mat'),'data','-v7.3');
        fid=fopen(fullfile(data.outputFolder,'summary.txt'),'w');
        if fid<0
            error('runV11:SummaryFile','Cannot write summary.txt.');
        end
        cleaner=onCleanup(@() fclose(fid));
        printSummary(fid,data);
        clear cleaner;
        fprintf('V11 configuration and raw/final results saved: %s\n',data.outputFolder);
    end
    if cfg.output.makePlots
        didPlot=plotV11Diagnostics(data);
        if cfg.output.saveFigures && didPlot
            figureFolder=saveV9Figures(data.outputFolder);
            fprintf('V11 figures saved: %s\n',figureFolder);
        end
    end
end

function printSummary(fid,data)
% One metric per line, following the V9 console layout; also used by summary.txt.
    sim=data.sim; cfg=data.cfg;
    fprintf(fid,'\n=== V11%s total UAV EE (propulsion + hover + RF) ===\n',sim.variant);
    fprintf(fid,'Version                   = %s\n',cfg.version);
    fprintf(fid,'Alpha preset              = %s\n',sim.alphaPresetName);
    fprintf(fid,'Finalize Joint = %d\n',sim.alphaFinalizeJoint);
    fprintf(fid,'Alpha mode/repair/solver  = %s / %s / %s\n',sim.alphaMode,sim.alphaRepair,sim.alphaFinalSolver);
    fprintf(fid,'Full particle dimension   = %d\n',data.particleLayout.dimension);
    fprintf(fid,'Total fitness evaluations = %d\n',data.numFitnessEvals);
    fprintf(fid,'Scenario seed             = %.0f\n',cfg.random.mainSeed);
    fprintf(fid,'Algorithm seed            = %u\n',cfg.random.algorithmSeed);
    fprintf(fid,'Polishing seed            = %u\n',cfg.random.polishSeed);
    fprintf(fid,'L (bit/user):\n');
    for u=1:sim.noUsers
        target=sim.minBitsPerUser(min(u,numel(sim.minBitsPerUser)));
        fprintf(fid,'  User %d                  = %.12e bit\n',u,target);
    end
    fprintf(fid,'Min bits per slot (total)  = %.12g bit\n',sim.minBitsPerSlot);
    fprintf(fid,'Min bits per user-slot     = ');
    fprintf(fid,'%.12g ',sim.minBitsPerUserPerSlot); fprintf(fid,'bit\n');
    fprintf(fid,'\nTiming and flight settings\n');
    fprintf(fid,'Hover per serving point   = %.9g s\n',sim.hoverTime);
    fprintf(fid,'EH / uplink time          = %.9g s\n',sim.ehTime);
    fprintf(fid,'RF / downlink time        = %.9g s\n',sim.rfTime);
    fprintf(fid,'Cruise speed              = %.9g m/s\n',sim.flight.cruiseSpeed);
    fprintf(fid,'UAV altitude              = %.9g m\n',sim.altitude);
    fprintf(fid,'Energy budget (gross)     = %.12g J\n',sim.energyBudgetJ);
    fprintf(fid,'Cruise power              = %.12g W\n',sim.cruisePower);
    fprintf(fid,'Hover power               = %.12g W\n',sim.hoverPower);
    fprintf(fid,'\nRadio settings\n');
    fprintf(fid,'BS transmit power         = %.9g dBm\n',sim.radio.bsPowerDbm);
    fprintf(fid,'Power splitting phi       = %.9g\n',sim.radio.powerSplit);
    fprintf(fid,'EH efficiency eta         = %.9g\n',sim.radio.ehEfficiency);
    fprintf(fid,'Bandwidth                 = %.9g Hz\n',sim.radio.bandwidthHz);
    fprintf(fid,'Reference gain beta0      = %.9g dB\n',sim.radio.referenceGainDb);
    names={'Baseline straight trajectory','Joint PSO without BS optimization', ...
        'Full PSO with BS optimization','Full IPSO with BS optimization'};
    results={data.resBase,data.trajJoint,data.trajFull,data.trajIPSO};
    for k=1:numel(results)
        r=results{k}; ee=r.eeComputed;
        fprintf(fid,'\n%s\n',names{k});
        fprintf(fid,'Feasible                  = %d\n',r.isFeasible);
        fprintf(fid,'EE (computed)             = %.12e bit/J\n',ee);
        fprintf(fid,'L / bit-slot / bit-user-slot QoS = %d / %d / %d\n', ...
            r.missionQoSFeasible,r.slotQoSFeasible,r.userSlotQoSFeasible);
        fprintf(fid,'Energy / geometry         = %d / %d\n',r.energyFeasible,r.geometryFeasible);
        fprintf(fid,'Total bits                = %.12e bit\n',r.totalBits);
        fprintf(fid,'Min bits per slot         = %.12e bit\n',r.slotBitsMin);
        fprintf(fid,'Max bits per slot         = %.12e bit\n',r.slotBitsMax);
        fprintf(fid,'Slots below slot QoS      = %d\n',r.numSlotsBelowMin);
        fprintf(fid,'User-slots below QoS      = %d\n',r.numUserSlotsBelowMin);
        fprintf(fid,'Total UAV energy          = %.12e J\n',r.totalEnergy);
        fprintf(fid,'Cruise energy             = %.12e J\n',r.flightEnergy);
        fprintf(fid,'Hover energy              = %.12e J\n',r.hoverEnergy);
        fprintf(fid,'RF transmit energy        = %.12e J\n',r.rfEnergy);
        fprintf(fid,'Harvested energy          = %.12e J\n',r.totalHarvestedEnergy);
        fprintf(fid,'Total flight distance     = %.9f m\n',r.totalDistance);
        fprintf(fid,'Flight time               = %.9f s\n',r.flightTime);
        fprintf(fid,'Total hover time          = %.9f s\n',r.totalHoverTime);
        fprintf(fid,'Mission time              = %.9f s\n',r.missionTime);
        fprintf(fid,'Excess energy             = %.12e J\n',r.energyShortfall);
        fprintf(fid,'Bits per user:\n');
        for u=1:numel(r.totalBitsPerUser)
            fprintf(fid,'  User %d                  = %.12e bit\n',u,r.totalBitsPerUser(u));
        end
        fprintf(fid,'Bit shortfall per user:\n');
        for u=1:numel(r.bitsShortfallPerUser)
            fprintf(fid,'  User %d                  = %.12e bit\n',u,r.bitsShortfallPerUser(u));
        end
    end
end

function out = finalizeAlpha(raw,sim,cfg,samples)
    switch sim.alphaFinalSolver
        case 'none'
            out=raw; out.alphaSolver='none';
        case 'random'
            rng(cfg.random.polishSeed,'twister');
            out=polishAlphaV11(raw,sim,samples);
        case 'qos'
            out=polishAlphaV11(raw,sim,0);
        otherwise
            error('runV11:AlphaSolver','Unknown final alpha solver.');
    end
end
