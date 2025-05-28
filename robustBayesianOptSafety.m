function [safeConfig, safetyStats] = robustBayesianOptSafety(config, inputData, productNames)
%ROBUSTBAYESIANOPTSAFETY Multi-layer safety checks for robust Bayesian optimization
%   [safeConfig, safetyStats] = robustBayesianOptSafety(config, inputData, productNames)
%   
%   Implements comprehensive safety mechanisms:
%   1. Parameter bounds validation and adjustment
%   2. Data integrity checks before optimization
%   3. Simulation stability validation
%   4. Adaptive safety limits based on data characteristics
%   5. Early warning system for parameter combinations
%
%   Inputs:
%   - config: Original configuration structure
%   - inputData: Input data for validation
%   - productNames: Cell array of product names
%
%   Outputs:
%   - safeConfig: Safety-validated configuration
%   - safetyStats: Detailed safety analysis and recommendations

fprintf('=== Robust Bayesian Optimization Safety Validation ===\n');

% Initialize outputs
safeConfig = config;
safetyStats = struct();
safetyStats.validationTime = tic;
safetyStats.warnings = {};
safetyStats.adjustments = {};
safetyStats.isSafe = true;

%% Step 1: Validate and Adjust Parameter Bounds
fprintf('Validating parameter bounds...\n');
[safeConfig, boundsStats] = validateParameterBounds(safeConfig, inputData, productNames);
safetyStats.parameterBounds = boundsStats;

%% Step 2: Data Integrity Validation
fprintf('Validating data integrity...\n');
[dataIntegrityStats] = validateDataIntegrity(inputData, productNames);
safetyStats.dataIntegrity = dataIntegrityStats;

if ~dataIntegrityStats.isValid
    safetyStats.isSafe = false;
    safetyStats.warnings{end+1} = 'Data integrity validation failed';
end

%% Step 3: Block Size Safety Validation
fprintf('Validating block size safety...\n');
[safeConfig, blockSizeStats] = validateBlockSizeSafety(safeConfig, inputData, productNames);
safetyStats.blockSize = blockSizeStats;

%% Step 4: Volatility Explosion Prevention
fprintf('Configuring volatility explosion prevention...\n');
[safeConfig, volatilityStats] = configureVolatilityPrevention(safeConfig, inputData, productNames);
safetyStats.volatilityPrevention = volatilityStats;

%% Step 5: Jump Detection and Modeling Safety
fprintf('Validating jump modeling safety...\n');
[safeConfig, jumpStats] = validateJumpModelingSafety(safeConfig, inputData, productNames);
safetyStats.jumpModeling = jumpStats;

%% Step 6: Regime Switching Safety
fprintf('Validating regime switching safety...\n');
[safeConfig, regimeStats] = validateRegimeSwitchingSafety(safeConfig);
safetyStats.regimeSwitching = regimeStats;

%% Step 7: Generate Safety Report
safetyStats.validationTime = toc(safetyStats.validationTime);
generateSafetyReport(safetyStats);

% Final safety assessment
if ~safetyStats.isSafe
    error('Safety validation failed. Please review warnings and adjust configuration.');
end

fprintf('Safety validation completed successfully (%.2f seconds)\n', safetyStats.validationTime);

end

function [safeConfig, boundsStats] = validateParameterBounds(config, inputData, productNames)
%VALIDATEPARAMETERBOUNDS Validate and adjust parameter bounds for safety

safeConfig = config;
boundsStats = struct();
boundsStats.adjustments = 0;
boundsStats.warnings = {};

% Calculate data characteristics for adaptive bounds
dataStats = calculateDataCharacteristics(inputData, productNames);

