function timeVaryingCorrelations = buildTimeVaryingCorrelations(alignedData, productNames, windowSize, displayNames, varargin)
% Builds time-varying correlation matrices using dynamic rolling windows and product inclusion
% Inputs:
%   alignedData: table with Timestamp and product columns (short names)
%   productNames: cell array of short, valid MATLAB variable names
%   windowSize: integer, rolling window size (default: dynamically selected)
%   displayNames: cell array of descriptive names for each product (for printing)
%   varargin: optional, 'minOverlap', 'consistencyMode'
% Output:
%   timeVaryingCorrelations: struct with fields:
%       - timestamps
%       - windowSize
%       - correlationTimeSeries (cell array)
%       - includedProducts (cell array)
%       - windowStartIdx, windowEndIdx
%       - displayNames
%       - config

    % === Configurable parameters ===
    p = inputParser;
    addParameter(p, 'minOverlap', 10);
    addParameter(p, 'consistencyMode', 'flexible'); % 'flexible' or 'strict'
    parse(p, varargin{:});
    minOverlap = p.Results.minOverlap;
    consistencyMode = p.Results.consistencyMode;

    fprintf('\n[Dynamic] Building time-varying correlation matrices...\n');
    nObservations = height(alignedData);
    nProducts = length(productNames);
    if nargin < 4 || isempty(displayNames)
        displayNames = productNames;
    end

    % === Step 1: Dynamically select window size ===
    maxWindow = nObservations;
    bestWindow = 0;
    if nargin < 3 || isempty(windowSize)
        % Try window sizes from large to small
        for w = min(168, maxWindow):-1:10
            valid = true;
            for t = w:nObservations
                windowStart = t - w + 1;
                windowEnd = t;
                for p = 1:nProducts
                    vals = alignedData.(productNames{p})(windowStart:windowEnd);
                    if sum(~isnan(vals)) < minOverlap
                        valid = false;
                        break;
                    end
                end
                if ~valid, break; end
            end
            if valid
                bestWindow = w;
                break;
            end
        end
        if bestWindow == 0
            bestWindow = 10; % fallback
            fprintf('[Dynamic] No window size found for all products. Using fallback window size: %d\n', bestWindow);
        else
            fprintf('[Dynamic] Selected window size: %d\n', bestWindow);
        end
        windowSize = bestWindow;
    else
        fprintf('[Dynamic] Using provided window size: %d\n', windowSize);
    end

    % === Step 2: Rolling window with dynamic product inclusion ===
    correlationTimeSeries = cell(nObservations, 1);
    includedProducts = cell(nObservations, 1);
    windowStartIdx = zeros(nObservations, 1);
    windowEndIdx = zeros(nObservations, 1);
    for t = windowSize:nObservations
        windowStart = t - windowSize + 1;
        windowEnd = t;
        windowStartIdx(t) = windowStart;
        windowEndIdx(t) = windowEnd;
        windowData = table();
        windowData.Timestamp = alignedData.Timestamp(windowStart:windowEnd);
        presentProducts = {};
        for p = 1:nProducts
            vals = alignedData.(productNames{p})(windowStart:windowEnd);
            if sum(~isnan(vals)) >= minOverlap
                windowData.(productNames{p}) = vals;
                presentProducts{end+1} = productNames{p}; %#ok<AGROW>
            end
        end
        includedProducts{t} = presentProducts;
        if strcmp(consistencyMode, 'strict') && length(presentProducts) < nProducts
            correlationTimeSeries{t} = nan(nProducts, nProducts);
        elseif length(presentProducts) >= 2
            windowCorr = calculateCorrelationWithPairwiseDeletion(windowData, presentProducts, '[TimeVarying] ');
            correlationTimeSeries{t} = windowCorr;
        else
            correlationTimeSeries{t} = nan(length(presentProducts));
        end
        if mod(t, 1000) == 0
            fprintf('   → Processed %d of %d time points (%.1f%%)\n', t, nObservations, t/nObservations*100);
        end
    end
    % Early points (expanding window)
    for t = 1:(windowSize-1)
        windowStartIdx(t) = 1;
        windowEndIdx(t) = t;
        windowData = table();
        windowData.Timestamp = alignedData.Timestamp(1:t);
        presentProducts = {};
        for p = 1:nProducts
            vals = alignedData.(productNames{p})(1:t);
            if sum(~isnan(vals)) >= minOverlap
                windowData.(productNames{p}) = vals;
                presentProducts{end+1} = productNames{p}; %#ok<AGROW>
            end
        end
        includedProducts{t} = presentProducts;
        if strcmp(consistencyMode, 'strict') && length(presentProducts) < nProducts
            correlationTimeSeries{t} = nan(nProducts, nProducts);
        elseif length(presentProducts) >= 2
            windowCorr = calculateCorrelationWithPairwiseDeletion(windowData, presentProducts, '[TimeVarying] ');
            correlationTimeSeries{t} = windowCorr;
        else
            correlationTimeSeries{t} = nan(length(presentProducts));
        end
    end

    % === Step 3: Save results in robust structure ===
    timeVaryingCorrelations = struct();
    timeVaryingCorrelations.timestamps = alignedData.Timestamp;
    timeVaryingCorrelations.windowSize = windowSize;
    timeVaryingCorrelations.correlationTimeSeries = correlationTimeSeries;
    timeVaryingCorrelations.includedProducts = includedProducts;
    timeVaryingCorrelations.windowStartIdx = windowStartIdx;
    timeVaryingCorrelations.windowEndIdx = windowEndIdx;
    timeVaryingCorrelations.displayNames = displayNames;
    timeVaryingCorrelations.config = struct('minOverlap', minOverlap, 'consistencyMode', consistencyMode);

    fprintf('[Dynamic] Built time-varying correlations for %d time points\n', nObservations);
end 