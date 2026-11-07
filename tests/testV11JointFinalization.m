function testV11JointFinalization()
%TESTV11JOINTFINALIZATION Joint raw/final, layout and legacy-default regressions.
    c=v11Config(); assert(isfield(c.alpha,'finalizeJoint') && ~c.alpha.finalizeJoint);
    old={'particle_noma_random','particle_noma_none','uniform_noma_none', ...
        'uniform_noma_qos','uniform_noc3_qos','particle_noc3_random'};
    for k=1:numel(old), x=v11AlphaPreset(old{k}); assert(~x.alpha.finalizeJoint); end
    c=v11AlphaPreset('uniform_noma_qos_fair'); assert(c.alpha.finalizeJoint);
    rng(2026,'twister'); s=buildV11Simulation(c,'B'); assert(s.alphaFinalizeJoint);
    missing=rmfield(c,'alpha'); rng(2026,'twister'); legacy=buildV11Simulation(missing,'B');
    assert(~legacy.alphaFinalizeJoint);
    c=v11Config(); rng(2026,'twister'); s=buildV11Simulation(c,'B');
    o=c.optimizers.joint; o.numParticles=3; o.maxIter=1;
    raw=optimizeTrajectoryV11JointPSO(s,o); rng(33,'twister'); final=polishAlphaV11(raw,s,3);
    assert(numel(final.bestParticle)==143 && final.particleLayout.dimension==143);
    assert(isempty(final.particleLayout.xBS));
    assert(isequal(final.xBS,s.xBS) && isequal(final.yBS,s.yBS));
    assert(isequal(final.bestHistory,raw.bestHistory));
    assert(final.numFitnessEvals==raw.numFitnessEvals+61);
    assert(final.bestFitness>=raw.bestFitness);
    c=v11AlphaPreset('uniform_noma_qos_fair'); c.alpha.qosMaxOuterIter=1;
    for name={'joint','full','ipso'}
        c.optimizers.(name{1}).numParticles=3; c.optimizers.(name{1}).maxIter=1;
    end
    c.output.makePlots=false; c.output.saveResults=true; c.output.saveFigures=false;
    folder=tempname; c.output.root=folder; cleanup=onCleanup(@() cleanupFolder(folder));
    data=runV11('B',c);
    assert(data.alphaFinalizeJoint && strcmp(data.trajJoint.alphaSolver,'qos'));
    saved=load(fullfile(data.outputFolder,'results.mat'));
    assert(saved.data.alphaFinalizeJoint && isfield(saved.data,'trajJointRaw'));
    assert(contains(fileread(fullfile(data.outputFolder,'summary.txt')),'Finalize Joint = 1'));
    assert(numel(data.trajJoint.bestParticle)==38 && data.trajJoint.particleLayout.dimension==38);
    assert(isequal(data.trajJoint.bestHistory,data.trajJointRaw.bestHistory));
    assert(data.trajJoint.numFitnessEvals==data.trajJointRaw.numFitnessEvals+1);
    c.alpha.finalizeJoint=false; plain=runV11('B',c);
    assert(~plain.alphaFinalizeJoint && isequaln(plain.trajJoint,plain.trajJointRaw));
    opts=struct('dryRun',true,'presets',{{'uniform_noma_qos_fair'}}, ...
        'variants',{{'B'}},'minBitsPerUser',1e6,'seeds',2026);
    planned=runV11AlphaStudy(opts); assert(planned.alphaFinalizeJoint);
    fprintf('B1 PASS: legacy defaults, fair preset, 143/38-dimensional Joint finalization, raw/history/counts.\n');
end

function cleanupFolder(folder)
    if isfolder(folder), rmdir(folder,'s'); end
end
