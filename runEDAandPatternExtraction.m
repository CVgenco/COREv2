% runEDAandPatternExtraction.m
% Orchestrates Sprint 1: Data cleaning, returns calculation, regime detection

function runEDAandPatternExtraction(configFile)
%RUNEDAANDPATTERNEXTRACTION Run EDA and pattern extraction pipeline.
%   Loads raw data, cleans, computes returns, detects regimes, saves results.

run(configFile); % Loads config
rawTable = readtable(config.dataFiles.nodalPrices, 'PreserveVariableNames', true);
rawTable = table2timetable(rawTable);

% Data cleaning
[cleanedTable, cleanInfo] = data_cleaning(rawTable, config);

% Returns calculation
[returnsTable, retInfo] = calculate_returns(cleanedTable, config);

% Regime detection
[regimeLabels, regimeInfo] = detect_regimes(returnsTable, config);

% Save results
if ~exist('EDA_Results', 'dir'), mkdir('EDA_Results'); end
save('EDA_Results/cleanedTable.mat', 'cleanedTable');
save('EDA_Results/returnsTable.mat', 'returnsTable');
save('EDA_Results/regimeLabels.mat', 'regimeLabels');
save('EDA_Results/cleanInfo.mat', 'cleanInfo');
save('EDA_Results/retInfo.mat', 'retInfo');
save('EDA_Results/regimeInfo.mat', 'regimeInfo');

fprintf('Sprint 1 complete: Cleaned data, returns, and regimes saved to EDA_Results.\n');
end

% === Load aligned data (assume already in workspace) ===
if ~exist('alignedTable', 'var') || ~exist('info', 'var')
    error('Run alignment first to produce alignedTable and info.');
end

% Map productNames to actual column names in alignedTable
actualVars = alignedTable.Properties.VariableNames;
mappedNames = cell(size(info.productNames));
for i = 1:numel(info.productNames)
    matchIdx = find(contains(lower(actualVars), lower(info.productNames{i})), 1);
    if ~isempty(matchIdx)
        mappedNames{i} = actualVars{matchIdx};
    else
        error('Could not find a column for product %s in alignedTable.', info.productNames{i});
    end
end
productNames = mappedNames; % Use these for all further analysis

patterns = struct();

% === Visualize missingness and overlap ===
missingMatrix = ismissing(alignedTable);
figure;
imagesc(missingMatrix);
colormap(gray);
colorbar;
title('Missingness Matrix (white = missing)');
xlabel('Product'); ylabel('Time Index');
set(gca, 'XTick', 1:numel(productNames), 'XTickLabel', productNames);
if savePlots, saveas(gcf, fullfile(outputDir, 'missingness_matrix.png')); end

% Overlap heatmap (pairwise non-NaN counts)
overlapCounts = zeros(numel(productNames));
for i = 1:numel(productNames)
    for j = 1:numel(productNames)
        overlapCounts(i,j) = sum(~isnan(alignedTable.(productNames{i})) & ~isnan(alignedTable.(productNames{j})));
    end
end
figure;
imagesc(overlapCounts);
colorbar;
title('Pairwise Overlap Counts');
xlabel('Product'); ylabel('Product');
set(gca, 'XTick', 1:numel(productNames), 'XTickLabel', productNames);
set(gca, 'YTick', 1:numel(productNames), 'YTickLabel', productNames);
if savePlots, saveas(gcf, fullfile(outputDir, 'overlap_heatmap.png')); end

