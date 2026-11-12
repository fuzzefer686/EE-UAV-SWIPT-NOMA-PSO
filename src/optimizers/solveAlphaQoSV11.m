function [alpha, info] = solveAlphaQoSV11(xTraj, yTraj, xBS, yBS, sim)
%SOLVEALPHAQOSV11 Core-only deterministic local dual/slot power allocation.
% Uses the unchanged rate helper for every objective/feasibility evaluation.
% A local RandStream leaves the caller's global RNG untouched.
    T=sim.numSteps; U=sim.noUsers; S=T-1; uniform=ones(1,U)/U;
    repair=getSimField(sim,'alphaRepair','noma'); c3=strcmp(repair,'noma');
    maxOuter=getSimField(sim,'alphaQosMaxOuterIter',200);
    tolerance=getSimField(sim,'alphaQosTol',1e-3);
    seed=getSimField(sim,'alphaQosSeed',12345);
    L=expandTarget(sim.minBitsPerUser,U);
    slotTarget=expandTarget(sim.minBitsPerUserPerSlot,U);
    alpha=repmat(uniform,T,1); bits=zeros(S,U); powers=zeros(S,1);
    hUsers=cell(S,1); hBS=cell(S,1); orders=zeros(S,U); noise=zeros(S,U);
    minOrdered=zeros(S,U); slotPossible=true(S,1); numRateEvals=0;
    users=[sim.xUser(:),sim.yUser(:),sim.zUser(:)];
    bs=[xBS(:),yBS(:),sim.zBS(:)];
    for t=1:S
        point=[xTraj(t),yTraj(t),sim.altitude];
        hUsers{t}=v11Channel(point,users,sim.gNLoSUsers,sim.radio);
        hBS{t}=v11Channel(point,bs,sim.gNLoSBS,sim.radio);
        [rate,~,order,power]=findAchievableRateV11(hUsers{t},hBS{t},uniform,sim);
        numRateEvals=numRateEvals+1;
        bits(t,:)=sim.rfTime*rate; powers(t)=power; orders(t,:)=order;
        noise(t,:)=sim.radio.noisePowerW./max(power*abs(hUsers{t}(order)).^2,realmin);
        gamma=expm1(min(700,log(2)*slotTarget(order)/(sim.rfTime*sim.radio.bandwidthHz)));
        b=zeros(1,U);
        for u=U:-1:1
            b(u)=gamma(u)*(noise(t,u)+sum(b(u+1:end)));
            if c3 && u<U, b(u)=max(b(u),b(u+1)); end
        end
        minOrdered(t,:)=b; slotPossible(t)=all(isfinite(b)) && sum(b)<=1+1e-12;
    end
    % Feasible uniform is the analytic C3 sum-rate maximum; no numerical work needed.
    uniformOK=all(sum(bits,1)>=L) && all(all(bits>=slotTarget)) ...
        && all(sum(bits,2)>=sim.minBitsPerSlot);
    bestAlpha=alpha; bestBits=bits; bestShort=sum(max(0,L-sum(bits,1)));
    bestObjective=sum(bits(:)); outer=0;
    if c3 && uniformOK
        info=packageInfo(); return;
    end
    % If even every user's interference-free upper bound is below its target,
    % total shortfall = sum(L)-sum(bits). Uniform is then the exact C3 optimum.
    upper=sim.rfTime*sim.radio.bandwidthHz*log2(1+1./noise);
    upperPhysical=zeros(S,U);
    for t=1:S, upperPhysical(t,orders(t,:))=upper(t,:); end
    if c3 && all(L>sum(upperPhysical,1)) && all(all(bits>=slotTarget))
        info=packageInfo(); return;
    end
    stream=RandStream('mt19937ar','Seed',seed);
    starts=zeros(S,U,5); starts(:,:,1)=repmat(uniform,S,1);
    for k=2:5
        draws=rand(stream,S,U); starts(:,:,k)=draws./sum(draws,2);
    end
    mu=zeros(1,U); eta=1e-6*median(L);
    for outer=1:maxOuter
        for t=1:S
            order=orders(t,:); weight=1+mu(order); weight=weight/max(weight);
            bestValue=-Inf; chosen=uniform;
            for k=1:5
                if k==1, initial=alpha(t,order); else, initial=starts(t,:,k); end
                a=project(initial,t); [value,rate]=slotValue(a,t,weight);
                for inner=1:12
                    % Analytic derivative of the unchanged ideal-SIC helper.
                    tail=fliplr(cumsum(fliplr(a)))-a;
                    d1=1./(noise(t,:)+tail+a); d0=1./(noise(t,:)+tail);
                    gradient=weight.*d1+[0,cumsum(weight(1:end-1).*(d1(1:end-1)-d0(1:end-1)))];
                    gradient=gradient-mean(gradient); gradient=gradient/max(1,max(abs(gradient)));
                    step=0.25; accepted=false;
                    for backtrack=1:10
                        trial=project(a+step*gradient,t);
                        if max(abs(trial-a))<1e-9, break; end
                        [trialValue,trialRate]=slotValue(trial,t,weight);
                        if trialValue>value+1e-10
                            a=trial; value=trialValue; rate=trialRate; accepted=true; break;
                        end
                        step=step/2;
                    end
                    if ~accepted, break; end
                end
                if value>bestValue
                    bestValue=value; chosen=a; chosenRate=rate;
                end
            end
            alpha(t,order)=chosen; bits(t,:)=sim.rfTime*chosenRate;
        end
        delivered=sum(bits,1); short=sum(max(0,L-delivered)); objective=sum(bits(:));
        % Candidates must satisfy every feasible slot's C5 before they compete.
        c5ok=all(all(bits(slotPossible,:)>=slotTarget-1e-7));
        oldc5=all(all(bestBits(slotPossible,:)>=slotTarget-1e-7));
        if (c5ok && ~oldc5) || (c5ok==oldc5 && ...
                (short<bestShort || (short==bestShort && objective>bestObjective)))
            bestAlpha=alpha; bestBits=bits; bestShort=short; bestObjective=objective;
        end
        if all(max(0,L-delivered)<=tolerance*L) && c5ok, break; end
        mu=max(0,mu+eta*(L-delivered)); eta=0.97*eta;
    end
    alpha=bestAlpha; alpha(end,:)=uniform; bits=bestBits;
    info=packageInfo();

    function a = project(a,t)
        a=max(real(a),0); a=a/max(sum(a),realmin);
        if sum(a)==0, a=uniform; end
        if c3, a=sort(a,'descend'); end
        if ~slotPossible(t)
            % Impossible C5 is reported rather than throwing or claiming repair.
            b=minOrdered(t,:);
            if all(isfinite(b)) && sum(b)>0, a=b/sum(b); end
            return;
        end
        b=minOrdered(t,:);
        gamma=expm1(min(700,log(2)*slotTarget(orders(t,:))/(sim.rfTime*sim.radio.bandwidthHz)));
        for u=U:-1:1
            a(u)=max(a(u),gamma(u)*(noise(t,u)+sum(a(u+1:end))));
            if c3 && u<U, a(u)=max(a(u),a(u+1)); end
        end
        if sum(a)>1
            % Anchored normalization preserves the affine SINR/C5 inequalities.
            % Dividing the clamped vector by its sum can violate those inequalities.
            a=b+max(0,(1-sum(b))/max(sum(a)-sum(b),realmin))*(a-b);
        else
            a(1)=a(1)+1-sum(a);
        end
    end

    function [value,rate] = slotValue(a,t,weight)
        physical=zeros(1,U); physical(orders(t,:))=a;
        rate=findAchievableRateV11(hUsers{t},hBS{t},physical,sim);
        numRateEvals=numRateEvals+1;
        value=sum(weight.*rate(orders(t,:)))/sim.radio.bandwidthHz;
    end

    function out = packageInfo()
        out.perUserBits=sum(bestBits,1); out.shortfall=max(0,L-out.perUserBits);
        out.outerIter=outer;
        out.userSlotFeasible=all(all(bestBits>=slotTarget-1e-7));
        out.slotFeasible=all(sum(bestBits,2)>=sim.minBitsPerSlot-1e-7);
        out.feasible=all(out.shortfall<=tolerance*L) && out.userSlotFeasible && out.slotFeasible;
        out.objective=bestObjective;
        out.numRateEvals=numRateEvals;
        out.slotFeasibilityPossible=all(slotPossible);
    end
end

function target = expandTarget(target,U)
    target=target(:).';
    if isscalar(target), target=repmat(target,1,U); end
end

function value = getSimField(s, name, fallback)
    if isfield(s,name) && ~isempty(s.(name))
        value=s.(name);
    else
        value=fallback;
    end
end
