% V11A: optimize X, NOMA alpha and optional BS positions; Y fixed, Z constant.
% Edit src/config/v11Config.m for BOTH V11 versions. V9 is independent.
clc;
close all;
projectRoot=fileparts(fileparts(mfilename('fullpath')));
addpath(projectRoot);
setup_project();
cfg=v11Config();
v11=runV11('A',cfg);
sim=v11.sim;
resBase=v11.resBase;
trajJoint=v11.trajJoint;
trajFullRaw=v11.trajFullRaw;
trajIPSORaw=v11.trajIPSORaw;
trajFull=v11.trajFull;
trajIPSO=v11.trajIPSO;
v11OutputFolder=v11.outputFolder;
