% diagnose_simulation_failure.m
% Focused diagnostic to identify why simulations are failing

fprintf('=== DIAGNOSING SIMULATION FAILURES ===\n');

%% Step 1: Validate current config
fprintf('\n1. Validating current configuration...\n');
try
    run('userConfig.m');
    fprintf('   ✓ Config loaded\n');
    
    % Check critical parameters
    issues = {};
    
    if ~isfield(config, 'simulation') || ~isfield(config.simulation, 'nPaths')
        issues{end+1} = 'Missing simulation.nPaths';
    elseif config.simulation.nPaths <= 0
        issues{end+1} = sprintf('Invalid nPaths: %d', config.simulation.nPaths);
    end
    
    if ~isfield(config, 'blockBootstrapping') || ~isfield(config.blockBootstrapping, 'blockSize')
        issues{end+1} = 'Missing blockBootstrapping.blockSize';
    elseif config.blockBootstrapping.blockSize <= 0 || config.blockBootstrapping.blockSize > 200
        issues{end+1} = sprintf('Invalid blockSize: %d', config.blockBootstrapping.blockSize);
    end
    
    if ~isfield(config, 'jumpModeling') || ~isfield(config.jumpModeling, 'threshold')
        issues{end+1} = 'Missing jumpModeling.threshold';
    elseif config.jumpModeling.threshold <= 0 || config.jumpModeling.threshold > 10
        issues{end+1} = sprintf('Invalid jumpThreshold: %.4f', config.jumpModeling.threshold);
    end
    
    if ~isfield(config, 'regimeVolatilityModulation') || ~isfield(config.regimeVolatilityModulation, 'amplificationFactor')
        issues{end+1} = 'Missing regimeVolatilityModulation.amplificationFactor';
    elseif config.regimeVolatilityModulation.amplificationFactor <= 0 || config.regimeVolatilityModulation.amplificationFactor > 5
        issues{end+1} = sprintf('Invalid regimeAmpFactor: %.4f', config.regimeVolatilityModulation.amplificationFactor);
    end
    
    if isempty(issues)
        fprintf('   ✓ All critical parameters valid\n');
        fprintf('     nPaths: %d\n', config.simulation.nPaths);
        fprintf('     blockSize: %d\n', config.blockBootstrapping.blockSize);
        fprintf('     jumpThreshold: %.4f\n', config.jumpModeling.threshold);
        fprintf('     regimeAmpFactor: %.4f\n', config.regimeVolatilityModulation.amplificationFactor);
    else
        fprintf('   ✗ Config issues found:\n');
        for i = 1:length(issues)
            fprintf('     - %s\n', issues{i});
        end
        return;
    end
    
catch ME
    fprintf('   ✗ Config loading failed: %s\n', ME.message);
    return;
end

%% Step 2: Check data dependencies
fprintf('\n2. Checking data dependencies...\n');
requiredFiles = {
    'EDA_Results/alignedTable.mat',
    'EDA_Results/info.mat',
    'EDA_Results/all_patterns.mat',
    'Correlation_Results/global_correlation_matrix.mat'
};

missingFiles = {};
for i = 1:length(requiredFiles)
    file = requiredFiles{i};
    if ~exist(file, 'file')
        missingFiles{end+1} = file;
    end
end

if isempty(missingFiles)
    fprintf('   ✓ All required files present\n');
else
    fprintf('   ✗ Missing files:\n');
    for i = 1:length(missingFiles)
        fprintf('     - %s\n', missingFiles{i});
    end
    return;
end

%% Step 3: Load and validate data
fprintf('\n3. Loading and validating data...\n');
try
    load('EDA_Results/alignedTable.mat', 'alignedTable');
    load('EDA_Results/info.mat', 'info');
    load('EDA_Results/all_patterns.mat', 'patterns');
    load('Correlation_Results/global_correlation_matrix.mat', 'Corr');
    
    fprintf('   ✓ Data loaded successfully\n');
    fprintf('     alignedTable: %d x %d\n', size(alignedTable, 1), size(alignedTable, 2));
    fprintf('     products: %d (%s)\n', length(info.productNames), strjoin(info.productNames, ', '));
    fprintf('     correlation matrix: %d x %d\n', size(Corr, 1), size(Corr, 2));
    
    % Check for NaN/Inf in critical data
    dataIssues = {};
    
    for i = 1:length(info.productNames)
        pname = info.productNames{i};
        if istable(alignedTable) && ismember(pname, alignedTable.Properties.VariableNames)
            data = alignedTable.(pname);
        else
            dataIssues{end+1} = sprintf('Product %s missing from alignedTable', pname);
            continue;
        end
        
        nanCount = sum(isnan(data));
        infCount = sum(isinf(data));
        
        if nanCount > length(data) * 0.5
            dataIssues{end+1} = sprintf('Product %s has %d%% NaN values', pname, round(nanCount/length(data)*100));
        end
        
        if infCount > 0
            dataIssues{end+1} = sprintf('Product %s has %d Inf values', pname, infCount);
        end
        
        if nanCount < length(data) && infCount == 0
            returns = diff(data);
            returns = returns(~isnan(returns));
            if length(returns) < 100
                dataIssues{end+1} = sprintf('Product %s has insufficient valid returns (%d)', pname, length(returns));
            end
        end
    end
    
    if isempty(dataIssues)
        fprintf('   ✓ Data validation passed\n');
    else
        fprintf('   ⚠ Data issues found:\n');
        for i = 1:length(dataIssues)
            fprintf('     - %s\n', dataIssues{i});
        end
    end
    
