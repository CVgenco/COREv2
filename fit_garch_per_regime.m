function regimeVolModels = fit_garch_per_regime(returns, regimeLabels, config)
%FIT_GARCH_PER_REGIME Fit GARCH/EGARCH/SV model to returns for each regime with automated order selection.
%   regimeVolModels = fit_garch_per_regime(returns, regimeLabels, config)
%   - returns: vector or table of returns
%   - regimeLabels: vector or table of regime labels
%   - config: struct with model selection options (fields: maxP, maxQ, criterion)
%   - regimeVolModels: struct array with model params and diagnostics

if istable(returns), returns = table2array(returns); end
if istable(regimeLabels), regimeLabels = table2array(regimeLabels); end
returns = returns(:); regimeLabels = regimeLabels(:);
regimes = unique(regimeLabels(~isnan(regimeLabels)));
nRegimes = numel(regimes);
regimeVolModels = struct();

% Model order grid
if isfield(config, 'maxP'), maxP = config.maxP; else, maxP = 2; end
if isfield(config, 'maxQ'), maxQ = config.maxQ; else, maxQ = 2; end
if isfield(config, 'criterion'), criterion = lower(config.criterion); else, criterion = 'aic'; end
modelTypes = {'GARCH','EGARCH'};

for r = 1:nRegimes
    idx = regimeLabels == regimes(r);
    ret_r = returns(idx);
    bestCrit = Inf; bestModel = []; bestType = ''; bestPQ = [1 1];
    for m = 1:numel(modelTypes)
        for p = 1:maxP
            for q = 1:maxQ
                try
                    switch modelTypes{m}
                        case 'GARCH'
                            mdl = garch(p,q);
                        case 'EGARCH'
                            mdl = egarch(p,q);
                    end
                    est = estimate(mdl, ret_r, 'Display', 'off');
                    [~,~,logL] = infer(est, ret_r);
                    k = numel(est.ParameterNames);
                    switch criterion
                        case 'bic'
                            critVal = -2*logL + k*log(numel(ret_r));
                        otherwise % 'aic'
                            critVal = -2*logL + 2*k;
                    end
                    if critVal < bestCrit
                        bestCrit = critVal; bestModel = est; bestType = modelTypes{m}; bestPQ = [p q];
                    end
                catch
                    continue;
                end
            end
        end
    end
    % Store best model
    regimeVolModels(r).type = bestType;
    regimeVolModels(r).model = bestModel;
    regimeVolModels(r).order = bestPQ;
    regimeVolModels(r).criterion = criterion;
    regimeVolModels(r).critValue = bestCrit;
    % Diagnostics
    [E,V] = infer(bestModel, ret_r);
    regimeVolModels(r).residuals = E;
    regimeVolModels(r).volatility = sqrt(V);
    % Plot
    figure; plot(sqrt(V)); title(sprintf('Fitted Volatility (Regime %d)', r));
    saveas(gcf, sprintf('EDA_Results/volatility_regime%d.png', r)); close;
    figure; histogram(E, 50); title(sprintf('Residuals (Regime %d)', r));
    saveas(gcf, sprintf('EDA_Results/residuals_regime%d.png', r)); close;
    fprintf('Regime %d: Best %s(%d,%d), %s=%.2f\n', r, bestType, bestPQ(1), bestPQ(2), upper(criterion), bestCrit);
end

end

% Unit test
function test_fit_garch_per_regime()
    t = (1:200)';
    x = [randn(100,1); 2*randn(100,1)];
    labels = [ones(100,1); 2*ones(100,1)];
    config.maxP = 2; config.maxQ = 2; config.criterion = 'aic';
    models = fit_garch_per_regime(x, labels, config);
    assert(numel(models) == 2);
    disp('test_fit_garch_per_regime passed');
end 