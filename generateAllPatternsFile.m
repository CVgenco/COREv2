function generateAllPatternsFile()
% generateAllPatternsFile - Creates the missing all_patterns.mat file for Sprint 4
% This script generates the patterns structure required by runSimulationAndScenarioGeneration.m
% The patterns must include jumpFrequency, jumpSizes, and jumpSizeFit fields for each product

fprintf('Generating all_patterns.mat file for Sprint 4...\n');

% Check if EDA_Results directory exists
if ~exist('EDA_Results', 'dir')
    mkdir('EDA_Results');
    fprintf('Created EDA_Results directory\n');
end

% Load configuration
try
    run('userConfig.m');
    fprintf('Loaded user configuration\n');
catch ME
    error('Failed to load userConfig.m: %s', ME.message);
end

% Load aligned data if available
try
    load('EDA_Results/alignedTable.mat', 'alignedTable');
    load('EDA_Results/info.mat', 'info');
    fprintf('Loaded alignedTable and info from EDA_Results\n');
catch
    fprintf('alignedTable.mat not found, attempting to load raw data...\n');
    
    % Try to load and process raw data
    try
        % Load historical nodal data
        nodalData = readtable(config.dataFiles.nodalPrices, 'PreserveVariableNames', true);
        if ~istimetable(nodalData)
            nodalData = table2timetable(nodalData);
        end
        
        % Create basic aligned table structure
        alignedTable = nodalData;
        productNames = setdiff(alignedTable.Properties.VariableNames, {'Timestamp'});
        info.productNames = productNames;
        
        fprintf('Loaded raw nodal data with %d products and %d observations\n', ...
                length(productNames), height(alignedTable));
    catch ME2
        error('Failed to load data: %s', ME2.message);
    end
end

% Get all available product names from EDA_Results files
fprintf('Discovering available products from EDA_Results...\n');
edaFiles = dir('EDA_Results/cleanedTable_*.mat');
availableProducts = {};
for i = 1:length(edaFiles)
    filename = edaFiles(i).name;
    % Extract product name from cleanedTable_PRODUCTNAME.mat
    productName = strrep(filename, 'cleanedTable_', '');
    productName = strrep(productName, '.mat', '');
    availableProducts{end+1} = productName;
end

% Also check if we have product names from info
if exist('info', 'var') && isfield(info, 'productNames')
    infoProducts = info.productNames;
    % Combine both sources, giving preference to EDA files
    allProducts = unique([availableProducts, infoProducts]);
else
    allProducts = availableProducts;
end

% Fallback to alignedTable if no products found
if isempty(allProducts)
    allProducts = setdiff(alignedTable.Properties.VariableNames, {'Timestamp'});
end

productNames = allProducts;
fprintf('Found %d products to process: %s\n', length(productNames), strjoin(productNames, ', '));

% Initialize patterns structure
patterns = struct();

