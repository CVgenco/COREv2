% consolidate_results.m
% Convert existing individual product files into combined format for Sprint 2

fprintf('=== Consolidating Sprint 1 Results ===\n');

% List of products
products = {'nodalPrices', 'hubPrices', 'nodalGeneration', 'regup', 'regdown', ...
           'nonspin', 'hourlyHubForecasts', 'hourlyNodalForecasts'};

% Initialize combined structures
combinedReturnsTable = struct();
combinedRegimeLabels = struct();
combinedCleanInfo = struct();
combinedRetInfo = struct();
combinedRegimeInfo = struct();

% Process each product
for i = 1:length(products)
    product = products{i};
    fprintf('Consolidating %s... ', product);
    
    try
        % Load individual files
        returnsFile = ['EDA_Results/returnsTable_' product '.mat'];
        regimeFile = ['EDA_Results/regimeLabels_' product '.mat'];
        cleanFile = ['EDA_Results/cleanInfo_' product '.mat'];
        retFile = ['EDA_Results/retInfo_' product '.mat'];
        regimeInfoFile = ['EDA_Results/regimeInfo_' product '.mat'];
        
        % Load returns table and extract the product data
        if exist(returnsFile, 'file')
            load(returnsFile, 'returnsTable');
            % Extract the product column from the table
            if istable(returnsTable) || istimetable(returnsTable)
                varNames = returnsTable.Properties.VariableNames;
                if ismember(product, varNames)
                    combinedReturnsTable.(product) = returnsTable.(product);
                else
                    % Use the first non-timestamp variable
                    dataVars = varNames(~contains(lower(varNames), {'time', 'date'}));
                    if ~isempty(dataVars)
                        combinedReturnsTable.(product) = returnsTable.(dataVars{1});
                    else
                        combinedReturnsTable.(product) = returnsTable.(varNames{1});
                    end
                end
            else
                combinedReturnsTable.(product) = returnsTable;
            end
        else
            fprintf('Missing returns file... ');
            combinedReturnsTable.(product) = [];
        end
        
        % Load regime labels
        if exist(regimeFile, 'file')
            load(regimeFile, 'regimeLabels');
            combinedRegimeLabels.(product) = regimeLabels;
        else
            fprintf('Missing regime file... ');
            combinedRegimeLabels.(product) = [];
        end
        
        % Load other info structures
        if exist(cleanFile, 'file')
            load(cleanFile, 'cleanInfo');
            combinedCleanInfo.(product) = cleanInfo;
        end
        
        if exist(retFile, 'file')
            load(retFile, 'retInfo');
            combinedRetInfo.(product) = retInfo;
        end
        
        if exist(regimeInfoFile, 'file')
            load(regimeInfoFile, 'regimeInfo');
            combinedRegimeInfo.(product) = regimeInfo;
        end
        
        fprintf('✓\n');
        
    catch ME
        fprintf('❌ Error: %s\n', ME.message);
    end
end

% Save combined structures
fprintf('\nSaving combined results...\n');
returnsTable = combinedReturnsTable;
regimeLabels = combinedRegimeLabels;
cleanInfo = combinedCleanInfo;
retInfo = combinedRetInfo;
regimeInfo = combinedRegimeInfo;

save('EDA_Results/returnsTable.mat', 'returnsTable');
save('EDA_Results/regimeLabels.mat', 'regimeLabels');
save('EDA_Results/cleanInfo.mat', 'cleanInfo');
save('EDA_Results/retInfo.mat', 'retInfo');
save('EDA_Results/regimeInfo.mat', 'regimeInfo');

% Verification
fprintf('\n=== Verification ===\n');
fprintf('Combined structures contain:\n');
for i = 1:length(products)
    product = products{i};
    hasReturns = isfield(returnsTable, product) && ~isempty(returnsTable.(product));
    hasRegimes = isfield(regimeLabels, product) && ~isempty(regimeLabels.(product));
    
    if hasReturns && hasRegimes
        nReturns = length(returnsTable.(product));
        nRegimes = length(regimeLabels.(product));
        fprintf('  ✓ %s: %d returns, %d regime labels\n', product, nReturns, nRegimes);
    else
        fprintf('  ❌ %s: Missing data\n', product);
    end
end

fprintf('\n✅ Consolidation complete! Ready for Sprint 2: Parameter Estimation\n');
