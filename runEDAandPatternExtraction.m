function runEDAandPatternExtraction(configFile)
%RUNEDAANDPATTERNEXTRACTION Run EDA and pattern extraction pipeline for all products.
%   Loads raw data, cleans, computes returns, detects regimes, saves results for each product.

run(configFile); % Loads config
fields = fieldnames(config.dataFiles);
for i = 1:numel(fields)
    product = fields{i};
    fname = config.dataFiles.(product);
    % Skip ancillaryForecast (not a time series)
    if contains(lower(product), 'ancillary')
        continue;
    end
    if ~exist(fname, 'file')
        fprintf('File not found for %s: %s\n', product, fname);
        continue;
    end
    fprintf('\n=== Processing %s ===\n', product);
    T = readtable(fname, 'PreserveVariableNames', true);
    % Use explicit timestamp variable if specified
    if isfield(config.timestampVars, product)
        tvar = config.timestampVars.(product);
        if ~istimetable(T)
            T = table2timetable(T, 'RowTimes', tvar);
        end
    else
        if ~istimetable(T)
            T = table2timetable(T);
        end
    end
    % Data cleaning
    [cleanedTable, cleanInfo] = data_cleaning(T, config);
    disp('First 5 rows of cleanedTable:');
    disp(cleanedTable(1:min(5,height(cleanedTable)),:));
    disp('Summary of cleanedTable:');
    disp(summary(cleanedTable));
    % Returns calculation
    [returnsTable, retInfo] = calculate_returns(cleanedTable, config);
    disp('First 5 rows of returnsTable:');
    disp(returnsTable(1:min(5,height(returnsTable)),:));
    disp('Summary of returnsTable:');
    disp(summary(returnsTable));
    % Regime detection
    [regimeLabels, regimeInfo] = detect_regimes(returnsTable, config);
    % Save results per product
    outdir = 'EDA_Results';
    if ~exist(outdir, 'dir'), mkdir(outdir); end
    save(fullfile(outdir, ['cleanedTable_' product '.mat']), 'cleanedTable');
    save(fullfile(outdir, ['returnsTable_' product '.mat']), 'returnsTable');
    save(fullfile(outdir, ['regimeLabels_' product '.mat']), 'regimeLabels');
    save(fullfile(outdir, ['cleanInfo_' product '.mat']), 'cleanInfo');
    save(fullfile(outdir, ['retInfo_' product '.mat']), 'retInfo');
    save(fullfile(outdir, ['regimeInfo_' product '.mat']), 'regimeInfo');
end
fprintf('Sprint 1 complete: Cleaned data, returns, and regimes saved to EDA_Results for all products.\n');
end
% runEDAandPatternExtraction.m
% Orchestrates Sprint 1: Data cleaning, returns calculation, regime detection