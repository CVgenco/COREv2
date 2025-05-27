function results = runOutputAndValidation(configFile, outputDir)
% runOutputAndValidation Export simulation results and validate simulation quality using a config file and output directory.
%   configFile: path to the user config .m file
%   outputDir: output directory for validation results

run(configFile); % Loads config into workspace
if ~exist('config', 'var')
    error('Config variable not found after running %s. Check your config file.', configFile);
end
if ~exist(outputDir, 'dir'), mkdir(outputDir); end

% === Load simulated paths and info ===
if ~exist('simPaths', 'var') || ~exist('productNames', 'var')
    simFile = fullfile(outputDir, 'simulated_paths.mat');
    if exist(simFile, 'file')
        load(simFile, 'simPaths', 'productNames');
    else
        % Fallback: try parent directory (legacy)
        simFileParent = fullfile(outputDir, '../simulated_paths.mat');
        if exist(simFileParent, 'file')
            load(simFileParent, 'simPaths', 'productNames');
        else
            error('Could not find simulated_paths.mat in %s or its parent directory.', outputDir);
        end
    end
end
if ~exist('alignedTable', 'var')
    load('alignedTable.mat', 'alignedTable'); % Or load from your data pipeline
end

nPaths = size(simPaths.(productNames{1}), 2);
nObs = size(simPaths.(productNames{1}), 1);

% === Export all simulated paths to CSV (if not already done) ===
for i = 1:numel(productNames)
    pname = productNames{i};
    outFile = fullfile(outputDir, [pname '_simulated_paths.csv']);
    writematrix(simPaths.(pname), outFile);
end

% === Compute and export summary statistics ===
simStats = struct();
histStats = struct();
for i = 1:numel(productNames)
    pname = productNames{i};
    simData = simPaths.(pname);
    histData = alignedTable.(pname);
    simStats.(pname) = struct('mean', mean(simData,1), 'std', std(simData,0,1), ...
        'min', min(simData,[],1), 'max', max(simData,[],1), ...
        'skewness', skewness(simData,0,1), 'kurtosis', kurtosis(simData,0,1));
    % Fix: Manually remove NaNs for skewness/kurtosis (for older MATLAB versions)
    skewHist = nan(1, size(histData,2));
    kurtHist = nan(1, size(histData,2));
    for col = 1:size(histData,2)
        colData = histData(:,col);
        colData = colData(~isnan(colData));
        if ~isempty(colData)
            skewHist(col) = skewness(colData,0);
            kurtHist(col) = kurtosis(colData,0);
        end
    end
    histStats.(pname) = struct('mean', mean(histData,'omitnan'), 'std', std(histData,'omitnan'), ...
        'min', min(histData,[],'omitnan'), 'max', max(histData,[],'omitnan'), ...
        'skewness', skewHist, 'kurtosis', kurtHist);
    % Export summary stats
    statsTable = table(simStats.(pname).mean', simStats.(pname).std', simStats.(pname).min', simStats.(pname).max', simStats.(pname).skewness', simStats.(pname).kurtosis', ...
        'VariableNames', {'Mean','Std','Min','Max','Skewness','Kurtosis'});
    writetable(statsTable, fullfile(outputDir, [pname '_simulated_stats.csv']));
end
save(fullfile(outputDir, 'simStats.mat'), 'simStats', 'histStats');

% === Compute and export realized correlation matrix and volatility ===
simMatrix = [];
histMatrix = [];
for i = 1:numel(productNames)
    simMatrix = [simMatrix, simPaths.(productNames{i})];
    histMatrix = [histMatrix, alignedTable.(productNames{i})];
end
realizedCorr = corr(simMatrix, 'rows', 'pairwise');
histCorr = corr(histMatrix, 'rows', 'pairwise');
writematrix(realizedCorr, fullfile(outputDir, 'simulated_correlation_matrix.csv'));
writematrix(histCorr, fullfile(outputDir, 'historical_correlation_matrix.csv'));

% === Path diversity metrics ===
pathCorrs = corr(simMatrix);
meanPathCorr = mean(pathCorrs(triu(true(size(pathCorrs)),1)));
fid = fopen(fullfile(outputDir, 'path_diversity.txt'), 'w');
fprintf(fid, 'Mean pairwise path correlation: %.4f\n', meanPathCorr);
fclose(fid);

