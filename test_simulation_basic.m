% test_simulation_basic.m
% Test if the restored userConfig.m works for a basic simulation

fprintf('=== TESTING BASIC SIMULATION FUNCTIONALITY ===\n');

% Test 1: Can we load the config?
fprintf('\n1. Testing config loading...\n');
try
    run('userConfig.m');
    fprintf('   ✓ Config loaded successfully\n');
    fprintf('   ✓ Simulation paths: %d\n', config.simulation.nPaths);
    fprintf('   ✓ Block size: %d\n', config.blockBootstrapping.blockSize);
    fprintf('   ✓ Jump threshold: %.4f\n', config.jumpModeling.threshold);
    fprintf('   ✓ Regime amp factor: %.4f\n', config.regimeVolatilityModulation.amplificationFactor);
catch ME
    fprintf('   ✗ Config loading failed: %s\n', ME.message);
    return;
end

% Test 2: Do required EDA files exist?
fprintf('\n2. Testing EDA data availability...\n');
try
    load('EDA_Results/alignedTable.mat', 'alignedTable');
    load('EDA_Results/info.mat', 'info');
    fprintf('   ✓ EDA data loaded successfully\n');
    fprintf('   ✓ Aligned table size: %s\n', mat2str(size(alignedTable)));
    fprintf('   ✓ Product count: %d\n', length(info.productNames));
    fprintf('   ✓ Products: %s\n', strjoin(info.productNames, ', '));
catch ME
    fprintf('   ✗ EDA data loading failed: %s\n', ME.message);
    return;
end

% Test 3: Do correlation matrices exist?
fprintf('\n3. Testing correlation data...\n');
corrFile = 'Correlation_Results/global_correlation_matrix.mat';
if exist(corrFile, 'file')
    try
        load(corrFile, 'Corr');
        fprintf('   ✓ Correlation matrix loaded\n');
        fprintf('   ✓ Matrix size: %s\n', mat2str(size(Corr)));
    catch ME
        fprintf('   ✗ Correlation matrix load failed: %s\n', ME.message);
        return;
    end
else
    fprintf('   ✗ Correlation matrix file missing: %s\n', corrFile);
    return;
end

% Test 4: Test a minimal simulation
fprintf('\n4. Testing minimal simulation...\n');
testDir = 'Test_Basic_Simulation';
if exist(testDir, 'dir')
    rmdir(testDir, 's');
end

try
    % Set minimal parameters for fast testing
    config.simulation.nPaths = 1;  % Just 1 path for speed
    
    % Save test config
    testConfigFile = 'test_config_basic.m';
    fid = fopen(testConfigFile, 'w');
    fprintf(fid, 'config = %s;\n', struct2config(config));
    fclose(fid);
    
    fprintf('   Running simulation with 1 path...\n');
    runSimulationAndScenarioGeneration(testConfigFile, testDir);
    
    % Check if output files were created
    files = dir(fullfile(testDir, '*'));
    fileNames = {files(~[files.isdir]).name};
    fprintf('   ✓ Simulation completed\n');
    fprintf('   ✓ Output files (%d): %s\n', length(fileNames), strjoin(fileNames(1:min(5,end)), ', '));
    
    if length(fileNames) > 5
        fprintf('     ... and %d more files\n', length(fileNames) - 5);
    end
    
catch ME
    fprintf('   ✗ Simulation failed: %s\n', ME.message);
    fprintf('   Stack trace:\n');
    for i = 1:length(ME.stack)
        fprintf('     %s (line %d)\n', ME.stack(i).name, ME.stack(i).line);
    end
    return;
end

% Test 5: Test validation
fprintf('\n5. Testing validation...\n');
try
    results = runOutputAndValidation(testConfigFile, testDir);
    fprintf('   ✓ Validation completed\n');
    
    if isstruct(results)
        fields = fieldnames(results);
        fprintf('   ✓ Results fields: %s\n', strjoin(fields, ', '));
    end
    
catch ME
    fprintf('   ✗ Validation failed: %s\n', ME.message);
    fprintf('   Stack trace:\n');
    for i = 1:length(ME.stack)
        fprintf('     %s (line %d)\n', ME.stack(i).name, ME.stack(i).line);
    end
end

% Test 6: Test error computation
fprintf('\n6. Testing error computation...\n');
try
    acfFile = fullfile(testDir, 'hubPrices_volatility_acf.csv');
    kurtosisFile = fullfile(testDir, 'hubPrices_kurtosis.txt');
    
    if exist(acfFile, 'file') && exist(kurtosisFile, 'file')
        [score, acfErr, kurtErr] = computeErrorScore(acfFile, kurtosisFile);
        fprintf('   ✓ Error score computed: %.6f\n', score);
        fprintf('   ✓ ACF error: %.6f\n', acfErr);
        fprintf('   ✓ Kurtosis error: %.6f\n', kurtErr);
        
        if isnan(score) || isinf(score)
            fprintf('   ⚠ Warning: Error score is invalid (NaN/Inf)\n');
        end
    else
        fprintf('   ✗ Required files missing for error computation\n');
        fprintf('     ACF file exists: %s\n', logical2str(exist(acfFile, 'file')));
        fprintf('     Kurtosis file exists: %s\n', logical2str(exist(kurtosisFile, 'file')));
    end
    
catch ME
    fprintf('   ✗ Error computation failed: %s\n', ME.message);
end

% Cleanup
if exist(testConfigFile, 'file')
    delete(testConfigFile);
end

fprintf('\n=== BASIC SIMULATION TEST COMPLETE ===\n');

% Helper functions
function str = logical2str(val)
if val
    str = 'true';
else
    str = 'false';
end
end

function configStr = struct2config(s)
% Simple struct to string conversion for config
configStr = 'struct(';
fields = fieldnames(s);
for i = 1:length(fields)
    field = fields{i};
    value = s.(field);
    if i > 1
        configStr = [configStr, ', '];
    end
    configStr = [configStr, sprintf('''%s'', ', field)];
    if isstruct(value)
        configStr = [configStr, struct2config(value)];
    elseif isnumeric(value)
        if isscalar(value)
            configStr = [configStr, num2str(value)];
        else
            configStr = [configStr, '[', num2str(value), ']'];
        end
    elseif ischar(value)
        configStr = [configStr, sprintf('''%s''', value)];
    elseif islogical(value)
        if value
            configStr = [configStr, 'true'];
        else
            configStr = [configStr, 'false'];
        end
    else
        configStr = [configStr, '''unknown'''];
    end
end
configStr = [configStr, ')'];
end
