function projectRoot = setup_project()
%SETUP_PROJECT Configure only active baseline source and scripts.
% Reference code is excluded to avoid duplicate function names.
    projectRoot = fileparts(mfilename('fullpath'));
    addpath(genpath(fullfile(projectRoot, 'src')));
    addpath(fullfile(projectRoot, 'scripts'));
    fprintf('V8 baseline path configured: %s\n', projectRoot);
end