%% Block Size Bounds
if isfield(safeConfig, 'blockBootstrapping') && isfield(safeConfig.blockBootstrapping, 'blockSize')
    originalBlockSize = safeConfig.blockBootstrapping.blockSize;
    
    % Calculate safe block size range based on data
    dataLength = dataStats.minDataLength;
    maxSafeBlockSize = floor(dataLength / 10);  % At least 10 blocks
    minSafeBlockSize = max(6, ceil(sqrt(dataLength / 100)));  % Minimum 6, scale with data
    
    % Adjust if necessary
    if originalBlockSize > maxSafeBlockSize
        safeConfig.blockBootstrapping.blockSize = maxSafeBlockSize;
        boundsStats.adjustments = boundsStats.adjustments + 1;
        boundsStats.warnings{end+1} = sprintf('Block size reduced from %d to %d for safety', ...
            originalBlockSize, maxSafeBlockSize);
    elseif originalBlockSize < minSafeBlockSize
        safeConfig.blockBootstrapping.blockSize = minSafeBlockSize;
        boundsStats.adjustments = boundsStats.adjustments + 1;
        boundsStats.warnings{end+1} = sprintf('Block size increased from %d to %d for stability', ...
            originalBlockSize, minSafeBlockSize);
    end
    
    boundsStats.blockSize = struct(...
        'original', originalBlockSize, ...
        'safe', safeConfig.blockBootstrapping.blockSize, ...
        'minSafe', minSafeBlockSize, ...
        'maxSafe', maxSafeBlockSize);
end

%% Regime Volatility Amplification Bounds
if isfield(safeConfig, 'regimeVolatilityModulation') && ...
   isfield(safeConfig.regimeVolatilityModulation, 'amplificationFactor')
    
    originalAmpFactor = safeConfig.regimeVolatilityModulation.amplificationFactor;
    
    % Adaptive bounds based on data volatility
    avgVolatility = dataStats.averageVolatility;
    if avgVolatility > 0.5  % High volatility data
        maxSafeAmp = 1.5;
        minSafeAmp = 0.3;
    else  % Normal volatility data
        maxSafeAmp = 2.0;
        minSafeAmp = 0.2;
    end
    
    % Adjust if necessary
    if originalAmpFactor > maxSafeAmp
        safeConfig.regimeVolatilityModulation.amplificationFactor = maxSafeAmp;
        boundsStats.adjustments = boundsStats.adjustments + 1;
        boundsStats.warnings{end+1} = sprintf('Regime amplification reduced from %.3f to %.3f for stability', ...
            originalAmpFactor, maxSafeAmp);
    elseif originalAmpFactor < minSafeAmp
        safeConfig.regimeVolatilityModulation.amplificationFactor = minSafeAmp;
        boundsStats.adjustments = boundsStats.adjustments + 1;
        boundsStats.warnings{end+1} = sprintf('Regime amplification increased from %.3f to %.3f for validity', ...
            originalAmpFactor, minSafeAmp);
    end
    
    boundsStats.regimeAmplification = struct(...
        'original', originalAmpFactor, ...
        'safe', safeConfig.regimeVolatilityModulation.amplificationFactor, ...
        'minSafe', minSafeAmp, ...
        'maxSafe', maxSafeAmp);
end

%% Jump Threshold Bounds
if isfield(safeConfig, 'jumpModeling') && isfield(safeConfig.jumpModeling, 'threshold')
    originalThreshold = safeConfig.jumpModeling.threshold;
    
    % Calculate safe threshold based on data characteristics
    dataRange = dataStats.averageRange;
    avgStd = dataStats.averageStd;
    
    minSafeThreshold = 0.1 * avgStd;  % At least 10% of standard deviation
    maxSafeThreshold = 0.5 * dataRange;  % At most 50% of data range
    
    % Adjust if necessary
    if originalThreshold > maxSafeThreshold
        safeConfig.jumpModeling.threshold = maxSafeThreshold;
        boundsStats.adjustments = boundsStats.adjustments + 1;
        boundsStats.warnings{end+1} = sprintf('Jump threshold reduced from %.3f to %.3f for stability', ...
            originalThreshold, maxSafeThreshold);
    elseif originalThreshold < minSafeThreshold
        safeConfig.jumpModeling.threshold = minSafeThreshold;
        boundsStats.adjustments = boundsStats.adjustments + 1;
        boundsStats.warnings{end+1} = sprintf('Jump threshold increased from %.3f to %.3f for detection', ...
            originalThreshold, minSafeThreshold);
    end
    
    boundsStats.jumpThreshold = struct(...
        'original', originalThreshold, ...
        'safe', safeConfig.jumpModeling.threshold, ...
        'minSafe', minSafeThreshold, ...
        'maxSafe', maxSafeThreshold);
