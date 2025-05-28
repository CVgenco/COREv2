function [cleanedData, outlierStats] = robustOutlierDetection(data, productName, options)
%ROBUSTOUTLIERDETECTION Comprehensive robust outlier detection for energy market data
%   [cleanedData, outlierStats] = robustOutlierDetection(data, productName, options)
%   
%   Applies multiple robust outlier detection methods:
%   1. IQR-based detection (more conservative than 5-sigma)
%   2. Modified Z-score using median (robust to outliers)
%   3. Energy market specific thresholds for different products
%   4. Interpolation-based outlier replacement
%
%   Inputs:
%   - data: Vector of price/return data
%   - productName: String identifying the energy product
%   - options: Optional struct with detection parameters
%
%   Outputs:
%   - cleanedData: Data with outliers replaced
%   - outlierStats: Statistics about outliers detected and removed

% Set default options
if nargin < 3 || isempty(options)
    options = struct();
end

% Default parameters for robust detection
defaults = struct(...
    'enableIQR', true, ...
    'enableModifiedZScore', true, ...
    'enableEnergyThresholds', true, ...
    'iqrMultiplier', 2.5, ...      % More conservative than 3-sigma
    'modifiedZThreshold', 3.5, ...  % Conservative modified Z-score
    'replacementMethod', 'interpolation', ... % 'interpolation', 'median', 'cap'
    'verbose', true);

% Merge with user options
fn = fieldnames(defaults);
for i = 1:length(fn)
    if ~isfield(options, fn{i})
        options.(fn{i}) = defaults.(fn{i});
    end
end

% Initialize outputs
cleanedData = data(:);
outlierStats = struct();
outlierStats.originalLength = length(data);
outlierStats.outlierIndices = [];
outlierStats.outlierValues = [];
outlierStats.detectionMethods = {};
outlierStats.replacementMethod = options.replacementMethod;

% Skip if data is empty or all NaN
if isempty(cleanedData) || all(isnan(cleanedData))
    if options.verbose
        fprintf('  %s: No valid data for outlier detection\n', productName);
    end
    return;
end

% Remove NaN values for detection (will be handled separately)
validIdx = ~isnan(cleanedData);
validData = cleanedData(validIdx);

if length(validData) < 10
    if options.verbose
        fprintf('  %s: Insufficient valid data for outlier detection (n=%d)\n', productName, length(validData));
    end
    return;
end

% Get energy market thresholds
thresholds = getEnergyMarketThresholds(productName);

%% Method 1: Energy Market Specific Thresholds
outlierMask = false(size(validData));
if options.enableEnergyThresholds && ~isempty(thresholds)
    energyOutliers = validData < thresholds.min | validData > thresholds.max;
    outlierMask = outlierMask | energyOutliers;
    
    if any(energyOutliers)
        outlierStats.detectionMethods{end+1} = sprintf('EnergyThresholds(%.0f,%.0f)', thresholds.min, thresholds.max);
        if options.verbose
            fprintf('  %s: %d outliers detected by energy thresholds\n', productName, sum(energyOutliers));
        end
    end
end

%% Method 2: IQR-based Detection
if options.enableIQR
    Q1 = prctile(validData, 25);
    Q3 = prctile(validData, 75);
    IQR = Q3 - Q1;
    
    if IQR > 0  % Avoid division by zero
        lowerBound = Q1 - options.iqrMultiplier * IQR;
        upperBound = Q3 + options.iqrMultiplier * IQR;
        
        iqrOutliers = validData < lowerBound | validData > upperBound;
        outlierMask = outlierMask | iqrOutliers;
        
        if any(iqrOutliers)
            outlierStats.detectionMethods{end+1} = sprintf('IQR(%.1f)', options.iqrMultiplier);
            if options.verbose
                fprintf('  %s: %d outliers detected by IQR method (bounds: %.2f, %.2f)\n', ...
                    productName, sum(iqrOutliers), lowerBound, upperBound);
            end
        end
    end
end

%% Method 3: Modified Z-Score (using median)
if options.enableModifiedZScore
    medianVal = median(validData);
    MAD = median(abs(validData - medianVal));  % Median Absolute Deviation
    
    if MAD > 0  % Avoid division by zero
        modifiedZScore = 0.6745 * (validData - medianVal) / MAD;
        
        zOutliers = abs(modifiedZScore) > options.modifiedZThreshold;
        outlierMask = outlierMask | zOutliers;
        
        if any(zOutliers)
            outlierStats.detectionMethods{end+1} = sprintf('ModifiedZ(%.1f)', options.modifiedZThreshold);
            if options.verbose
                fprintf('  %s: %d outliers detected by modified Z-score\n', productName, sum(zOutliers));
            end
        end
    end
