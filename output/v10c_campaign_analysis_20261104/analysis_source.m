projectRoot='/Users/fuzzefer/Documents/MATLAB/EE-UAV-SWIPT-NOMA-PSO';
cd(projectRoot); setup_project;
source=fullfile(projectRoot,'results/v10c/comparisons/tp56c4ac89_c18b_4ba7_a165_f827ae426187/comparison.mat');
loaded=load(source,'report'); report=loaded.report; T=report.summary;
assert(height(T)==54);
assert(height(unique(T(:,{'preset','seed','algorithm'}),'rows'))==54);
assert(all(T.evaluations==120120));
assert(isequal(report.seeds,[2026,608060,3486784401]));
assert(isequal(report.presets,0:5) && strcmp(report.profile,'full'));
out=fullfile(projectRoot,'output/v10c_campaign_analysis_20261104');
if ~isfolder(out), mkdir(out); end
details=struct([]); n=0; cross=struct([]); nc=0;
for i=1:size(report.runs,1)
    for j=1:size(report.runs,2)
        d=report.runs{i,j}; cfg=d.cfg; sim=d.sim;
        assert(cfg.search.numParticles==120 && cfg.search.maxIter==1000);
        assert(cfg.mission.minBitsPerUser==3e6 && cfg.mission.minBitsPerUserPerSlot==5e3);
        assert(sim.energyBudgetJ==17000);
        names=fieldnames(d.searches);
        for a=1:numel(names)
            s=d.searches.(names{a}); r=s.result; c=s.candidate;
            fresh=evaluateV10CCandidate(c,sim);
            assert(fresh.isFeasible==r.isFeasible);
            assert(abs(fresh.eeComputed-r.eeComputed)<1e-6*max(1,r.eeComputed));
            assert(numel(s.history.bestFitness)==1001);
            assert(all(diff(s.history.bestFitness)>=-1e-10));
            if strcmp(names{a},'joint_pso')
                assert(isequal(c.bsXY,[sim.xBS(:),sim.yBS(:)]));
            end
            n=n+1;
            z.preset=cfg.preset; z.seed=cfg.random.mainSeed; z.algorithm=s.algorithm;
            z.method=names{a}; z.version=cfg.version; z.feasible=r.isFeasible;
            z.EE=r.eeComputed; z.validEE=NaN;
            if r.isFeasible, z.validEE=r.eeComputed; end
            z.energyJ=r.totalEnergy; z.moveJ=r.movementEnergy;
            z.hoverJ=r.hoverEnergy; z.rfJ=r.rfEnergy;
            z.totalMbit=r.totalBits/1e6; z.minUserMbit=min(r.totalBitsPerUser)/1e6;
            z.minSlotUserBits=min(r.bitsPerUserPerSlot,[],'all');
            z.Lok=r.missionQoSFeasible; z.qok=r.userSlotQoSFeasible;
            z.energyOK=r.energyFeasible; z.geometryOK=r.geometryFeasible;
            z.timeOK=r.timingFeasible; z.alphaOK=r.alphaFeasible;
            z.numUsersBelowL=sum(r.bitsShortfallPerUser>1e-4);
            z.numSlotUserBelowQ=sum(r.userSlotShortfall>1e-4,'all');
            z.missingMbit=sum(r.bitsShortfallPerUser)/1e6;
            z.hoverTotal=sum(c.uplinkTime+c.downlinkTime);
            h=c.uplinkTime+c.downlinkTime; f=c.uplinkTime./h;
            z.hoverMin=min(h); z.hoverMax=max(h); z.hoverStd=std(h,0);
            z.ULtotal=sum(c.uplinkTime); z.DLtotal=sum(c.downlinkTime);
            z.ULfractionWeighted=z.ULtotal/z.hoverTotal;
            z.ULfractionMin=min(f); z.ULfractionMax=max(f);
            z.ULfractionStd=std(f,0);
            z.hoverNearMin=sum(abs(h-0.1)<1e-6);
            z.hoverNearMax=sum(abs(h-3)<1e-6);
            z.ULfractionNearMax=sum(abs(f-0.95)<1e-6);
            z.distanceM=r.totalDistance; z.visits=r.numServiceVisits;
            z.exactStays=20-r.numServiceVisits;
            z.missionSeconds=r.missionTime;
            first=find(s.history.feasible,1);
            z.firstFeasibleIter=NaN;
            if ~isempty(first), z.firstFeasibleIter=first-1; end
            z.lastImprovementIter=find(diff(s.history.bestFitness)>0,1,'last');
            if isempty(z.lastImprovementIter), z.lastImprovementIter=0; end
            z.gainLast200Pct=NaN;
            if r.isFeasible && s.history.feasible(801)
                z.gainLast200Pct=100*(r.eeComputed/s.history.eeComputed(801)-1);
            end
            z.userMbits={r.totalBitsPerUser/1e6};
            z.folder=d.outputFolder;
            if n==1, details=z; else, details(n)=z; end
            if strcmp(cfg.preset,'C4')
                nc=nc+1; c5cfg=v10cConfig('C5','smoke');
                c5cfg.random.mainSeed=cfg.random.mainSeed;
                c5cfg.motion.allowExperimental=true;
                c5sim=buildV10CSimulation(c5cfg);
                assert(isequal(c5sim.radio,sim.radio));
                r5=evaluateV10CCandidate(c,c5sim);
                assert(abs(r5.totalBits-r.totalBits)<1e-7*max(1,r.totalBits));
                cross(nc).seed=cfg.random.mainSeed;
                cross(nc).method=names{a}; cross(nc).energyC4=r.totalEnergy;
                cross(nc).energyC5=r5.totalEnergy;
                cross(nc).feasibleC5=r5.isFeasible;
                cross(nc).EEC5=r5.eeComputed;
                cross(nc).minUserMbitC5=min(r5.totalBitsPerUser)/1e6;
                cross(nc).minSlotUserBitsC5=min(r5.bitsPerUserPerSlot,[],'all');
            end
        end
    end