end

end

function dataStats = calculateDataCharacteristics(inputData, productNames)
%CALCULATEDATACHARACTERISTICS Calculate key data characteristics for safety bounds

dataStats = struct();
dataLengths = [];
volatilities = [];
stds = [];
ranges = [];

for i = 1:length(productNames)
    productName = productNames{i};
    
    % Extract product data
    if istable(inputData) || istimetable(inputData)
        if ismember(productName, inputData.Properties.VariableNames)
            productData = inputData.(productName);
        else
            continue;
        end
    elseif isstruct(inputData)
        if isfield(inputData, productName)
            productData = inputData.(productName);
        else
            continue;
        end
    else
        continue;
    end
    
    % Calculate characteristics
    validData = productData(~isnan(productData));
    if length(validData) > 10
        dataLengths(end+1) = length(validData);
        
        % Calculate volatility (using returns)
        returns = diff(log(abs(validData) + 1));  % Log returns with offset
        volatilities(end+1) = std(returns, 'omitnan');
        
        stds(end+1) = std(validData, 'omitnan');
        ranges(end+1) = range(validData);
    end
end

% Aggregate statistics
dataStats.minDataLength = min(dataLengths);
dataStats.maxDataLength = max(dataLengths);
dataStats.averageDataLength = mean(dataLengths);
dataStats.averageVolatility = mean(volatilities);
dataStats.averageStd = mean(stds);
dataStats.averageRange = mean(ranges);

end

function dataIntegrityStats = validateDataIntegrity(inputData, productNames)
%VALIDATEDATAINTEGRITY Validate data integrity for optimization

dataIntegrityStats = struct();
dataIntegrityStats.isValid = true;
dataIntegrityStats.issues = {};
dataIntegrityStats.productStats = struct();

for i = 1:length(productNames)
    productName = productNames{i};
    
    % Extract product data
    if istable(inputData) || istimetable(inputData)
        if ismember(productName, inputData.Properties.VariableNames)
            productData = inputData.(productName);
        else
            dataIntegrityStats.issues{end+1} = sprintf('Product %s not found in data', productName);
            dataIntegrityStats.isValid = false;
            continue;
        end
    elseif isstruct(inputData)
        if isfield(inputData, productName)
            productData = inputData.(productName);
        else
            dataIntegrityStats.issues{end+1} = sprintf('Product %s not found in data', productName);
            dataIntegrityStats.isValid = false;
            continue;
        end
    else
        dataIntegrityStats.issues{end+1} = 'Unsupported data format';
        dataIntegrityStats.isValid = false;
        continue;
    end
    
    % Validate product data
    productStats = struct();
    productStats.length = length(productData);
    productStats.missingCount = sum(isnan(productData));
    productStats.missingPercentage = (productStats.missingCount / productStats.length) * 100;
    productStats.hasValidData = (productStats.length - productStats.missingCount) >= 50;
    productStats.hasExtremeValues = any(abs(productData) > 10000);
    
    % Check for issues
    if ~productStats.hasValidData
        dataIntegrityStats.issues{end+1} = sprintf('%s has insufficient valid data (%d points)', ...
            productName, productStats.length - productStats.missingCount);
        dataIntegrityStats.isValid = false;
    end
    
    if productStats.missingPercentage > 50
        dataIntegrityStats.issues{end+1} = sprintf('%s has too much missing data (%.1f%%)', ...
            productName, productStats.missingPercentage);
        dataIntegrityStats.isValid = false;
    end
    
    if productStats.hasExtremeValues
        dataIntegrityStats.issues{end+1} = sprintf('%s contains extreme values (>10000)', productName);
    end
    
    dataIntegrityStats.productStats.(productName) = productStats;
