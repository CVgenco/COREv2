function [enhancedData, preprocessStats] = enhancedDataPreprocessing(rawData, productNames, config)
%ENHANCEDDATAPREPROCESSING Comprehensive data preprocessing with robust outlier detection
%   [enhancedData, preprocessStats] = enhancedDataPreprocessing(rawData, productNames, config)
%   
%   Performs comprehensive data preprocessing including:
%   1. Robust outlier detection and removal
%   2. Enhanced missing data handling
%   3. Volatility explosion prevention
%   4. Data quality validation
%   5. Adaptive block size optimization for bootstrapping
%
%   Inputs:
%   - rawData: Table/timetable or struct with energy market data
%   - productNames: Cell array of product names to process
%   - config: Configuration struct with preprocessing options
%
%   Outputs:
%   - enhancedData: Preprocessed data with outliers removed
%   - preprocessStats: Detailed statistics about preprocessing

fprintf('=== Enhanced Data Preprocessing with Robust Outlier Detection ===\n');

% Initialize outputs
enhancedData = rawData;
preprocessStats = struct();
preprocessStats.totalProducts = length(productNames);
preprocessStats.processingTime = tic;

% Default configuration
if nargin < 3 || isempty(config)
    config = getDefaultPreprocessingConfig();
end

% Configure outlier detection options
outlierOptions = struct(...
    'enableIQR', config.outlierDetection.enableIQR, ...
    'enableModifiedZScore', config.outlierDetection.enableModifiedZScore, ...
    'enableEnergyThresholds', config.outlierDetection.enableEnergyThresholds, ...
    'iqrMultiplier', config.outlierDetection.iqrMultiplier, ...
    'modifiedZThreshold', config.outlierDetection.modifiedZThreshold, ...
    'replacementMethod', config.outlierDetection.replacementMethod, ...
    'verbose', config.outlierDetection.verbose);

% Initialize summary statistics
totalOutliers = 0;
processedProducts = 0;

%% Process each product
for i = 1:length(productNames)
    productName = productNames{i};
    
    try
        % Extract product data
        if istable(enhancedData) || istimetable(enhancedData)
            if ismember(productName, enhancedData.Properties.VariableNames)
                productData = enhancedData.(productName);
            else
                fprintf('  Warning: Product %s not found in data table\n', productName);
                continue;
            end
        elseif isstruct(enhancedData)
            if isfield(enhancedData, productName)
                productData = enhancedData.(productName);
            else
                fprintf('  Warning: Product %s not found in data struct\n', productName);
                continue;
            end
        else
            fprintf('  Error: Unsupported data format for %s\n', productName);
            continue;
        end
        
        fprintf('Processing %s (%d/%d)...\n', productName, i, length(productNames));
        
        % Record original statistics
        originalStats = struct();
        originalStats.length = length(productData);
        originalStats.missingCount = sum(isnan(productData));
        originalStats.missingPercentage = (originalStats.missingCount / originalStats.length) * 100;
        originalStats.range = [min(productData), max(productData)];
        originalStats.std = std(productData, 'omitnan');
        
        %% Step 1: Robust Outlier Detection
        [cleanedData, outlierStats] = robustOutlierDetection(productData, productName, outlierOptions);
        
        %% Step 2: Enhanced Missing Data Handling
        if config.missingDataHandling.enabled
            cleanedData = enhancedMissingDataFill(cleanedData, productName, config.missingDataHandling);
        end
        
        %% Step 3: Volatility Explosion Prevention
        if config.volatilityControl.enabled
            cleanedData = preventVolatilityExplosions(cleanedData, productName, config.volatilityControl);
        end
        
        %% Step 4: Data Quality Validation
        qualityStats = validateDataQuality(cleanedData, productName, config.qualityValidation);
        
        % Store cleaned data back
        if istable(enhancedData) || istimetable(enhancedData)
            enhancedData.(productName) = cleanedData;
        else
            enhancedData.(productName) = cleanedData;
        end
        
        % Record preprocessing statistics
        preprocessStats.(productName) = struct();
        preprocessStats.(productName).original = originalStats;
        preprocessStats.(productName).outliers = outlierStats;
        preprocessStats.(productName).quality = qualityStats;
        preprocessStats.(productName).finalLength = length(cleanedData);
        preprocessStats.(productName).improvementRatio = outlierStats.numOutliers / originalStats.length;
        
        % Update summary counters
        totalOutliers = totalOutliers + outlierStats.numOutliers;
        processedProducts = processedProducts + 1;
        
    catch ME
        fprintf('  Error processing %s: %s\n', productName, ME.message);
        preprocessStats.errors.(productName) = ME.message;
    end
