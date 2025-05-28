function regimeCopulas = fit_copula_per_regime(innovationsStruct, regimeLabels, config)
%FIT_COPULA_PER_REGIME Fit a copula to the joint distribution of regime-specific innovations across products.
%   regimeCopulas = fit_copula_per_regime(innovationsStruct, regimeLabels, config)
%   - innovationsStruct: struct of regime-specific innovations for each product
%   - regimeLabels: table of regime labels (products as columns)
%   - config: struct with copula options (type: 'gaussian', 't', 'vine')
%   - regimeCopulas: struct array with copula parameters and diagnostics

products = fieldnames(innovationsStruct);
nRegimes = numel(innovationsStruct.(products{1}));
regimeCopulas = struct();

if isfield(config, 'copulaType')
    copulaType = lower(config.copulaType);
else
    copulaType = 't';
end

for r = 1:nRegimes
    % Collect innovations for all products in this regime
    % First, find the minimum length across all products for this regime
    minLength = inf;
    for p = 1:numel(products)
        currentLength = length(innovationsStruct.(products{p})(r).innovations);
        minLength = min(minLength, currentLength);
    end
    
    % If any product has no innovations for this regime, skip
    if minLength == 0
        fprintf('Warning: No innovations found for regime %d, skipping copula fitting\n', r);
        regimeCopulas(r).type = 'none';
        regimeCopulas(r).params = [];
        continue;
    end
    
    % Build innovation matrix using the minimum length
    innovMat = zeros(minLength, numel(products));
    for p = 1:numel(products)
        innovations = innovationsStruct.(products{p})(r).innovations(:);
        % Take the first minLength observations
        innovMat(:,p) = innovations(1:minLength);
    end
    
    % Remove rows with NaN
    innovMat = innovMat(~any(isnan(innovMat),2),:);
    
    % Check if we have enough observations after removing NaNs
    if size(innovMat,1) < 2
        fprintf('Warning: Not enough valid observations for regime %d copula fitting (only %d), skipping\n', r, size(innovMat,1));
        regimeCopulas(r).type = 'none';
        regimeCopulas(r).params = [];
        continue;
    end
    % Fit copula
    % Transform innovations to uniform [0,1] with safeguards for extreme values
    U = normcdf(innovMat);
    % Ensure values are strictly between 0 and 1 (required by copulafit)
    epsilon = 1e-10;
    U = max(epsilon, min(1-epsilon, U));
    
    switch copulaType
        case 'gaussian'
            [R,~] = copulafit('Gaussian', U);
            regimeCopulas(r).type = 'Gaussian';
            regimeCopulas(r).params = R;
        case 't'
            [R,nu] = copulafit('t', U);
            regimeCopulas(r).type = 't';
            regimeCopulas(r).params = R;
            regimeCopulas(r).df = round(max(1, nu)); % Ensure df is a positive integer
        otherwise
            error('Unsupported copula type');
    end
    
    % Diagnostics: plot pairwise scatter and simulated samples (only if copula was fitted)
    if ~strcmp(regimeCopulas(r).type, 'none')
        nSim = floor(min(1000, size(innovMat,1)));
        if nSim >= 2
            % Generate samples based on copula type
            if strcmp(regimeCopulas(r).type, 't')
                % Ensure df is a positive integer for mvtrnd
                df_int = round(max(1, regimeCopulas(r).df));
                u = copularnd('t', regimeCopulas(r).params, nSim, df_int);
            elseif strcmp(regimeCopulas(r).type, 'Gaussian')
                u = copularnd('Gaussian', regimeCopulas(r).params, nSim);
            else
                error('Unsupported copula type for sampling: %s', regimeCopulas(r).type);
            end
            
            figure;
            for p1 = 1:numel(products)
                for p2 = p1+1:numel(products)
                    subplot(numel(products),numel(products),(p1-1)*numel(products)+p2);
                    scatter(norminv(u(:,p1)), norminv(u(:,p2)), 10, 'b.');
                    hold on;
                    scatter(innovMat(1:nSim,p1), innovMat(1:nSim,p2), 10, 'r.');
                    title(sprintf('Regime %d: %s vs %s', r, products{p1}, products{p2}));
                end
            end
            saveas(gcf, sprintf('EDA_Results/copula_regime%d.png', r)); close;
        end
    end
end

end

% Unit test
function test_fit_copula_per_regime()
    products = {'A','B'};
    for p = 1:2
        s.(products{p})(1).innovations = randn(100,1);
        s.(products{p})(2).innovations = randn(100,1)*2;
    end
    regimeLabels = array2table([ones(100,1); 2*ones(100,1)], 'VariableNames', products);
    config.copulaType = 't';
    copulas = fit_copula_per_regime(s, regimeLabels, config);
    assert(numel(copulas) == 2);
    disp('test_fit_copula_per_regime passed');
end