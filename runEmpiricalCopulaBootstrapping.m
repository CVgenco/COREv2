% runEmpiricalCopulaBootstrapping.m
% Orchestrates Sprint 3: Empirical/Copula-based innovation bootstrapping and correlation modeling

function runEmpiricalCopulaBootstrapping(configFile)
%RUNEMPIRICALCOPULABOOTSTRAPPING Run empirical/correlated innovation extraction and copula fitting.
%   Loads returns, regime labels, and volatility models, extracts innovations, fits copulas, saves results.

run(configFile); % Loads config
load('EDA_Results/returnsTable.mat', 'returnsTable');
load('EDA_Results/regimeLabels.mat', 'regimeLabels');
load('EDA_Results/paramResults.mat', 'paramResults');

% Handle both table and struct formats
if istable(returnsTable)
    products = returnsTable.Properties.VariableNames;
else
    products = fieldnames(returnsTable);
end
innovationsStruct = struct();
regimeVolModels = struct();
for i = 1:numel(products)
    pname = products{i};
    ret = returnsTable.(pname);
    reg = regimeLabels.(pname);
    regimeVolModels_i = paramResults.(pname).garchModels;
    innovationsStruct.(pname) = extract_empirical_innovations(ret, reg, regimeVolModels_i);
end

% Fit copula for each regime across all products
copulaStruct = fit_copula_per_regime(innovationsStruct, regimeLabels, config);

save('EDA_Results/innovationsStruct.mat', 'innovationsStruct');
save('EDA_Results/copulaStruct.mat', 'copulaStruct');
fprintf('Sprint 3 complete: Innovations and copula parameters saved to EDA_Results.\n');
end 