end

%% Step 5: Optimize Block Size for Bootstrapping
if config.blockSizeOptimization.enabled
    optimalBlockSizes = optimizeBlockSizes(enhancedData, productNames, config.blockSizeOptimization);
    preprocessStats.optimalBlockSizes = optimalBlockSizes;
    
    % Update configuration with optimal block size
    if isfield(config, 'blockBootstrapping')
        % Use the median optimal block size across products
        medianBlockSize = median(structfun(@(x) x.optimal, optimalBlockSizes));
        recommendedBlockSize = round(medianBlockSize);
        
        fprintf('\n=== Block Size Optimization Results ===\n');
        fprintf('Current block size: %d\n', config.blockBootstrapping.blockSize);
        fprintf('Recommended block size: %d\n', recommendedBlockSize);
        
        if recommendedBlockSize ~= config.blockBootstrapping.blockSize
            fprintf('Consider updating block size to %d for better stability\n', recommendedBlockSize);
        end
        
        preprocessStats.blockSizeRecommendation = recommendedBlockSize;
    end
end

%% Final Summary
preprocessStats.processingTime = toc(preprocessStats.processingTime);
preprocessStats.summary = struct();
preprocessStats.summary.productsProcessed = processedProducts;
preprocessStats.summary.totalOutliers = totalOutliers;
preprocessStats.summary.averageOutliersPerProduct = totalOutliers / max(processedProducts, 1);
preprocessStats.summary.processingTimeSeconds = preprocessStats.processingTime;

fprintf('\n=== Preprocessing Summary ===\n');
fprintf('Products processed: %d/%d\n', processedProducts, length(productNames));
fprintf('Total outliers detected and replaced: %d\n', totalOutliers);
fprintf('Average outliers per product: %.1f\n', preprocessStats.summary.averageOutliersPerProduct);
fprintf('Processing time: %.2f seconds\n', preprocessStats.summary.processingTimeSeconds);

end

function config = getDefaultPreprocessingConfig()
%GETDEFAULTPREPROCESSINGCONFIG Get default configuration for preprocessing

config = struct();

% Outlier detection configuration
config.outlierDetection = struct();
config.outlierDetection.enableIQR = true;
config.outlierDetection.enableModifiedZScore = true;
config.outlierDetection.enableEnergyThresholds = true;
config.outlierDetection.iqrMultiplier = 2.5;
config.outlierDetection.modifiedZThreshold = 3.5;
config.outlierDetection.replacementMethod = 'interpolation';
config.outlierDetection.verbose = true;

% Missing data handling
config.missingDataHandling = struct();
config.missingDataHandling.enabled = true;
config.missingDataHandling.method = 'adaptive';
config.missingDataHandling.maxGapSize = 24;  % Maximum gap size to interpolate
config.missingDataHandling.verbose = true;

% Volatility control
config.volatilityControl = struct();
config.volatilityControl.enabled = true;
config.volatilityControl.maxVolatilityRatio = 50;  % Maximum allowed volatility ratio
config.volatilityControl.smoothingWindow = 12;    % Hours for volatility smoothing
config.volatilityControl.verbose = true;

% Data quality validation
config.qualityValidation = struct();
config.qualityValidation.enabled = true;
config.qualityValidation.maxMissingPercentage = 20;
config.qualityValidation.minDataPoints = 100;
config.qualityValidation.verbose = true;

