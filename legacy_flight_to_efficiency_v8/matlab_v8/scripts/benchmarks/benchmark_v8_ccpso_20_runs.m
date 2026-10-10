function benchmark_v8_ccpso_20_runs(firstRun, lastRun)
% BENCHMARK_V8_CCPSO_20_RUNS
% Chạy thử nghiệm đối kháng 20 lần cho phiên bản V8-SNAPSHOT-CCPSO
% Cấu hình và 20 seeds ngẫu nhiên TRÙNG KHỚP 100% với các tập kết quả V8 và V9 đã có.
%
% So sánh 3 thuật toán:
%   1. Full Standard JointPSO (149D - V8 gốc)
%   2. Full CC-JointPSO (38D + 6D + 105D - V8-SNAPSHOT-CCPSO)
%   3. Full IPSO (149D - V8 Improved PSO)
%
% Output:
%   - Các file log chi tiết: result_v8_ccpso/RESULT_1_V8_CCPSO.txt ... RESULT_20_V8_CCPSO.txt
%   - File CSV tổng hợp: output/csv/v8_ccpso_20_runs_comparison.csv
%   - File MAT tiến độ: result_v8_ccpso/V8_CCPSO_20Runs_progress.mat

    clc;
    close all;

    %% 1. Cấu hình phạm vi chạy (Mặc định: cả 20 runs)
    if nargin < 1 || isempty(firstRun)
        firstRunIndex = 1;
    else
        firstRunIndex = firstRun;
    end

    if nargin < 2 || isempty(lastRun)
        lastRunIndex = 20;
    else
        lastRunIndex = lastRun;
    end

    % Thiết lập số vòng lặp (1000 iter là chuẩn của V8; có thể hạ xuống nếu muốn test nhanh)
    maxIterFull = 1000;
    enableAlphaPolish = true;
    generatePlotsForBatch = false;

    %% 2. Danh sách 20 Seeds chuẩn của V8 và V9
    seedList = [ ...
        608060;     3486784401; 2026;       650446043;  36849619; ...
        33651854;   644642105;  127737724;  533585194;  152213280; ...
        953983899;  911725975;  182069212;  227220789;  266299233; ...
        873962939;  517299465;  926867425;  832189295;  927443955 ...
    ];

    %% 3. Thiết lập đường dẫn thư mục
    thisScript = mfilename('fullpath');
    projectRoot = fileparts(fileparts(fileparts(thisScript)));
    addpath(projectRoot);
    setup_project();

    outLogDir = fullfile(projectRoot, 'result_v8_ccpso');
    if exist(outLogDir, 'dir') ~= 7
        mkdir(outLogDir);
    end

    csvDir = fullfile(projectRoot, 'output', 'csv');
    if exist(csvDir, 'dir') ~= 7
        mkdir(csvDir);
    end
    csvSummaryPath = fullfile(csvDir, 'v8_ccpso_20_runs_comparison.csv');

    fprintf('\n============================================================\n');
    fprintf('   BENCHMARK 20 RUNS: V8-SNAPSHOT-CCPSO vs STANDARD PSO    \n');
    fprintf('============================================================\n');
    fprintf('Phạm vi chạy: Run %d -> Run %d (trong tổng số 20 seeds)\n', firstRunIndex, lastRunIndex);
    fprintf('Số vòng lặp : %d iterations\n', maxIterFull);
    fprintf('Thư mục logs: %s\n', outLogDir);
    fprintf('Thư mục CSV : %s\n', csvSummaryPath);
    fprintf('============================================================\n\n');

    %% 4. Mảng lưu trữ kết quả thống kê
    numSelected = lastRunIndex - firstRunIndex + 1;
    resTable = cell(numSelected + 1, 11);
    resTable(1, :) = {'Run', 'Seed', 'V8_Standard_Fit_kbps', 'CCPSO_Fit_kbps', 'Delta_Fit_Pct', ...
                      'V8_Standard_MinRate_bps', 'CCPSO_MinRate_bps', 'Delta_MinRate_Pct', ...
                      'Time_Standard_s', 'Time_CCPSO_s', 'Speedup_Factor'};

    totalBatchTimer = tic;
    rowCounter = 1;

    %% 5. Vòng lặp chạy từng Seed
    for runIdx = firstRunIndex:lastRunIndex
        currentSeed = seedList(runIdx);
        logFile = fullfile(outLogDir, sprintf('RESULT_%d_V8_CCPSO.txt', runIdx));

        fprintf('\n>>> BẮT ĐẦU RUN %d/%d (mainSeed = %.0f) <<<\n', ...
            runIdx, 20, currentSeed);

        % Ghi log diary
        if exist(logFile, 'file') == 2
            delete(logFile);
        end
        diary(logFile);
        diary on;

        runTimer = tic;

        try
            % Thiết lập cấu hình hệ thống đồng nhất 100% với V8
            useFixedSeed = true;
            mainSeed = currentSeed;
            generatePlots = generatePlotsForBatch;
            runAlphaPolish = enableAlphaPolish;

            % Gọi script chính
            run('maincodeV8_CCPSO.m');

            diary off;

            elapsed = toc(runTimer);
            fprintf('>>> HOÀN THÀNH RUN %d trong %.1f giây! <<<\n', runIdx, elapsed);

            % Thu thập số liệu vào bảng
            rowCounter = rowCounter + 1;
            fitStd_kbps = trajFull.bestFitness / 1e3;
            fitCC_kbps  = trajCC.bestFitness / 1e3;
            deltaFitPct = (trajCC.bestFitness - trajFull.bestFitness) / trajFull.bestFitness * 100;

            minRateStd_bps = min(trajFull.stepMin);
            minRateCC_bps  = min(trajCC.stepMin);
            deltaMinPct    = (minRateCC_bps - minRateStd_bps) / minRateStd_bps * 100;

            speedup = timeFull / max(timeCC, eps);

            resTable(rowCounter, :) = { ...
                runIdx, currentSeed, fitStd_kbps, fitCC_kbps, deltaFitPct, ...
                minRateStd_bps, minRateCC_bps, deltaMinPct, ...
                timeFull, timeCC, speedup ...
            };

            % In tóm tắt nhanh của run này
            fprintf('    [KẾT QUẢ RUN %d]: Standard Fit = %.2f kbps | CC-PSO Fit = %.2f kbps (%+.2f%%) | Speedup = %.2fx\n', ...
                runIdx, fitStd_kbps, fitCC_kbps, deltaFitPct, speedup);

        catch ME
            diary off;
            fprintf('\n[LỖI TẠI RUN %d]: %s\n', runIdx, ME.message);
            fprintf('File: %s (Line %d)\n', ME.stack(1).file, ME.stack(1).line);
        end
    end

    totalTime = toc(totalBatchTimer);
    fprintf('\n============================================================\n');
    fprintf('HOÀN TẤT TOÀN BỘ BATCH RUNS (Tổng thời gian: %.1f s / %.2f phút)\n', ...
        totalTime, totalTime / 60);
    fprintf('============================================================\n');

    %% 6. Xuất bảng CSV tổng hợp
    if rowCounter > 1
        T_out = cell2table(resTable(2:rowCounter, :), 'VariableNames', resTable(1, :));
        writetable(T_out, csvSummaryPath);
        fprintf('Đã lưu bảng so sánh tổng hợp vào:\n  %s\n\n', csvSummaryPath);
        disp(T_out);
    end
end
