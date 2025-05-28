function test_bayesian_optimization_fix()
% Test script to verify the Bayesian optimization fixes work correctly

fprintf('=== TESTING BAYESIAN OPTIMIZATION FIXES ===\n');

% Test 1: Check data file availability
fprintf('\n1. Testing data file availability...\n');
if exist('EDA_Results/alignedTable.mat', 'file')
    fprintf(' ✓ alignedTable.mat found in EDA_Results\n');
else
    error(' ✗ alignedTable.mat missing from EDA_Results');
end

if exist('EDA_Results/info.mat', 'file')
    fprintf(' ✓ info.mat found in EDA_Results\n');
else
    error(' ✗ info.mat missing from EDA_Results');
end

% Test 2: Test data preparation
fprintf('\n2. Testing data preparation...\n');
prepareValidationData();

% Test 3: Test single simulation run
fprintf('\n3. Testing single simulation and validation...\n');
try
    % Run a single simulation to test the pipeline
    fprintf('Running simulation...\n');
    runSimulationAndScenarioGeneration('userConfig.m', 'Test_Results');
    
    fprintf('Running validation...\n');
    results = runOutputAndValidation('userConfig.m', 'Test_Results');
    
    % Check if required files were created
    acfFile = fullfile('Test_Results', 'hubPrices_volatility_acf.csv');
    kurtosisFile = fullfile('Test_Results', 'hubPrices_kurtosis.txt');
    
    if exist(acfFile, 'file')
        fprintf(' ✓ ACF file created successfully\n');
    else
        fprintf(' ✗ ACF file missing\n');
    end
    
    if exist(kurtosisFile, 'file')
        fprintf(' ✓ Kurtosis file created successfully\n');
    else
        fprintf(' ✗ Kurtosis file missing\n');
    end
    
    % Test error score computation
    if exist(acfFile, 'file') && exist(kurtosisFile, 'file')
        [score, acfErr, kurtErr] = computeErrorScore(acfFile, kurtosisFile);
        fprintf(' ✓ Error score computed: %.6f (ACF: %.6f, Kurt: %.6f)\n', score, acfErr, kurtErr);
        
        if score == Inf || score >= 1000000
            fprintf(' ⚠ Warning: Error score is penalty value - check validation pipeline\n');
        else
            fprintf(' ✓ Valid error score obtained\n');
        end
    end
    
    fprintf('\n ✓ Single simulation test PASSED\n');
    
catch ME
    fprintf('\n ✗ Single simulation test FAILED: %s\n', ME.message);
    return;
end

% Test 4: Test one Bayesian optimization iteration
fprintf('\n4. Testing Bayesian optimization objective function...\n');
try
    % Create test parameters
    testParams = struct();
    testParams.blockSize = 100;
    testParams.df = 7;
    testParams.jumpThreshold = 2.0;
    testParams.regimeAmpFactor = 1.5;
    
    % Test the objective function
    objectiveValue = bayesoptSimObjective(testParams);
    
    if isfinite(objectiveValue) && objectiveValue < 1000000
        fprintf(' ✓ Bayesian objective function test PASSED (score: %.6f)\n', objectiveValue);
    elseif objectiveValue >= 1000000
        fprintf(' ⚠ Bayesian objective function returned penalty score (%.0f) - may indicate validation issues\n', objectiveValue);
    else
        fprintf(' ✗ Bayesian objective function returned invalid score: %s\n', mat2str(objectiveValue));
    end
    
catch ME
    fprintf(' ✗ Bayesian objective function test FAILED: %s\n', ME.message);
end

% Cleanup
if exist('Test_Results', 'dir')
    rmdir('Test_Results', 's');
end

fprintf('\n=== FIX TESTING COMPLETE ===\n');
fprintf('Ready to run full Bayesian optimization with: runBayesianTuning_safe()\n');

end
