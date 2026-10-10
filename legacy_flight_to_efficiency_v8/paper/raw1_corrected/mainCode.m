% MAINCODE Entry point for the paper-aligned UAV simulation.
clc;
clear variables;
close all;

results.powerAllocation = runPowerAllocationSimulation();
results.trajectory = runTrajectorySimulation();
