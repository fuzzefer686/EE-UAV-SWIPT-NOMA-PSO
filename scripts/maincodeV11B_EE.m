% V11B: optimize X/Y, NOMA alpha and optional BS positions; Z constant.
% Y advances towards endXY by at least cfg.geometry.minYProgress metres.
clc;
close all;
projectRoot=fileparts(fileparts(mfilename('fullpath')));
addpath(projectRoot);
setup_project();
cfg=v11Config();
v11=runV11('B',cfg);
sim=v11.sim;
resBase=v11.resBase;
trajJoint=v11.trajJoint;
trajFullRaw=v11.trajFullRaw;
trajIPSORaw=v11.trajIPSORaw;
trajFull=v11.trajFull;
trajIPSO=v11.trajIPSO;
v11OutputFolder=v11.outputFolder;
