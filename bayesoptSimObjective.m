function objectiveValue = bayesoptSimObjective(params)
% bayesoptSimObjective Objective function for Bayesian optimization of simulation parameters
%   params: table of parameters (blockSize, df, jumpThreshold, regimeAmpFactor)
%   Returns: objectiveValue (scalar error score)

% Ensure required data is loaded
if ~exist('alignedTable', 'var') || ~exist('info', 'var')
    try
        load('EDA_Results/alignedTable.mat', 'alignedTable');
        load('EDA_Results/info.mat', 'info');
    catch
        warning('Could not load alignedTable or info. Make sure EDA_Results/alignedTable.mat and info.mat exist.');
        objectiveValue = Inf;
        fprintf('DEBUG: bayesoptSimObjective returning Inf due to data load failure.\n');
        return;
    end
end

% Extract parameters
blockSize = params.blockSize;
df = params.df;
jumpThreshold = params.jumpThreshold;
regimeAmpFactor = params.regimeAmpFactor;

fprintf('Testing with: blockSize = %d, df = %d, jumpThreshold = %.4f, regimeAmpFactor = %.4f\n', ...
    blockSize, df, jumpThreshold, regimeAmpFactor);

% Update userConfig.m with current parameters
updateUserConfig(blockSize, df, jumpThreshold, regimeAmpFactor);

% Run simulation and diagnostics
try
    fprintf('DEBUG: Running simulation and validation for blockSize=%d, df=%d, jumpThreshold=%.2f, regimeAmpFactor=%.2f...\n', blockSize, df, jumpThreshold, regimeAmpFactor);
    runSimulationAndScenarioGeneration('userConfig.m', 'BayesOpt_Results');
    results = runOutputAndValidation('userConfig.m', 'BayesOpt_Results');
    fprintf('DEBUG: Simulation and validation completed.\n');

    % Compute error score (ACF + kurtosis)
    fprintf('DEBUG: Computing error score...\n');
    acfFile = fullfile('BayesOpt_Results', 'hubPrices_volatility_acf.csv');
    kurtosisFile = fullfile('BayesOpt_Results', 'hubPrices_kurtosis.txt');
    [score_val, acfErr, kurtErr] = computeErrorScore(acfFile, kurtosisFile);
    fprintf('DEBUG: computeErrorScore returned: score_val=%.4f, acfErr=%.4f, kurtErr=%.4f\n', score_val, acfErr, kurtErr);
    
    if isscalar(score_val) && isnumeric(score_val) && ~isempty(score_val)
        objectiveValue = score_val;
        fprintf('DEBUG: bayesoptSimObjective returning score_val: %.4f\n', objectiveValue);
    else
        warning('computeErrorScore did not return a valid numeric scalar (Value: %s). Defaulting to Inf.', mat2str(score_val));
        objectiveValue = Inf;
        fprintf('DEBUG: bayesoptSimObjective returning Inf due to invalid score_val.\n');
    end

catch ME
    warning('Simulation or Validation failed: %s', ME.message);
    objectiveValue = Inf;
    fprintf('DEBUG: bayesoptSimObjective returning Inf due to simulation/validation failure. ME.identifier: %s\n', ME.identifier);
end

fprintf('DEBUG: Reached end of bayesoptSimObjective normally. Final objectiveValue = %.4f\n', objectiveValue);
end 