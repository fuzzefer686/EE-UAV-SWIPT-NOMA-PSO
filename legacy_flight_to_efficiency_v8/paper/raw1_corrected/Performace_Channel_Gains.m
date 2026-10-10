% PERFORMACE_CHANNEL_GAINS Backward-compatible entry point.
%
% The original repository contained a second, divergent copy of the main
% simulation here. Both entry points now use the same corrected workflow.
clc;
clear variables;
close all;

results.powerAllocation = runPowerAllocationSimulation();
results.trajectory = runTrajectorySimulation();
