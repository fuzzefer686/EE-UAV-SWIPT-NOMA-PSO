function bestOut = polishAlphaV12(bestIn, sim, nSamples, optimizeBS, polishOpts)
%POLISHALPHAV12 V9 candidate search, accepting by the full V12 mission fitness.
% Geometry/BS and optimizer histories are unchanged unless a better polished
% incumbent is adopted via optional polishOpts within the same evaluation cap.
    if nargin < 4 || isempty(optimizeBS)
        optimizeBS = true;
    end
    if nargin < 5 || isempty(polishOpts)
        polishOpts = struct();
    end
    validateattributes(nSamples, {'numeric'}, {'scalar', 'finite', 'integer', 'nonnegative'});
    validateattributes(optimizeBS, {'logical', 'numeric'}, {'scalar', 'binary'});
    optimizeBS = logical(optimizeBS);

    layout = v10ParticleLayout(sim, optimizeBS);
    D = layout.dimension;
    particle = bestIn.bestParticle(:).';
    evalCountPolish = 0;
    evalCountIncumbentPolish = 0;

    [~, current] = evaluateTrajectoryV12(particle, sim, optimizeBS);
    evalCountPolish = evalCountPolish + 1;
    initial = current;

    numSlots = sim.numSteps - 1;
    defaultCap = 1 + numSlots * nSamples;
    maxPolishEvals = defaultCap;
    if isfield(polishOpts, 'maxPolishEvals') && ~isempty(polishOpts.maxPolishEvals)
        validateattributes(polishOpts.maxPolishEvals, {'numeric'}, ...
            {'scalar', 'finite', 'integer', 'positive'});
        maxPolishEvals = double(polishOpts.maxPolishEvals);
    end

    hasPolishedCandidates = isfield(polishOpts, 'candidates') && ~isempty(polishOpts.candidates);
    polIncAvailable = false;
    bestPolIncFit = -inf;
    bestPolIncEE = NaN;
    bestPolIncFeasible = NaN;
    bestPolIncSource = '';
    bestPolIncParticle = [];
    % Indices of polishOpts.candidates screened (evaluated or reused) for source-cost accounting.
    polishCandidatesUsed = zeros(1, 0);

    if ~hasPolishedCandidates && maxPolishEvals == defaultCap
        % Exact legacy branch: zero RNG or order perturbation.
        for t = 1:numSlots
            idx = layout.positionCount + (t - 1) * sim.noUsers + (1:sim.noUsers);
            bestParticle = particle;
            bestResult = current;
            for sample = 1:nSamples
                if sample == 1
                    alpha = ones(1, sim.noUsers) / sim.noUsers;
                elseif sample == 2
                    alpha = particle(idx);
                else
                    alpha = rand(1, sim.noUsers);
                end
                alpha = max(alpha, sim.pMin);
                alpha = alpha / sum(alpha);
                trial = particle;
                trial(idx) = alpha;
                [trialFitness, trialResult] = evaluateTrajectoryV12(trial, sim, optimizeBS);
                evalCountPolish = evalCountPolish + 1;
                if trialFitness > bestResult.fitness
                    bestParticle = trial;
                    bestResult = trialResult;
                end
            end
            particle = bestParticle;
            current = bestResult;
        end
    else
        if hasPolishedCandidates
            cands = polishOpts.candidates;
            seen = particle;
            for m = 1:numel(cands)
                if ~isfield(cands(m), 'particle') || numel(cands(m).particle) ~= D
                    continue;
                end
                pCand = cands(m).particle(:).';
                srcCand = '';
                if isfield(cands(m), 'source') && ~isempty(cands(m).source)
                    srcCand = char(cands(m).source);
                end
                % If identical to bestIn.bestParticle within 1e-15, reuse initial evaluation.
                if max(abs(pCand - initialParticleRow(bestIn.bestParticle, D))) <= 1e-15
                    cFit = initial.fitness;
                    cRes = initial;
                    pEval = particle;
                    polishCandidatesUsed(end + 1) = m; %#ok<AGROW>
                else
                    diffs = max(abs(seen - pCand), [], 2);
                    if any(diffs <= 1e-15)
                        continue;
                    end
                    if evalCountPolish >= maxPolishEvals
                        break;
                    end
                    seen = [seen; pCand]; %#ok<AGROW>
                    [cFit, cRes] = evaluateTrajectoryV12(pCand, sim, optimizeBS);
                    evalCountPolish = evalCountPolish + 1;
                    evalCountIncumbentPolish = evalCountIncumbentPolish + 1;
                    polishCandidatesUsed(end + 1) = m; %#ok<AGROW>
                    pEval = pCand;
                    if ~cRes.geometryFeasible && evalCountPolish < maxPolishEvals
                        pEval = repairV10Particle(pEval, sim, optimizeBS);
                        [cFit, cRes] = evaluateTrajectoryV12(pEval, sim, optimizeBS);
                        evalCountPolish = evalCountPolish + 1;
                        evalCountIncumbentPolish = evalCountIncumbentPolish + 1;
                    end
                end
                if ~polIncAvailable || cFit > bestPolIncFit
                    polIncAvailable = true;
                    bestPolIncFit = cFit;
                    bestPolIncEE = cRes.eeComputed;
                    bestPolIncFeasible = double(cRes.isFeasible);
                    bestPolIncSource = srcCand;
                    bestPolIncParticle = pEval;
                end
                if cFit > current.fitness
                    particle = pEval;
                    current = cRes;
                end
            end
        end

        rem = max(0, maxPolishEvals - evalCountPolish);
        baseSamp = floor(rem / max(1, numSlots));
        extraSlots = mod(rem, max(1, numSlots));
        for t = 1:numSlots
            nSampSlot = baseSamp + double(t <= extraSlots);
            if nSampSlot <= 0
                continue;
            end
            idx = layout.positionCount + (t - 1) * sim.noUsers + (1:sim.noUsers);
            bestParticle = particle;
            bestResult = current;
            for sample = 1:nSampSlot
                if sample == 1
                    alpha = ones(1, sim.noUsers) / sim.noUsers;
                elseif sample == 2
                    alpha = particle(idx);
                else
                    alpha = rand(1, sim.noUsers);
                end
                alpha = max(alpha, sim.pMin);
                alpha = alpha / sum(alpha);
                trial = particle;
                trial(idx) = alpha;
                [trialFitness, trialResult] = evaluateTrajectoryV12(trial, sim, optimizeBS);
                evalCountPolish = evalCountPolish + 1;
                if trialFitness > bestResult.fitness
                    bestParticle = trial;
                    bestResult = trialResult;
                end
            end
            particle = bestParticle;
            current = bestResult;
        end
    end

    bestOut = bestIn;
    fields = fieldnames(current);
    for k = 1:numel(fields)
        bestOut.(fields{k}) = current.(fields{k});
    end
    bestOut.bestParticle = particle;
    bestOut.bestFitness = current.fitness;
    bestOut.bestEE = current.eeComputed;
    bestOut.bestFeasible = current.isFeasible;
    bestOut.alphaPolished = true;
    bestOut.alphaPolishSamples = nSamples;

    rawCount = 0;
    if isfield(bestIn, 'evalCount') && ~isempty(bestIn.evalCount)
        rawCount = bestIn.evalCount;
    end
    bestOut.evalCountRaw = rawCount;
    bestOut.evalCountPolish = evalCountPolish;
    bestOut.evalCountTotal = rawCount + evalCountPolish;
    bestOut.evalCount = bestOut.evalCountTotal;

    rawIncCount = 0;
    if isfield(bestIn, 'evalCountIncumbentRaw') && ~isempty(bestIn.evalCountIncumbentRaw)
        rawIncCount = bestIn.evalCountIncumbentRaw;
    end
    bestOut.evalCountIncumbentRaw = rawIncCount;
    bestOut.evalCountIncumbentPolish = evalCountIncumbentPolish;
    bestOut.polishCandidatesUsed = polishCandidatesUsed;

    if polIncAvailable
        bestOut.incumbentUsed = true;
        bestOut.incumbentRetained = max(abs(particle - bestPolIncParticle)) <= 1e-15;
        bestOut.incumbentEE = bestPolIncEE;
        bestOut.incumbentFeasible = bestPolIncFeasible;
        bestOut.incumbentSource = bestPolIncSource;
    elseif isfield(bestIn, 'incumbentUsed') && logical(bestIn.incumbentUsed)
        bestOut.incumbentUsed = true;
        if isfield(bestIn, 'incumbentRetained') && logical(bestIn.incumbentRetained)
            bestOut.incumbentRetained = max(abs(particle - bestIn.bestParticle(:).')) <= 1e-15;
        else
            bestOut.incumbentRetained = false;
        end
    else
        bestOut.incumbentUsed = false;
        bestOut.incumbentRetained = false;
        bestOut.incumbentEE = NaN;
        bestOut.incumbentFeasible = NaN;
        bestOut.incumbentSource = '';
    end

    bestOut.mode = [bestIn.mode, '-alpha-polished'];
    fprintf(['V12 alpha polishing: EE %.6e -> %.6e bit/J | ', ...
        'L:%d bitSlot:%d bitUserSlot:%d | feasible %d\n'], ...
        initial.eeComputed, current.eeComputed, current.missionQoSFeasible, ...
        current.slotQoSFeasible, current.userSlotQoSFeasible, current.isFeasible);
end

function row = initialParticleRow(p, D)
    row = reshape(p, 1, D);
end
