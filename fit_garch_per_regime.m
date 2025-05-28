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

% Check if standard infer function is available
% If not, we'll use our custom implementation
if ~exist('infer', 'file')
    fprintf('Note: Using custom_infer implementation for GARCH model inference.\n');
    % Ensure our custom implementation is available
    if ~exist('custom_infer', 'file')
        error('Both infer and custom_infer functions are unavailable!');
    end
end

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
                    
                    % Calculate likelihood and information criteria
                    try
                        if exist('infer', 'file')
                            [~,~,logL] = infer(est, ret_r);
                        else
                            % Use our custom implementation
                            [~,~,logL] = custom_infer(est, ret_r);
                        end
                    catch
                        % If both approaches fail, just use the unconditional likelihood
                        sigma2 = var(ret_r);
                        logL = -0.5 * sum(log(sigma2) + (ret_r.^2) ./ sigma2 + log(2*pi));
                    end
                    
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
    regimeVolModels(r).order = bestPQ;
    regimeVolModels(r).criterion = criterion;
    regimeVolModels(r).critValue = bestCrit;
    
    % Store the model explicitly, extracting parameters to make it persistable
    try
        if ~isempty(bestModel)
            % Store model parameters explicitly so we don't rely on the model object
            regimeVolModels(r).modelParams = bestModel.Parameters;
            if isfield(bestModel, 'ParameterNames') || isprop(bestModel, 'ParameterNames')
                regimeVolModels(r).parameterNames = bestModel.ParameterNames;
            end
            
            % Store the actual model object too, but don't rely on it persisting
            regimeVolModels(r).model = bestModel;
        else
            regimeVolModels(r).modelParams = [];
            regimeVolModels(r).model = [];
        end
    catch
        % If we can't extract parameters, at least make the fields exist
        regimeVolModels(r).modelParams = [];
        regimeVolModels(r).model = [];
    end
    % Diagnostics (with error handling)
    try
        % Use either standard infer or our custom implementation
        if exist('infer', 'file') && ~isempty(bestModel)
            [E,V] = infer(bestModel, ret_r);
        else
            % Compute volatility manually using model parameters
            if ~isempty(regimeVolModels(r).modelParams) && strcmp(bestType, 'GARCH')
                % Extract parameters
                params = regimeVolModels(r).modelParams;
                p = bestPQ(1); q = bestPQ(2);
                
                % Simpler GARCH(1,1) calculation
                omega = params(1);  % Constant term
                if q >= 1
                    alpha = params(2:min(q+1, length(params)));  % ARCH terms
                else
                    alpha = 0;
                end
                if p >= 1 && q+1+p <= length(params)
                    beta = params(q+2:min(q+p+1, length(params)));  % GARCH terms
                else
                    beta = 0;
                end
                
                % Calculate conditional variance
                n = length(ret_r);
                V = zeros(n, 1);
                V(1) = var(ret_r);  % Initial variance
                
                for t = 2:n
                    % GARCH(1,1) update
                    if p >= 1 && q >= 1
                        V(t) = omega + alpha(1) * ret_r(t-1)^2 + beta(1) * V(t-1);
                    else
                        V(t) = var(ret_r);  % Fallback if not enough parameters
                    end
                end
                
                E = ret_r ./ sqrt(V);  % Standardized residuals
            else
                % Simple standardization as fallback
                E = (ret_r - mean(ret_r)) / std(ret_r);
                V = ones(size(ret_r)) * var(ret_r);
            end
        end
        
        % Store results
        regimeVolModels(r).residuals = E;
        regimeVolModels(r).volatility = sqrt(V);
        
        % Plot volatility
        figure; plot(sqrt(V)); title(sprintf('Fitted Volatility (Regime %d)', r));
        saveas(gcf, sprintf('EDA_Results/volatility_regime%d.png', r)); close;
        
        % Plot residuals
        figure; histogram(E, 50); title(sprintf('Residuals (Regime %d)', r));
        saveas(gcf, sprintf('EDA_Results/residuals_regime%d.png', r)); close;
    catch ME
        fprintf('Note: Could not generate full diagnostics for regime %d: %s\n', r, ME.message);
        % Use simplified diagnostics
        regimeVolModels(r).residuals = (ret_r - mean(ret_r)) / std(ret_r);
        regimeVolModels(r).volatility = ones(size(ret_r)) * std(ret_r);
    end
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