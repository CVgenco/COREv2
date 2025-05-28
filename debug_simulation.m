% debug_simulation.m
% Simple script to debug why all simulations are failing in Bayesian optimization

% Test parameters (first from the log file)
blockSize = 18;
df = 5; % innovation distribution degrees of freedom
jumpThreshold = 0.02;
regimeAmpFactor = 1.9201;

fprintf('=== DEBUGGING SIMULATION FAILURE ===\n');
fprintf('Testing with:\n');
fprintf('  blockSize = %d\n', blockSize);
fprintf('  df = %d\n', df);
fprintf('  jumpThreshold = %.4f\n', jumpThreshold);
fprintf('  regimeAmpFactor = %.4f\n', regimeAmpFactor);

% Step 1: Load required data
fprintf('\n1. Loading EDA results...\n');
try
    load('EDA_Results/alignedTable.mat', 'alignedTable');
    load('EDA_Results/info.mat', 'info');
    fprintf('   ✓ EDA data loaded successfully\n');
    fprintf('   ✓ alignedTable size: %s\n', mat2str(size(alignedTable)));
    fprintf('   ✓ Product names: %s\n', strjoin(info.productNames, ', '));
catch ME
    fprintf('   ✗ Failed to load EDA data: %s\n', ME.message);
    return;
end

% Step 2: Update config
fprintf('\n2. Updating user config...\n');
try
    updateUserConfig(blockSize, df, jumpThreshold, regimeAmpFactor);
    fprintf('   ✓ userConfig.m updated successfully\n');
catch ME
    fprintf('   ✗ Failed to update config: %s\n', ME.message);
    return;
end

% Step 3: Test simulation
fprintf('\n3. Testing simulation...\n');
try
    % Create test output directory
    testDir = 'Debug_Simulation_Test';
    if exist(testDir, 'dir')
        rmdir(testDir, 's');
    end
    mkdir(testDir);
    
    % Run just the simulation part
    runSimulationAndScenarioGeneration('userConfig.m', testDir);
    fprintf('   ✓ Simulation completed successfully\n');
    
    % Check output files
    files = dir(fullfile(testDir, '*'));
    fileNames = {files(~[files.isdir]).name};
    fprintf('   ✓ Output files: %s\n', strjoin(fileNames, ', '));
    
catch ME
    fprintf('   ✗ Simulation failed: %s\n', ME.message);
    fprintf('   Stack trace:\n');
    for i = 1:length(ME.stack)
        fprintf('     %s (line %d)\n', ME.stack(i).name, ME.stack(i).line);
    end
    return;
end

% Step 4: Test validation
fprintf('\n4. Testing validation...\n');
try
    results = runOutputAndValidation('userConfig.m', testDir);
    fprintf('   ✓ Validation completed successfully\n');
    fprintf('   ✓ Results structure: %s\n', mat2str(size(results)));
    
    % Check if results contain expected fields
    if isstruct(results)
        fields = fieldnames(results);
        fprintf('   ✓ Result fields: %s\n', strjoin(fields, ', '));
    end
    
catch ME
    fprintf('   ✗ Validation failed: %s\n', ME.message);
    fprintf('   Stack trace:\n');
    for i = 1:length(ME.stack)
        fprintf('     %s (line %d)\n', ME.stack(i).name, ME.stack(i).line);
    end
    return;
end

% Step 5: Test error computation
fprintf('\n5. Testing error computation...\n');
try
    acfFile = fullfile(testDir, 'hubPrices_volatility_acf.csv');
    kurtosisFile = fullfile(testDir, 'hubPrices_kurtosis.txt');
    
    % Check if required files exist
    if exist(acfFile, 'file')
        fprintf('   ✓ ACF file exists: %s\n', acfFile);
    else
        fprintf('   ✗ ACF file missing: %s\n', acfFile);
    end
    
    if exist(kurtosisFile, 'file')
        fprintf('   ✓ Kurtosis file exists: %s\n', kurtosisFile);
    else
        fprintf('   ✗ Kurtosis file missing: %s\n', kurtosisFile);
    end
    
    if exist(acfFile, 'file') && exist(kurtosisFile, 'file')
        [score_val, acfErr, kurtErr] = computeErrorScore(acfFile, kurtosisFile);
        fprintf('   ✓ Error score computed: %.6f (ACF: %.6f, Kurt: %.6f)\n', score_val, acfErr, kurtErr);
    else
        fprintf('   ✗ Cannot compute error score - required files missing\n');
    end
    
catch ME
    fprintf('   ✗ Error computation failed: %s\n', ME.message);
    fprintf('   Stack trace:\n');
    for i = 1:length(ME.stack)
        fprintf('     %s (line %d)\n', ME.stack(i).name, ME.stack(i).line);
    end
end

fprintf('\n=== DEBUG COMPLETE ===\n');
