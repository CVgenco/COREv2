function test_copula_size_fix()
%TEST_COPULA_SIZE_FIX Test the fixed copula fitting with different sized innovation vectors

% Create synthetic innovation data with different sizes for each product
products = {'product1', 'product2', 'product3'};
innovationsStruct = struct();

% Product 1: 1000 observations for regime 1, 800 for regime 2
innovationsStruct.product1(1).innovations = randn(1000, 1);
innovationsStruct.product1(2).innovations = randn(800, 1) * 1.5;

% Product 2: 900 observations for regime 1, 700 for regime 2
innovationsStruct.product2(1).innovations = randn(900, 1) * 0.8;
innovationsStruct.product2(2).innovations = randn(700, 1) * 1.2;

% Product 3: 1100 observations for regime 1, 600 for regime 2
innovationsStruct.product3(1).innovations = randn(1100, 1) * 1.1;
innovationsStruct.product3(2).innovations = randn(600, 1) * 0.9;

% Set up config
config.copulaType = 't';

% Test the copula fitting
fprintf('Testing copula fitting with different innovation vector sizes...\n');
try
    regimeCopulas = fit_copula_per_regime(innovationsStruct, [], config);
    fprintf('Success! Copula fitting completed.\n');
    
    % Display results
    for r = 1:2
        fprintf('Regime %d: Type = %s\n', r, regimeCopulas(r).type);
        if ~strcmp(regimeCopulas(r).type, 'none')
            if isfield(regimeCopulas(r).params, 'R')
                fprintf('  Correlation matrix size: %dx%d\n', size(regimeCopulas(r).params.R));
            end
        end
    end
    
catch ME
    fprintf('Error: %s\n', ME.message);
    rethrow(ME);
end

fprintf('Test completed successfully!\n');
end
