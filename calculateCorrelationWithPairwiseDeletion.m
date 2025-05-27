function corrMatrix = calculateCorrelationWithPairwiseDeletion(alignedData, productNames, warningPrefix)
% Calculates correlation matrix with pairwise deletion for missing values
% Inputs:
%   alignedData: table with Timestamp and product columns
%   productNames: cell array of product names (columns in alignedData)
%   warningPrefix: (optional) string to prefix warning messages
% Output:
%   corrMatrix: nProducts x nProducts correlation matrix

    if nargin < 3
        warningPrefix = '';
    end

    nProducts = length(productNames);
    corrMatrix = eye(nProducts);
    for i = 1:nProducts
        for j = i+1:nProducts
            product1 = alignedData.(productNames{i});
            product2 = alignedData.(productNames{j});
            validPairs = ~isnan(product1) & ~isnan(product2);
            if sum(validPairs) >= 2
                corrMatrix(i, j) = corr(product1(validPairs), product2(validPairs));
                corrMatrix(j, i) = corrMatrix(i, j);
            else
                corrMatrix(i, j) = 0;
                corrMatrix(j, i) = 0;
                fprintf(' → %sWarning: Insufficient data for correlation between %s and %s\n', warningPrefix, productNames{i}, productNames{j});
            end
        end
    end
end 