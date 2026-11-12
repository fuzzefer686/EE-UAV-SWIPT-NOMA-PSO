% C0-C5 x 3 scenario seeds x 3 methods = 54 searches.
% Common setup: L=3 Mbit/user, q=5 kbit/user/slot, Emax=17000 J.
% Each method uses 120 particles and 1000 iterations (profile 'full').
% C5 explicitly opts into unvalidated experimental motion; it is not Dai.
projectRoot=fileparts(fileparts(mfilename('fullpath')));
addpath(projectRoot);
setup_project();
seeds=[2026,608060,3486784401];
presets=0:5;
v10cCampaign=runV10CComparison('full',seeds,presets);