end
D=struct2table(details); F=D(D.feasible,:);
G=groupsummary(D,["preset","algorithm"],["mean","std","min","max"],"validEE");
Counts=groupsummary(D,["preset","algorithm"],"sum","feasible");
ByMethod=groupsummary(D,"algorithm","sum","feasible");
Timing=groupsummary(D(D.feasible & ~strcmp(D.preset,'C5'),:), ...
    ["preset","algorithm"],"mean",["hoverTotal","hoverMin","hoverMax","hoverStd", ...
    "ULfractionWeighted","ULfractionStd","exactStays","distanceM","energyJ","totalMbit","gainLast200Pct"]);
writetable(D,fullfile(out,'details.csv'));
writetable(G,fullfile(out,'ee_by_preset_method.csv'));
writetable(Counts,fullfile(out,'feasibility_counts.csv'));
writetable(Timing,fullfile(out,'timing_energy.csv'));
writetable(struct2table(cross),fullfile(out,'C4_candidates_under_C5.csv'));
analysis=struct('source',source,'rowCount',height(T),'feasibleCount',height(F), ...
    'profile',report.profile,'seeds',report.seeds,'details',details, ...
    'groupedEE',table2struct(G),'feasibility',table2struct(Counts), ...
    'methodCounts',table2struct(ByMethod),'timing',table2struct(Timing), ...
    'crossC4toC5',cross);
fid=fopen(fullfile(out,'analysis.json'),'w');
fwrite(fid,jsonencode(analysis,PrettyPrint=true),'char'); fclose(fid);
disp(jsonencode(struct('rowCount',height(T),'feasibleCount',height(F), ...
    'groupedEE',table2struct(G),'methodCounts',table2struct(ByMethod))));
disp('OVERNIGHT_ANALYSIS_PASSED');
