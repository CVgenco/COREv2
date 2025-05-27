function regimeInnovs = extract_empirical_innovations(returns, regimeLabels, regimeVolModels)
%EXTRACT_EMPIRICAL_INNOVATIONS Extract standardized residuals from fitted volatility models for each regime.
%   regimeInnovs = extract_empirical_innovations(returns, regimeLabels, regimeVolModels)
%   - returns: vector or table of returns
%   - regimeLabels: vector or table of regime labels
%   - regimeVolModels: struct array of fitted volatility models (from fit_garch_per_regime)
%   - regimeInnovs: struct array with regime-specific innovations and diagnostics

if istable(returns), returns = table2array(returns); end
if istable(regimeLabels), regimeLabels = table2array(regimeLabels); end
returns = returns(:); regimeLabels = regimeLabels(:);
regimes = unique(regimeLabels(~isnan(regimeLabels)));
nRegimes = numel(regimes);
regimeInnovs = struct();

for r = 1:nRegimes
    idx = regimeLabels == regimes(r);
    ret_r = returns(idx);
    model = regimeVolModels(r).model;
    [E,V] = infer(model, ret_r);
    innov = E ./ sqrt(V);
    regimeInnovs(r).innovations = innov;
    regimeInnovs(r).mean = mean(innov, 'omitnan');
    regimeInnovs(r).std = std(innov, 'omitnan');
    regimeInnovs(r).skew = skewness(innov, 'omitnan');
    regimeInnovs(r).kurt = kurtosis(innov, 'omitnan');
    % Plot
    figure; histogram(innov, 50); title(sprintf('Innovations (Regime %d)', r));
    saveas(gcf, sprintf('EDA_Results/innovations_regime%d.png', r)); close;
end

end

% Unit test
function test_extract_empirical_innovations()
    t = (1:200)';
    x = [randn(100,1); 2*randn(100,1)];
    labels = [ones(100,1); 2*ones(100,1)];
    config.maxP = 1; config.maxQ = 1;
    models = fit_garch_per_regime(x, labels, config);
    innovs = extract_empirical_innovations(x, labels, models);
    assert(numel(innovs) == 2);
    disp('test_extract_empirical_innovations passed');
end 