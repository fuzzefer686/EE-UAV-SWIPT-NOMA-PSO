function testSaveV9Figures()
% Run in a fresh MATLAB session after setup_project; addpath('tests').
% Close the original windows during export and verify every snapshot survives.
    assert(isempty(findall(groot, 'Type', 'figure')), ...
        'Run testSaveV9Figures in a fresh MATLAB session.');
    outputRoot = tempname;
    mkdir(outputRoot);
    cleanup = onCleanup(@() cleanupTest(outputRoot));

    first = figure(7);
    set(first, 'Visible', 'off', 'Position', [100, 100, 400, 300]);
    ax = subplot(2, 1, 1, 'Parent', first);
    plot(ax, 1:3, [1, 4, 9]);
    legend(ax, 'Example');
    ax = subplot(2, 1, 2, 'Parent', first);
    imagesc(ax, magic(3));
    colorbar(ax);
    second = figure(8);
    set(second, 'Visible', 'off', 'Position', [100, 100, 400, 300]);
    plot(axes('Parent', second), 1:3, [3, 2, 1]);

    % openfig runs this saved callback when the first private copy opens.
    % It deletes both originals, reproducing handle loss during PNG export.
    first.CreateFcn = @closeOriginalWindows;
    setappdata(groot, 'saveV9FiguresTestOriginals', [first, second]);
    outputFolder = saveV9Figures(outputRoot);

    assert(~isgraphics(first) && ~isgraphics(second), ...
        'The original windows must actually close during this test.');
    assert(numel(dir(fullfile(outputFolder, '*.fig'))) == 2);
    assert(numel(dir(fullfile(outputFolder, '*.png'))) == 2);
    assert(isempty(findall(groot, 'Type', 'figure')), ...
        'Export copies must be cleaned up.');
    for number = [7, 8]
        fileBase = fullfile(outputFolder, sprintf('figure_%02d', number));
        info = imfinfo([fileBase, '.png']);
        assert(info.Width > 0 && info.Height > 0);
        restored = openfig([fileBase, '.fig'], 'new', 'invisible');
        assert(~isempty(findall(restored, 'Type', 'axes')));
        if number == 7
            line = findobj(restored, 'Type', 'line');
            assert(isequal(line(1).YData, [1, 4, 9]));
            assert(~isempty(findall(restored, 'Type', 'colorbar')));
        end
        delete(restored);
    end
    fprintf('Figure snapshot/export checks passed after closing original windows.\n');
end

function closeOriginalWindows(~, ~)
    key = 'saveV9FiguresTestOriginals';
    if isappdata(groot, key)
        originals = getappdata(groot, key);
        rmappdata(groot, key);
        delete(originals(isgraphics(originals, 'figure')));
    end
end

function cleanupTest(outputRoot)
    closeOriginalWindows([], []);
    if isfolder(outputRoot)
        rmdir(outputRoot, 's');
    end
end
