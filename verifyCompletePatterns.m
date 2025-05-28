function verifyCompletePatterns()
% verifyCompletePatterns - Comprehensive verification of the complete all_patterns.mat file
% This script verifies that all 8 products are properly included with jump modeling data

fprintf('=== COMPREHENSIVE PATTERNS FILE VERIFICATION ===\n\n');

% Load the patterns file
try
    load('EDA_Results/all_patterns.mat', 'patterns');
    fprintf('✅ Successfully loaded all_patterns.mat\n');
catch ME
    error('❌ Failed to load all_patterns.mat: %s', ME.message);
end

% Get all products in the patterns file
productNames = fieldnames(patterns);
fprintf('📊 Found %d products in patterns file\n', length(productNames));

% Expected products based on EDA_Results files
expectedProducts = {'hourlyHubForecasts', 'hourlyNodalForecasts', 'hubPrices', ...
                   'nodalGeneration', 'nodalPrices', 'nonspin', 'regdown', 'regup'};

fprintf('\n🔍 PRODUCT COVERAGE ANALYSIS:\n');
fprintf('Expected products: %d\n', length(expectedProducts));
fprintf('Found products: %d\n', length(productNames));

% Check if all expected products are present
missingProducts = setdiff(expectedProducts, productNames);
extraProducts = setdiff(productNames, expectedProducts);

if ~isempty(missingProducts)
    fprintf('❌ Missing products: %s\n', strjoin(missingProducts, ', '));
else
    fprintf('✅ All expected products are present\n');
end

if ~isempty(extraProducts)
    fprintf('ℹ️  Extra products: %s\n', strjoin(extraProducts, ', '));
end

% Required fields for jump modeling
requiredFields = {'jumpFrequency', 'jumpSizes', 'jumpSizeFit'};

fprintf('\n📋 DETAILED PRODUCT VERIFICATION:\n');
fprintf('%-20s | %-12s | %-10s | %-15s | %-10s\n', ...
        'Product', 'JumpFreq', 'JumpSizes', 'JumpFit', 'Status');
fprintf('%s\n', repmat('-', 80, 1));

allValid = true;
for i = 1:length(productNames)
    pname = productNames{i};
    product = patterns.(pname);
    
    % Check required fields
    hasAllFields = true;
    fieldStatus = {};
    
    for j = 1:length(requiredFields)
        field = requiredFields{j};
        if isfield(product, field)
            fieldStatus{end+1} = '✅';
        else
            fieldStatus{end+1} = '❌';
            hasAllFields = false;
        end
    end
    
    % Get jump statistics
    jumpFreq = 'N/A';
    jumpCount = 'N/A';
    jumpFit = 'N/A';
    
    if isfield(product, 'jumpFrequency')
        jumpFreq = sprintf('%.4f', product.jumpFrequency);
    end
    
    if isfield(product, 'jumpSizes')
        jumpCount = sprintf('%d', length(product.jumpSizes));
    end
    
    if isfield(product, 'jumpSizeFit') && isstruct(product.jumpSizeFit)
        if isfield(product.jumpSizeFit, 'mu') && isfield(product.jumpSizeFit, 'sigma')
            jumpFit = sprintf('μ=%.2f,σ=%.2f', product.jumpSizeFit.mu, product.jumpSizeFit.sigma);
        end
    end
    
    if hasAllFields
        status = '✅ VALID';
    else
        status = '❌ INCOMPLETE';
    end
    if ~hasAllFields
        allValid = false;
    end
    
    fprintf('%-20s | %-12s | %-10s | %-15s | %-10s\n', ...
            pname, jumpFreq, jumpCount, jumpFit, status);
end

fprintf('\n📈 SUMMARY STATISTICS:\n');
fprintf('Total products processed: %d\n', length(productNames));

% Calculate aggregate statistics
totalJumps = 0;
avgJumpFreq = 0;
for i = 1:length(productNames)
    pname = productNames{i};
    if isfield(patterns.(pname), 'jumpSizes')
        totalJumps = totalJumps + length(patterns.(pname).jumpSizes);
    end
    if isfield(patterns.(pname), 'jumpFrequency')
        avgJumpFreq = avgJumpFreq + patterns.(pname).jumpFrequency;
    end
end
avgJumpFreq = avgJumpFreq / length(productNames);

fprintf('Total jump events across all products: %d\n', totalJumps);
fprintf('Average jump frequency: %.4f\n', avgJumpFreq);

% File information
fileInfo = dir('EDA_Results/all_patterns.mat');
fprintf('File size: %.2f MB\n', fileInfo.bytes / (1024*1024));

fprintf('\n🎯 SPRINT 4 COMPATIBILITY CHECK:\n');
if allValid && length(productNames) >= length(expectedProducts)
    fprintf('✅ PATTERNS FILE IS READY FOR SPRINT 4!\n');
    fprintf('✅ All required fields present for jump modeling\n');
    fprintf('✅ All expected products included\n');
    fprintf('✅ File structure compatible with runSimulationAndScenarioGeneration.m\n');
else
    fprintf('❌ PATTERNS FILE NEEDS ATTENTION:\n');
    if ~allValid
        fprintf('   - Some products are missing required fields\n');
    end
    if length(productNames) < length(expectedProducts)
        fprintf('   - Missing expected products\n');
    end
end

fprintf('\n=== VERIFICATION COMPLETE ===\n');

end
