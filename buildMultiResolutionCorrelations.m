function multiResCorrelations = buildMultiResolutionCorrelations(historicalNodalData, historicalHubData, historicalGenData, historicalAncillaryData, hasGenData, hasAncillaryData, productNames, displayNames)
% Builds separate correlation matrices for each native resolution (Phase 2C)
% Inputs:
%   historicalNodalData, historicalHubData, historicalGenData, historicalAncillaryData: tables/structs
%   hasGenData, hasAncillaryData: logical flags
%   productNames: cell array of short, valid MATLAB variable names
%   displayNames: cell array of descriptive names for each product
% Output:
%   multiResCorrelations: struct with fields for each resolution

    fprintf('\nPhase 2C: Building multi-resolution correlation matrices...\n');
    multiResCorrelations = struct();
    multiResCorrelations.resolutions = {};
    multiResCorrelations.correlationMatrices = struct();
    multiResCorrelations.productNames = productNames;
    multiResCorrelations.displayNames = displayNames;
    multiResCorrelations.dataQuality = struct();

    % Collect all datasets with their native resolutions
    datasets = struct();
    [~, nodalRes] = parseVariableResolutionData(temporaryFilePath(historicalNodalData));
    datasets.nodal.data = historicalNodalData;
    datasets.nodal.resolution = nodalRes;
    datasets.nodal.priority = 1.0;
    if ~isempty(historicalHubData)
        [~, hubRes] = parseVariableResolutionData(temporaryFilePath(historicalHubData));
        datasets.hub.data = historicalHubData;
        datasets.hub.resolution = hubRes;
        datasets.hub.priority = 0.9;
    end
    if hasGenData && ~isempty(historicalGenData)
        [~, genRes] = parseVariableResolutionData(temporaryFilePath(historicalGenData));
        datasets.gen.data = historicalGenData;
        datasets.gen.resolution = genRes;
        datasets.gen.priority = 0.8;
    end
    if hasAncillaryData
        ancTypes = fieldnames(historicalAncillaryData);
        for a = 1:length(ancTypes)
            ancType = ancTypes{a};
            if ~isempty(historicalAncillaryData.(ancType))
                [~, ancRes] = parseVariableResolutionData(temporaryFilePath(historicalAncillaryData.(ancType)));
                datasets.(ancType).data = historicalAncillaryData.(ancType);
                datasets.(ancType).resolution = ancRes;
                datasets.(ancType).priority = 0.7;
            end
        end
    end
    % Identify unique resolutions
    datasetNames = fieldnames(datasets);
    resolutions = {};
    for d = 1:length(datasetNames)
        res = datasets.(datasetNames{d}).resolution;
        if ~ismember(res, resolutions)
            resolutions{end+1} = res;
        end
    end
    fprintf(' → Found %d unique resolutions: %s\n', length(resolutions), strjoin(resolutions, ', '));
    multiResCorrelations.resolutions = resolutions;
    % Build correlation matrix for each resolution
    for r = 1:length(resolutions)
        resolution = resolutions{r};
        fprintf(' → Building correlation matrix for %s resolution\n', resolution);
        % Collect datasets for this resolution
        resolutionDatasets = {};
        for d = 1:length(datasetNames)
            if strcmp(datasets.(datasetNames{d}).resolution, resolution)
                resolutionDatasets{end+1} = datasetNames{d};
            end
        end
        if isempty(resolutionDatasets)
            fprintf('   → No datasets found for %s resolution, skipping\n', resolution);
            continue;
        end
        % Combine datasets for this resolution, aligning to a master timeline
        combinedData = datasets.(resolutionDatasets{1}).data;
        for d = 2:length(resolutionDatasets)
            nextData = datasets.(resolutionDatasets{d}).data;
            % Align to master timeline using outerjoin
            combinedData = outerjoin(combinedData, nextData, 'Keys', 'Timestamp', 'MergeKeys', true, 'Type', 'left');
        end
        % Remove duplicate Timestamp columns if any
        if sum(strcmp(combinedData.Properties.VariableNames, 'Timestamp')) > 1
            combinedData = removevars(combinedData, find(strcmp(combinedData.Properties.VariableNames, 'Timestamp'), 2));
        end
        % Ensure all productNames are present, fill missing with NaN
        for i = 1:length(productNames)
            if ~ismember(productNames{i}, combinedData.Properties.VariableNames)
                combinedData.(productNames{i}) = nan(height(combinedData), 1);
            end
        end
        % Calculate correlation matrix
        if height(combinedData) > 10 && length(productNames) > 1
            dataMatrix = [];
            for i = 1:length(productNames)
                dataMatrix = [dataMatrix, combinedData.(productNames{i})];
            end
            correlationMatrix = corr(dataMatrix, 'rows', 'pairwise');
            multiResCorrelations.correlationMatrices.(resolution) = correlationMatrix;
            % Data quality metrics
            qualityMetrics = struct();
            for i = 1:length(productNames)
                qualityMetrics.(productNames{i}) = sum(~isnan(combinedData.(productNames{i}))) / height(combinedData);
            end
            multiResCorrelations.dataQuality.(resolution) = qualityMetrics;
            offDiagCorr = correlationMatrix(triu(true(size(correlationMatrix)), 1));
            avgCorr = mean(offDiagCorr);
            fprintf('   → %s: %d observations, %d products, avg correlation = %.4f\n', resolution, height(combinedData), length(productNames), avgCorr);
        else
            fprintf('   → Warning: Insufficient data for %s resolution (%d obs, %d products)\n', resolution, height(combinedData), length(productNames));
            multiResCorrelations.correlationMatrices.(resolution) = [];
        end
    end
    fprintf(' → Built %d resolution-specific correlation matrices\n', length(fieldnames(multiResCorrelations.correlationMatrices)));
end

function filePath = temporaryFilePath(data)
    % Helper to create a temp file for parseVariableResolutionData
    filePath = 'temp_data_for_resolution_detection.csv';
    writetable(data, filePath);
end 