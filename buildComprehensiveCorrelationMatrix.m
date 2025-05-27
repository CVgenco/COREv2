function [correlationMatrix, productNames, displayNames] = buildComprehensiveCorrelationMatrix(nodalData, hubData, genData, ancillaryData, hasGenData, hasAncillaryData, nodalFile, hubFile, genFile, ancillaryFiles)
% Builds correlation matrix from all available historical data,
% by synchronizing all data at their native resolutions first (Python-like).

    % --- Apply suffixes to column names in each input table ---
    % Nodal data
    origNodalNames = setdiff(nodalData.Properties.VariableNames, {'Timestamp'});
    suffixedNodalNames = cell(size(origNodalNames));
    for i = 1:length(origNodalNames)
        suffixedNodalNames{i} = sprintf('%s_nodal', origNodalNames{i});
    end
    if ~isempty(origNodalNames)
        nodalData = renamevars(nodalData, origNodalNames, suffixedNodalNames);
    end

    % Hub data
    if ~isempty(hubData)
        origHubNames = setdiff(hubData.Properties.VariableNames, {'Timestamp'});
        suffixedHubNames = cell(size(origHubNames));
        for i = 1:length(origHubNames)
            suffixedHubNames{i} = sprintf('%s_hub', origHubNames{i});
        end
        if ~isempty(origHubNames)
            hubData = renamevars(hubData, origHubNames, suffixedHubNames);
        end
    else
        suffixedHubNames = {}; % Ensure it's defined
    end

    % Gen data
    if hasGenData && ~isempty(genData)
        origGenNames = setdiff(genData.Properties.VariableNames, {'Timestamp'});
        suffixedGenNames = cell(size(origGenNames));
        for i = 1:length(origGenNames)
            suffixedGenNames{i} = sprintf('%s_gen', origGenNames{i});
        end
        if ~isempty(origGenNames)
            genData = renamevars(genData, origGenNames, suffixedGenNames);
        end
    else
        suffixedGenNames = {}; % Ensure it's defined
    end

    % Ancillary data
    suffixedAncillaryNames = {};
    if hasAncillaryData
        ancTypes = fieldnames(ancillaryData);
        for a = 1:length(ancTypes)
            ancType = ancTypes{a};
            if ~isempty(ancillaryData.(ancType))
                origAncNames = setdiff(ancillaryData.(ancType).Properties.VariableNames, {'Timestamp'});
                tempSuffixedAncNames = cell(size(origAncNames));
                for i = 1:length(origAncNames)
                    tempSuffixedAncNames{i} = sprintf('%s_%s', origAncNames{i}, lower(ancType));
                end
                if ~isempty(origAncNames)
                    ancillaryData.(ancType) = renamevars(ancillaryData.(ancType), origAncNames, tempSuffixedAncNames);
                end
                suffixedAncillaryNames = [suffixedAncillaryNames, tempSuffixedAncNames];
            end
        end
    end

    % --- Collect all productNames and displayNames ---
    productNames = [suffixedNodalNames, suffixedHubNames, suffixedGenNames, suffixedAncillaryNames];
    displayNames = {}; % Rebuild displayNames based on the new productNames and source files
    
    % Nodal display names
    for i = 1:length(suffixedNodalNames)
        originalName = strrep(suffixedNodalNames{i}, '_nodal', '');
        displayNames{end+1} = sprintf('%s (%s)', originalName, nodalFile);
    end
    % Hub display names
    if ~isempty(hubData)
        for i = 1:length(suffixedHubNames)
            originalName = strrep(suffixedHubNames{i}, '_hub', '');
            displayNames{end+1} = sprintf('%s (%s)', originalName, hubFile);
        end
    end
    % Gen display names
    if hasGenData && ~isempty(genData)
        for i = 1:length(suffixedGenNames)
            originalName = strrep(suffixedGenNames{i}, '_gen', '');
            displayNames{end+1} = sprintf('%s (%s)', originalName, genFile);
        end
    end
    % Ancillary display names
    if hasAncillaryData
        currentAncIdx = 1;
        ancTypes = fieldnames(ancillaryData);
         for a = 1:length(ancTypes)
            ancType = ancTypes{a};
            if ~isempty(ancillaryData.(ancType))
                % Count how many products came from this ancillary type
                numProdsFromType = sum(endsWith(suffixedAncillaryNames, ['_' lower(ancType)]));
                for k = 1:numProdsFromType
                    if currentAncIdx <= length(suffixedAncillaryNames)
                        originalName = strrep(suffixedAncillaryNames{currentAncIdx}, ['_' lower(ancType)], '');
                        displayNames{end+1} = sprintf('%s (%s)', originalName, ancillaryFiles.(ancType));
                        currentAncIdx = currentAncIdx + 1;
                    end
                end
            end
        end
    end
    % Remove any empty cells from productNames if some datasets were empty
    productNames = productNames(~cellfun('isempty',productNames));
    if isrow(productNames) && ~isempty(productNames) % Ensure productNames is a column vector if not empty
        productNames = productNames';
    elseif isempty(productNames)
        productNames = {}; % Ensure it's an empty cell array
    end


    % Initialize correlation matrix
    nProducts = length(productNames);
    if nProducts <= 1
        fprintf(' → Only one product or no products for correlation, returning identity/empty matrix\n');
        if nProducts == 1
            correlationMatrix = eye(1);
        else
            correlationMatrix = [];
        end
        return;
    end
    
    % --- Clean and sort each table before converting to timetable ---
    % Nodal data
    if ~isempty(nodalData)
        nodalData = nodalData(~isnat(nodalData.Timestamp), :);
        nodalData = sortrows(nodalData, 'Timestamp');
    end
    % Hub data
    if ~isempty(hubData)
        hubData = hubData(~isnat(hubData.Timestamp), :);
        hubData = sortrows(hubData, 'Timestamp');
    end
    % Gen data
    if hasGenData && ~isempty(genData)
        genData = genData(~isnat(genData.Timestamp), :);
        genData = sortrows(genData, 'Timestamp');
    end
    % Ancillary data
    if hasAncillaryData
        ancTypes = fieldnames(ancillaryData);
        for a = 1:length(ancTypes)
            ancType = ancTypes{a};
            if ~isempty(ancillaryData.(ancType))
                ancillaryData.(ancType) = ancillaryData.(ancType)(~isnat(ancillaryData.(ancType).Timestamp), :);
                ancillaryData.(ancType) = sortrows(ancillaryData.(ancType), 'Timestamp');
            end
        end
    end

    % --- Convert to timetables (native resolution) and synchronize ---
    tts = {};
    % Nodal
    if ~isempty(nodalData) && ~isempty(setdiff(nodalData.Properties.VariableNames, {'Timestamp'}))
        nodalTT = table2timetable(nodalData, 'RowTimes', nodalData.Timestamp);
        tts{end+1} = nodalTT;
    end
    % Hub
    if ~isempty(hubData) && ~isempty(setdiff(hubData.Properties.VariableNames, {'Timestamp'}))
        hubTT = table2timetable(hubData, 'RowTimes', hubData.Timestamp);
        tts{end+1} = hubTT;
    end
    % Gen
    if hasGenData && ~isempty(genData) && ~isempty(setdiff(genData.Properties.VariableNames, {'Timestamp'}))
        genTT = table2timetable(genData, 'RowTimes', genData.Timestamp);
        tts{end+1} = genTT;
    end
    % Ancillary
    if hasAncillaryData
        ancTypes = fieldnames(ancillaryData);
        for a = 1:length(ancTypes)
            ancType = ancTypes{a};
            if ~isempty(ancillaryData.(ancType)) && ~isempty(setdiff(ancillaryData.(ancType).Properties.VariableNames, {'Timestamp'}))
                ancTT = table2timetable(ancillaryData.(ancType), 'RowTimes', ancillaryData.(ancType).Timestamp);
                tts{end+1} = ancTT;
            end
        end
    end

    if isempty(tts)
        fprintf(' → No data to synchronize for correlation matrix construction.\n');
        correlationMatrix = eye(nProducts); % Or handle as error
        return;
    end

    masterTT = synchronize(tts{:}, 'union', 'fillwithmissing'); % Use fillwithmissing or let NaNs propagate
    alignedData = timetable2table(masterTT, 'ConvertRowTimes', true);
    if ~isempty(alignedData)
        alignedData.Properties.VariableNames{1} = 'Timestamp'; % Ensure first column is Timestamp
    else
        fprintf(' → Warning: Synchronization resulted in an empty table. Cannot build correlation matrix.\n');
        correlationMatrix = eye(nProducts);
        return;
    end
    
    % Diagnostic: Print alignedData column names and productNames
    fprintf('\nAlignedData columns (after native sync): \n');
    disp(alignedData.Properties.VariableNames');
    fprintf('productNames for correlation: \n');
    disp(productNames);

    % Build dataMatrix using productNames directly
    dataMatrix = [];
    for i = 1:length(productNames)
        if ismember(productNames{i}, alignedData.Properties.VariableNames)
            dataMatrix = [dataMatrix, alignedData.(productNames{i})];
        else
            fprintf(' → Warning: Product %s expected but not found in alignedData after native sync. Filling with NaNs.\n', productNames{i});
            dataMatrix = [dataMatrix, nan(height(alignedData),1)];
        end
    end
    
    if isempty(dataMatrix)
        fprintf(' → Warning: dataMatrix is empty. Cannot compute correlation matrix.\n');
        correlationMatrix = eye(nProducts);
        return;
    end

    correlationMatrix = corr(dataMatrix, 'rows', 'pairwise');
    
    % Ensure the correlation matrix is symmetric and positive semi-definite
    if any(isnan(correlationMatrix(:)))
        fprintf(' → Warning: Correlation matrix contains NaNs. Setting to identity and returning.\n');
        correlationMatrix = eye(nProducts); % Fallback for severe data issues
    else
        correlationMatrix = (correlationMatrix + correlationMatrix') / 2; % Make symmetric
        [~, p] = chol(correlationMatrix);
        if p > 0
            fprintf(' → Correlation matrix is not positive semi-definite, applying nearest PSD approximation\n');
            [V, D] = eig(correlationMatrix);
            D = diag(max(diag(D), 0)); % Ensure non-negative eigenvalues
            correlationMatrix = V * D * V';
            % Rescale to ensure diagonal is 1
            d = diag(correlationMatrix);
            if any(d <= 0) % Prevent division by zero or sqrt of negative
                fprintf(' → Warning: Non-positive diagonal elements after PSD approx. Setting to identity.\n');
                correlationMatrix = eye(nProducts);
            else
                correlationMatrix = correlationMatrix ./ sqrt(d * d');
                correlationMatrix(logical(eye(nProducts))) = 1; % Ensure diagonal is exactly 1
            end
        end
    end
        
    % Diagnostic: Print number of non-NaN values per product from alignedData
    fprintf('\n=== Data Availability Diagnostics (after native sync) ===\n');
    for i = 1:length(productNames)
        if ismember(productNames{i}, alignedData.Properties.VariableNames)
            fprintf('%s: %d non-NaN values\n', productNames{i}, sum(~isnan(alignedData.(productNames{i}))));
        else
            fprintf('%s: Not found in alignedData\n', productNames{i});
        end
    end
    % Diagnostic: Print number of overlapping (non-NaN) pairs for each product pair
    for i = 1:length(productNames)
        for j = i+1:length(productNames)
            if ismember(productNames{i}, alignedData.Properties.VariableNames) && ismember(productNames{j}, alignedData.Properties.VariableNames)
                validIdx = ~isnan(alignedData.(productNames{i})) & ~isnan(alignedData.(productNames{j}));
                fprintf('Overlap %s & %s: %d\n', productNames{i}, productNames{j}, sum(validIdx));
            else
                fprintf('Overlap %s & %s: Cannot compute (one or both products missing from alignedData)\n', productNames{i}, productNames{j});
            end
        end
    end
    
    fprintf(' → Built comprehensive correlation matrix (Python-like native sync) for %d products\n', nProducts);
end