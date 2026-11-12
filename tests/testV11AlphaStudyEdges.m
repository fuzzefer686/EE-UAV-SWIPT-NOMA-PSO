function testV11AlphaStudyEdges()
%TESTV11ALPHASTUDYEDGES Dry-run budgets/vector labels and summary edge groups.
    c=v11Config(); c.mission.minBitsPerUserPerSlot=0; c.mission.energyBudgetJ=Inf;
    o=struct('dryRun',true,'smoke',true,'cfg',c,'presets',{{'uniform_noma_none'}}, ...
        'variants',{{'B'}},'seeds',2026,'minBitsPerUser',{{[1e6,2e6,3e6,1e6,2e6]}}, ...
        'numParticles',99,'maxIter',99);
    T=runV11AlphaStudy(o);
    assert(height(T)==1 && T.numParticles==5 && T.maxIter==3,'Smoke must force 5 particles/3 iterations.');
    assert(isnumeric(T.L) && isnan(T.L));
    assert(contains(string(T.LLabel),'2000000') && ~T.alphaFinalizeJoint);
    o=rmfield(o,'smoke'); o.minBitsPerUser=[1e6,2e6,3e6];
    sweep=runV11AlphaStudy(o); assert(height(sweep)==3 && isequal(sweep.L,[1e6;2e6;3e6]));
    % A real summary with one sample must say NaN, and handle absent groups.
    T.eeUAV=12; T.feasible=false;
    file=tempname; fid=fopen(file,'w'); assert(fid>=0);
    cleanup=onCleanup(@() delete(file));
    writeV11AlphaStudySummary(fid,T,{'uniform_noma_none','missing_preset'},{'B'}, ...
        {[1e6,2e6,3e6,1e6,2e6],7e6}); fclose(fid);
    text=fileread(file);
    assert(contains(text,'12 +/- NaN') && contains(text,'(no feasible run)'));
    assert(~contains(text,'Feasible-only EE') && ~contains(text,'missing_preset') && ~contains(text,'L=7000000'));
    T.feasible=true; fid=fopen(file,'w');
    writeV11AlphaStudySummary(fid,T,{'uniform_noma_none'},{'B'},{[1e6,2e6,3e6,1e6,2e6]}); fclose(fid);
    assert(contains(fileread(file),'Feasible-only EE: 12 +/- NaN (n=1)'));
    fprintf('B4 PASS: smoke budget, numeric sweep, vector targets, singleton std, empty/all-infeasible groups.\n');
end
