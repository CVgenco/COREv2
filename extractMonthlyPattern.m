function monthlyPattern = extractMonthlyPattern(timestamps, prices, months)
    % Ensure timestamps are datetime objects
    if ~isa(timestamps, 'datetime')
        try
            timestamps = datetime(timestamps);
        catch
            error('Cannot convert timestamps to datetime format');
        end
    end

    % SPRINT 1: Use precomputed months if provided
    if nargin < 3 || isempty(months)
        [~, months, ~, ~, ~, ~] = datevec(timestamps);
    end

    % First, ensure we only process rows where BOTH timestamp and price are valid.
    validTimeIdx = ~isnat(timestamps); % Check for Not-a-Time
    validPriceIdx = ~isnan(prices);
    combinedValidIdx = validTimeIdx & validPriceIdx;

    if ~any(combinedValidIdx)
        fprintf(' → Warning (extractMonthlyPattern): No valid timestamp/price pairs. Skipping accumarray.\n');
        monthlyPattern = nan(12,3);
        return;
    end

    validMonths = months(combinedValidIdx);
    pricesValid = prices(combinedValidIdx);

    monthNumbers = validMonths;
    
    % Validate monthNumbers before calling accumarray (as a final check)
    if isempty(monthNumbers)
        fprintf(' → Warning (extractMonthlyPattern): monthNumbers is empty after filtering. Skipping accumarray.\n');
        monthlyPattern = nan(12,3);
    elseif any(monthNumbers <= 0) || any(isnan(monthNumbers)) || any(isinf(monthNumbers)) || any(mod(monthNumbers, 1) ~= 0) || any(monthNumbers > 12)
        fprintf(' → Warning (extractMonthlyPattern): monthNumbers contains invalid (non-positive integer or >12) subscripts after filtering. Skipping accumarray.\n');
        monthlyPattern = nan(12,3);
    else
        monthlyPattern = zeros(12, 3); % [mean, std, median]
        monthlyPattern(:, 1) = accumarray(monthNumbers, pricesValid, [12 1], @mean, NaN);
        monthlyPattern(:, 2) = accumarray(monthNumbers, pricesValid, [12 1], @std, NaN);
        monthlyPattern(:, 3) = accumarray(monthNumbers, pricesValid, [12 1], @median, NaN);
    end
end 