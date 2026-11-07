% V12B: optimize X/Y, NOMA alpha and optional BS positions; Z constant.
% Y advances towards endXY by at least cfg.geometry.minYProgress metres.
clc;
close all;
projectRoot=fileparts(fileparts(mfilename('fullpath')));
addpath(projectRoot);
setup_project();
cfg=v12Config();
v12=runV12('B',cfg);
sim=v12.sim;
resBase=v12.resBase;
trajJoint=v12.trajJoint;
trajFullRaw=v12.trajFullRaw;
trajIPSORaw=v12.trajIPSORaw;
trajFull=v12.trajFull;
trajIPSO=v12.trajIPSO;
v12OutputFolder=v12.outputFolder;
