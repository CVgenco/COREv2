% runParameterEstimation.m
% Orchestrates Sprint 2: Automated parameter estimation for regimes, GARCH, and jumps

function runParameterEstimation(configFile)
%RUNPARAMETERESTIMATION Run parameter estimation pipeline for Sprint 2.
%   Loads returns and regime labels, fits Markov, GARCH, and jump models, saves results.

run(configFile); % Loads config
load('EDA_Results/returnsTable.mat', 'returnsTable');
load('EDA_Results/regimeLabels.mat', 'regimeLabels');

% Handle both table and struct formats
if istable(returnsTable)
    products = returnsTable.Properties.VariableNames;
else
    products = fieldnames(returnsTable);
end
paramResults = struct();

for i = 1:numel(products)
    pname = products{i};
    ret = returnsTable.(pname);
    reg = regimeLabels.(pname);
    
    % Ensure both are column vectors and same length
    ret = ret(:);
    reg = reg(:);
    minLen = min(length(ret), length(reg));
    ret = ret(1:minLen);
    reg = reg(1:minLen);
    
    % Remove NaN values
    validIdx = ~isnan(ret) & ~isnan(reg);
    ret = ret(validIdx);
    reg = reg(validIdx);
    
    fprintf('Processing %s: %d valid observations\n', pname, length(ret));
    
    % Fit regime Markov model
    markovModel = fit_regime_markov_model(reg);
    % Fit GARCH/EGARCH per regime
    garchModels = fit_garch_per_regime(ret, reg, config);
    % Fit jumps per regime
    jumpModels = fit_jumps_per_regime(ret, reg, config);
    % Store
    paramResults.(pname).markovModel = markovModel;
    paramResults.(pname).garchModels = garchModels;
    paramResults.(pname).jumpModels = jumpModels;
end

save('EDA_Results/paramResults.mat', 'paramResults');
fprintf('Sprint 2 complete: Parameter estimation results saved to EDA_Results.\n');
end 