% === For each product: EDA, pattern extraction, volatility/jumps ===
for i = 1:numel(productNames)
    pname = productNames{i};
    values = alignedTable.(pname);
    timestamps = alignedTable.Properties.RowTimes;
    fprintf('\n[EDA] Processing %s\n', pname);
    
    % Diagnostic: Check if all values are NaN
    if all(isnan(values))
        warning('[EDA] All values for %s are NaN after alignment. Check data and alignment.', pname);
    end
    
    % Plot time series
    figure;
    plot(timestamps, values); title(['Time Series: ' pname]); ylabel(pname); xlabel('Time');
    if savePlots
        if ~exist(outputDir, 'dir'), mkdir(outputDir); end
        saveas(gcf, fullfile(outputDir, [pname '_timeseries.png']));
    end
    
    % Plot missingness
    figure;
    plot(timestamps, ismissing(values)); title(['Missingness: ' pname]); ylabel('Missing (1=missing)'); xlabel('Time');
    if savePlots
        if ~exist(outputDir, 'dir'), mkdir(outputDir); end
        saveas(gcf, fullfile(outputDir, [pname '_missingness.png']));
    end
    
    % Extract patterns
    patterns.(pname).hourly   = extractHourlyPattern(timestamps, values);
    patterns.(pname).daily    = extractDailyPattern(timestamps, values);
    patterns.(pname).monthly  = extractMonthlyPattern(timestamps, values);
    patterns.(pname).holiday  = extractHolidayPattern(timestamps, values);
    patterns.(pname).seasonal = extractSeasonalBehaviorPattern(timestamps, values);
    % --- Enhanced: Extract and save all jump statistics ---
    volJumpStats = extractVolatilityAndJumps(timestamps, values);
    patterns.(pname).volJump = volJumpStats;
    % Save jump indices, sizes, and frequency for downstream use
    patterns.(pname).jumpIndices = volJumpStats.jumpIndices;
    patterns.(pname).jumpSizes   = volJumpStats.jumpSizes;
    patterns.(pname).jumpFrequency = volJumpStats.jumpFrequency;
    patterns.(pname).nJumps = volJumpStats.nJumps;
    % Optionally, fit a parametric distribution to jump sizes (e.g., normal)
    if ~isempty(volJumpStats.jumpSizes)
        mu_jump = mean(volJumpStats.jumpSizes, 'omitnan');
        sigma_jump = std(volJumpStats.jumpSizes, 'omitnan');
        patterns.(pname).jumpSizeFit = struct('mu', mu_jump, 'sigma', sigma_jump);
    else
        patterns.(pname).jumpSizeFit = struct('mu', NaN, 'sigma', NaN);
    end
    % --- Regime-conditional jump stats (if regime info available) ---
    if exist('regimeInfo', 'var') && isfield(regimeInfo, pname) && ~all(isnan(regimeInfo.(pname).regimeStates))
        regimes = regimeInfo.(pname).regimeStates;
        nRegimes = regimeInfo.(pname).nRegimes;
        regimeJumpStats = struct();
        returns = diff(values);
        for r = 1:nRegimes
            regimeIdx = (regimes(2:end) == r); % returns are 1 shorter
            regimeReturnIdx = find(regimeIdx); % indices in returns for regime r
            regimeJumps = abs(returns(regimeIdx)) > 4 * std(returns(regimeIdx), 'omitnan');
            regimeJumpStats(r).jumpFrequency = sum(regimeJumps) / max(1, sum(regimeIdx));
            regimeJumpStats(r).jumpSizes = returns(regimeReturnIdx(regimeJumps));
            regimeJumpStats(r).nJumps = sum(regimeJumps);
            if ~isempty(regimeJumpStats(r).jumpSizes)
                regimeJumpStats(r).jumpSizeFit = struct('mu', mean(regimeJumpStats(r).jumpSizes, 'omitnan'), 'sigma', std(regimeJumpStats(r).jumpSizes, 'omitnan'));
            else
                regimeJumpStats(r).jumpSizeFit = struct('mu', NaN, 'sigma', NaN);
            end
        end
        patterns.(pname).regimeJumpStats = regimeJumpStats;
    end
    
    % --- Calibrate t-distribution degrees of freedom (DoF) to match historical kurtosis ---
    globalKurt = patterns.(pname).volJump.kurtosis;
    patterns.(pname).tDegreesOfFreedom = estimate_t_dof(globalKurt);
    % Regime-conditional DoF
    if isfield(patterns.(pname), 'regimeJumpStats')
        regimeStats = patterns.(pname).regimeJumpStats;
        regimeTDoF = nan(1, numel(regimeStats));
        for r = 1:numel(regimeStats)
            % Use kurtosis of regime returns if available, else fallback
            if isfield(regimeStats(r), 'jumpSizes') && ~isempty(regimeStats(r).jumpSizes)
                regimeKurt = kurtosis(regimeStats(r).jumpSizes);
                regimeTDoF(r) = estimate_t_dof(regimeKurt);
            else
                regimeTDoF(r) = patterns.(pname).tDegreesOfFreedom;
            end
        end
        patterns.(pname).regimeTDoF = regimeTDoF;
    end
    
    % Save pattern tables
    if savePatterns
        if ~exist(outputDir, 'dir'), mkdir(outputDir); end
        save(fullfile(outputDir, [pname '_patterns.mat']), '-struct', 'patterns', pname);
        if ~exist(outputDir, 'dir'), mkdir(outputDir); end
        writematrix(patterns.(pname).hourly, fullfile(outputDir, [pname '_hourly.csv']));
        if ~exist(outputDir, 'dir'), mkdir(outputDir); end
        writematrix(patterns.(pname).daily, fullfile(outputDir, [pname '_daily.csv']));
        if ~exist(outputDir, 'dir'), mkdir(outputDir); end
        writematrix(patterns.(pname).monthly, fullfile(outputDir, [pname '_monthly.csv']));
        if ~exist(outputDir, 'dir'), mkdir(outputDir); end
        % Save volJump.mat with robust directory creation and debug print
        disp(['Saving to directory: ', outputDir]);
        if ~exist(outputDir, 'dir'), mkdir(outputDir); end
        save(fullfile(outputDir, [pname '_volJump.mat']), '-struct', 'patterns', pname);
    end
