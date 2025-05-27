% applyBayesianRegimeSwitchingVolatility.m
% Applies Bayesian volatility modeling with regime-switching to enhance price paths.
% Now accepts a stabilityTestAlpha parameter for regime stability testing.
% Usage:
%   [enhancedPaths, modelDiagnostics] = applyBayesianRegimeSwitchingVolatility(sampledPaths, historicalData, nodeNames, stabilityTestAlpha)

function [enhancedPaths, modelDiagnostics] = applyBayesianRegimeSwitchingVolatility(sampledPaths, historicalData, nodeNames, stabilityTestAlpha)
    % Initialize output
    enhancedPaths = sampledPaths;
    modelDiagnostics = struct();
    fprintf('\nApplying Bayesian Volatility Modeling with Regime-Switching...\n');
    for i = 1:length(nodeNames)
        nodeName = nodeNames{i};
        fprintf(' → Processing node %s (%d of %d)\n', nodeName, i, length(nodeNames));
        % Extract historical data
        historicalPrices = historicalData.(nodeName).rawHistorical;
        historicalTimestamps = historicalData.(nodeName).timestamps;
        % Step 1: Identify regimes in historical data (pass stabilityTestAlpha)
        regimeModel = identifyVolatilityRegimes(historicalPrices, historicalTimestamps, stabilityTestAlpha);
        % Step 2: Estimate Bayesian volatility model for each regime
        bayesianModel = estimateBayesianVolatilityModel(historicalPrices, regimeModel);
        % Step 3: Apply Bayesian model to sampled paths
        enhancedPaths.(nodeName) = applyBayesianModel(sampledPaths.(nodeName), sampledPaths.Timestamp, bayesianModel);
        % Store diagnostics
        modelDiagnostics.(nodeName).regimeModel = regimeModel;
        modelDiagnostics.(nodeName).bayesianModel = bayesianModel;
    end
    fprintf('Bayesian Volatility Modeling with Regime-Switching completed successfully.\n');
end 