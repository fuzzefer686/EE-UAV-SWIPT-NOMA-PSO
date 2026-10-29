% V10A: optimize X, NOMA alpha and optional BS positions; Y fixed, Z constant.
% Edit src/config/v10Config.m for BOTH V10 versions. V9 is independent.
clc;
close all;
projectRoot=fileparts(fileparts(mfilename('fullpath')));
addpath(projectRoot);
setup_project();
cfg=v10Config();
v10=runV10('A',cfg);
sim=v10.sim;
resBase=v10.resBase;
trajJoint=v10.trajJoint;
trajFullRaw=v10.trajFullRaw;
trajIPSORaw=v10.trajIPSORaw;
trajFull=v10.trajFull;
trajIPSO=v10.trajIPSO;
v10OutputFolder=v10.outputFolder;
