function testV11BaselineFixture()
%TESTV11BASELINEFIXTURE Context must survive tests without changing measurements.
    root=fileparts(fileparts(mfilename('fullpath')));
    x=jsondecode(fileread(fullfile(root,'tests','fixtures','v11_baseline_50iter_seed2026.json')));
    note=['Checksum-only baseline from V10 at 4 particles x 50 iterations. Negative ', ...
        'fitness means user-slot QoS violated; NOT a feasible reference solution.'];
    assert(isfield(x,'note') && strcmp(x.note,note),'Baseline feasibility note is missing.');
    assert(x.seed==2026 && x.numParticles==4 && x.maxIter==50);
    assert(x.bestFitness==-0.062626972472287684 && numel(x.bestParticle)==149);
    fprintf('B5 PASS: baseline note and measured numeric reference preserved.\n');
end
