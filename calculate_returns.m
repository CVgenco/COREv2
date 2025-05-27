function [returnsTable, info] = calculate_returns(cleanedTable, config)
%CALCULATE_RETURNS Compute returns for each product.
%   [returnsTable, info] = calculate_returns(cleanedTable, config)
%   - Computes log or arithmetic returns (configurable)
%   - Plots return distributions, logs summary stats
%   - Returns returns table and info struct

vars = cleanedTable.Properties.VariableNames;
timeIndex = cleanedTable.Properties.RowTimes;
returnsTable = cleanedTable(2:end, :); % Will fill below
info = struct();

if isfield(config, 'returns') && isfield(config.returns, 'type')
    retType = config.returns.type;
else
    retType = 'log';
end

for i = 1:numel(vars)
    v = vars{i};
    data = cleanedTable.(v);
    if strcmpi(retType, 'log')
        ret = diff(log(data));
    else
        ret = diff(data);
    end
    returnsTable.(v) = ret;
    % Diagnostics
    mu = mean(ret, 'omitnan');
    sigma = std(ret, 'omitnan');
    skewness_val = skewness(ret, 'omitnan');
    kurtosis_val = kurtosis(ret, 'omitnan');
    info.(v) = struct('mean', mu, 'std', sigma, 'skew', skewness_val, 'kurtosis', kurtosis_val);
    % Plot
    figure; histogram(ret, 50); title(['Return Distribution: ' v]); xlabel('Return'); ylabel('Count');
    saveas(gcf, ['EDA_Results/returns_hist_' v '.png']); close;
    figure; qqplot(ret); title(['QQ Plot: ' v]);
    saveas(gcf, ['EDA_Results/returns_qq_' v '.png']); close;
    fprintf('Returns for %s: mean=%.4g, std=%.4g, skew=%.4g, kurt=%.4g\n', v, mu, sigma, skewness_val, kurtosis_val);
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