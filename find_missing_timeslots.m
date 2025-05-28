% find_missing_timeslots.m
% Script to find missing timestamps in all CSV files in the Data directory
% and print the file name and missing timeslots.

% List of files to check (add more as needed)
files = {
    'historical_hub_prices.csv',
    'historical_nodal_prices.csv',
    'historical_nodal_generation.csv',
    'historical_regup.csv',
    'historical_regdown.csv',
    'historical_nonspin.csv',
    'hourly_hub_forecasts.csv',
    'hourly_nodal_forecasts.csv'
};

% Directory containing the data files
folder = '../Data';

for i = 1:numel(files)
    fname = files{i};
    fpath = fullfile(folder, fname);
    if ~isfile(fpath)
        fprintf('File not found: %s\n', fpath);
        continue;
    end
    T = readtable(fpath);
    % Detect timestamp column
    tcol = find(contains(lower(T.Properties.VariableNames), 'time'), 1);
    if isempty(tcol)
        fprintf('No timestamp column in %s\n', fname);
        continue;
    end
    timestamps = T{:, tcol};
    if iscell(timestamps)
        timestamps = string(timestamps);
    end
    timestamps = datetime(timestamps, 'InputFormat', 'yyyy-MM-dd HH:mm:ss');
    % Infer resolution (mode of diff)
    dt = mode(diff(timestamps));
    % Build expected timeline
    expected = (timestamps(1):dt:timestamps(end))';
    missing = setdiff(expected, timestamps);
    if ~isempty(missing)
        % Find contiguous ranges of missing timestamps
        dmissing = diff(missing);
        rangeBreaks = [1; find(dmissing > dt) + 1; numel(missing) + 1];
        fprintf('File: %s\n', fname);
        fprintf('  Missing %d timestamps in %d ranges:\n', numel(missing), numel(rangeBreaks)-1);
        for r = 1:numel(rangeBreaks)-1
            idx1 = rangeBreaks(r);
            idx2 = rangeBreaks(r+1)-1;
            if idx1 == idx2
                fprintf('    %s\n', datestr(missing(idx1), 'yyyy-mm-dd HH:MM:SS'));
            else
                fprintf('    %s to %s\n', datestr(missing(idx1), 'yyyy-mm-dd HH:MM:SS'), datestr(missing(idx2), 'yyyy-mm-dd HH:MM:SS'));
            end
        end
    end
end
