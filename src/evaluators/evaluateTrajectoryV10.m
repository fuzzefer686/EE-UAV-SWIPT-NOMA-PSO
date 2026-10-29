function [fitness, result] = evaluateTrajectoryV10(particle, sim, optimizeBS, channelAllocation)
%EVALUATETRAJECTORYV10 Shared configured physics for A/B and all algorithms.
% channelAllocation=true is the V9 channel-based straight-line baseline.
    if nargin<4
        channelAllocation=false;
    end
    result=decodeV10Particle(particle,sim,optimizeBS);
    T=sim.numSteps; U=sim.noUsers; tol=sim.feasibilityTolerance;
    points=[result.xTraj(:),result.yTraj(:),result.zTraj(:)];
    geometry=all(isfinite(particle(:))) ...
        && all(result.xTraj>=sim.x_min-tol & result.xTraj<=sim.x_max+tol) ...
        && all(result.yTraj>=sim.y_min-tol & result.yTraj<=sim.y_max+tol);
    if strcmp(sim.variant,'B')
        geometry=geometry && all(sim.yDirection*diff(result.yTraj)>=sim.minYProgress-tol);
    end
    if optimizeBS
        geometry=geometry && all(result.xBS>=sim.xBS_min-tol & result.xBS<=sim.xBS_max+tol) ...
            && all(result.yBS>=sim.yBS_min-tol & result.yBS<=sim.yBS_max+tol);
    end
    result.geometryFeasible=geometry;
    result.achRate=NaN(T,U); result.alphaTrace=NaN(T,U);
    result.alphaOrdTrace=NaN(T,U); result.idxWeak2StrongTrace=NaN(T,U);
    result.h2UserTrace=NaN(T,U); result.h2BSTrace=NaN(T,sim.noBS);
    result.pt=NaN(T,1);
    if geometry
        users=[sim.xUser(:),sim.yUser(:),sim.zUser(:)];
        bs=[result.xBS(:),result.yBS(:),result.zBS(:)];
        for t=1:T
            hBS=v10Channel(points(t,:),bs,sim.gNLoSBS,sim.radio);
            hUsers=v10Channel(points(t,:),users,sim.gNLoSUsers,sim.radio);
            result.h2UserTrace(t,:)=abs(hUsers).^2;
            result.h2BSTrace(t,:)=abs(hBS).^2;
            [~,order]=sort(abs(hUsers).^2,'ascend');
            if channelAllocation
                % Same channel-based coefficient formula as V9; no equality indexing.
                amplitude=abs(hUsers);
                if sum(amplitude)>0
                    alpha=(1-amplitude/sum(amplitude))/(U-1);
                else
                    alpha=ones(1,U)/U;
                end
            else
                raw=max(result.rawAlpha(t,:),sim.pMin);
                raw=raw/sum(raw);
                alpha=zeros(1,U); alpha(order)=sort(raw,'descend');
            end
            [rate,alphaOrd,order,power]=findAchievableRateV10(hUsers,hBS,alpha,sim);
            result.achRate(t,:)=rate;
            result.alphaTrace(t,:)=alpha;
            result.alphaOrdTrace(t,:)=alphaOrd;
            result.idxWeak2StrongTrace(t,:)=order;
            result.pt(t)=power;
        end
    end
    result.stepMin=min(result.achRate,[],2);
    result.fitIdx=1:(T-1);
    result.minFit=min(result.stepMin(result.fitIdx));
    result.meanFit=mean(result.stepMin(result.fitIdx));
    result.minInternal=min(result.stepMin(2:T-1));
    result.meanInternal=mean(result.stepMin(2:T-1));
    result=addV10EnergyMetrics(result,sim);
    result.variant=sim.variant;
    result.objectiveMode=sim.objectiveMode;
    result.penalty=double(~result.geometryFeasible);
    fitness=result.fitness;
end
