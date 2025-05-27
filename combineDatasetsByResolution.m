function [combinedData, productNames] = combineDatasetsByResolution(datasets, datasetNames)
% Combines multiple datasets that share the same resolution
% Inputs:
%   datasets: struct of .data tables
%   datasetNames: cell array of dataset field names
% Outputs:
%   combinedData: table with Timestamp and all products
%   productNames: cell array of product names

    % Start with timestamps from first dataset
    firstDataset = datasets.(datasetNames{1}).data;
    combinedData = table();
    combinedData.Timestamp = firstDataset.Timestamp;
    % Collect all product names
    productNames = {};
    % Add each dataset's products to combined data
    for d = 1:length(datasetNames)
        datasetName = datasetNames{d};
        data = datasets.(datasetName).data;
        sourceFile = datasets.(datasetName).sourceFile;
        % Get product columns (excluding Timestamp)
        dataProductNames = setdiff(data.Properties.VariableNames, {'Timestamp'});
        % Add each product to combined data with timestamp alignment
        for p = 1:length(dataProductNames)
            productName = dataProductNames{p};
            % Use 'column (filename)' format for clarity
            labeledProductName = sprintf('%s (%s)', productName, sourceFile);
            productNames{end+1} = labeledProductName;
            % Align this product's data to combined timestamp
            alignedSeries = alignSeriesToTimeline(data.Timestamp, data.(productName), combinedData.Timestamp);
            combinedData.(labeledProductName) = alignedSeries;
        end
    end
end

function alignedSeries = alignSeriesToTimeline(sourceTimestamps, sourceValues, targetTimestamps)
% Aligns a time series to a target timeline
    alignedSeries = nan(size(targetTimestamps));
    for t = 1:length(targetTimestamps)
        targetTime = targetTimestamps(t);
        % Find exact match first
        exactMatch = find(sourceTimestamps == targetTime, 1);
        if ~isempty(exactMatch)
            alignedSeries(t) = sourceValues(exactMatch);
        else
            % Find closest timestamp within reasonable tolerance
            timeDiffs = abs(sourceTimestamps - targetTime);
            [minDiff, closestIdx] = min(timeDiffs);
            % Use closest match if within 1 minute tolerance
            if minDiff <= minutes(1)
                alignedSeries(t) = sourceValues(closestIdx);
            end
        end
    end
end 