catch ME
    fprintf('   ✗ Data loading/validation failed: %s\n', ME.message);
    return;
end

%% Step 4: Test parameter update function
fprintf('\n4. Testing parameter update function...\n');
try
    % Create backup
    copyfile('userConfig.m', 'userConfig_diagnostic_backup.m');
    
    % Test with known good parameters
    testBlockSize = 48;
    testDf = 8;
    testJumpThreshold = 2.0;
    testRegimeAmp = 1.2;
    
    fprintf('   Testing updateUserConfig with: blockSize=%d, df=%d, jumpThreshold=%.2f, regimeAmp=%.2f\n', ...
        testBlockSize, testDf, testJumpThreshold, testRegimeAmp);
    
    updateUserConfig(testBlockSize, testDf, testJumpThreshold, testRegimeAmp);
    
    % Reload and verify
    clear config;
    run('userConfig.m');
    
    success = true;
    if config.blockBootstrapping.blockSize ~= testBlockSize
        fprintf('   ✗ blockSize update failed: expected %d, got %d\n', testBlockSize, config.blockBootstrapping.blockSize);
        success = false;
    end
    
    if config.innovationDistribution.degreesOfFreedom ~= testDf
        fprintf('   ✗ df update failed: expected %d, got %d\n', testDf, config.innovationDistribution.degreesOfFreedom);
        success = false;
    end
    
    if abs(config.jumpModeling.threshold - testJumpThreshold) > 0.001
        fprintf('   ✗ jumpThreshold update failed: expected %.3f, got %.3f\n', testJumpThreshold, config.jumpModeling.threshold);
        success = false;
    end
    
    if abs(config.regimeVolatilityModulation.amplificationFactor - testRegimeAmp) > 0.001
        fprintf('   ✗ regimeAmp update failed: expected %.3f, got %.3f\n', testRegimeAmp, config.regimeVolatilityModulation.amplificationFactor);
        success = false;
    end
    
    if success
        fprintf('   ✓ Parameter update function works correctly\n');
    end
    
    % Restore backup
    copyfile('userConfig_diagnostic_backup.m', 'userConfig.m');
    delete('userConfig_diagnostic_backup.m');
    
catch ME
    fprintf('   ✗ Parameter update test failed: %s\n', ME.message);
    
    % Restore backup if it exists
    if exist('userConfig_diagnostic_backup.m', 'file')
        copyfile('userConfig_diagnostic_backup.m', 'userConfig.m');
        delete('userConfig_diagnostic_backup.m');
    end
    return;
end

%% Step 5: Check regime data
fprintf('\n5. Checking regime data...\n');
regimeFile = 'EDA_Results/regimeInfo.mat';
if exist(regimeFile, 'file')
    try
        load(regimeFile, 'regimeInfo');
        fprintf('   ✓ regimeInfo loaded\n');
        
        if isstruct(regimeInfo)
            regimeFields = fieldnames(regimeInfo);
            fprintf('   ✓ Regime data available for: %s\n', strjoin(regimeFields, ', '));
            
            % Check regime data quality
            regimeIssues = {};
            for i = 1:length(regimeFields)
                field = regimeFields{i};
                if isfield(regimeInfo.(field), 'regimeStates')
                    regimeStates = regimeInfo.(field).regimeStates;
                    nanCount = sum(isnan(regimeStates));
                    uniqueRegimes = unique(regimeStates(~isnan(regimeStates)));
                    
                    if nanCount > length(regimeStates) * 0.8
                        regimeIssues{end+1} = sprintf('%s: %d%% NaN regime states', field, round(nanCount/length(regimeStates)*100));
                    end
                    
                    if length(uniqueRegimes) < 2
                        regimeIssues{end+1} = sprintf('%s: insufficient regime diversity (%d unique)', field, length(uniqueRegimes));
                    end
                else
                    regimeIssues{end+1} = sprintf('%s: missing regimeStates field', field);
                end
            end
            
            if isempty(regimeIssues)
                fprintf('   ✓ Regime data quality good\n');
            else
                fprintf('   ⚠ Regime data issues:\n');
                for i = 1:length(regimeIssues)
                    fprintf('     - %s\n', regimeIssues{i});
                end
            end
        else
            fprintf('   ⚠ regimeInfo is not a struct\n');
        end
    catch ME
        fprintf('   ⚠ Failed to load regimeInfo: %s\n', ME.message);
    end
else
    fprintf('   ⚠ regimeInfo.mat not found - simulations may use fallback regime handling\n');
end

fprintf('\n=== DIAGNOSIS COMPLETE ===\n');
fprintf('\nNext steps:\n');
fprintf('1. If all checks pass, try running the safe Bayesian optimization: runBayesianTuning_safe()\n');
fprintf('2. If data issues found, re-run EDA: runEDA\n');
fprintf('3. If config issues found, manually fix userConfig.m\n');
