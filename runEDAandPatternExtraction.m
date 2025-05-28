function runEDAandPatternExtraction(configFile)
%RUNEDAANDPATTERNEXTRACTION Run EDA and pattern extraction pipeline for all products.
%   Loads raw data, cleans, computes returns, detects regimes, saves combined results.

run(configFile); % Loads config
fields = fieldnames(config.dataFiles);

% Initialize combined structures for all products
combinedReturnsTable = struct();
combinedRegimeLabels = struct();
combinedCleanInfo = struct();
combinedRetInfo = struct();
combinedRegimeInfo = struct();

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
    
    % Add to combined structures
    % Store both the returns data and timestamps
    productVarNames = returnsTable.Properties.VariableNames;
    if ismember(product, productVarNames)
        % Product name matches variable name
        combinedReturnsTable.(product) = returnsTable.(product);
    elseif ismember('Price', productVarNames)
        % Common case: variable is named 'Price'
        combinedReturnsTable.(product) = returnsTable.Price;
    else
        % Use the first variable
        combinedReturnsTable.(product) = returnsTable.(productVarNames{1});
    end
    
    % Store timestamps for each product
    combinedReturnsTable.([product '_timestamps']) = returnsTable.Timestamp;
    
    % Add regime labels and info
    combinedRegimeLabels.(product) = regimeLabels;
    combinedCleanInfo.(product) = cleanInfo;
    combinedRetInfo.(product) = retInfo;
    combinedRegimeInfo.(product) = regimeInfo;
    
    % Still save individual files for debugging/reference
    outdir = 'EDA_Results';
    if ~exist(outdir, 'dir'), mkdir(outdir); end
    save(fullfile(outdir, ['cleanedTable_' product '.mat']), 'cleanedTable');
    save(fullfile(outdir, ['returnsTable_' product '.mat']), 'returnsTable');
    save(fullfile(outdir, ['regimeLabels_' product '.mat']), 'regimeLabels');
    save(fullfile(outdir, ['cleanInfo_' product '.mat']), 'cleanInfo');
    save(fullfile(outdir, ['retInfo_' product '.mat']), 'retInfo');
    save(fullfile(outdir, ['regimeInfo_' product '.mat']), 'regimeInfo');
end

% Save combined structures that the next workflow modules expect
fprintf('\nSaving combined results for Sprint 2...\n');
returnsTable = combinedReturnsTable;
regimeLabels = combinedRegimeLabels;
cleanInfo = combinedCleanInfo;
retInfo = combinedRetInfo;
regimeInfo = combinedRegimeInfo;

save('EDA_Results/returnsTable.mat', 'returnsTable');
save('EDA_Results/regimeLabels.mat', 'regimeLabels');
save('EDA_Results/cleanInfo.mat', 'cleanInfo');
save('EDA_Results/retInfo.mat', 'retInfo');
save('EDA_Results/regimeInfo.mat', 'regimeInfo');

fprintf('✅ Sprint 1 complete: Combined results saved for Sprint 2\n');
fprintf('   - returnsTable.mat: Returns for all products\n');
fprintf('   - regimeLabels.mat: Regime labels for all products\n');
fprintf('   - Individual product files also saved for reference\n');
end
% runEDAandPatternExtraction.m
% Orchestrates Sprint 1: Data cleaning, returns calculation, regime detection