end

end

function [safeConfig, blockSizeStats] = validateBlockSizeSafety(config, inputData, productNames)
%VALIDATEBLOCKSIZESAFETY Validate block size safety for simulation stability

safeConfig = config;
blockSizeStats = struct();
blockSizeStats.isValid = true;
blockSizeStats.recommendations = {};

if ~isfield(safeConfig, 'blockBootstrapping') || ...
   ~isfield(safeConfig.blockBootstrapping, 'blockSize')
    blockSizeStats.isValid = false;
    blockSizeStats.recommendations{end+1} = 'Block bootstrapping configuration missing';
    return;
end

currentBlockSize = safeConfig.blockBootstrapping.blockSize;
blockSizeStats.current = currentBlockSize;

% Calculate average data length
dataLengths = [];
for i = 1:length(productNames)
    productName = productNames{i};
    
    if istable(inputData) || istimetable(inputData)
        if ismember(productName, inputData.Properties.VariableNames)
            productData = inputData.(productName);
            validData = productData(~isnan(productData));
            dataLengths(end+1) = length(validData);
        end
    elseif isstruct(inputData)
        if isfield(inputData, productName)
            productData = inputData.(productName);
            validData = productData(~isnan(productData));
            dataLengths(end+1) = length(validData);
        end
    end
end

if isempty(dataLengths)
    blockSizeStats.isValid = false;
    blockSizeStats.recommendations{end+1} = 'No valid data found for block size validation';
    return;
end

avgDataLength = mean(dataLengths);
minDataLength = min(dataLengths);

% Calculate safe block size limits
maxSafeBlockSize = floor(minDataLength / 8);  % At least 8 blocks from shortest series
minSafeBlockSize = max(6, floor(sqrt(avgDataLength / 50)));  % Adaptive minimum

blockSizeStats.minSafe = minSafeBlockSize;
blockSizeStats.maxSafe = maxSafeBlockSize;
blockSizeStats.averageDataLength = avgDataLength;
blockSizeStats.minDataLength = minDataLength;

% Validate current block size
if currentBlockSize > maxSafeBlockSize
    safeConfig.blockBootstrapping.blockSize = maxSafeBlockSize;
    blockSizeStats.adjusted = maxSafeBlockSize;
    blockSizeStats.recommendations{end+1} = sprintf('Block size reduced from %d to %d to prevent instability', ...
        currentBlockSize, maxSafeBlockSize);
elseif currentBlockSize < minSafeBlockSize
    safeConfig.blockBootstrapping.blockSize = minSafeBlockSize;
    blockSizeStats.adjusted = minSafeBlockSize;
    blockSizeStats.recommendations{end+1} = sprintf('Block size increased from %d to %d for better stability', ...
        currentBlockSize, minSafeBlockSize);
else
    blockSizeStats.adjusted = currentBlockSize;
    blockSizeStats.recommendations{end+1} = 'Block size is within safe range';
end

end

function [safeConfig, volatilityStats] = configureVolatilityPrevention(config, inputData, productNames)
%CONFIGUREVOLATILITYPREVENTION Configure volatility explosion prevention

safeConfig = config;
volatilityStats = struct();

% Add volatility prevention configuration if not present
if ~isfield(safeConfig, 'volatilityPrevention')
    safeConfig.volatilityPrevention = struct();
end

