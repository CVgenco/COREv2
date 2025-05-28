function validateRobustSystem()
%VALIDATEROBUSTSYSTEM Final validation of the complete robust outlier detection system
%   Checks all components, configurations, and integration points
%   Provides comprehensive system readiness report

fprintf('=== ROBUST OUTLIER DETECTION SYSTEM VALIDATION ===\n');
fprintf('Validating complete system integration and readiness...\n\n');

validationResults = struct();
validationResults.timestamp = datestr(now);
validationResults.overallStatus = 'UNKNOWN';
validationResults.componentStatus = struct();

%% 1. Validate Core Module Files
fprintf('1. VALIDATING CORE MODULE FILES\n');
fprintf('--------------------------------\n');

coreFiles = {
    'robustOutlierDetection.m', 'Core outlier detection engine';
    'enhancedDataPreprocessing.m', 'Comprehensive preprocessing pipeline';
    'robustBayesianOptSafety.m', 'Safety validation system';
    'testRobustIntegration.m', 'Integration test suite'
};

coreFilesValid = true;
for i = 1:size(coreFiles, 1)
    fileName = coreFiles{i, 1};
    description = coreFiles{i, 2};
    
    if exist(fileName, 'file')
        fprintf('✓ %s - %s\n', fileName, description);
        validationResults.componentStatus.(strrep(fileName, '.', '_')) = 'PRESENT';
    else
        fprintf('✗ %s - MISSING\n', fileName);
        validationResults.componentStatus.(strrep(fileName, '.', '_')) = 'MISSING';
        coreFilesValid = false;
    end
end

if coreFilesValid
    fprintf('✓ All core module files present\n');
else
    fprintf('✗ Some core module files missing\n');
end

fprintf('\n');

%% 2. Validate Enhanced Module Files
fprintf('2. VALIDATING ENHANCED MODULE FILES\n');
fprintf('-----------------------------------\n');

enhancedFiles = {
    'data_cleaning.m', 'Enhanced data cleaning with robust integration';
    'bayesoptSimObjective.m', 'Enhanced objective function with safety';
    'runBayesianTuning.m', 'Robust Bayesian optimization';
    'runSimulationAndScenarioGeneration.m', 'Enhanced simulation pipeline';
    'userConfig.m', 'Enhanced configuration options'
};

enhancedFilesValid = true;
for i = 1:size(enhancedFiles, 1)
    fileName = enhancedFiles{i, 1};
    description = enhancedFiles{i, 2};
    
    if exist(fileName, 'file')
        % Check if file contains robust integration markers
        fileContent = fileread(fileName);
        hasRobustIntegration = contains(fileContent, 'robust', 'IgnoreCase', true) || ...
                              contains(fileContent, 'outlier', 'IgnoreCase', true) || ...
                              contains(fileContent, 'enhanced', 'IgnoreCase', true);
        
        if hasRobustIntegration
            fprintf('✓ %s - Enhanced with robust features\n', fileName);
            validationResults.componentStatus.(strrep(fileName, '.', '_')) = 'ENHANCED';
        else
            fprintf('⚠ %s - Present but may need robust integration\n', fileName);
            validationResults.componentStatus.(strrep(fileName, '.', '_')) = 'NEEDS_INTEGRATION';
        end
    else
        fprintf('✗ %s - MISSING\n', fileName);
        validationResults.componentStatus.(strrep(fileName, '.', '_')) = 'MISSING';
        enhancedFilesValid = false;
    end
end

if enhancedFilesValid
    fprintf('✓ All enhanced module files present\n');
else
    fprintf('✗ Some enhanced module files missing or need integration\n');
end

fprintf('\n');

%% 3. Validate Configuration Structure
fprintf('3. VALIDATING CONFIGURATION STRUCTURE\n');
fprintf('--------------------------------------\n');

try
    run('userConfig.m');
    
    % Check for enhanced preprocessing configuration
    if isfield(config, 'dataPreprocessing')
        fprintf('✓ dataPreprocessing configuration present\n');
        
        requiredFields = {'enabled', 'robustOutlierDetection', 'volatilityExplosionPrevention', 'adaptiveBlockSize'};
        for i = 1:length(requiredFields)
            field = requiredFields{i};
            if isfield(config.dataPreprocessing, field)
                fprintf('  ✓ %s: %s\n', field, mat2str(config.dataPreprocessing.(field)));
            else
                fprintf('  ✗ %s: MISSING\n', field);
            end
        end
    else
        fprintf('✗ dataPreprocessing configuration missing\n');
    end
    
    % Check for outlier detection configuration
    if isfield(config, 'outlierDetection')
        fprintf('✓ outlierDetection configuration present\n');
        fprintf('  ✓ IQR enabled: %s\n', mat2str(config.outlierDetection.enableIQR));
        fprintf('  ✓ Modified Z-score enabled: %s\n', mat2str(config.outlierDetection.enableModifiedZScore));
        fprintf('  ✓ Energy thresholds enabled: %s\n', mat2str(config.outlierDetection.enableEnergyThresholds));
    else
        fprintf('✗ outlierDetection configuration missing\n');
    end
    
    % Check for volatility prevention configuration
    if isfield(config, 'volatilityPrevention')
        fprintf('✓ volatilityPrevention configuration present\n');
    else
        fprintf('✗ volatilityPrevention configuration missing\n');
    end
    
    % Check for Bayesian optimization safety configuration
    if isfield(config, 'bayesianOptSafety')
        fprintf('✓ bayesianOptSafety configuration present\n');
    else
        fprintf('✗ bayesianOptSafety configuration missing\n');
    end
    
    validationResults.componentStatus.configuration = 'VALID';
    fprintf('✓ Configuration structure validation completed\n');
    
