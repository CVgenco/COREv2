function hourlyPattern = extractHourlyPattern(timestamps, prices, hours)
    % Ensure timestamps are datetime objects
    if ~isa(timestamps, 'datetime')
        try
            timestamps = datetime(timestamps);
        catch
            error('Cannot convert timestamps to datetime format');
        end
    end

    % SPRINT 1: Use precomputed hours if provided
    if nargin < 3 || isempty(hours)
        [~, ~, ~, hours, ~, ~] = datevec(timestamps);
    end

    % First, ensure we only process rows where BOTH timestamp and price are valid.
    validTimeIdx = ~isnat(timestamps); % Check for Not-a-Time
    validPriceIdx = ~isnan(prices);
    combinedValidIdx = validTimeIdx & validPriceIdx;

    if ~any(combinedValidIdx)
        fprintf(' → Warning (extractHourlyPattern): No valid timestamp/price pairs. Skipping accumarray.\n');
        hourlyPattern = nan(24,3);
        return;
    end

    validHours = hours(combinedValidIdx);
    pricesValid = prices(combinedValidIdx);

    hourNumbers = validHours + 1; % 1-based indexing for accumarray
    
    % Validate hourNumbers before calling accumarray (as a final check)
    if isempty(hourNumbers)
        fprintf(' → Warning (extractHourlyPattern): hourNumbers is empty after filtering. Skipping accumarray.\n');
        hourlyPattern = nan(24,3);
    elseif any(hourNumbers <= 0) || any(isnan(hourNumbers)) || any(isinf(hourNumbers)) || any(mod(hourNumbers, 1) ~= 0)
        fprintf(' → Warning (extractHourlyPattern): hourNumbers contains invalid (non-positive integer) subscripts after filtering. Skipping accumarray.\n');
        hourlyPattern = nan(24,3);
    else
        hourlyPattern = zeros(24, 3); % [mean, std, median]
        hourlyPattern(:, 1) = accumarray(hourNumbers, pricesValid, [24 1], @mean, NaN);
        hourlyPattern(:, 2) = accumarray(hourNumbers, pricesValid, [24 1], @std, NaN);
        hourlyPattern(:, 3) = accumarray(hourNumbers, pricesValid, [24 1], @median, NaN);
    end
end 