end

% Save all patterns as a struct
if savePatterns
    if ~exist(outputDir, 'dir'), mkdir(outputDir); end
    save(fullfile(outputDir, 'all_patterns.mat'), 'patterns');
end

% === Diagnostic: Print non-NaN counts and time ranges for all products in alignedTable ===
if exist('alignedTable', 'var')
    disp('--- Diagnostic: Non-NaN counts and time ranges for alignedTable columns ---');
    for v = 1:numel(alignedTable.Properties.VariableNames)
        col = alignedTable.Properties.VariableNames{v};
        if isnumeric(alignedTable.(col)) || islogical(alignedTable.(col))
            nNonNaN = sum(~isnan(alignedTable.(col)));
            if nNonNaN > 0
                tmin = alignedTable.Properties.RowTimes(find(~isnan(alignedTable.(col)),1,'first'));
                tmax = alignedTable.Properties.RowTimes(find(~isnan(alignedTable.(col)),1,'last'));
                fprintf('%s: %d non-NaN values | Time range: %s to %s\n', col, nNonNaN, string(tmin), string(tmax));
            else
                fprintf('%s: 0 non-NaN values\n', col);
            end
        end
    end
end

% === Robust Regime Detection for All Products ===
regimeInfo = struct();
for i = 1:numel(productNames)
    pname = productNames{i};
    values = alignedTable.(pname);
    timestamps = alignedTable.Properties.RowTimes;
    % Only run regime detection if there are enough non-NaN values
    if sum(~isnan(values)) > 100
        fprintf('[RegimeDetection] Detecting regimes for %s...\n', pname);
        try
            regimeModel = identifyVolatilityRegimes(values, datenum(timestamps));
            regimeStates = regimeModel.regimes;
            nRegimes = regimeModel.optimalRegimes;
            regimeInfo.(pname).regimeStates = regimeStates;
            regimeInfo.(pname).nRegimes = nRegimes;
            % Assign to workspace for downstream use
            assignin('base', ['regimeStates_' pname], regimeStates);
            assignin('base', ['nRegimes_' pname], nRegimes);
        catch ME
            warning('[RegimeDetection] Failed for %s: %s', pname, ME.message);
            regimeInfo.(pname).regimeStates = nan(size(values));
            regimeInfo.(pname).nRegimes = 0;
        end
    else
        warning('[RegimeDetection] Not enough data for %s, skipping regime detection.', pname);
        regimeInfo.(pname).regimeStates = nan(size(values));
        regimeInfo.(pname).nRegimes = 0;
    end
end
save(fullfile(outputDir, 'regime_info.mat'), 'regimeInfo');

disp('EDA and pattern extraction complete. Results saved to EDA_Results/');

function dof = estimate_t_dof(target_kurt)
    % For t-distribution, kurtosis = 6/(dof-4) for dof > 4
    % Solve for dof: dof = 6/target_kurt + 4
    if target_kurt > 0
        dof = 6/target_kurt + 4;
        if dof < 5, dof = 5; end % t-distribution only defined for dof > 4
    else
        dof = 30; % fallback to nearly Gaussian
    end
end 