% Process each product to extract jump modeling parameters
for i = 1:length(productNames)
    pname = productNames{i};
    fprintf('Processing product %d/%d: %s\n', i, length(productNames), pname);
    
    try
    try
        % First try to load from individual product file
        productFile = sprintf('EDA_Results/cleanedTable_%s.mat', pname);
        if exist(productFile, 'file')
            fprintf('  Loading data from %s\n', productFile);
            productData = load(productFile);
            
            % Get the cleaned table
            if isfield(productData, 'cleanedTable')
                cleanedTable = productData.cleanedTable;
                if istimetable(cleanedTable)
                    priceColumns = setdiff(cleanedTable.Properties.VariableNames, {'Timestamp'});
                    if ~isempty(priceColumns)
                        priceData = cleanedTable.(priceColumns{1}); % Take first price column
                        timestamps = cleanedTable.Properties.RowTimes;
                    else
                        error('No price columns found in cleanedTable');
                    end
                else
                    priceColumns = setdiff(cleanedTable.Properties.VariableNames, {'Timestamp'});
                    if ~isempty(priceColumns)
                        priceData = cleanedTable.(priceColumns{1});
                        timestamps = cleanedTable.Timestamp;
                    else
                        error('No price columns found in cleanedTable');
                    end
                end
            else
                error('cleanedTable variable not found in %s', productFile);
            end
        else
            % Fallback to alignedTable
            fprintf('  Product file not found, using alignedTable\n');
            if istimetable(alignedTable)
                priceData = alignedTable.(pname);
                timestamps = alignedTable.Properties.RowTimes;
            else
                priceData = alignedTable.(pname);
                timestamps = alignedTable.Timestamp;
            end
        end
        
        % Remove NaN values
        validIdx = ~isnan(priceData);
        priceData = priceData(validIdx);
        timestamps = timestamps(validIdx);
        
        if length(priceData) < 100
            warning('Insufficient data for %s (only %d valid observations)', pname, length(priceData));
            continue;
        end
        
        % Calculate returns
        returns = diff(priceData);
        
        % Extract jump characteristics
        fprintf('  Extracting jump characteristics for %s...\n', pname);
        
        % Define jump threshold (e.g., 3 standard deviations)
        returnStd = std(returns, 'omitnan');
        jumpThreshold = 3 * returnStd;
        
        % Identify jumps
        isJump = abs(returns) > jumpThreshold;
        jumpIndices = find(isJump);
        
        % Calculate jump frequency (jumps per observation)
        jumpFrequency = sum(isJump) / length(returns);
        
        % Extract jump sizes
        jumpSizes = returns(isJump);
        if isempty(jumpSizes)
            % If no jumps found, create minimal jump structure
            jumpSizes = [-2*returnStd, 2*returnStd]; % Minimal jump sizes
            jumpFrequency = 0.01; % Very low frequency
        end
        
        % Fit normal distribution to jump sizes
        if length(jumpSizes) >= 2
            jumpMean = mean(jumpSizes);
            jumpStd = std(jumpSizes);
        else
            jumpMean = 0;
            jumpStd = returnStd;
        end
        
        % Store pattern data for this product
        patterns.(pname) = struct();
        patterns.(pname).jumpFrequency = jumpFrequency;
        patterns.(pname).jumpSizes = jumpSizes;
        patterns.(pname).jumpSizeFit = struct('mu', jumpMean, 'sigma', jumpStd);
        
        % Store additional basic pattern information
        patterns.(pname).rawHistorical = priceData;
        patterns.(pname).timestamps = timestamps;
        patterns.(pname).returnStd = returnStd;
        patterns.(pname).jumpThreshold = jumpThreshold;
        
        fprintf('  %s: jumpFreq=%.4f, jumpSizes=%d, jumpMean=%.4f, jumpStd=%.4f\n', ...
                pname, jumpFrequency, length(jumpSizes), jumpMean, jumpStd);
        
    catch ME
        warning('Failed to process product %s: %s', pname, ME.message);
        continue;
    end
end

% Verify patterns structure
fprintf('\nVerifying patterns structure...\n');
processedProducts = fieldnames(patterns);
fprintf('Successfully processed %d products: %s\n', ...
        length(processedProducts), strjoin(processedProducts, ', '));

% Check required fields for each product
requiredFields = {'jumpFrequency', 'jumpSizes', 'jumpSizeFit'};
for i = 1:length(processedProducts)
    pname = processedProducts{i};
    for j = 1:length(requiredFields)
        field = requiredFields{j};
        if ~isfield(patterns.(pname), field)
            warning('Missing required field %s for product %s', field, pname);
        end
    end
end

% Save patterns to all_patterns.mat
outputFile = 'EDA_Results/all_patterns.mat';
try
    save(outputFile, 'patterns');
    fprintf('\n✅ Successfully saved patterns to %s\n', outputFile);
    
    % Verify the file was saved correctly
    testLoad = load(outputFile);
    if isfield(testLoad, 'patterns')
        fprintf('✅ File verification passed - patterns variable found\n');
        fprintf('✅ File size: %.2f KB\n', dir(outputFile).bytes / 1024);
    else
        error('File verification failed - patterns variable not found');
    end
    
catch ME
    error('Failed to save patterns file: %s', ME.message);
end

fprintf('\n🎉 all_patterns.mat generation complete!\n');
fprintf('You can now run runSimulationAndScenarioGeneration.m for Sprint 4\n');

end
