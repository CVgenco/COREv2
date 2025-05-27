% runParameterEstimation.m
% Orchestrates Sprint 2: Automated parameter estimation for regimes, GARCH, and jumps

function runParameterEstimation(configFile)
%RUNPARAMETERESTIMATION Run parameter estimation pipeline for Sprint 2.
%   Loads returns and regime labels, fits Markov, GARCH, and jump models, saves results.

run(configFile); % Loads config
load('EDA_Results/returnsTable.mat', 'returnsTable');
load('EDA_Results/regimeLabels.mat', 'regimeLabels');

products = returnsTable.Properties.VariableNames;
paramResults = struct();

for i = 1:numel(products)
    pname = products{i};
    ret = returnsTable.(pname);
    reg = regimeLabels.(pname);
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