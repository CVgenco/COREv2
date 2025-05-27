function regimeCorrelations = buildRegimeDependentCorrelations(nodalData, hubData, genData, ancillaryData, hasGenData, hasAncillaryData, productNames, displayNames, regimeStates, nRegimes)
% Builds regime-dependent correlation matrices using regime labels
% Inputs:
%   nodalData, hubData, genData, ancillaryData: tables/structs with Timestamp and product columns
%   hasGenData, hasAncillaryData: logical flags
%   productNames: cell array of short, valid MATLAB variable names
%   displayNames: cell array of descriptive names for each product (for printing)
%   regimeStates: vector of regime labels for each row
%   nRegimes: number of regimes
% Output:
%   regimeCorrelations: struct of regime-specific correlation matrices

    % Align all datasets to a common timeline
    alignedData = alignToHourly(nodalData, hubData, genData, ancillaryData, hasGenData, hasAncillaryData);
    nProducts = length(productNames);
    regimeCorrelations = struct();
    for r = 1:nRegimes
        regimeIdx = (regimeStates == r);
        if sum(regimeIdx) < 50
            fprintf('   → Warning: Only %d observations for regime %d, using overall correlation\n', sum(regimeIdx), r);
            regimeCorrelations.(sprintf('regime_%d', r)) = eye(nProducts);
            continue;
        end
        regimeData = alignedData(regimeIdx, :);
        windowCorr = calculateCorrelationWithPairwiseDeletion(regimeData, productNames, '[Regime] ');
        regimeCorrelations.(sprintf('regime_%d', r)) = windowCorr;
        fprintf('   → Regime %d: %d observations\n', r, sum(regimeIdx));
        for i = 1:nProducts
            fprintf('      %2d: %s\n', i, displayNames{i});
        end
    end
end 