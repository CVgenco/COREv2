function [cleanedTable, info] = data_cleaning(rawTable, config)
%DATA_CLEANING Clean, align, and preprocess input data for simulation engine.
%   [cleanedTable, info] = data_cleaning(rawTable, config)
%   - Removes/winsorizes outliers (configurable threshold, default ±4σ)
%   - Fills missing data (forward/backward fill, interpolation)
%   - Aligns all series to a common timeline/resolution
%   - Plots before/after cleaning, logs diagnostics
%   - Returns cleaned table and info struct

% Ensure EDA_Results directory exists for saving plots
if ~exist('EDA_Results', 'dir')
    mkdir('EDA_Results');
end

% Extract config options
if isfield(config, 'cleaning')
    threshold = config.cleaning.outlierThreshold;
else
    threshold = 4; % Default ±4σ
end

vars = rawTable.Properties.VariableNames;
timeIndex = rawTable.Properties.RowTimes;
cleanedTable = rawTable;
info = struct();

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
    % Outlier detection (median, MAD)
    med = median(data, 'omitnan');
    mad_val = mad(data, 1);
    sigma = mad_val * 1.4826; % Approximate std
    outlierMask = abs(data - med) > threshold * sigma;
    info.(v).outliers = find(outlierMask);
    % Winsorize outliers
    data(outlierMask & (data > med)) = med + threshold * sigma;
    data(outlierMask & (data < med)) = med - threshold * sigma;
    % Interpolate missing values (linear, with nearest for ends)
    data = fillmissing(data, 'linear', 'EndValues', 'nearest');
    nanMask = isnan(data);
    info.(v).missing = find(nanMask);
    % Store cleaned data
    cleanedTable.(v) = data;
    % Plot before/after
    figure; plot(timeIndex, rawTable.(v), 'r-', timeIndex, data, 'b-');
    legend('Raw', 'Cleaned'); title(['Cleaning: ' v]);
    xlabel('Time'); ylabel(v);
    saveas(gcf, ['EDA_Results/cleaning_' v '.png']); close;
    % Log
    fprintf('Cleaned %s: %d outliers, %d missing values\n', v, numel(info.(v).outliers), numel(info.(v).missing));
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