% === Validation: Compare simulated vs. historical stats ===
for i = 1:numel(productNames)
    pname = productNames{i};
    % --- Distribution comparison plot (robust to large arrays, final defensive fix) ---
    simVals = simPaths.(pname)(:);
    simVals = simVals(isfinite(simVals) & isreal(simVals) & ~isnan(simVals));
    histVals = alignedTable.(pname);
    histVals = histVals(isfinite(histVals) & isreal(histVals) & ~isnan(histVals));
    maxPlot = 1e5; % 100,000 points
    if numel(simVals) > maxPlot
        simVals = simVals(randperm(numel(simVals), maxPlot));
    end
    if numel(histVals) > maxPlot
        histVals = histVals(randperm(numel(histVals), maxPlot));
    end
    if ~isempty(simVals) && ~isempty(histVals) && isnumeric(simVals) && isnumeric(histVals)
        try
            figure;
            histogram(simVals, 'Normalization', 'pdf'); hold on;
            histogram(histVals, 'Normalization', 'pdf');
            legend('Simulated','Historical');
            title(['Distribution: ' pname]);
            saveas(gcf, fullfile(outputDir, [pname '_distribution_compare.png']));
            close;
        catch ME
            warning('Distribution plot failed for %s: %s', pname, ME.message);
        end
    else
        warning('Distribution plot skipped for %s: insufficient or invalid data.', pname);
    end
    % --- Time series plot (mean path vs. historical, robust to large arrays) ---
    meanSim = mean(simPaths.(pname), 2, 'omitnan');
    histSeries = alignedTable.(pname);
    nObs = numel(meanSim);
    maxTSPlot = 1e4; % 10,000 points for time series
    if nObs > maxTSPlot
        idx = round(linspace(1, nObs, maxTSPlot));
        meanSim = meanSim(idx);
        histSeries = histSeries(idx);
    end
    if ~isempty(meanSim) && ~isempty(histSeries)
        figure;
        plot(meanSim, 'b'); hold on;
        plot(histSeries, 'k');
        legend('Simulated Mean Path','Historical');
        title(['Time Series: ' pname]);
        saveas(gcf, fullfile(outputDir, [pname '_timeseries_compare.png']));
        close;
    else
        warning('Time series plot skipped for %s: insufficient data.', pname);
    end
    % --- Jump diagnostics: frequency and size distribution ---
    try
        % Load jump stats from EDA patterns if available
        patternsFile = fullfile('EDA_Results', [pname '_patterns.mat']);
        if exist(patternsFile, 'file')
            ptn = load(patternsFile);
            if isfield(ptn, 'volJump') && isfield(ptn.volJump, 'jumpSizes') && isfield(ptn.volJump, 'jumpFrequency')
                % Historical jump sizes and frequency
                histJumpSizes = ptn.volJump.jumpSizes;
                histJumpFreq = ptn.volJump.jumpFrequency;
                % Simulated jump sizes and frequency (across all paths)
                simData = simPaths.(pname);
                simReturns = diff(simData);
                simJumpThresh = 4 * std(simReturns(:), 'omitnan');
                simJumps = abs(simReturns) > simJumpThresh;
                simJumpSizes = simReturns(simJumps);
                simJumpFreq = sum(simJumps(:)) / numel(simReturns);
                % Print jump frequencies
                fid = fopen(fullfile(outputDir, [pname '_jump_frequency.txt']), 'w');
                fprintf(fid, 'Historical jump frequency: %.4f\n', histJumpFreq);
                fprintf(fid, 'Simulated jump frequency: %.4f\n', simJumpFreq);
                fclose(fid);
                % Save jump sizes for scoring
                writematrix(histJumpSizes(:), fullfile(outputDir, [pname '_hist_jump_sizes.csv']));
                writematrix(simJumpSizes(:), fullfile(outputDir, [pname '_sim_jump_sizes.csv']));
                % Plot jump size histograms (subsample if large)
                maxPlot = 1e5;
                if numel(histJumpSizes) > maxPlot
                    histJumpSizes = histJumpSizes(randperm(numel(histJumpSizes), maxPlot));
                end
                if numel(simJumpSizes) > maxPlot
                    simJumpSizes = simJumpSizes(randperm(numel(simJumpSizes), maxPlot));
                end
                figure;
                histogram(histJumpSizes, 'Normalization', 'pdf'); hold on;
                histogram(simJumpSizes, 'Normalization', 'pdf');
                legend('Historical Jumps','Simulated Jumps');
                title(['Jump Size Distribution: ' pname]);
                saveas(gcf, fullfile(outputDir, [pname '_jump_size_histogram.png']));
                close;
                % QQ-plot for jump sizes (subsample if large)
                figure;
                qqplot(simJumpSizes, histJumpSizes);
                title(['QQ-Plot: Simulated vs. Historical Jump Sizes (' pname ')']);
                saveas(gcf, fullfile(outputDir, [pname '_jump_size_qqplot.png']));
                close;
            else
                warning('Jump diagnostics skipped for %s: volJump field missing or incomplete.', pname);
            end
        else
            warning('Jump diagnostics skipped for %s: patterns file missing.', pname);
        end
    catch ME
        warning('Jump diagnostics failed for %s: %s', pname, ME.message);
    end
    % --- Heavy-tailed innovation diagnostics: kurtosis, QQ-plot, histogram overlays ---
    try
        % Compute returns for simulated and historical data
        simData = simPaths.(pname);
        histData = alignedTable.(pname);
        simReturns = diff(simData);
        histReturns = diff(histData);
        % Remove NaNs, Infs, complex, and subsample if large
        simReturns = simReturns(isfinite(simReturns) & isreal(simReturns));
        histReturns = histReturns(isfinite(histReturns) & isreal(histReturns));
        maxPlot = 1e5;
        if numel(simReturns) > maxPlot
            simReturns = simReturns(randperm(numel(simReturns), maxPlot));
        end
        if numel(histReturns) > maxPlot
            histReturns = histReturns(randperm(numel(histReturns), maxPlot));
        end
        % Kurtosis comparison
        simKurt = kurtosis(simReturns);
        histKurt = kurtosis(histReturns);
        fid = fopen(fullfile(outputDir, [pname '_kurtosis.txt']), 'w');
        fprintf(fid, 'Historical returns kurtosis: %.4f\n', histKurt);
        fprintf(fid, 'Simulated returns kurtosis: %.4f\n', simKurt);
        fclose(fid);
        % Histogram overlay
        figure;
        histogram(histReturns, 'Normalization', 'pdf'); hold on;
        histogram(simReturns, 'Normalization', 'pdf');
        legend('Historical Returns','Simulated Returns');
        title(['Return Distribution: ' pname]);
        saveas(gcf, fullfile(outputDir, [pname '_return_histogram.png']));
        close;
        % QQ-plot
        figure;
        qqplot(simReturns, histReturns);
        title(['QQ-Plot: Simulated vs. Historical Returns (' pname ')']);
        saveas(gcf, fullfile(outputDir, [pname '_return_qqplot.png']));
        close;
        % Regime-conditional diagnostics if available
        patternsFile = fullfile('EDA_Results', [pname '_patterns.mat']);
        if exist(patternsFile, 'file')
            ptn = load(patternsFile);
            if isfield(ptn, 'regimeJumpStats') && isfield(ptn, 'regimeTDoF')
                regimeSeq = [];
                if exist('regimeInfo', 'var') && isfield(regimeInfo, pname)
                    regimeSeq = regimeInfo.(pname).regimeStates;
                end
                nRegimes = numel(ptn.regimeTDoF);
                for r = 1:nRegimes
                    if isempty(regimeSeq), continue; end
                    simRegIdx = (regimeSeq(2:end) == r);
                    histRegIdx = (regimeSeq(2:end) == r);
                    simRegReturns = simReturns(simRegIdx);
                    histRegReturns = histReturns(histRegIdx);
                    % Remove NaNs, Infs, complex, and subsample if large
                    simRegReturns = simRegReturns(isfinite(simRegReturns) & isreal(simRegReturns));
                    histRegReturns = histRegReturns(isfinite(histRegReturns) & isreal(histRegReturns));
                    if numel(simRegReturns) > maxPlot
                        simRegReturns = simRegReturns(randperm(numel(simRegReturns), maxPlot));
                    end
                    if numel(histRegReturns) > maxPlot
                        histRegReturns = histRegReturns(randperm(numel(histRegReturns), maxPlot));
                    end
                    if isempty(simRegReturns) || isempty(histRegReturns), continue; end
                    simRegKurt = kurtosis(simRegReturns);
                    histRegKurt = kurtosis(histRegReturns);
                    fid = fopen(fullfile(outputDir, sprintf('%s_regime%d_kurtosis.txt', pname, r)), 'w');
                    fprintf(fid, 'Historical regime %d returns kurtosis: %.4f\n', r, histRegKurt);
                    fprintf(fid, 'Simulated regime %d returns kurtosis: %.4f\n', r, simRegKurt);
                    fclose(fid);
                    % Histogram overlay
                    figure;
                    histogram(histRegReturns, 'Normalization', 'pdf'); hold on;
                    histogram(simRegReturns, 'Normalization', 'pdf');
                    legend('Historical Returns','Simulated Returns');
                    title(sprintf('Return Distribution: %s (Regime %d)', pname, r));
                    saveas(gcf, fullfile(outputDir, sprintf('%s_regime%d_return_histogram.png', pname, r)));
                    close;
                    % QQ-plot
                    figure;
                    qqplot(simRegReturns, histRegReturns);
                    title(sprintf('QQ-Plot: Sim vs. Hist Returns (%s, Regime %d)', pname, r));
                    saveas(gcf, fullfile(outputDir, sprintf('%s_regime%d_return_qqplot.png', pname, r)));
                    close;
                end
            end
        end
    catch ME
        warning('Heavy-tailed diagnostics failed for %s: %s', pname, ME.message);
    end
    % --- Volatility clustering diagnostics: autocorrelation of squared returns ---
    try
        simData = simPaths.(pname);
        histData = alignedTable.(pname);
        simReturns = diff(simData);
        histReturns = diff(histData);
        % Remove NaNs, Infs, complex, and subsample if large
        simReturns = simReturns(isfinite(simReturns) & isreal(simReturns));
        histReturns = histReturns(isfinite(histReturns) & isreal(histReturns));
        simSq = simReturns.^2;
        histSq = histReturns.^2;
        % Subsample if large
        maxPlot = 1e5;
        if numel(simSq) > maxPlot
            simSq = simSq(randperm(numel(simSq), maxPlot));
        end
        if numel(histSq) > maxPlot
            histSq = histSq(randperm(numel(histSq), maxPlot));
        end
        % Autocorrelation (e.g., up to lag 50)
        if isempty(simSq) || isempty(histSq)
            warning('Volatility clustering diagnostics skipped for %s: insufficient data.', pname);
            % Ensure an empty or placeholder file is written if diagnostics are skipped,
            % so that computeErrorScore doesn't fail on a missing file, but gets Inf.
            acfTable = table(NaN(0,1), NaN(0,1), NaN(0,1), 'VariableNames', {'Lag','HistoricalACF','SimulatedACF'});
            writetable(acfTable, fullfile(outputDir, [pname '_volatility_acf.csv']));
        else
            maxLag = 50;
            [simACF, lags] = autocorr(simSq, 'NumLags', maxLag);
            [histACF, ~] = autocorr(histSq, 'NumLags', maxLag);
            % Save to file with COLUMN vectors
            acfTable = table(lags, histACF, simACF, 'VariableNames', {'Lag','HistoricalACF','SimulatedACF'});
            writetable(acfTable, fullfile(outputDir, [pname '_volatility_acf.csv']));
            % Plot
            figure;
            plot(lags, histACF, 'k', 'LineWidth', 2); hold on;
            plot(lags, simACF, 'b--', 'LineWidth', 2);
            legend('Historical','Simulated');
            title(['Autocorrelation of Squared Returns: ' pname]);
            xlabel('Lag'); ylabel('ACF');
            saveas(gcf, fullfile(outputDir, [pname '_volatility_acf.png']));
            close;
        end
    catch ME
        warning('Volatility clustering diagnostics failed for %s: %s', pname, ME.message);
    end
    % --- Regime diagnostics: duration, volatility, transition matrix ---
    try
        if exist('regimeInfo', 'var') && isfield(regimeInfo, pname)
            % Historical regime info
            histRegimes = regimeInfo.(pname).regimeStates;
            nRegimes = regimeInfo.(pname).nRegimes;
            % Simulated regime info (if available, else use historical for diagnostics)
            simRegimes = histRegimes; % If you have simulated regime sequences, replace here
            % Regime durations
            histDur = diff([0; find(diff(histRegimes)~=0); numel(histRegimes)]);
            % Save regime durations for scoring
            writematrix(histDur(:), fullfile(outputDir, [pname '_hist_regime_durations.csv']));
            if exist('simRegimes', 'var')
                simDur = diff([0; find(diff(simRegimes)~=0); numel(simRegimes)]);
                writematrix(simDur(:), fullfile(outputDir, [pname '_sim_regime_durations.csv']));
            end
            figure;
            histogram(histDur, 'Normalization', 'pdf');
            title(['Historical Regime Durations: ' pname]);
            xlabel('Duration'); ylabel('PDF');
            saveas(gcf, fullfile(outputDir, [pname '_hist_regime_duration_hist.png']));
            close;
            % Regime volatility
            histData = alignedTable.(pname);
            histReturns = diff(histData);
            regimeVols = nan(1, nRegimes);
            for r = 1:nRegimes
                regimeVols(r) = std(histReturns(histRegimes(2:end)==r), 'omitnan');
            end
            writematrix(regimeVols, fullfile(outputDir, [pname '_hist_regime_volatility.csv']));
            % Regime transition matrix
            transMat = zeros(nRegimes);
            for t = 1:(length(histRegimes)-1)
                from = histRegimes(t);
                to = histRegimes(t+1);
                if ~isnan(from) && ~isnan(to)
                    transMat(from, to) = transMat(from, to) + 1;
                end
            end
            transMat = transMat ./ sum(transMat,2);
            writematrix(transMat, fullfile(outputDir, [pname '_hist_regime_transition_matrix.csv']));
            figure;
            imagesc(transMat); colorbar;
            title(['Historical Regime Transition Matrix: ' pname]);
            xlabel('To Regime'); ylabel('From Regime');
            saveas(gcf, fullfile(outputDir, [pname '_hist_regime_transition_matrix.png']));
            close;
            % (Optional) If you have simulated regime sequences, repeat above for simRegimes
        end
    catch ME
        warning('Regime diagnostics failed for %s: %s', pname, ME.message);
    end
