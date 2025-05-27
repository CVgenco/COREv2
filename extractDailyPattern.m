function dailyPattern = extractDailyPattern(timestamps, prices, daysOfWeek)
    % Ensure timestamps are datetime objects
    if ~isa(timestamps, 'datetime')
        try
            timestamps = datetime(timestamps);
        catch
            error('Cannot convert timestamps to datetime format');
        end
    end
    
    % SPRINT 1: Use precomputed daysOfWeek if provided
    if nargin < 3 || isempty(daysOfWeek)
        t_num = datenum(timestamps);
        daysOfWeek = mod(floor(t_num) - 1, 7) + 1; % 1=Sunday, 7=Saturday
    end

    % First, ensure we only process rows where BOTH timestamp and price are valid.
    validTimeIdx = ~isnat(timestamps); % Check for Not-a-Time
    validPriceIdx = ~isnan(prices);
    combinedValidIdx = validTimeIdx & validPriceIdx;

    if ~any(combinedValidIdx)
        fprintf(' → Warning (extractDailyPattern): No valid timestamp/price pairs. Skipping accumarray.\n');
        dailyPattern = nan(7,3);
        return;
    end

    validDays = daysOfWeek(combinedValidIdx);
    pricesValid = prices(combinedValidIdx);

    dayNumbers = validDays;
    
    % Validate dayNumbers before calling accumarray (as a final check)
    if isempty(dayNumbers)
        fprintf(' → Warning (extractDailyPattern): dayNumbers is empty after filtering. Skipping accumarray.\n');
        dailyPattern = nan(7,3);
    elseif any(dayNumbers <= 0) || any(isnan(dayNumbers)) || any(isinf(dayNumbers)) || any(mod(dayNumbers, 1) ~= 0) || any(dayNumbers > 7)
        fprintf(' → Warning (extractDailyPattern): dayNumbers contains invalid (non-positive integer or >7) subscripts after filtering. Skipping accumarray.\n');
        dailyPattern = nan(7,3);
    else
        dailyPattern = zeros(7, 3); % [mean, std, median]
        dailyPattern(:, 1) = accumarray(dayNumbers, pricesValid, [7 1], @mean, NaN);
        dailyPattern(:, 2) = accumarray(dayNumbers, pricesValid, [7 1], @std, NaN);
        dailyPattern(:, 3) = accumarray(dayNumbers, pricesValid, [7 1], @median, NaN);
    end
end 