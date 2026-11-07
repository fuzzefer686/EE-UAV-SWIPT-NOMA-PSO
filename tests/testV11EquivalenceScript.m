function testV11EquivalenceScript()
%TESTV11EQUIVALENCESCRIPT Inspect production budgets without executing them.
    assert(exist('compareV11V10Equivalence','file')==2,'Equivalence script is missing.');
    r=compareV11V10Equivalence('B',2026,3e6,struct('dryRun',true));
    assert(r.cfg10.optimizers.full.numParticles==120 && r.cfg11.optimizers.full.maxIter==1000);
    assert(~r.cfg11.alpha.finalizeJoint && strcmp(r.preset,'particle_noma_random'));
    assert(r.dryRun && isempty(r.allPass));
    assert(~r.cfg10.output.makePlots && ~r.cfg11.output.saveResults);
    o=struct('dryRun',true,'numParticles',4,'maxIter',50,'preset','uniform_noma_qos_fair');
    r=compareV11V10Equivalence('A',608060,[1e6,2e6,3e6,1e6,2e6],o);
    assert(r.cfg10.optimizers.ipso.numParticles==4 && r.cfg11.optimizers.joint.maxIter==50);
    assert(r.geometryOnly && r.cfg11.alpha.finalizeJoint);
    assert(isequal(r.cfg10.mission.minBitsPerUser,r.cfg11.mission.minBitsPerUser));
    assert(isequal(r.cfg10.random,r.cfg11.random));
    fprintf('B2 PASS: comparator dryRun validates full/default and overridden budgets without executing them.\n');
end
