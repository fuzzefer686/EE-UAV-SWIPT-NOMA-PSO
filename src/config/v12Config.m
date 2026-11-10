function cfg = v12Config()
%V12CONFIG Shared editable configuration for V12A and V12B.
% Extends V10 defaults with causal UL/DL decode-and-forward power splitting
% and quasi-steady horizontal acceleration/deceleration propulsion energy.
    cfg = v10Config();
    cfg.version = 'V12-CausalDF-Accel-1';

    % Causal decode-and-forward SWIPT settings
    cfg.radio.powerSplitMode = 'optimal-causal'; % 'optimal-causal' or 'fixed'
    cfg.radio.enforceUlDlCausality = true;
    cfg.radio.phiMin = 0;
    cfg.radio.phiMax = 0.999; % practical SWIPT cap (>= 0.1% ID branch power)

    % Quasi-steady horizontal acceleration/deceleration settings
    cfg.flight.motionMode = 'quasi-steady-accel'; % 'quasi-steady-accel' or 'steady-cruise'
    cfg.flight.acceleration = 3.0; % m/s^2, positive horizontal acceleration/deceleration
    cfg.flight.quadratureNodes = 16; % Gauss-Legendre nodes on [0, 1]

    % V12 optimizer modes, symmetric Joint polishing, budget cap, and seed policy
    cfg.optimizers.initMode = 'v10';            % 'v10' or 'clustered' ('auto' removed)
    cfg.optimizers.updateMode = 'independent';  % 'independent' or 'correlated'
    cfg.optimizers.mutationMode = 'elementwise'; % 'elementwise' or 'block' (Full IPSO)
    cfg.optimizers.polishJoint = true;          % symmetric raw/polished comparison across optimizers
    cfg.optimizers.incumbentMode = 'none';      % 'none', 'jointToFull', 'LContinuation', or 'crossModel'
    cfg.optimizers.maxEvals = [];               % [] => finite P*(maxIter+1) in runV12/campaign; Inf => uncapped legacy parity
    cfg.optimizers.seedMode = 'per-scenario';   % 'per-scenario' or 'fixed' (used by runV12Campaign)

    projectRoot = fileparts(fileparts(fileparts(mfilename('fullpath'))));
    cfg.output.root = fullfile(projectRoot, 'results', 'v12');
end
