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

% Check if infer function is available (only check once)
% If not, we'll use our custom implementation
if ~exist('infer', 'file')
    fprintf('Note: Using custom_infer implementation for GARCH model inference.\n');
    % Ensure our custom implementation is available
    if ~exist('custom_infer', 'file')
        error('Both infer and custom_infer functions are unavailable!');
    end
end

for r = 1:nRegimes
    idx = regimeLabels == regimes(r);
    ret_r = returns(idx);
    model = regimeVolModels(r).model;
    
    % Extract innovations using the most reliable approach
    try
        % First try: Use built-in infer if available and model is valid
        if exist('infer', 'file') && ~isempty(model) && ~(isnumeric(model) && isempty(model))
            [E,V] = infer(model, ret_r);
            innov = E;
        % Second try: Use model parameters if available
        elseif isstruct(model) && isfield(model, 'modelParams') && ~isempty(model.modelParams) && ...
               isfield(model, 'type') && ~isempty(model.type) && isfield(model, 'order')
            % Extract parameters
            params = model.modelParams;
            type = model.type;
            order = model.order;
            
            if strcmp(type, 'GARCH') && numel(order) >= 2
                p = order(1); q = order(2);
                
                % Simple GARCH(1,1) manual implementation
                omega = params(1);  % Constant term
                if q >= 1 && numel(params) >= 2
                    alpha = params(2);  % ARCH term
                else
                    alpha = 0;
                end
                if p >= 1 && numel(params) >= 3
                    beta = params(3);  % GARCH term
                else
                    beta = 0;
                end
                
                % Calculate conditional variance
                n = length(ret_r);
                V = zeros(n, 1);
                V(1) = var(ret_r);  % Initial variance
                
                for t = 2:n
                    % GARCH(1,1) update
                    V(t) = omega + alpha * ret_r(t-1)^2 + beta * V(t-1);
                end
                
                innov = ret_r ./ sqrt(V);  % Standardized residuals
            else
                % Fallback to standardizing
                innov = (ret_r - mean(ret_r)) / std(ret_r);
            end
        else
            % Third try: Simple standardization if no model info available
            innov = (ret_r - mean(ret_r)) / std(ret_r);
        end
    catch
        % Final fallback: Simple standardization
        innov = (ret_r - mean(ret_r)) / std(ret_r);
    end
    
    % Clean up any invalid values
    innov(isnan(innov)) = 0;
    innov(isinf(innov)) = 0;
    
    regimeInnovs(r).innovations = innov;
    regimeInnovs(r).mean = mean(innov(~isnan(innov)));
    regimeInnovs(r).std = std(innov(~isnan(innov)));
    regimeInnovs(r).skew = skewness(innov(~isnan(innov)));
    regimeInnovs(r).kurt = kurtosis(innov(~isnan(innov)));
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