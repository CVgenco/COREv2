function [returnsTable, info] = calculate_returns(cleanedTable, config)
%CALCULATE_RETURNS Compute returns for each product.
%   [returnsTable, info] = calculate_returns(cleanedTable, config)
%   - Computes log or arithmetic returns (configurable)
%   - Plots return distributions, logs summary stats
%   - Returns returns table and info struct

% Diagnostic: print first few rows of input
fprintf('First 5 rows of input to calculate_returns (cleanedTable):\n');
disp(cleanedTable(1:min(5,height(cleanedTable)),:));

returnsTable = cleanedTable; % Default fallback
info = struct();

if isempty(cleanedTable) || width(cleanedTable) < 1
    warning('Input cleanedTable is empty or has no columns.');
    returnsTable(:,:) = NaN;
    return;
end

vars = cleanedTable.Properties.VariableNames;
timeIndex = cleanedTable.Properties.RowTimes;
returnsTable = cleanedTable(2:end, :); % Will fill below

if isfield(config, 'returns') && isfield(config.returns, 'type')
    retType = config.returns.type;
else
    retType = 'log';
end

for i = 1:numel(vars)
    v = vars{i};
    data = cleanedTable.(v);
    if isnumeric(data)
        if strcmpi(retType, 'log')
            % Handle zero and negative prices for log returns
            % Replace zero and negative prices with small positive value
            data_safe = data;
            data_safe(data_safe <= 0) = 0.01; % Replace with 1 cent
            ret = diff(log(data_safe));
        else
            ret = diff(data);
        end
        returnsTable.(v) = ret;
        % Diagnostics
        ret_no_nan = ret(~isnan(ret));
        skewness_val = skewness(ret_no_nan, 0);
        kurtosis_val = kurtosis(ret_no_nan, 0);
        mu = mean(ret_no_nan);
        sigma = std(ret_no_nan);
        info.(v) = struct('mean', mu, 'std', sigma, 'skew', skewness_val, 'kurtosis', kurtosis_val);
    else
        returnsTable.(v) = NaN(size(data));
    end
end

% Diagnostic: print first few rows and summary of output
fprintf('First 5 rows of output from calculate_returns (returnsTable):\n');
disp(returnsTable(1:min(5,height(returnsTable)),:));
disp('Summary of returnsTable:');
disp(summary(returnsTable));

% Warn if all returns are NaN
if all(all(ismissing(returnsTable)))
    warning('All returns are NaN after calculation. Check input data and cleaning logic.');
end

% Diagnostic: print NaN summary after return calculation
for i = 1:numel(vars)
    v = vars{i};
    retData = returnsTable.(v);
    nanIdx = find(isnan(retData));
    if ~isempty(nanIdx)
        fprintf('After return calculation, %s has %d NaNs. Indices (first 10): %s\n', v, numel(nanIdx), mat2str(nanIdx(1:min(10,end))));
        % Print corresponding timestamps for all NaNs (first 10)
        if istimetable(returnsTable)
            nanTimes = string(returnsTable.Properties.RowTimes(nanIdx));
            fprintf('Timestamps of NaNs in %s (first 10):\n', v);
            disp(nanTimes(1:min(10,end)))
        end
    else
        fprintf('After return calculation, %s has no NaNs.\n', v);
    end
end
end

% Unit test (example)
function test_calculate_returns()
    t = (1:100)';
    x = cumsum(randn(100,1));
    T = timetable(datetime(2020,1,1) + days(t-1), x, 'VariableNames', {'TestVar'});
    config.returns.type = 'log';
    [rets, info] = calculate_returns(T, config);
    assert(height(rets) == 99);
    disp('test_calculate_returns passed');
end