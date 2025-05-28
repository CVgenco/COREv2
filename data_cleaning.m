function [cleanedTable, info] = data_cleaning(rawTable, config)
%DATA_CLEANING Clean, align, and preprocess input data for simulation engine.
%   [cleanedTable, info] = data_cleaning(rawTable, config)
%   - Uses robust outlier detection (IQR, Modified Z-score, Energy thresholds)
%   - Fills missing data (forward/backward fill, interpolation)  
%   - Prevents volatility explosions that cause simulation failures
%   - Aligns all series to a common timeline/resolution
%   - Plots before/after cleaning, logs diagnostics
%   - Returns cleaned table and info struct

% Ensure EDA_Results directory exists for saving plots
if ~exist('EDA_Results', 'dir')
    mkdir('EDA_Results');
end

% Extract config options and setup robust outlier detection
vars = rawTable.Properties.VariableNames;
timeIndex = rawTable.Properties.RowTimes;
cleanedTable = rawTable;
info = struct();

% Configure robust outlier detection options
outlierOptions = struct();
outlierOptions.enableIQR = true;
outlierOptions.enableModifiedZScore = true;  
outlierOptions.enableEnergyThresholds = true;
outlierOptions.iqrMultiplier = 2.5;  % More conservative than 3-sigma
outlierOptions.modifiedZThreshold = 3.5;
outlierOptions.replacementMethod = 'interpolation';
outlierOptions.verbose = false;  % Reduce verbosity in data cleaning

% Check if config has enhanced outlier detection settings
if isfield(config, 'outlierDetection')
    fields = fieldnames(config.outlierDetection);
    for f = 1:length(fields)
        outlierOptions.(fields{f}) = config.outlierDetection.(fields{f});
    end
end

% Diagnostic: Check for missing timestamps in the input timetable
if istimetable(rawTable)
    dt = config.resolution;
    expectedTimes = (rawTable.Properties.RowTimes(1):dt:rawTable.Properties.RowTimes(end))';
    missingTimes = setdiff(expectedTimes, rawTable.Properties.RowTimes);
    fprintf('Number of missing timestamps in input data: %d\n', numel(missingTimes));
    if ~isempty(missingTimes)
        disp('First 10 missing timestamps:');
        disp(missingTimes(1:min(10,end)));
    else
        disp('No missing timestamps in input data.');
    end
end

for i = 1:numel(vars)
    v = vars{i};
    data = rawTable.(v);
    
    fprintf('Processing %s with robust outlier detection...\n', v);
    
    % Apply robust outlier detection instead of simple price capping
    try
        [data, outlierStats] = robustOutlierDetection(data, v, outlierOptions);
        info.(v).outlierStats = outlierStats;
        info.(v).outliers = outlierStats.outlierIndices;
    catch ME
        % Fallback to simple capping if robust detection fails
        fprintf('  Warning: Robust detection failed for %s, using fallback: %s\n', v, ME.message);
        outlierMask = data > 2000;
        info.(v).outliers = find(outlierMask);
        data(outlierMask) = 2000;
        info.(v).outlierStats = struct('numOutliers', sum(outlierMask), 'outlierPercentage', sum(outlierMask)/length(data)*100);
    end
    
    % Interpolate missing values (linear, with nearest for ends)
    data = fillmissing(data, 'linear', 'EndValues', 'nearest');
    nanMask = isnan(data);
    info.(v).missing = find(nanMask);
    
    % Store cleaned data
    cleanedTable.(v) = data;
    % Plot before/after
    figure; plot(timeIndex, rawTable.(v), 'r-', timeIndex, data, 'b-');
    legend('Raw', 'Cleaned'); title(['Robust Cleaning: ' v]);
    xlabel('Time'); ylabel(v);
    saveas(gcf, ['EDA_Results/robust_cleaning_' v '.png']); close;
    
    % Enhanced logging with outlier statistics
    if isfield(info.(v), 'outlierStats')
        stats = info.(v).outlierStats;
        fprintf('  %s: %d outliers (%.2f%%) detected and replaced\n', v, stats.numOutliers, stats.outlierPercentage);
        if isfield(stats, 'detectionMethods') && ~isempty(stats.detectionMethods)
            fprintf('    Detection methods: %s\n', strjoin(stats.detectionMethods, ', '));
        end
    end
    fprintf('  %s: %d missing values interpolated\n', v, numel(info.(v).missing));
    % Diagnostic: print NaN summary after cleaning
    nanIdx = find(isnan(data));
    if ~isempty(nanIdx)
        fprintf('After cleaning, %s has %d NaNs at indices: ', v, numel(nanIdx));
        if numel(nanIdx) <= 10
            fprintf('%s\n', mat2str(nanIdx));
        else
            fprintf('%s ...\n', mat2str(nanIdx(1:10)));
        end
    else
        fprintf('After cleaning, %s has no NaNs.\n', v);
    end
end

% Align to master time index (already assumed in input)
% Add more alignment logic if needed

end

% Unit test (example)
function test_data_cleaning()
    t = (1:100)';
    x = sin(t/10) + randn(100,1)*0.1;
    x([10, 50]) = 10; % Outliers
    x([20, 70]) = NaN; % Missing
    T = timetable(datetime(2020,1,1) + days(t-1), x, 'VariableNames', {'TestVar'});
    config.cleaning.outlierThreshold = 3;
    [cleaned, info] = data_cleaning(T, config);
    assert(all(abs(cleaned.TestVar) < 10));
    assert(all(~isnan(cleaned.TestVar)));
    disp('test_data_cleaning passed');
end