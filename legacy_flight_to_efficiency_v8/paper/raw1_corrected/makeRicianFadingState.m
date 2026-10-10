function fading = makeRicianFadingState(noUsers, noBS)
%MAKERICIANFADINGSTATE Create fixed, independent LoS/NLoS samples.
%
% The same samples are reused while PSO evaluates candidate positions.
% This keeps the objective function deterministic for a given simulation
% realization while preserving independent LoS and NLoS components.

    fading.userLOS = exp(1i * 2 * pi * rand(1, noUsers));
    fading.userNLOS = sqrt(1/2) * (randn(1, noUsers) + 1i * randn(1, noUsers));

    fading.bsLOS = exp(1i * 2 * pi * rand(1, noBS));
    fading.bsNLOS = sqrt(1/2) * (randn(1, noBS) + 1i * randn(1, noBS));
end
