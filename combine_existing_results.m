% combine_existing_results.m
% Combine individual product files into combined format for Sprint 2

fprintf('=== Combining Existing Results for Sprint 2 ===\n');

% Define products
products = {'nodalPrices', 'hubPrices', 'nodalGeneration', 'regup', 'regdown', ...
           'nonspin', 'hourlyHubForecasts', 'hourlyNodalForecasts'};

% Initialize combined structures
combinedReturnsTable = struct();
combinedRegimeLabels = struct();

% Process each product
for i = 1:length(products)
    pname = products{i};
    fprintf('Processing %s... ', pname);
    
    % Load returns table for this product
    returnsFile = ['EDA_Results/returnsTable_' pname '.mat'];
    if exist(returnsFile, 'file')
        load(returnsFile, 'returnsTable');
        
        % Extract the returns data for this product
        if istimetable(returnsTable) || istable(returnsTable)
            vars = returnsTable.Properties.VariableNames;
            if ismember('Price', vars)
                % Common case: variable is named 'Price'
                combinedReturnsTable.(pname) = returnsTable.Price;
            elseif ismember(pname, vars)
                % Product name matches variable name
                combinedReturnsTable.(pname) = returnsTable.(pname);
            elseif ~isempty(vars)
                % Use the first data column
                combinedReturnsTable.(pname) = returnsTable.(vars{1});
            else
                fprintf('❌ No data columns found\n');
                continue;
            end
        else
            fprintf('❌ Invalid returns table format\n');
            continue;
        end
    else
        fprintf('❌ Returns file not found\n');
        continue;
    end
    
    % Load regime labels for this product
    regimeFile = ['EDA_Results/regimeLabels_' pname '.mat'];
    if exist(regimeFile, 'file')
        load(regimeFile, 'regimeLabels');
        combinedRegimeLabels.(pname) = regimeLabels;
    else
        fprintf('❌ Regime labels file not found\n');
        continue;
    end
    
    fprintf('✅ Success\n');
end

% Save combined files
fprintf('\nSaving combined files...\n');

% Save combined returns table
returnsTable = combinedReturnsTable;
save('EDA_Results/returnsTable.mat', 'returnsTable');
fprintf('✅ Saved EDA_Results/returnsTable.mat\n');

% Save combined regime labels
regimeLabels = combinedRegimeLabels;
save('EDA_Results/regimeLabels.mat', 'regimeLabels');
fprintf('✅ Saved EDA_Results/regimeLabels.mat\n');

% Verification
fprintf('\n=== Verification ===\n');
fprintf('Combined returnsTable contains:\n');
retFields = fieldnames(returnsTable);
for i = 1:length(retFields)
    pname = retFields{i};
    data = returnsTable.(pname);
    nValid = sum(~isnan(data));
    fprintf('  ✅ %s: %d observations (%d valid)\n', pname, length(data), nValid);
end

fprintf('\nRegime labels structure contains:\n');
regimeFields = fieldnames(regimeLabels);
for i = 1:length(regimeFields)
    pname = regimeFields{i};
    regimes = regimeLabels.(pname);
    if ~isempty(regimes)
        uniqueRegimes = unique(regimes(~isnan(regimes)));
        fprintf('  ✅ %s: %d observations, regimes [%s]\n', pname, length(regimes), num2str(uniqueRegimes'));
    else
        fprintf('  ❌ %s: Empty\n', pname);
    end
end

fprintf('\n🚀 Ready for Sprint 2: Parameter Estimation!\n');
