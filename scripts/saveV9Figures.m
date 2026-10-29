function outputFolder = saveV9Figures(outputRoot)
%SAVEV9FIGURES Save all open figures as PNG (300 dpi) and editable FIG files.
% Each call creates a new timestamped folder without replacing previous runs.
% Can also be called after plotting existing V9 results, without rerunning PSO.
% Snapshot every FIG first, then export PNGs from private invisible copies.
    if nargin < 1 || isempty(outputRoot)
        outputRoot = fullfile(fileparts(fileparts(mfilename('fullpath'))), ...
            'results', 'ee_rf', 'figures');
    end

    outputFolder = '';
    % Refresh graphics without dispatching queued window-close callbacks.
    drawnow nocallbacks;
    figures = findall(groot, 'Type', 'figure');
    if isempty(figures)
        warning('saveV9Figures:NoFigures', 'No open figures to save.');
        return;
    end
    [~, order] = sort([figures.Number]);
    figures = figures(order);

    runName = ['run_', char(datetime('now', 'Format', 'yyyyMMdd_HHmmss_SSS'))];
    outputFolder = fullfile(outputRoot, runName);
    suffix = 1;
    while exist(outputFolder, 'file') || exist(outputFolder, 'dir')
        outputFolder = fullfile(outputRoot, sprintf('%s_%02d', runName, suffix));
        suffix = suffix + 1;
    end
    [ok, message] = mkdir(outputFolder);
    if ~ok
        error('saveV9Figures:CreateFolderFailed', ...
            'Cannot create figure folder %s: %s', outputFolder, message);
    end

    figFiles = cell(1, numel(figures));
    figureNumbers = NaN(1, numel(figures));
    figCount = 0;
    % Take all editable snapshots before the slower PNG exports can process
    % callbacks or the user closes the original figure windows.
    for k = 1:numel(figures)
        fig = figures(k);
        % A window may have closed before its snapshot was taken.
        if ~isgraphics(fig, 'figure')
            warning('saveV9Figures:ClosedFigure', ...
                'Figure closed before its FIG snapshot; skipping it.');
            continue;
        end
        figureNumber = fig.Number;
        fileBase = fullfile(outputFolder, sprintf('figure_%02d', figureNumber));
        try
            savefig(fig, [fileBase, '.fig']);
            figFiles{k} = [fileBase, '.fig'];
            figureNumbers(k) = figureNumber;
            figCount = figCount + 1;
        catch exportError
            warning('saveV9Figures:SnapshotFailed', ...
                'Figure %d FIG snapshot failed: %s\nContinuing with other figures.', ...
                figureNumber, exportError.message);
        end
    end

    pngCount = 0;
    for k = 1:numel(figFiles)
        if isempty(figFiles{k})
            continue;
        end
        try
            % A new invisible figure is independent of the original window.
            % Hide its handle from ordinary close-all operations as well.
            exportFig = openfig(figFiles{k}, 'new', 'invisible');
            exportCleanup = onCleanup(@() deleteExportFigure(exportFig));
            set(exportFig, 'HandleVisibility', 'off');
            pngFile = [figFiles{k}(1:end-4), '.png'];
            print(exportFig, pngFile, '-dpng', '-r300');
            pngCount = pngCount + 1;
        catch exportError
            warning('saveV9Figures:ExportFailed', ...
                ['Figure %d PNG export failed: %s\n' ...
                 'The FIG snapshot is preserved at %s. Continuing with other figures.'], ...
                figureNumbers(k), exportError.message, figFiles{k});
        end
        clear exportCleanup;
    end
    fprintf('\nSaved %d/%d FIG snapshots and %d/%d PNG images to:\n%s\n', ...
        figCount, numel(figures), pngCount, numel(figures), outputFolder);
end

function deleteExportFigure(fig)
    if isgraphics(fig, 'figure')
        delete(fig);
    end
end