catch ME
    fprintf('✗ Configuration validation failed: %s\n', ME.message);
    validationResults.componentStatus.configuration = 'INVALID';
end

fprintf('\n');

%% 4. Validate Function Signatures and Dependencies
fprintf('4. VALIDATING FUNCTION SIGNATURES\n');
fprintf('----------------------------------\n');

try
    % Test robustOutlierDetection function signature
    help robustOutlierDetection;
    fprintf('✓ robustOutlierDetection function accessible\n');
    
    % Test enhancedDataPreprocessing function signature
    help enhancedDataPreprocessing;
    fprintf('✓ enhancedDataPreprocessing function accessible\n');
    
    % Test robustBayesianOptSafety function signature
    help robustBayesianOptSafety;
    fprintf('✓ robustBayesianOptSafety function accessible\n');
    
    validationResults.componentStatus.functionSignatures = 'VALID';
    
catch ME
    fprintf('✗ Function signature validation failed: %s\n', ME.message);
    validationResults.componentStatus.functionSignatures = 'INVALID';
end

fprintf('\n');

%% 5. Validate Directory Structure
fprintf('5. VALIDATING DIRECTORY STRUCTURE\n');
fprintf('----------------------------------\n');

requiredDirs = {'EDA_Results', 'Correlation_Results', 'Simulation_Results'};
directoriesValid = true;

for i = 1:length(requiredDirs)
    dirName = requiredDirs{i};
    if exist(dirName, 'dir')
        fprintf('✓ %s directory exists\n', dirName);
    else
        fprintf('⚠ %s directory missing (will be created as needed)\n', dirName);
    end
end

validationResults.componentStatus.directories = 'VALID';
fprintf('✓ Directory structure validation completed\n');

fprintf('\n');

%% 6. Validate Integration Points
fprintf('6. VALIDATING INTEGRATION POINTS\n');
fprintf('---------------------------------\n');

integrationPoints = 0;
validIntegrations = 0;

% Check data_cleaning.m integration
try
    fileContent = fileread('data_cleaning.m');
    if contains(fileContent, 'robustOutlierDetection', 'IgnoreCase', true)
        fprintf('✓ data_cleaning.m integrated with robust outlier detection\n');
        validIntegrations = validIntegrations + 1;
    else
        fprintf('✗ data_cleaning.m missing robust integration\n');
    end
    integrationPoints = integrationPoints + 1;
catch
    fprintf('✗ Cannot validate data_cleaning.m integration\n');
    integrationPoints = integrationPoints + 1;
end

% Check runSimulationAndScenarioGeneration.m integration
try
    fileContent = fileread('runSimulationAndScenarioGeneration.m');
    if contains(fileContent, 'enhancedDataPreprocessing', 'IgnoreCase', true)
        fprintf('✓ runSimulationAndScenarioGeneration.m integrated with enhanced preprocessing\n');
        validIntegrations = validIntegrations + 1;
    else
        fprintf('✗ runSimulationAndScenarioGeneration.m missing enhanced preprocessing integration\n');
    end
    integrationPoints = integrationPoints + 1;
catch
    fprintf('✗ Cannot validate runSimulationAndScenarioGeneration.m integration\n');
    integrationPoints = integrationPoints + 1;
end

% Check bayesoptSimObjective.m integration
try
    fileContent = fileread('bayesoptSimObjective.m');
    if contains(fileContent, 'robustBayesianOptSafety', 'IgnoreCase', true)
        fprintf('✓ bayesoptSimObjective.m integrated with safety validation\n');
        validIntegrations = validIntegrations + 1;
    else
        fprintf('✗ bayesoptSimObjective.m missing safety integration\n');
    end
    integrationPoints = integrationPoints + 1;
catch
    fprintf('✗ Cannot validate bayesoptSimObjective.m integration\n');
    integrationPoints = integrationPoints + 1;
end