% Calculate volatility characteristics from data
volatilities = [];
for i = 1:length(productNames)
    productName = productNames{i};
    
    if istable(inputData) || istimetable(inputData)
        if ismember(productName, inputData.Properties.VariableNames)
            productData = inputData.(productName);
        else
            continue;
        end
    elseif isstruct(inputData)
        if isfield(inputData, productName)
            productData = inputData.(productName);
        else
            continue;
        end
    else
        continue;
    end
    
    validData = productData(~isnan(productData));
    if length(validData) > 50
        % Calculate rolling volatility
        returns = diff(log(abs(validData) + 1));
        rollingVol = movstd(returns, min(12, floor(length(returns)/4)), 'omitnan');
        volatilities = [volatilities; rollingVol];
    end
end

if ~isempty(volatilities)
    avgVolatility = mean(volatilities, 'omitnan');
    maxVolatility = prctile(volatilities, 95);
    
    % Configure adaptive volatility limits
    safeConfig.volatilityPrevention.enabled = true;
    safeConfig.volatilityPrevention.maxVolatilityRatio = min(50, max(10, 3 * maxVolatility / avgVolatility));
    safeConfig.volatilityPrevention.smoothingWindow = 12;
    safeConfig.volatilityPrevention.emergencyResetThreshold = 100 * avgVolatility;
    
    volatilityStats.avgVolatility = avgVolatility;
    volatilityStats.maxVolatility = maxVolatility;
    volatilityStats.configuredRatio = safeConfig.volatilityPrevention.maxVolatilityRatio;
    volatilityStats.emergencyThreshold = safeConfig.volatilityPrevention.emergencyResetThreshold;
else
    % Default safe configuration
    safeConfig.volatilityPrevention.enabled = true;
    safeConfig.volatilityPrevention.maxVolatilityRatio = 25;
    safeConfig.volatilityPrevention.smoothingWindow = 12;
    safeConfig.volatilityPrevention.emergencyResetThreshold = 100;
    
    volatilityStats.avgVolatility = NaN;
    volatilityStats.maxVolatility = NaN;
    volatilityStats.configuredRatio = 25;
    volatilityStats.emergencyThreshold = 100;
end

end

function [safeConfig, jumpStats] = validateJumpModelingSafety(config, inputData, productNames)
%VALIDATEJUMPMODELINGSAFETY Validate jump modeling safety

safeConfig = config;
jumpStats = struct();
jumpStats.isValid = true;

if ~isfield(safeConfig, 'jumpModeling')
    safeConfig.jumpModeling = struct();
    safeConfig.jumpModeling.enabled = false;
    jumpStats.configured = false;
    return;
end

jumpStats.configured = true;
jumpStats.enabled = safeConfig.jumpModeling.enabled;

if ~safeConfig.jumpModeling.enabled
    jumpStats.isValid = true;
    return;
end

% Calculate jump characteristics from data
jumpSizes = [];
for i = 1:length(productNames)
    productName = productNames{i};
    
    if istable(inputData) || istimetable(inputData)
        if ismember(productName, inputData.Properties.VariableNames)
            productData = inputData.(productName);
        else
            continue;
        end
    elseif isstruct(inputData)
        if isfield(inputData, productName)
            productData = inputData.(productName);
        else
            continue;
        end
    else
        continue;
    end
    
    validData = productData(~isnan(productData));
    if length(validData) > 10
        returns = diff(validData);
        returnStd = std(returns, 'omitnan');
        
        % Identify potential jumps (returns > 3 std deviations)
        jumpMask = abs(returns) > 3 * returnStd;
        if any(jumpMask)
            jumpSizes = [jumpSizes; abs(returns(jumpMask))];
        end
    end
end

% Configure safe jump thresholds
if ~isempty(jumpSizes)
    medianJumpSize = median(jumpSizes);
    maxSafeJumpSize = prctile(jumpSizes, 90);
    
    % Ensure jump threshold is reasonable
    if isfield(safeConfig.jumpModeling, 'threshold')
        if safeConfig.jumpModeling.threshold > maxSafeJumpSize
            safeConfig.jumpModeling.threshold = maxSafeJumpSize;
            jumpStats.adjustedThreshold = true;
        end
    else
        safeConfig.jumpModeling.threshold = medianJumpSize;
        jumpStats.adjustedThreshold = true;
    end
    
    jumpStats.medianJumpSize = medianJumpSize;
    jumpStats.maxSafeJumpSize = maxSafeJumpSize;
