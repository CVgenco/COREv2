% fill_missing_data.m
% Script to fill missing data in price CSV files using linear interpolation,
% then backfilling and forward filling for any remaining NaNs.
% Overwrites the original file with the filled data.

% List of files and their time resolutions (in minutes)
files = {
    '/Users/chayanvohra/Downloads/Energy Price & Risk Simulator/Price Forecaster/CORE/historical_hub_prices.csv', 5;
    '/Users/chayanvohra/Downloads/Energy Price & Risk Simulator/Price Forecaster/CORE/historical_nodal_prices.csv', 5;
    '/Users/chayanvohra/Downloads/Energy Price & Risk Simulator/Price Forecaster/CORE/historical_regup.csv', 60;
    '/Users/chayanvohra/Downloads/Energy Price & Risk Simulator/Price Forecaster/CORE/historical_regdown.csv', 60;
    '/Users/chayanvohra/Downloads/Energy Price & Risk Simulator/Price Forecaster/CORE/historical_nonspin.csv', 60
};

for i = 1:size(files,1)
    filename = files{i,1};
    dt_minutes = files{i,2};
    T = readtable(filename);
    % Ensure Timestamp is datetime and convert to UTC
    if ~isdatetime(T.Timestamp)
        T.Timestamp = datetime(T.Timestamp, 'InputFormat', 'yyyy-MM-dd HH:mm:ss');
    end
    if isempty(T.Timestamp.TimeZone)
        T.Timestamp.TimeZone = 'local'; % or 'America/Chicago' if you know the source
    end
    T.Timestamp = datetime(T.Timestamp, 'TimeZone', 'UTC');
    % 1. Create a complete time vector in UTC
    startTime = min(T.Timestamp);
    endTime = max(T.Timestamp);
    dt = minutes(dt_minutes);
    fullTime = (startTime:dt:endTime)';
    % 2. Reindex table to full time grid
    T_full = table(fullTime, 'VariableNames', {'Timestamp'});
    T = outerjoin(T_full, T, 'Keys', 'Timestamp', 'MergeKeys', true);
    % 3. Fill missing data for all columns except Timestamp
    varNames = T.Properties.VariableNames;
    for v = 2:numel(varNames)
        T.(varNames{v}) = fillmissing(T.(varNames{v}), 'linear');
        T.(varNames{v}) = fillmissing(T.(varNames{v}), 'next');
        T.(varNames{v}) = fillmissing(T.(varNames{v}), 'previous');
    end
    % 4. Write to new filled file (preserve original)
    [filepath, name, ext] = fileparts(filename);
    filled_filename = fullfile(filepath, [name '_filled' ext]);
    % Convert Timestamp to string in UTC for CSV
    T.Timestamp = datestr(T.Timestamp, 'yyyy-mm-dd HH:MM:SS');
    writetable(T, filled_filename);
    fprintf('Filled, regularized, and UTC-converted %s -> %s\n', filename, filled_filename);
end
