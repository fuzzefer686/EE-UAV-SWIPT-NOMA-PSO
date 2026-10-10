function projectRoot = setup_project()
%SETUP_PROJECT Add the active project folders to the MATLAB search path.
%   PROJECTROOT = SETUP_PROJECT() prepares the repository for running the
%   V8/V9 scripts under scripts/main and scripts/benchmarks.
%   Archived files are intentionally excluded from the MATLAB path.

    projectRoot = fileparts(mfilename('fullpath'));

    activeFolders = {
        fullfile(projectRoot, 'src'), ...
        fullfile(projectRoot, 'scripts') ...
    };

    for k = 1:numel(activeFolders)
        addpath(genpath(activeFolders{k}));
    end

    fprintf('UAV SWIPT-NOMA project path configured:\n  %s\n', projectRoot);
end
