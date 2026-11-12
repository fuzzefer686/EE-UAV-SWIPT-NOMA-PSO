% V10C reference PSO/IPSO experiment. Select C0..C5 and smoke/quick/full.
projectRoot=fileparts(fileparts(mfilename('fullpath')));
addpath(projectRoot);
setup_project();
cfg=v10cConfig('C4','quick');
v10c=runV10C(cfg);
