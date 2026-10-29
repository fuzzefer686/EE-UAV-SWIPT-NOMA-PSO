% V10B: optimize X/Y, NOMA alpha and optional BS positions; Z constant.
% Y advances towards endXY by at least cfg.geometry.minYProgress metres.
clc;
close all;
projectRoot=fileparts(fileparts(mfilename('fullpath')));
addpath(projectRoot);
setup_project();
cfg=v10Config();
v10=runV10('B',cfg);
sim=v10.sim;
resBase=v10.resBase;
trajJoint=v10.trajJoint;
trajFullRaw=v10.trajFullRaw;
trajIPSORaw=v10.trajIPSORaw;
trajFull=v10.trajFull;
trajIPSO=v10.trajIPSO;
v10OutputFolder=v10.outputFolder;
