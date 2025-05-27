function [data, resolution] = parseVariableResolutionData(filePath)
% Parses CSV or table data with variable resolution
% Inputs:
%   filePath: path to CSV file or table
% Outputs:
%   data: table with Timestamp column
%   resolution: string ('5min', '15min', 'hourly', etc.)

    if istable(filePath)
        data = filePath;
    else
        data = readtable(filePath);
    end
    % Ensure Timestamp column exists
    assert(ismember('Timestamp', data.Properties.VariableNames), 'CSV file must have a Timestamp column');
    % Convert Timestamp to datetime if it's not already
    if ~isa(data.Timestamp, 'datetime')
        data.Timestamp = datetime(data.Timestamp);
    end
    % Fix two-digit years
    if any(year(data.Timestamp) < 100)
        fprintf(' → Warning: Detected two-digit years, interpreting as 21st century\n');
        twoDigitYears = year(data.Timestamp) < 100;
        fixedDates = data.Timestamp(twoDigitYears);
        fixedDates.Year = fixedDates.Year + 2000;
        data.Timestamp(twoDigitYears) = fixedDates;
    end
    % Sort by timestamp
    data = sortrows(data, 'Timestamp');
    % Determine resolution
    if height(data) <= 1
        resolution = 'unknown';
    else
        timeDiffs = diff(data.Timestamp);
        uniqueDiffs = unique(timeDiffs);
        counts = zeros(size(uniqueDiffs));
        for i = 1:length(uniqueDiffs)
            counts(i) = sum(timeDiffs == uniqueDiffs(i));
        end
        [~, idx] = max(counts);
        mostCommonDiff = uniqueDiffs(idx);
        if mostCommonDiff <= minutes(5)
            resolution = '5min';
        elseif mostCommonDiff <= minutes(15)
            resolution = '15min';
        elseif mostCommonDiff <= hours(1)
            resolution = 'hourly';
        elseif mostCommonDiff <= days(1)
            resolution = 'daily';
        elseif mostCommonDiff <= days(7)
            resolution = 'weekly';
        elseif mostCommonDiff <= days(31)
            resolution = 'monthly';
        else
            resolution = 'unknown';
        end
    end
end 