% testBayesOptFix.m
% Quick test to verify the brace indexing fix works

fprintf('=== Testing Bayesian Optimization Fix ===\n');

% Test parameters
params = struct();
params.blockSize = 24;
params.df = 5;
params.jumpThreshold = 0.05;
params.regimeAmpFactor = 1.0;

try
    % Load required data
    if ~exist('alignedTable.mat', 'file') && exist('EDA_Results/alignedTable.mat', 'file')
        copyfile('EDA_Results/alignedTable.mat', 'alignedTable.mat');
    end
    
    load('alignedTable.mat', 'alignedTable');
    fprintf('✓ Data loaded successfully\n');
    
    % Test the enhanced data preprocessing function directly
    if istable(alignedTable) || istimetable(alignedTable)
        productNames = alignedTable.Properties.VariableNames;
        productNames = productNames(~contains(lower(productNames), {'time', 'date'}));
    else
        productNames = fieldnames(alignedTable);
    end
    
    fprintf('✓ Product names extracted: %d products\n', length(productNames));
    
    % Load config
    run('userConfig.m');
    
    % Test enhanced data preprocessing
    fprintf('Testing enhanced data preprocessing...\n');
    [enhancedData, stats] = enhancedDataPreprocessing(alignedTable, productNames, config);
    fprintf('✓ Enhanced data preprocessing completed successfully!\n');
    fprintf('  Products processed: %d\n', stats.totalProducts);
    
    fprintf('\n🎉 SUCCESS: Brace indexing error is FIXED!\n');
    
catch ME
    fprintf('❌ ERROR: %s\n', ME.message);
    fprintf('Identifier: %s\n', ME.identifier);
    if ~isempty(ME.stack)
        fprintf('Stack trace:\n');
        for i = 1:length(ME.stack)
            fprintf('  %s (line %d)\n', ME.stack(i).name, ME.stack(i).line);
        end
    end
end
