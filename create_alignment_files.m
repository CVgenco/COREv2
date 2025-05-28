% create_alignment_files.m
% Creates the missing alignedTable.mat and info.mat files needed for Sprint 4
% Combines individual product cleaned tables into a synchronized aligned table

fprintf('Creating alignment files for Sprint 4...\n');

% Load configuration (as script, not function)
run('userConfig.m');

% Define the products we want to include (historical only, no forecasts)
productFiles = {
    'nodalPrices', 'hubPrices', 'nodalGeneration', 
    'regup', 'regdown', 'nonspin'
};

fprintf('Loading individual product tables...\n');

% Load individual cleaned tables and combine them
alignedTables = {};
productNames = {};

for i = 1:length(productFiles)
    productName = productFiles{i};
    filename = sprintf('EDA_Results/cleanedTable_%s.mat', productName);
    
    if exist(filename, 'file')
        fprintf('Loading %s...\n', productName);
        data = load(filename);
        if isfield(data, 'cleanedTable') && istimetable(data.cleanedTable)
            % Rename the variable to the product name
            data.cleanedTable.Properties.VariableNames{1} = productName;
            alignedTables{end+1} = data.cleanedTable;
            productNames{end+1} = productName;
        else
            fprintf('Warning: %s does not contain a valid timetable\n', filename);
        end
    else
        fprintf('Warning: %s not found, skipping\n', filename);
    end
end

% Synchronize all tables using intersection (common time points)
if length(alignedTables) > 0
    fprintf('Synchronizing %d product tables...\n', length(alignedTables));
    alignedTable = alignedTables{1};
    
    for i = 2:length(alignedTables)
        alignedTable = synchronize(alignedTable, alignedTables{i}, 'intersection', 'mean');
    end
    
    fprintf('Synchronized table has %d observations and %d products\n', height(alignedTable), width(alignedTable));
else
    error('No valid product tables found to align');
end

% Create info structure
info = struct();
info.productNames = productNames;
info.nObservations = height(alignedTable);
info.nProducts = width(alignedTable);
info.chosenResolution = 3600; % 1 hour (estimated)
info.resolutionSource = 'combined_cleaned_tables';

% Add timestamp info
info.startTime = alignedTable.Properties.RowTimes(1);
info.endTime = alignedTable.Properties.RowTimes(end);

fprintf('Products found: %s\n', strjoin(info.productNames, ', '));
fprintf('Number of observations: %d\n', info.nObservations);
fprintf('Number of products: %d\n', info.nProducts);
fprintf('Time range: %s to %s\n', string(info.startTime), string(info.endTime));

% Save the files in the root directory where Sprint 4 expects them
save('alignedTable.mat', 'alignedTable');
save('info.mat', 'info');

fprintf('✓ Created alignedTable.mat\n');
fprintf('✓ Created info.mat\n');
fprintf('Ready to run Sprint 4!\n');
