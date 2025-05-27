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
    innovMat = [];
    for p = 1:numel(products)
        innovMat(:,p) = innovationsStruct.(products{p})(r).innovations(:);
    end
    % Remove rows with NaN
    innovMat = innovMat(~any(isnan(innovMat),2),:);
    % Fit copula
    switch copulaType
        case 'gaussian'
            [R,~] = copulafit('Gaussian', normcdf(innovMat));
            regimeCopulas(r).type = 'Gaussian';
            regimeCopulas(r).params = R;
        case 't'
            [R,nu] = copulafit('t', normcdf(innovMat));
            regimeCopulas(r).type = 't';
            regimeCopulas(r).params = struct('R',R,'nu',nu);
        otherwise
            error('Unsupported copula type');
    end
    % Diagnostics: plot pairwise scatter and simulated samples
    nSim = min(1000, size(innovMat,1));
    u = copularnd(regimeCopulas(r).type, regimeCopulas(r).params, nSim);
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