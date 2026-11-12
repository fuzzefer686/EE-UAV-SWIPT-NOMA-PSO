function [algorithmSeed, polishSeed] = deriveV12OptimizerSeeds(mainSeed)
%DERIVEV12OPTIMIZERSEEDS Exact 32-bit bijective seed derivation per scenario.
% Uses 16-bit split double arithmetic (max intermediate < 2^33 << 2^53) to
% avoid MATLAB uint64 saturation. Reproduces v10Config defaults at seed 2026:
%   deriveV12OptimizerSeeds(2026) -> [151459287, 152459287].
    validateattributes(mainSeed, {'numeric'}, {'scalar', 'real', 'finite', 'nonnegative'});
    M = 4294967296; % 2^32
    s = mod(floor(double(mainSeed)), M);

    baseAlgo = 151459287;
    basePol  = 152459287;

    deltaAlgo = mod(mix32(s, 1) - mix32(2026, 1), M);
    deltaPol  = mod(mix32(s, 2) - mix32(2026, 2), M);

    algorithmSeed = mod(baseAlgo + deltaAlgo, M);
    polishSeed    = mod(basePol  + deltaPol,  M);
    if polishSeed == algorithmSeed
        polishSeed = mod(polishSeed + 1000000, M);
    end
end

function h = mix32(x, stream)
    % Bijective MurmurHash3-style 32-bit avalanche using exact 16-bit split multiply.
    if stream == 1
        c1 = 2246822519;
        c2 = 3266489917;
    else
        c1 = 2654435761;
        c2 = 668265263;
    end
    u = uint32(x);
    u = bitxor(u, bitshift(u, -16));
    u = uint32(mulMod32(double(u), c1));
    u = bitxor(u, bitshift(u, -13));
    u = uint32(mulMod32(double(u), c2));
    u = bitxor(u, bitshift(u, -16));
    h = double(u);
end

function prod32 = mulMod32(a, b)
    % Exact (a * b) mod 2^32 in IEEE-754 double via 16-bit split.
    aLo = mod(a, 65536);
    aHi = floor(a / 65536);
    bLo = mod(b, 65536);
    bHi = floor(b / 65536);
    mid = mod(aHi * bLo + aLo * bHi, 65536);
    prod32 = mod(mid * 65536 + aLo * bLo, 4294967296);
end
