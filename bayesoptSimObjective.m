function objectiveValue = bayesoptSimObjective(params)
% bayesoptSimObjective Robust objective function for Bayesian optimization
%   params: table of parameters (blockSize, df, jumpThreshold, regimeAmpFactor)
%   Returns: objectiveValue (scalar error score)
%   
%   Enhanced with:
%   - Robust safety validation before simulation
%   - Enhanced error handling and recovery
%   - Multi-layer stability checks
%   - Volatility explosion prevention

% Ensure required data is loaded
if ~exist('alignedTable', 'var') || ~exist('info', 'var')
    try
        load('EDA_Results/alignedTable.mat', 'alignedTable');
        load('EDA_Results/info.mat', 'info');
        fprintf('DEBUG: Successfully loaded data files\n');
    catch
        warning('Could not load alignedTable or info. Make sure EDA_Results/alignedTable.mat and info.mat exist.');
        objectiveValue = 1000000;  % Use penalty score instead of Inf
        fprintf('DEBUG: bayesoptSimObjective returning penalty score due to data load failure.\n');
        return;
    end
end

% Extract parameters
blockSize = params.blockSize;
df = params.df;
jumpThreshold = params.jumpThreshold;
regimeAmpFactor = params.regimeAmpFactor;

fprintf('Testing parameters: blockSize=%d, df=%d, jumpThreshold=%.4f, regimeAmpFactor=%.4f\n', ...
    blockSize, df, jumpThreshold, regimeAmpFactor);

%% Step 1: Safety validation before simulation
try
    % Create temporary config for safety validation
    tempConfig = struct();
    tempConfig.blockBootstrapping.blockSize = blockSize;
    tempConfig.blockBootstrapping.enabled = true;
    tempConfig.innovationDistribution.degreesOfFreedom = df;
    tempConfig.innovationDistribution.enabled = false; % Default to false for Bayesian opt
    tempConfig.jumpModeling.threshold = jumpThreshold;
    tempConfig.jumpModeling.enabled = true;
    tempConfig.regimeVolatilityModulation.amplificationFactor = regimeAmpFactor;
    tempConfig.regimeVolatilityModulation.enabled = true;
    
    % Add required safety configuration fields
    tempConfig.dataPreprocessing.enabled = true;
    tempConfig.dataPreprocessing.robustOutlierDetection = true;
    tempConfig.volatilityPrevention.enabled = true;
    tempConfig.bayesianOptSafety.enabled = true;
    
    % Get product names from alignedTable
    if istable(alignedTable) || istimetable(alignedTable)
        productNames = alignedTable.Properties.VariableNames;
    else
        productNames = fieldnames(alignedTable);
    end
    
    % Run safety validation
    fprintf('DEBUG: Running safety validation...\n');
    [safeConfig, safetyStats] = robustBayesianOptSafety(tempConfig, alignedTable, productNames);
    
    % Check if parameters were adjusted for safety
    if safeConfig.blockBootstrapping.blockSize ~= blockSize
        fprintf('  Block size adjusted from %d to %d for safety\n', blockSize, safeConfig.blockBootstrapping.blockSize);
        blockSize = safeConfig.blockBootstrapping.blockSize;
    end
    
    if safeConfig.regimeVolatilityModulation.amplificationFactor ~= regimeAmpFactor
        fprintf('  Regime amplification adjusted from %.4f to %.4f for safety\n', ...
            regimeAmpFactor, safeConfig.regimeVolatilityModulation.amplificationFactor);
        regimeAmpFactor = safeConfig.regimeVolatilityModulation.amplificationFactor;
    end
    
    fprintf('DEBUG: Safety validation completed successfully\n');
    
catch ME
    warning('Safety validation failed: %s', ME.message);
    objectiveValue = 1000000;  % Penalty for unsafe parameters
    fprintf('DEBUG: Returning penalty score due to safety validation failure\n');
    return;
end

% Update userConfig.m with current parameters
updateUserConfig(blockSize, df, jumpThreshold, regimeAmpFactor);

% Run simulation and diagnostics
try
    fprintf('DEBUG: Running simulation and validation for blockSize=%d, df=%d, jumpThreshold=%.2f, regimeAmpFactor=%.2f...\n', blockSize, df, jumpThreshold, regimeAmpFactor);
    
    % Ensure working directory has required data files for validation
    if ~exist('alignedTable.mat', 'file') && exist('EDA_Results/alignedTable.mat', 'file')
        copyfile('EDA_Results/alignedTable.mat', 'alignedTable.mat');
        fprintf('DEBUG: Copied alignedTable.mat to working directory\n');
    end
    if ~exist('regimeInfo.mat', 'file') && exist('EDA_Results/regimeInfo.mat', 'file')
        copyfile('EDA_Results/regimeInfo.mat', 'regimeInfo.mat');
        fprintf('DEBUG: Copied regimeInfo.mat to working directory\n');
    end
    
    runSimulationAndScenarioGeneration('userConfig.m', 'BayesOpt_Results');
    results = runOutputAndValidation('userConfig.m', 'BayesOpt_Results');
    fprintf('DEBUG: Simulation and validation completed.\n');

    % Compute error score (ACF + kurtosis)
    fprintf('DEBUG: Computing error score...\n');
    acfFile = fullfile('BayesOpt_Results', 'hubPrices_volatility_acf.csv');
    kurtosisFile = fullfile('BayesOpt_Results', 'hubPrices_kurtosis.txt');
    [score_val, acfErr, kurtErr] = computeErrorScore(acfFile, kurtosisFile);
    fprintf('DEBUG: computeErrorScore returned: score_val=%.4f, acfErr=%.4f, kurtErr=%.4f\n', score_val, acfErr, kurtErr);
    
    if isscalar(score_val) && isnumeric(score_val) && ~isempty(score_val) && isfinite(score_val)
        objectiveValue = score_val;
        fprintf('DEBUG: bayesoptSimObjective returning score_val: %.4f\n', objectiveValue);
    else
        warning('computeErrorScore did not return a valid numeric scalar (Value: %s). Using penalty score.', mat2str(score_val));
        objectiveValue = 1000000;  % Use penalty score instead of Inf
        fprintf('DEBUG: bayesoptSimObjective returning penalty score due to invalid score_val.\n');
    end

catch ME
    warning('Simulation or Validation failed: %s', ME.message);
    objectiveValue = 1000000;  % Use penalty score instead of Inf
    fprintf('DEBUG: bayesoptSimObjective returning penalty score due to simulation/validation failure. ME.identifier: %s\n', ME.identifier);
end

fprintf('DEBUG: Reached end of bayesoptSimObjective normally. Final objectiveValue = %.4f\n', objectiveValue);
end 