end

%% Record outlier statistics
outlierIndicesInValid = find(outlierMask);
if ~isempty(outlierIndicesInValid)
    % Map back to original indices
    validIndices = find(validIdx);
    outlierStats.outlierIndices = validIndices(outlierIndicesInValid);
    outlierStats.outlierValues = cleanedData(outlierStats.outlierIndices);
    outlierStats.numOutliers = length(outlierStats.outlierIndices);
    outlierStats.outlierPercentage = (outlierStats.numOutliers / outlierStats.originalLength) * 100;
    
    %% Replace outliers
    cleanedData = replaceOutliers(cleanedData, outlierStats.outlierIndices, options.replacementMethod);
    
    if options.verbose
        fprintf('  %s: Total %d outliers (%.2f%%) detected and replaced using %s\n', ...
            productName, outlierStats.numOutliers, outlierStats.outlierPercentage, options.replacementMethod);
    end
else
    outlierStats.numOutliers = 0;
    outlierStats.outlierPercentage = 0;
    
    if options.verbose
        fprintf('  %s: No outliers detected\n', productName);
    end
end

% Summary statistics
outlierStats.dataRange = [min(cleanedData), max(cleanedData)];
outlierStats.dataStats = struct(...
    'mean', mean(cleanedData, 'omitnan'), ...
    'median', median(cleanedData, 'omitnan'), ...
    'std', std(cleanedData, 'omitnan'), ...
    'skewness', skewness(cleanedData), ...
    'kurtosis', kurtosis(cleanedData));

end

function thresholds = getEnergyMarketThresholds(productName)
%GETENERGYMARKETTHRESHOLDS Get realistic price bounds for energy market products
%   Returns min/max thresholds based on energy market knowledge

thresholds = struct('min', [], 'max', []);

% Convert to lowercase for comparison
productLower = lower(productName);

% Energy market specific thresholds based on typical market conditions
if contains(productLower, {'hub', 'nodal', 'price'})
    % Hub and nodal prices: typically -$1000 to $3000/MWh
    thresholds.min = -1000;
    thresholds.max = 3000;
    
elseif contains(productLower, {'regup', 'regdown'})
    % Regulation up/down: typically $0 to $500/MW
    thresholds.min = 0;
    thresholds.max = 500;
    
elseif contains(productLower, 'nonspin')
    % Non-spinning reserves: typically $0 to $200/MW
    thresholds.min = 0;
    thresholds.max = 200;
    
elseif contains(productLower, 'generation')
    % Generation data: depends on context, use conservative bounds
    thresholds.min = -1000;  % Allow for negative net generation
    thresholds.max = 5000;   % High generation capacity
    
elseif contains(productLower, {'forecast', 'load'})
    % Forecasts and load: typically non-negative with high upper bound
    thresholds.min = -500;   % Allow some negative values for forecast errors
    thresholds.max = 10000;  % High load values
    
else
    % Generic energy market data
    thresholds.min = -2000;
    thresholds.max = 5000;
end

end

function cleanedData = replaceOutliers(data, outlierIndices, method)
%REPLACEOUTLIERS Replace outliers using specified method

cleanedData = data;

if isempty(outlierIndices)
    return;
end

switch lower(method)
    case 'interpolation'
        % Use linear interpolation to replace outliers
        validIdx = true(size(data));
        validIdx(outlierIndices) = false;
        validIdx = validIdx & ~isnan(data);
        
        if sum(validIdx) >= 2
            % Interpolate only if we have at least 2 valid points
            cleanedData(outlierIndices) = interp1(...
                find(validIdx), data(validIdx), outlierIndices, 'linear', 'extrap');
        else
            % Fall back to median if insufficient valid data
            cleanedData(outlierIndices) = median(data, 'omitnan');
        end
        
    case 'median'
        % Replace with median of non-outlier values
        validData = data;
        validData(outlierIndices) = [];
        medianVal = median(validData, 'omitnan');
        cleanedData(outlierIndices) = medianVal;
        
    case 'cap'
        % Cap at reasonable percentiles
        lowerCap = prctile(data, 5);
        upperCap = prctile(data, 95);
        cleanedData(data < lowerCap) = lowerCap;
        cleanedData(data > upperCap) = upperCap;
        
    case 'winsorize'
        % Winsorize at 5th and 95th percentiles
        lowerBound = prctile(data, 5);
        upperBound = prctile(data, 95);
        cleanedData = max(min(data, upperBound), lowerBound);
        
    otherwise
        error('Unknown replacement method: %s', method);
end

end