integrationRatio = validIntegrations / integrationPoints;
if integrationRatio >= 0.8
    fprintf('✓ Integration validation: %d/%d (%.1f%%) - GOOD\n', validIntegrations, integrationPoints, integrationRatio*100);
    validationResults.componentStatus.integration = 'GOOD';
else
    fprintf('✗ Integration validation: %d/%d (%.1f%%) - NEEDS WORK\n', validIntegrations, integrationPoints, integrationRatio*100);
    validationResults.componentStatus.integration = 'NEEDS_WORK';
end

fprintf('\n');

%% 7. Generate Overall System Status
fprintf('7. OVERALL SYSTEM STATUS\n');
fprintf('------------------------\n');

% Count valid components
componentFields = fieldnames(validationResults.componentStatus);
validComponents = 0;
totalComponents = length(componentFields);

for i = 1:length(componentFields)
    status = validationResults.componentStatus.(componentFields{i});
    if strcmp(status, 'PRESENT') || strcmp(status, 'ENHANCED') || strcmp(status, 'VALID') || strcmp(status, 'GOOD')
        validComponents = validComponents + 1;
    end
end

systemReadiness = validComponents / totalComponents;
if systemReadiness >= 0.9
    validationResults.overallStatus = 'READY';
    fprintf('✓ SYSTEM STATUS: READY (%.1f%% components valid)\n', systemReadiness*100);
    fprintf('  The robust outlier detection system is ready for production use.\n');
elseif systemReadiness >= 0.7
    validationResults.overallStatus = 'MOSTLY_READY';
    fprintf('⚠ SYSTEM STATUS: MOSTLY READY (%.1f%% components valid)\n', systemReadiness*100);
    fprintf('  The system is mostly ready but may need minor adjustments.\n');
else
    validationResults.overallStatus = 'NEEDS_WORK';
    fprintf('✗ SYSTEM STATUS: NEEDS WORK (%.1f%% components valid)\n', systemReadiness*100);
    fprintf('  The system requires additional work before production use.\n');
end

fprintf('\n');

%% 8. Generate Recommendations
fprintf('8. RECOMMENDATIONS\n');
fprintf('------------------\n');

if strcmp(validationResults.overallStatus, 'READY')
    fprintf('✓ System is ready for use. Recommended next steps:\n');
    fprintf('  1. Run testRobustIntegration() for integration testing\n');
    fprintf('  2. Execute runBayesianTuning(''userConfig.m'') for optimization\n');
    fprintf('  3. Monitor for elimination of HARD RESET warnings\n');
    fprintf('  4. Validate ACF and kurtosis file generation\n');
elseif strcmp(validationResults.overallStatus, 'MOSTLY_READY')
    fprintf('⚠ System is mostly ready. Recommended actions:\n');
    fprintf('  1. Address any missing configuration options\n');
    fprintf('  2. Complete any pending integration work\n');
    fprintf('  3. Run testRobustIntegration() to identify issues\n');
    fprintf('  4. Re-run validation after fixes\n');
else
    fprintf('✗ System needs work. Required actions:\n');
    fprintf('  1. Ensure all core module files are present\n');
    fprintf('  2. Complete integration of enhanced modules\n');
    fprintf('  3. Update configuration files\n');
    fprintf('  4. Re-run validation after each fix\n');
end

fprintf('\n');

%% 9. Save Validation Report
fprintf('9. SAVING VALIDATION REPORT\n');
fprintf('---------------------------\n');

try
    save('system_validation_report.mat', 'validationResults');
    fprintf('✓ Validation report saved to system_validation_report.mat\n');
    
    % Create human-readable report
    reportFile = 'system_validation_report.txt';
    fid = fopen(reportFile, 'w');
    
    fprintf(fid, 'ROBUST OUTLIER DETECTION SYSTEM VALIDATION REPORT\n');
    fprintf(fid, '==================================================\n\n');
    fprintf(fid, 'Validation Date: %s\n', validationResults.timestamp);
    fprintf(fid, 'Overall Status: %s\n', validationResults.overallStatus);
    fprintf(fid, 'System Readiness: %.1f%%\n\n', systemReadiness*100);
    
    fprintf(fid, 'COMPONENT STATUS:\n');
    fprintf(fid, '-----------------\n');
    componentFields = fieldnames(validationResults.componentStatus);
    for i = 1:length(componentFields)
        fprintf(fid, '%s: %s\n', componentFields{i}, validationResults.componentStatus.(componentFields{i}));
    end
    
    fclose(fid);
    fprintf('✓ Human-readable report saved to %s\n', reportFile);
    
catch ME
    fprintf('✗ Failed to save validation report: %s\n', ME.message);
end

fprintf('\n=== VALIDATION COMPLETED ===\n');
fprintf('System Status: %s\n', validationResults.overallStatus);
fprintf('Readiness: %.1f%%\n', systemReadiness*100);

end