% Block size optimization
config.blockSizeOptimization = struct();
config.blockSizeOptimization.enabled = true;
config.blockSizeOptimization.minBlockSize = 12;
config.blockSizeOptimization.maxBlockSize = 168;  % 1 week
config.blockSizeOptimization.evaluationMethod = 'stability';
config.blockSizeOptimization.verbose = true;

end

function cleanedData = enhancedMissingDataFill(data, productName, options)
%ENHANCEDMISSINGDATAFILL Enhanced missing data handling

cleanedData = data;
missingIndices = find(isnan(data));

if isempty(missingIndices)
    if options.verbose
        fprintf('    %s: No missing data to fill\n', productName);
    end
    return;
end

originalMissingCount = length(missingIndices);

% Find gaps in missing data
gapStarts = [missingIndices(1)];
gapEnds = [];
for i = 2:length(missingIndices)
    if missingIndices(i) > missingIndices(i-1) + 1
        gapEnds = [gapEnds, missingIndices(i-1)];
        gapStarts = [gapStarts, missingIndices(i)];
    end
end
gapEnds = [gapEnds, missingIndices(end)];

% Process each gap
for g = 1:length(gapStarts)
    gapSize = gapEnds(g) - gapStarts(g) + 1;
    
    if gapSize <= options.maxGapSize
        % Interpolate small gaps
        validIdx = ~isnan(cleanedData);
        if sum(validIdx) >= 2
            cleanedData(gapStarts(g):gapEnds(g)) = interp1(...
                find(validIdx), cleanedData(validIdx), ...
                gapStarts(g):gapEnds(g), 'linear', 'extrap');
        end
    else
        % For large gaps, use forward/backward fill
        cleanedData(gapStarts(g):gapEnds(g)) = fillLargeGap(cleanedData, gapStarts(g), gapEnds(g));
    end
end

finalMissingCount = sum(isnan(cleanedData));
if options.verbose && originalMissingCount > 0
    fprintf('    %s: Filled %d/%d missing values (%.1f%% success)\n', ...
        productName, originalMissingCount - finalMissingCount, originalMissingCount, ...
        ((originalMissingCount - finalMissingCount) / originalMissingCount) * 100);
end

end

function filledData = fillLargeGap(data, startIdx, endIdx)
%FILLLARGGEGAP Fill large gaps using forward/backward fill

filledData = data(startIdx:endIdx);

% Try forward fill first
if startIdx > 1 && ~isnan(data(startIdx - 1))
    filledData(:) = data(startIdx - 1);
% Try backward fill
elseif endIdx < length(data) && ~isnan(data(endIdx + 1))
    filledData(:) = data(endIdx + 1);
% Use median as last resort
else
    validData = data(~isnan(data));
    if ~isempty(validData)
        filledData(:) = median(validData);
    end
end

end

function cleanedData = preventVolatilityExplosions(data, productName, options)
%PREVENTVOLATILITYEXPLOSIONS Prevent extreme volatility that causes simulation failures

cleanedData = data;

% Calculate rolling volatility
windowSize = min(options.smoothingWindow, floor(length(data) / 4));
if windowSize < 3
    if options.verbose
        fprintf('    %s: Insufficient data for volatility control\n', productName);
    end
    return;
end

% Calculate rolling standard deviation
rollingVol = movstd(cleanedData, windowSize, 'omitnan');
medianVol = median(rollingVol, 'omitnan');

if medianVol == 0 || isnan(medianVol)
    if options.verbose
        fprintf('    %s: Cannot calculate volatility (median = 0)\n', productName);
    end
    return;
end

% Identify extreme volatility periods
extremeVolMask = rollingVol > options.maxVolatilityRatio * medianVol;
extremeIndices = find(extremeVolMask);

if ~isempty(extremeIndices)
    % Smooth extreme volatility periods
    for idx = extremeIndices'
        windowStart = max(1, idx - windowSize);
        windowEnd = min(length(cleanedData), idx + windowSize);
        
        % Replace with smoothed value
        windowData = cleanedData(windowStart:windowEnd);
        cleanedData(idx) = median(windowData, 'omitnan');
    end
    
    if options.verbose
        fprintf('    %s: Smoothed %d extreme volatility points (ratio > %.1f)\n', ...
            productName, length(extremeIndices), options.maxVolatilityRatio);
    end
