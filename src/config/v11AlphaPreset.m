function cfg = v11AlphaPreset(name, cfg)
%V11ALPHAPRESET Named alpha strategy; optional cfg preserves caller overrides.
    if nargin<2, cfg=v11Config(); end
    name=validatestring(name,{'particle_noma_random','particle_noma_none', ...
        'uniform_noma_none','uniform_noma_qos','uniform_noc3_qos','particle_noc3_random', ...
        'uniform_noma_qos_fair'});
    parts=strsplit(name,'_');
    cfg.alpha.mode=parts{1}; cfg.alpha.repair=parts{2};
    if strcmp(cfg.alpha.repair,'noc3'), cfg.alpha.repair='none'; end
    cfg.alpha.finalSolver=parts{3}; cfg.alpha.presetName=name;
    cfg.alpha.finalizeJoint=strcmp(name,'uniform_noma_qos_fair');
    if strcmp(cfg.alpha.repair,'none') && strcmp(cfg.alpha.finalSolver,'none')
        warning('V11:NoC3FixedAlpha','With uniform fixed alpha, disabling C3 has no effect.');
    end
end