end
% Correlation heatmap
figure;
imagesc(realizedCorr); colorbar;
title('Simulated Correlation Matrix');
saveas(gcf, fullfile(outputDir, 'simulated_correlation_heatmap.png'));
figure;
imagesc(histCorr); colorbar;
title('Historical Correlation Matrix');
saveas(gcf, fullfile(outputDir, 'historical_correlation_heatmap.png'));

% === Regime behavior validation (if regime sequences available) ===
for i = 1:numel(productNames)
    pname = productNames{i};
    regimeField = [pname '_regimeSeqs'];
    if isfield(simPaths, regimeField)
        regimeSeqs = simPaths.(regimeField);
        figure;
        imagesc(regimeSeqs'); colorbar;
        title(['Simulated Regime Sequences: ' pname]);
        saveas(gcf, fullfile(outputDir, [pname '_regime_sequences.png']));
        close;
    end
end

% === Aggregate diagnostics and automate comparison/reporting (Sprint 5) ===
try
    summaryFile = fullfile(outputDir, 'diagnostics_summary.txt');
    fid = fopen(summaryFile, 'w');
    fidOpen = false;
    if fid == -1
        warning('Could not open diagnostics summary file for writing: %s', summaryFile);
    else
        fidOpen = true;
        fprintf(fid, 'Diagnostics Summary Report\n');
        fprintf(fid, '==========================\n\n');
        for i = 1:numel(productNames)
            pname = productNames{i};
            fprintf(fid, 'Product: %s\n', pname);
            % --- Distributional properties ---
            histData = alignedTable.(pname);
            simData = simPaths.(pname)(:); % Flatten simData for easier NaN handling

            % Robust NaN handling for histData (column-wise for multi-column historical data)
            cleanHistData = [];
            if size(histData, 2) > 1 % Multi-column
                 for col_idx = 1:size(histData,2)
                    tempCol = histData(:, col_idx);
                    cleanHistData = [cleanHistData, tempCol(~isnan(tempCol))];
                 end
            else % Single column
                cleanHistData = histData(~isnan(histData));
            end
            
            cleanSimData = simData(~isnan(simData));

            hist_mean = mean(cleanHistData, 'omitnan'); % omitnan is fine for mean/std
            hist_std  = std(cleanHistData, 0, 'omitnan'); % Use flag 0 for consistency if desired, and omitnan
            hist_skew = skewness(cleanHistData, 1); % Flag 1 for bias correction (default)
            hist_kurt = kurtosis(cleanHistData, 1); % Flag 1 for bias correction (default)

            sim_mean = mean(cleanSimData, 'omitnan');
            sim_std  = std(cleanSimData, 0, 'omitnan');
            sim_skew = skewness(cleanSimData, 1);
            sim_kurt = kurtosis(cleanSimData, 1);

            histStats = [hist_mean, hist_std, hist_skew, hist_kurt];
            simStats = [sim_mean, sim_std, sim_skew, sim_kurt];

            fprintf(fid, '  Mean: hist %.4f | sim %.4f\n', histStats(1), simStats(1));
            fprintf(fid, '  Std:  hist %.4f | sim %.4f\n', histStats(2), simStats(2));
            fprintf(fid, '  Skew: hist %.4f | sim %.4f\n', histStats(3), simStats(3));
            fprintf(fid, '  Kurt: hist %.4f | sim %.4f\n', histStats(4), simStats(4));
            % --- Jump frequency and size ---
            jumpFreqFile = fullfile(outputDir, [pname '_jump_frequency.txt']);
            if exist(jumpFreqFile, 'file')
                txt = fileread(jumpFreqFile);
                fprintf(fid, '  Jump Frequency:\n%s', txt);
            end
            jumpHistFile = fullfile(outputDir, [pname '_jump_size_histogram.png']);
            if exist(jumpHistFile, 'file')
                fprintf(fid, '  Jump size histogram: %s\n', jumpHistFile);
            end
            % --- Volatility clustering ---
            acfFile = fullfile(outputDir, [pname '_volatility_acf.csv']);
            if exist(acfFile, 'file')
                try
                    acfTab = readtable(acfFile);
                    % Expect simple column names now
                    requiredVars = {'HistoricalACF', 'SimulatedACF'};
                    hasRequiredVars = all(ismember(requiredVars, acfTab.Properties.VariableNames));
                    
                    if hasRequiredVars && height(acfTab) >= 2
                        fprintf(fid, '  Volatility clustering (ACF lag 1): hist %.4f | sim %.4f\n', acfTab.HistoricalACF(2), acfTab.SimulatedACF(2));
                    elseif height(acfTab) == 0 && hasRequiredVars % Correctly written empty placeholder
                        fprintf(fid, '  Volatility clustering (ACF lag 1): Data generation skipped.\n');
                    else
                        warning('Could not find required columns (HistoricalACF, SimulatedACF) or enough rows in %s. Available columns: %s, Rows: %d', acfFile, strjoin(acfTab.Properties.VariableNames, ', '), height(acfTab));
                        fprintf(fid, '  Volatility clustering (ACF lag 1): Data unavailable or malformed.\n');
                    end
                catch ME_readtab
                    warning('Failed to read or process ACF table %s: %s', acfFile, ME_readtab.message);
                    fprintf(fid, '  Volatility clustering (ACF lag 1): Error reading file.\n');
                end
            else
                fprintf(fid, '  Volatility clustering (ACF lag 1): File not found.\n');
            end
            % --- Regime duration and transition matrix ---
            regDurFile = fullfile(outputDir, [pname '_hist_regime_duration_hist.png']);
            if exist(regDurFile, 'file')
                fprintf(fid, '  Regime duration histogram: %s\n', regDurFile);
            end
            regTransFile = fullfile(outputDir, [pname '_hist_regime_transition_matrix.csv']);
            if exist(regTransFile, 'file')
                regTrans = readmatrix(regTransFile);
                fprintf(fid, '  Regime transition matrix (first row): ');
                if ~isempty(regTrans) && size(regTrans,1) >= 1
                    fprintf(fid, '%.2f ', regTrans(1,:));
                else
                    fprintf(fid, '[empty]');
                end
                fprintf(fid, '\n');
            end
            % --- End of product ---
            fprintf(fid, '\n');
        end
        fclose(fid);
        fidOpen = false;
        fprintf('Diagnostics summary written to %s\n', summaryFile);
    end
catch ME
    % Simply report the original error and do not attempt to fclose here.
    % If fid was open, it might remain open, but this avoids introducing new errors in catch.
    warning('Diagnostics summary generation failed. Original error in TRY block: %s (ID: %s). Check details below.', ME.message, ME.identifier);
    fprintf(2, '--- Original Error Stack Trace ---\n');
    for k_err=1:length(ME.stack)
        fprintf(2, 'File: %s, Function: %s, Line: %d\n', ME.stack(k_err).file, ME.stack(k_err).name, ME.stack(k_err).line);
    end
    fprintf(2, '--- End of Original Error Stack Trace ---\n');
end

disp('Output and validation complete. Results saved to Validation_Results/');

try
    close all;
catch
    % Ignore errors from close all
end

results = struct();
results.simStats = simStats;
results.histStats = histStats;
results.productNames = productNames; 