else
    % Disable jump modeling if no jumps detected
    safeConfig.jumpModeling.enabled = false;
    jumpStats.disabledDueToNoJumps = true;
end

end

function [safeConfig, regimeStats] = validateRegimeSwitchingSafety(config)
%VALIDATEREGIMESWITCHINGSAFETY Validate regime switching safety

safeConfig = config;
regimeStats = struct();
regimeStats.isValid = true;

if ~isfield(safeConfig, 'regimeVolatilityModulation')
    regimeStats.isValid = false;
    regimeStats.issues = {'Regime volatility modulation configuration missing'};
    return;
end

% Validate amplification factor
if isfield(safeConfig.regimeVolatilityModulation, 'amplificationFactor')
    ampFactor = safeConfig.regimeVolatilityModulation.amplificationFactor;
    
    % Ensure amplification factor is within safe bounds
    if ampFactor > 3.0
        safeConfig.regimeVolatilityModulation.amplificationFactor = 3.0;
        regimeStats.adjustedAmplification = true;
        regimeStats.adjustmentReason = 'Reduced from extreme value for stability';
    elseif ampFactor < 0.1
        safeConfig.regimeVolatilityModulation.amplificationFactor = 0.1;
        regimeStats.adjustedAmplification = true;
        regimeStats.adjustmentReason = 'Increased from too low value for validity';
    end
    
    regimeStats.amplificationFactor = safeConfig.regimeVolatilityModulation.amplificationFactor;
end

% Ensure max volatility ratio is set
if ~isfield(safeConfig.regimeVolatilityModulation, 'maxVolRatio')
    safeConfig.regimeVolatilityModulation.maxVolRatio = 50;
    regimeStats.addedMaxVolRatio = true;
end

end

function generateSafetyReport(safetyStats)
%GENERATESAFETYREPORT Generate a comprehensive safety validation report

fprintf('\n=== Safety Validation Report ===\n');

% Parameter bounds validation
if isfield(safetyStats, 'parameterBounds')
    pb = safetyStats.parameterBounds;
    if pb.adjustments > 0
        fprintf('Parameter Bounds: %d adjustments made\n', pb.adjustments);
        for i = 1:length(pb.warnings)
            fprintf('  - %s\n', pb.warnings{i});
        end
    else
        fprintf('Parameter Bounds: All parameters within safe ranges\n');
    end
end

% Data integrity validation
if isfield(safetyStats, 'dataIntegrity')
    di = safetyStats.dataIntegrity;
    if di.isValid
        fprintf('Data Integrity: Validation passed\n');
    else
        fprintf('Data Integrity: Issues found\n');
        for i = 1:length(di.issues)
            fprintf('  - %s\n', di.issues{i});
        end
    end
end

% Block size validation
if isfield(safetyStats, 'blockSize')
    bs = safetyStats.blockSize;
    if isfield(bs, 'adjusted') && bs.adjusted ~= bs.current
        fprintf('Block Size: Adjusted from %d to %d\n', bs.current, bs.adjusted);
    else
        fprintf('Block Size: Current size (%d) is safe\n', bs.current);
    end
end

% Volatility prevention
if isfield(safetyStats, 'volatilityPrevention')
    vp = safetyStats.volatilityPrevention;
    fprintf('Volatility Prevention: Configured with ratio %.1f\n', vp.configuredRatio);
end

% Summary
fprintf('\nSafety Status: ');
if safetyStats.isSafe
    fprintf('SAFE - Optimization can proceed\n');
else
    fprintf('UNSAFE - Review issues before proceeding\n');
end

fprintf('Validation time: %.2f seconds\n', safetyStats.validationTime);

end