end

end

function qualityStats = validateDataQuality(data, productName, options)
%VALIDATEDATAQUALITY Validate data quality after preprocessing

qualityStats = struct();
qualityStats.length = length(data);
qualityStats.missingCount = sum(isnan(data));
qualityStats.missingPercentage = (qualityStats.missingCount / qualityStats.length) * 100;
qualityStats.isValid = true;
qualityStats.warnings = {};

% Check minimum data points
if qualityStats.length < options.minDataPoints
    qualityStats.isValid = false;
    qualityStats.warnings{end+1} = sprintf('Insufficient data points: %d < %d', ...
        qualityStats.length, options.minDataPoints);
end

% Check missing data percentage
if qualityStats.missingPercentage > options.maxMissingPercentage
    qualityStats.isValid = false;
    qualityStats.warnings{end+1} = sprintf('Too much missing data: %.1f%% > %.1f%%', ...
        qualityStats.missingPercentage, options.maxMissingPercentage);
end

if options.verbose
    if qualityStats.isValid
        fprintf('    %s: Data quality validation passed\n', productName);
    else
        fprintf('    %s: Data quality issues found:\n', productName);
        for w = 1:length(qualityStats.warnings)
            fprintf('      - %s\n', qualityStats.warnings{w});
        end
    end
end

end

function optimalBlockSizes = optimizeBlockSizes(data, productNames, options)
%OPTIMIZEBLOCKSIZES Find optimal block sizes for each product

optimalBlockSizes = struct();

for i = 1:length(productNames)
    productName = productNames{i};
    
    % Extract product data
    if istable(data) || istimetable(data)
        if ismember(productName, data.Properties.VariableNames)
            productData = data.(productName);
        else
            continue;
        end
    else
        if isfield(data, productName)
            productData = data.(productName);
        else
            continue;
        end
    end
    
    % Remove NaN values for analysis
    validData = productData(~isnan(productData));
    
    if length(validData) < options.minBlockSize * 3
        optimalBlockSizes.(productName) = struct('optimal', options.minBlockSize, 'scores', []);
        continue;
    end
    
    % Test different block sizes
    blockSizes = options.minBlockSize:6:min(options.maxBlockSize, floor(length(validData)/3));
    scores = zeros(size(blockSizes));
    
    for b = 1:length(blockSizes)
        blockSize = blockSizes(b);
        scores(b) = evaluateBlockSize(validData, blockSize, options.evaluationMethod);
    end
    
    % Find optimal block size (minimize score for stability)
    [~, optimalIdx] = min(scores);
    optimalBlockSize = blockSizes(optimalIdx);
    
    optimalBlockSizes.(productName) = struct(...
        'optimal', optimalBlockSize, ...
        'scores', scores, ...
        'blockSizes', blockSizes);
    
    if options.verbose
        fprintf('    %s: Optimal block size = %d\n', productName, optimalBlockSize);
    end
end

end

function score = evaluateBlockSize(data, blockSize, method)
%EVALUATEBLOCKSIZE Evaluate block size based on stability criterion

switch lower(method)
    case 'stability'
        % Evaluate based on block variance stability
        nBlocks = floor(length(data) / blockSize);
        if nBlocks < 3
            score = Inf;
            return;
        end
        
        blockVars = zeros(nBlocks, 1);
        for b = 1:nBlocks
            blockStart = (b-1) * blockSize + 1;
            blockEnd = b * blockSize;
            blockData = data(blockStart:blockEnd);
            blockVars(b) = var(blockData, 'omitnan');
        end
        
        % Score is coefficient of variation of block variances
        score = std(blockVars, 'omitnan') / mean(blockVars, 'omitnan');
        
    otherwise
        error('Unknown evaluation method: %s', method);
end

end
