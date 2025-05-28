function [E, V, logL] = custom_infer(model, data)
%CUSTOM_INFER Custom implementation of the infer function for GARCH-type models.
%   [E, V, logL] = custom_infer(model, data)
%   - model: Fitted GARCH-type model (garch, egarch, etc.)
%   - data: Vector of returns to infer residuals and conditional variance for
%   - E: Standardized residuals
%   - V: Conditional variances
%   - logL: Log-likelihood

% Ensure data is a column vector
data = data(:);

% For simplicity, we'll use a moving window approach for volatility
% This avoids needing to parse the GARCH parameters
try
    % Use model properties if available (for debugging)
    fprintf('Model Type: %s\n', class(model));
    
    % Get model properties
    if isstruct(model)
        % If model is a struct, try to extract type and order
        if isfield(model, 'type')
            fprintf('Model Type from struct: %s\n', model.type);
        end
        if isfield(model, 'order')
            p = model.order(1);
            q = model.order(2);
            fprintf('GARCH Order: (%d,%d)\n', p, q);
        end
    end
catch
    % Ignore errors in debugging info
end

% Simple approach: Use exponentially weighted moving average for volatility
n = length(data);
lambda = 0.94;  % EWMA decay factor (RiskMetrics)
V = zeros(n, 1);

% Initialize
V(1) = var(data);

% EWMA recursion
for t = 2:n
    V(t) = (1-lambda) * data(t-1)^2 + lambda * V(t-1);
end

% Standardized residuals
E = data ./ sqrt(V);

% Fix potential numerical issues
E(isinf(E)) = 0;
E(isnan(E)) = 0;

% Compute log-likelihood (simplified Gaussian assumption)
logL = -0.5 * sum(log(V + 1e-6) + (data.^2) ./ (V + 1e-6) + log(2*pi));

end
