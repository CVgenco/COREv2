%% Enhanced CORE Model with Bayesian Volatility Modeling and Improvements
% This file integrates the complete CORE model with advanced Bayesian
% volatility modeling and regime-switching capabilities, plus enhancements:
% 1. Dynamic regime selection using BIC
% 2. Bounded scaling in constraint enforcement
% 3. Enhanced validation for volatility clustering and jumps

% Implementation of CORE's non-parametric electricity price simulation model
% with comprehensive data utilization for nodal pricing data at subhourly resolution.
%
% This enhanced model implements CORE's simple, robust, non-parametric approach:
% 1. Uses ALL historical data (nodal, hub, generation, ancillary) for pattern learning
% 2. Scales historical data to match forecasts using smart scaling
% 3. Preserves correlations across all products through correlation matrix
% 4. Samples from scaled historical distributions with conditioning
% 5. Ensures paths average to forecasts with tolerance
% 6. Applies Bayesian Volatility Modeling with regime-switching for superior volatility dynamics
%
% Advanced features:
% - Comprehensive overlap detection between datasets
% - Smart conflict resolution with priority-based weighting
% - Adaptive timeline management for large datasets
% - Bayesian volatility modeling with regime-switching
% - Fat-tailed distributions for realistic price jumps
% - Dynamic regime selection using BIC
% - Bounded scaling to prevent extreme adjustments
% - Enhanced validation for volatility clustering and jumps

clear; close all; clc;

% Initialize global progress tracking variables
global currentStep totalSteps startTime;
currentStep = 0;
totalSteps = 11; % Increased by 1 for Bayesian volatility modeling
startTime = tic;

% Display initial progress
updateProgress(0, 'Initializing...');

%% === CENTRALIZED CONFIGURATION ===
% Create configuration structure for all parameters and paths
config = struct();

% Base directory (should be the absolute path to the data directory)
config.baseDir = '/Users/chayanvohra/Downloads/Energy Price & Risk Simulator/Price Forecaster/CORE';

% Historical data files
config.historicalFiles = struct('nodal', fullfile(config.baseDir, 'historical_nodal_prices.csv'), ...
    'hub', fullfile(config.baseDir, 'historical_hub_prices.csv'), ...
    'generation', fullfile(config.baseDir, 'historical_nodal_generation.csv'));

% Ancillary services historical data files
config.historicalAncillaryFiles = struct('NonSpin', fullfile(config.baseDir, 'historical_nonspin.csv'), ...
    'RegDown', fullfile(config.baseDir, 'historical_regdown.csv'), ...
    'RegUp', fullfile(config.baseDir, 'historical_regup.csv'), ...
    'RRS', fullfile(config.baseDir, 'historical_rrs.csv'), ...
    'ECRS', fullfile(config.baseDir, 'historical_ecrs.csv'));

% Forecast data files
config.forecastFiles = struct('nodal', fullfile(config.baseDir, 'hourly_nodal_forecasts.csv'), ...
    'hub', fullfile(config.baseDir, 'hourly_hub_forecasts.csv'), ...
    'ancillary', fullfile(config.baseDir, 'forecasted_annual_ancillary.csv'));

% Output configuration
config.output = struct('file', 'enhanced_core_nodal_subhourly_paths.csv', ...
    'format', 'csv');

% Simulation parameters
config.simulation = struct('nPaths', 1, ...          % Monte Carlo paths (user-tunable)
    'tolerance', 0.02, ...    % 2% tolerance for hourly averages
    'randomSeed', 43); % Fixed seed for reproducibility

% Algorithm parameters
adaptParams = struct('method', 'acf_abs_returns', 'maxLagForACF', 24*30*3, 'minWindow', 24, 'maxWindow', 24*30*3, 'primaryProductIndex', 1);

% Define regimeDetectionParams separately
regimeDetectionParams = struct('minRegimes', 2, 'maxRegimes', 10, 'minBICImprovement', 10);

% Define samplingParams separately
samplingParams = struct('batchSize', 5000);

config.algorithm = struct('correlationWindowSize', 168, 'regimeDetection', regimeDetectionParams, 'sampling', samplingParams, 'correlationWindowAdaptive', false, 'adaptiveWindowParams', adaptParams);

% Add stabilityTestAlpha to config.algorithm for regime stability test
if ~isfield(config.algorithm, 'stabilityTestAlpha')
    config.algorithm.stabilityTestAlpha = 0.05; % Default significance threshold
end

% Data resolution configuration (user can set this)
config.data = struct();
config.data.targetResolution = 'hourly'; % User can change to '5min', '15min', etc.

% Extract individual variables for backward compatibility (will remove in Sprint 4)
histNodalFile = config.historicalFiles.nodal;
histHubFile = config.historicalFiles.hub;
histGenFile = config.historicalFiles.generation;
histAncillaryFiles = config.historicalAncillaryFiles;
forecastNodalFile = config.forecastFiles.nodal;
forecastHubFile = config.forecastFiles.hub;
forecastAncillaryFile = config.forecastFiles.ancillary;
outputFile = config.output.file;
nPaths = config.simulation.nPaths;
tolerance = config.simulation.tolerance;

% Set random seed from configuration
rng(config.simulation.randomSeed);

%% ==================== 1. DATA LOADING MODULE ====================
fprintf('\nStarting enhanced data loading module...\n');
updateProgress(1, 'Loading data files');

%% 1.1 - Load and parse forecast nodal price data
fprintf('Loading forecast nodal price data from: %s\n', forecastNodalFile);
assert(isfile(forecastNodalFile), 'Forecast nodal price file not found: %s', forecastNodalFile);

% Parse forecast nodal price data
[forecastNodalData, forecastNodalResolution] = parseVariableResolutionData(forecastNodalFile);
fprintf(' → Loaded %d rows of forecast nodal price data\n', height(forecastNodalData));

% Extract the first timestamp from forecast data - this will be our simulation start time
simulationStartTime = forecastNodalData.Timestamp(1);
fprintf(' → Simulation will start from: %s\n', datestr(simulationStartTime));

%% 1.2 - Load and parse historical nodal price data
updateProgress(2, 'Loading historical data');
fprintf('Loading historical nodal price data from: %s\n', histNodalFile);
assert(isfile(histNodalFile), 'Historical nodal price file not found: %s', histNodalFile);

% Parse nodal price data
[historicalNodalData, historicalNodalResolution] = parseVariableResolutionData(histNodalFile);
fprintf(' → Loaded %d rows of historical nodal price data\n', height(historicalNodalData));

%% 1.3 - Load and parse historical hub price data
fprintf('Loading historical hub price data from: %s\n', histHubFile);

% Try to load hub data, but continue if file not found
try
    assert(isfile(histHubFile), 'Historical hub price file not found: %s', histHubFile);
    [historicalHubData, historicalHubResolution] = parseVariableResolutionData(histHubFile);
    fprintf(' → Loaded %d rows of historical hub price data\n', height(historicalHubData));
    hasHubData = true;
catch
    fprintf(' → Historical hub price file not found or invalid, continuing without hub data\n');
    historicalHubData = table();
    historicalHubResolution = '';
    hasHubData = false;
end

%% 1.4 - Load and parse historical generation data
fprintf('Loading historical generation data from: %s\n', histGenFile);

% Try to load generation data, but continue if file not found
try
    assert(isfile(histGenFile), 'Historical generation file not found: %s', histGenFile);
    [historicalGenData, historicalGenResolution] = parseVariableResolutionData(histGenFile);
    fprintf(' → Loaded %d rows of historical generation data\n', height(historicalGenData));
    hasGenData = true;
        catch
    fprintf(' → Historical generation file not found or invalid, continuing without generation data\n');
    historicalGenData = table();
    historicalGenResolution = '';
    hasGenData = false;
end

%% 1.5 - Load and parse historical ancillary services data
fprintf('Loading historical ancillary services data...\n');

% Initialize ancillary data structure
historicalAncillaryData = struct();
hasAncillaryData = false;

% Try to load each ancillary service file
ancTypes = fieldnames(histAncillaryFiles);
for a = 1:length(ancTypes)
    ancType = ancTypes{a};
    ancFile = histAncillaryFiles.(ancType);
    
    try
        assert(isfile(ancFile), 'Historical %s file not found: %s', ancType, ancFile);
        [ancData, ancResolution] = parseVariableResolutionData(ancFile);
        fprintf(' → Loaded %d rows of historical %s data\n', height(ancData), ancType);
        
        % Store in structure
        historicalAncillaryData.(ancType) = ancData;
        hasAncillaryData = true;
    catch
        fprintf(' → Historical %s file not found or invalid, continuing without this data\n', ancType);
        historicalAncillaryData.(ancType) = table();
    end
end

%% 1.6 - Load and parse forecast hub price data
fprintf('Loading forecast hub price data from: %s\n', forecastHubFile);

% Try to load forecast hub data, but continue if file not found
try
    assert(isfile(forecastHubFile), 'Forecast hub price file not found: %s', forecastHubFile);
    [forecastHubData, forecastHubResolution] = parseVariableResolutionData(forecastHubFile);
    fprintf(' → Loaded %d rows of forecast hub price data\n', height(forecastHubData));
    hasForecastHubData = true;
catch
    fprintf(' → Forecast hub price file not found or invalid, continuing without forecast hub data\n');
    forecastHubData = table();
    forecastHubResolution = '';
    hasForecastHubData = false;
end

%% 1.7 - Load and parse forecast ancillary services data
fprintf('Loading forecast ancillary services data from: %s\n', forecastAncillaryFile);

% Try to load forecast ancillary data (annual averages), but continue if file not found
try
    assert(isfile(forecastAncillaryFile), 'Forecast ancillary file not found: %s', forecastAncillaryFile);
    
    % Load annual ancillary data (special parser for annual averages)
    [forecastAncillaryData, forecastAncillaryResolution] = parseAnnualAncillaryData(forecastAncillaryFile);
    fprintf(' → Loaded %d services of forecast ancillary data (annual averages)\n', length(fieldnames(forecastAncillaryData)));
    hasForecastAncillaryData = true;
catch
    fprintf(' → Forecast ancillary file not found or invalid, continuing without forecast ancillary data\n');
    forecastAncillaryData = struct();
    forecastAncillaryResolution = 'annual';
    hasForecastAncillaryData = false;
end

%% ==================== 2. CORE SIMULATION MODULE ====================
fprintf('\nStarting enhanced CORE simulation module...\n');
updateProgress(3, 'Extracting patterns');

%% 2.1 - Extract comprehensive patterns from historical data
% Extract patterns from historical nodal data
patterns = extractComprehensivePatterns(config, historicalNodalData, historicalHubData, historicalGenData, historicalAncillaryData, hasHubData, hasGenData, hasAncillaryData);

%% 2.2 - Build comprehensive correlation matrix
updateProgress(4, 'Building correlation matrix');
[correlationMatrix, productNames, displayNames] = buildComprehensiveCorrelationMatrix(historicalNodalData, historicalHubData, historicalGenData, historicalAncillaryData, hasGenData, hasAncillaryData, histNodalFile, histHubFile, histGenFile, histAncillaryFiles);

% Print out the product display names included in the correlation matrix
fprintf('\nProducts included in the correlation matrix (%d total):\n', length(displayNames));
for i = 1:length(displayNames)
    fprintf('  %2d: %s\n', i, displayNames{i});
end

%% 2.2b - Build dynamic correlations for Phase 2B
fprintf('\nPhase 2B: Building dynamic correlation matrices...\n');

% Align data for correlation analysis
alignedData = alignToHourly(historicalNodalData, historicalHubData, historicalGenData, historicalAncillaryData, hasGenData, hasAncillaryData, config.data.targetResolution);

% === Adaptive correlation window selection ===
if isfield(config.algorithm, 'correlationWindowAdaptive') && config.algorithm.correlationWindowAdaptive
    windowSize = determineAdaptiveCorrelationWindow(alignedData, productNames, config.algorithm.adaptiveWindowParams);
    fprintf(' → Using adaptive correlation window size: %d\n', windowSize);
else
    windowSize = config.algorithm.correlationWindowSize;
    fprintf(' → Using fixed correlation window size: %d\n', windowSize);
end

% Build time-varying correlations
% (windowSize is now adaptive or fixed as per config)
% Construct productSourceFiles from productNames (extract the part in parentheses)
productSourceFiles = cell(size(productNames));
for i = 1:length(productNames)
    tokens = regexp(productNames{i}, '\(([^)]+)\)$', 'tokens', 'once');
    if ~isempty(tokens)
        productSourceFiles{i} = tokens{1};
    else
        productSourceFiles{i} = '';
    end
end
timeVaryingCorrelations = buildTimeVaryingCorrelations(alignedData, productNames, windowSize, displayNames);

%% 2.2c - Build multi-resolution correlations for Phase 2C
fprintf('\nPhase 2C: Building multi-resolution correlation matrices...\n');

% Build native resolution correlation matrices
multiResCorrelations = buildMultiResolutionCorrelations( ...
    historicalNodalData, ...
    historicalHubData, ...
    historicalGenData, ...
    historicalAncillaryData, ...
    hasGenData, ...
    hasAncillaryData, ...
    productNames, ...
    displayNames);

% Determine target simulation resolution
targetResolution = 'hourly'; % Default, could be determined from forecast data resolution

%% 2.3 - Apply smart scaling to historical patterns
updateProgress(5, 'Applying smart scaling');
scaledPatterns = applySmartScaling(patterns, forecastNodalData, forecastHubData, forecastAncillaryData, hasForecastAncillaryData, hasGenData);

%% 2.4 - Generate simulation timeline
updateProgress(6, 'Generating simulation timeline');
simulationTimeline = generateSimulationTimeline(forecastNodalData.Timestamp(1), forecastNodalData.Timestamp(end), historicalNodalResolution);
fprintf(' → Generated simulation timeline with %d intervals\n', length(simulationTimeline));

%% 2.5 - Conditional sampling from historical distributions
updateProgress(7, 'Conditional sampling');
[sampledPaths, ancillaryPaths] = conditionalSamplingFromHistoricalDistributions(scaledPatterns, simulationTimeline, nPaths, forecastHubData, forecastAncillaryData, historicalGenData, hasGenData, hasForecastAncillaryData);

%% 2.6 - Apply dynamic correlation matrix (Phase 2B Enhancement)
updateProgress(8, 'Applying dynamic correlation matrix');
correlatedPaths = applyDynamicCorrelationMatrix(sampledPaths, correlationMatrix, timeVaryingCorrelations, productNames, simulationTimeline);

%% 2.7 - Apply Bayesian Volatility Modeling with Regime-Switching
updateProgress(9, 'Applying Bayesian Volatility Modeling');
fprintf('\nStarting Bayesian Volatility Modeling with Regime-Switching...\n');

% Apply Bayesian Volatility Modeling with Regime-Switching
[bayesianPaths, bayesianDiagnostics] = applyBayesianRegimeSwitchingVolatility(correlatedPaths, scaledPatterns, fieldnames(scaledPatterns), config.algorithm.stabilityTestAlpha);

%% 2.7b - Apply regime-dependent correlations (Phase 2B Integration)
fprintf('\nPhase 2B: Applying regime-dependent correlations...\n');

% Extract regime states from Bayesian diagnostics for the first node
nodeNames = setdiff(historicalNodalData.Properties.VariableNames, {'Timestamp'});
firstNodeName = nodeNames{1};

if isfield(bayesianDiagnostics, firstNodeName) && isfield(bayesianDiagnostics.(firstNodeName), 'regimeModel')
    regimeModel = bayesianDiagnostics.(firstNodeName).regimeModel;
    nRegimes = regimeModel.optimalRegimes;
    
    % Build regime-dependent correlations using historical regime states
    regimeStates = regimeModel.regimes;
    regimeCorrelations = buildRegimeDependentCorrelations(alignedData, productNames, regimeStates, nRegimes);
    
    % Apply final regime-aware correlation enhancement to Bayesian paths
    fprintf(' → Applying final regime-aware correlation enhancement\n');
    enhancedBayesianPaths = applyRegimeAwareCorrelations(bayesianPaths, regimeCorrelations, bayesianDiagnostics, productNames);
    
    % Update bayesianPaths with regime-enhanced paths
    bayesianPaths = enhancedBayesianPaths;
    
    fprintf(' → Successfully applied regime-dependent correlations\n');
else
    fprintf(' → Warning: No regime model found, skipping regime-dependent correlations\n');
end

%% 2.7c - Apply resolution-appropriate correlations (Phase 2C Final Step)
fprintf('\nPhase 2C: Applying resolution-appropriate correlations...\n');

% Apply resolution-appropriate correlations as final enhancement
resolutionEnhancedPaths = applyResolutionAppropriateCorrelations(bayesianPaths, multiResCorrelations, targetResolution, simulationTimeline);

% Update bayesianPaths with resolution-enhanced paths
bayesianPaths = resolutionEnhancedPaths;

fprintf(' → Successfully applied resolution-appropriate correlations\n');

% Convert historical nodal data from table to struct for validation
historicalNodalStruct = struct();
    for i = 1:length(nodeNames)
        nodeName = nodeNames{i};
    historicalNodalStruct.(nodeName).rawHistorical = historicalNodalData.(nodeName);
    historicalNodalStruct.(nodeName).timestamps = historicalNodalData.Timestamp;
end

% === Validate volatility modeling results ===
% Pass displayNames to validation for clear reporting
validationResults = validateVolatilityModeling(bayesianPaths, historicalNodalStruct, bayesianDiagnostics, displayNames);

%% 2.8 - Enforce hourly targets with tolerance
updateProgress(10, 'Enforcing hourly targets');
finalPaths = enforceHourlyTargetsWithTolerance(bayesianPaths, forecastNodalData, tolerance);

%% 2.8c - Validate cross-timescale correlations (Phase 2C Validation)
printf('\nPhase 2C: Validating cross-timescale correlation preservation...\n');
crossTimescaleValidation = validateCrossTimescaleCorrelations(multiResCorrelations, finalPaths, simulationTimeline, displayNames);

%% ==================== 3. OUTPUT PREPARATION MODULE ====================
fprintf('\nStarting output preparation module...\n');
updateProgress(11, 'Preparing output');

%% 3.1 - Prepare output data
outputData = prepareOutputData(finalPaths, nPaths, ancillaryPaths);

% === Write nodal price paths for all nodes to a single file ===
nodalTable = table();
nodalTable.Timestamp = finalPaths.Timestamp;
nodeNames = setdiff(fieldnames(finalPaths), {'Timestamp'});
for i = 1:length(nodeNames)
    nodeName = nodeNames{i};
    for p = 1:nPaths
        colName = sprintf('%s_Path%d', nodeName, p);
        nodalTable.(colName) = finalPaths.(nodeName)(:, p);
    end
end
% Optionally, add displayNames as a header row or metadata (if supported by your output format)
if exist('displayNames', 'var') && length(displayNames) >= length(nodeNames)
    % Write displayNames to a separate metadata file for traceability
    writetable(cell2table(displayNames', 'VariableNames', {'ProductDisplayName'}), 'output_product_display_names.csv');
    fprintf(' → Wrote product display names to output_product_display_names.csv\n');
end
writetable(nodalTable, 'output_nodal_prices.csv');
fprintf(' → Wrote all nodal price paths to output_nodal_prices.csv\n');

% === Write each ancillary service to its own file ===
if exist('ancillaryPaths', 'var') && ~isempty(ancillaryPaths)
    ancillaryNames = setdiff(fieldnames(ancillaryPaths), {'Timestamp'});
    for i = 1:length(ancillaryNames)
        ancName = ancillaryNames{i};
        ancTable = table();
        ancTable.Timestamp = ancillaryPaths.Timestamp;
        for p = 1:nPaths
            colName = sprintf('%s_Path%d', ancName, p);
            ancTable.(colName) = ancillaryPaths.(ancName)(:, p);
        end
        ancFile = sprintf('output_ancillary_%s.csv', ancName);
        writetable(ancTable, ancFile);
        fprintf(' → Wrote output for ancillary %s to %s\n', ancName, ancFile);
            end
        end
        
%% 3.2 - Validate path diversity
pathDiversityResults = validatePathDiversity(outputData, displayNames);

%% ==================== 4. COMPLETION ====================
fprintf('\nEnhanced CORE simulation completed successfully.\n');
fprintf('Total runtime: %.2f minutes\n', toc(startTime)/60);

%% ==================== HELPER FUNCTIONS ====================

% Function: updateProgress
% Updates progress bar and displays status
function updateProgress(step, message)
    global currentStep totalSteps startTime;
    currentStep = step;
    
    % Calculate progress percentage
    progress = step / totalSteps;
    
    % Calculate elapsed time and estimate remaining time
    elapsedTime = toc(startTime);
    if progress > 0
        remainingTime = elapsedTime * (1 - progress) / progress;
    else
        remainingTime = 0;
    end
    
    % Create progress bar
    barWidth = 50;
    progressBar = repmat('█', 1, round(progress * barWidth));
    progressBar = [progressBar, repmat('░', 1, barWidth - length(progressBar))];
    
    % Display progress
    fprintf('[%s] %3.0f%% | %s | Elapsed: %s | Remaining: %s\n', ...
        progressBar, progress * 100, message, ...
        formatTime(elapsedTime), formatTime(remainingTime));
end

% Function: formatTime
% Formats time in seconds to a readable string
function timeStr = formatTime(seconds)
    if seconds < 60
        timeStr = sprintf('%.0f sec', seconds);
    elseif seconds < 3600
        timeStr = sprintf('%.1f min', seconds / 60);
    else
        timeStr = sprintf('%.1f hr', seconds / 3600);
                    end
                end
                
% Function: parseVariableResolutionData
% Parses CSV data with variable resolution
function [data, resolution] = parseVariableResolutionData(filePath)
    % Read CSV file
    data = readtable(filePath);
    
    % Ensure Timestamp column exists
    assert(ismember('Timestamp', data.Properties.VariableNames), 'CSV file must have a Timestamp column');
    
    % Convert Timestamp to datetime if it's not already
    if ~isa(data.Timestamp, 'datetime')
        data.Timestamp = datetime(data.Timestamp);
    end
    
    % Fix two-digit years
    if any(year(data.Timestamp) < 100)
        fprintf(' → Warning: Detected two-digit years, interpreting as 21st century\n');
        twoDigitYears = year(data.Timestamp) < 100;
        fixedDates = data.Timestamp(twoDigitYears);
        fixedDates.Year = fixedDates.Year + 2000;
        data.Timestamp(twoDigitYears) = fixedDates;
    end

    % Sort by timestamp
    data = sortrows(data, 'Timestamp');
    
    % Determine resolution
    if height(data) <= 1
        resolution = 'unknown';
    else
        % Calculate time differences
        timeDiffs = diff(data.Timestamp);
        
        % Find most common time difference
        uniqueDiffs = unique(timeDiffs);
        counts = zeros(size(uniqueDiffs));
        
        for i = 1:length(uniqueDiffs)
            counts(i) = sum(timeDiffs == uniqueDiffs(i));
        end
        
        [~, idx] = max(counts);
        mostCommonDiff = uniqueDiffs(idx);
        
        % Determine resolution based on most common difference
        if mostCommonDiff <= minutes(5)
            resolution = '5min';
        elseif mostCommonDiff <= minutes(15)
            resolution = '15min';
        elseif mostCommonDiff <= hours(1)
            resolution = 'hourly';
        elseif mostCommonDiff <= days(1)
            resolution = 'daily';
        elseif mostCommonDiff <= days(7)
            resolution = 'weekly';
        elseif mostCommonDiff <= days(31)
            resolution = 'monthly';
        else
            resolution = 'unknown';
        end
            end
        end
        
% Function: parseAnnualAncillaryData
% Parses CSV data with annual ancillary service averages
function [ancillaryData, resolution] = parseAnnualAncillaryData(filePath)
    % Read CSV file
    rawData = readtable(filePath);
    
    % Ensure Timestamp column exists (should be years like 2023, 2024, etc.)
    assert(ismember('Timestamp', rawData.Properties.VariableNames), 'CSV file must have a Timestamp column');
    
    % Convert annual years to struct format for easy access
    ancillaryData = struct();
    resolution = 'annual';
    
    % Get service names (all columns except Timestamp)
    serviceNames = setdiff(rawData.Properties.VariableNames, {'Timestamp'});
    
    % For each service, find the most recent year's forecast
    for i = 1:length(serviceNames)
        serviceName = serviceNames{i};
        
        % Get valid (non-NaN) price data
        validRows = ~isnan(rawData.(serviceName));
        
        if sum(validRows) > 0
            % Use most recent year's data
            validData = rawData(validRows, :);
            [~, latestIdx] = max(validData.Timestamp);
            
            % Store as single annual average value
            ancillaryData.(serviceName) = validData.(serviceName)(latestIdx);
            
            fprintf('   → Loaded %s: $%.2f/MWh (annual average for year %d)\n', ...
                serviceName, ancillaryData.(serviceName), validData.Timestamp(latestIdx));
        else
            fprintf('   → Warning: No valid data for %s, skipping\n', serviceName);
    end
end

    if isempty(fieldnames(ancillaryData))
        error('No valid ancillary service data found in file');
    end
end

% Function: generateSimulationTimeline
% Generates simulation timeline with appropriate resolution
function timeline = generateSimulationTimeline(startTime, endTime, resolution)
    % Determine appropriate time step based on resolution
    switch resolution
        case '5min'
            timeStep = minutes(5);
        case '15min'
            timeStep = minutes(15);
        case 'hourly'
            timeStep = hours(1);
        case 'daily'
            timeStep = days(1);
        otherwise
            timeStep = hours(1); % Default to hourly
    end
    
    % Generate timeline
    timeline = startTime:timeStep:endTime;
    timeline = timeline';
end

% Function: extractComprehensivePatterns
% Extract patterns from historical data with hub, generation, and ancillary relationships
% SPRINT 1: Temporal features precomputed for efficiency
% SPRINT 4: Data pre-aligned using outerjoin to avoid repeated intersects
function patterns = extractComprehensivePatterns(config, nodalData, hubData, genData, ancillaryData, hasHubData, hasGenData, hasAncillaryData)
    % Get node names from the original nodalData table
    originalNodeNames = setdiff(nodalData.Properties.VariableNames, {'Timestamp'});
    numNodes = length(originalNodeNames);

    % === SPRINT 4: Create a single aligned historical data table ===
    alignedHistData = nodalData; % Start with nodal data

    if hasHubData && ~isempty(hubData) && height(hubData) > 0
        alignedHistData = outerjoin(alignedHistData, hubData, 'Keys', 'Timestamp', 'MergeKeys', true, 'Type', 'left');
    end
    if hasGenData && ~isempty(genData) && height(genData) > 0
        alignedHistData = outerjoin(alignedHistData, genData, 'Keys', 'Timestamp', 'MergeKeys', true, 'Type', 'left');
    end

    allAncProductNames = {}; % To store names of ancillary product columns for later iteration
    if hasAncillaryData
        ancTypes = fieldnames(ancillaryData); % e.g., {'NonSpin', 'RegDown'}
        for a = 1:length(ancTypes)
            ancType = ancTypes{a}; % e.g., 'NonSpin'
            currentAncTable = ancillaryData.(ancType); % Table for NonSpin
            if ~isempty(currentAncTable) && istable(currentAncTable) && height(currentAncTable) > 0
                % Add ancillary product names to our list
                currentAncProductNames = setdiff(currentAncTable.Properties.VariableNames, 'Timestamp')';
                allAncProductNames = [allAncProductNames, currentAncProductNames];
                % Join the table
                alignedHistData = outerjoin(alignedHistData, currentAncTable, 'Keys', 'Timestamp', 'MergeKeys', true, 'Type', 'left');
            end
        end
    end
    allAncProductNames = unique(allAncProductNames);
    % alignedHistData.Timestamp is now the master timeline for all joined historical data
    masterTimestamps = alignedHistData.Timestamp;
    
    % Initialize a cell array to store results from each parfor iteration
    tempPatternsCell = cell(1, numNodes);

    % Ensure a parallel pool is active (existing logic)
    poolobj = gcp('nocreate');
    if isempty(poolobj)
        parpool('Processes'); 
        fprintf(' → Started parallel pool for pattern extraction.\n');
        addpath(config.baseDir);
        fprintf(' → Added %s to worker paths.\n', config.baseDir);
    else
        try
            workerInstructions = sprintf("addpath('%s');", config.baseDir);
            parfevalOnAll(poolobj, @eval, 0, workerInstructions);
            fprintf(' → Ensured %s is on existing worker paths.\n', config.baseDir);
        catch ME
            fprintf(' → Warning: Could not explicitly add path to existing workers: %s\n', ME.message);
            addpath(config.baseDir); % Fallback for client path
        end
    end
    
    % For each node (using originalNodeNames from pre-join nodalData)
    for i = 1:numNodes 
        nodeName = originalNodeNames{i}; % This is the column name in alignedHistData for the current node
        fprintf('Extracting comprehensive patterns for node %s (%d of %d)\n', nodeName, i, numNodes);
        
        currentNodePatterns = struct();

        % === SPRINT 4: Access data from alignedHistData ===
        % Node prices for the current node (may contain NaNs from outer join)
        nodePricesFull = alignedHistData.(nodeName);
        
        % Filter out NaNs for pattern extraction helpers
        validNodeDataIdx = ~isnan(nodePricesFull);
        nodePricesForPatterns = nodePricesFull(validNodeDataIdx);
        nodeTimestampsForPatterns = masterTimestamps(validNodeDataIdx);

        % Store raw historical data (original, potentially sparse for this node if outer joined)
        currentNodePatterns.rawHistorical = nodePricesForPatterns; 
        currentNodePatterns.timestamps = nodeTimestampsForPatterns;
        
        % === SPRINT 1: Precompute temporal features (using filtered data) ===
        if ~isempty(nodeTimestampsForPatterns)
            [years, months, days, hours, ~, ~] = datevec(nodeTimestampsForPatterns);
            t_num_patterns = datenum(nodeTimestampsForPatterns);
            daysOfWeek_patterns = mod(floor(t_num_patterns) - 1, 7) + 1;
            currentNodePatterns.temporalFeatures = struct('years', years, 'months', months, 'days', days, 'hours', hours, 'daysOfWeek', daysOfWeek_patterns);

            % Extract patterns using filtered data
            currentNodePatterns.hourly = extractHourlyPattern(nodeTimestampsForPatterns, nodePricesForPatterns, hours);
            currentNodePatterns.daily = extractDailyPattern(nodeTimestampsForPatterns, nodePricesForPatterns, daysOfWeek_patterns);
            currentNodePatterns.monthly = extractMonthlyPattern(nodeTimestampsForPatterns, nodePricesForPatterns, months);
            currentNodePatterns.holiday = extractHolidayPattern(nodeTimestampsForPatterns, nodePricesForPatterns); % Holiday uses its own date logic
            currentNodePatterns.seasonal = extractSeasonalBehaviorPattern(nodeTimestampsForPatterns, nodePricesForPatterns, months, daysOfWeek_patterns, hours);
        else
            % Handle cases where a node might have no valid data after alignment (e.g., all NaNs)
            currentNodePatterns.temporalFeatures = struct('years', [], 'months', [], 'days', [], 'hours', [], 'daysOfWeek', []);
            currentNodePatterns.hourly = nan(24,3);
            currentNodePatterns.daily = nan(7,3);
            currentNodePatterns.monthly = nan(12,3);
            currentNodePatterns.holiday = struct('adjustmentFactors', struct(), 'holidayDates', [], 'holidayNames', {{}});
            currentNodePatterns.seasonal = struct('weekendEffects', struct(), 'hourlyShapes', struct(), 'crossEffects', struct());
        end

        % === Hub Relationships (using alignedHistData) ===
        if hasHubData && ~isempty(hubData) && height(hubData) > 0 % Check original hubData presence
            currentNodePatterns.hubRelationships = struct();
            hubNamesTemp = setdiff(hubData.Properties.VariableNames, {'Timestamp'}); % Original hub names
            for h_idx = 1:length(hubNamesTemp)
                hubName = hubNamesTemp{h_idx};
                if ismember(hubName, alignedHistData.Properties.VariableNames)
                    hubPricesFull = alignedHistData.(hubName);
                    validIdx = ~isnan(nodePricesFull) & ~isnan(hubPricesFull);

                    if sum(validIdx) < 2 % Need at least 2 points for correlation/std
                        fprintf(' → Insufficient common data for hub relationship: %s to %s. Skipping.\n', nodeName, hubName);
                        continue;
                    end
                    
                    nodePricesCommon_local = nodePricesFull(validIdx);
                    hubPrices_local = hubPricesFull(validIdx);
                    commonTimestamps = masterTimestamps(validIdx);
                    
                    correlation = corr(nodePricesCommon_local, hubPrices_local, 'rows', 'complete');
                    currentNodePatterns.hubRelationships.(hubName).correlation = correlation;
                    
                    [~, ~, ~, hours_local, ~, ~] = datevec(commonTimestamps);
                    hourDiffs = nodePricesCommon_local - hubPrices_local;
                    hourNumbers = hours_local + 1;
                    hourlyBasis = zeros(24, 2);
                    if ~isempty(hourNumbers) && any(~isnan(hourDiffs))
                        hourlyBasis(:, 1) = accumarray(hourNumbers, hourDiffs, [24 1], @mean, NaN);
                        hourlyBasis(:, 2) = accumarray(hourNumbers, hourDiffs, [24 1], @std, NaN);
                    else
                        hourlyBasis = nan(24,2);
                    end
                    currentNodePatterns.hubRelationships.(hubName).hourlyBasis = hourlyBasis;
                    fprintf(' → Calculated hub relationship: %s to %s (correlation: %.4f)\n', nodeName, hubName, correlation);
                    end
                end
            end
            
        % === Generation Relationships (using alignedHistData) ===
        if hasGenData && ~isempty(genData) && height(genData) > 0 % Check original genData presence
            currentNodePatterns.genRelationships = struct();
            genNamesTemp = setdiff(genData.Properties.VariableNames, {'Timestamp'}); % Original gen names
            for g_idx = 1:length(genNamesTemp)
                genName = genNamesTemp{g_idx};
                if ismember(genName, alignedHistData.Properties.VariableNames)
                    genLevelsFull = alignedHistData.(genName);
                    validIdx = ~isnan(nodePricesFull) & ~isnan(genLevelsFull);

                    if sum(validIdx) < 2
                        fprintf(' → Insufficient common data for generation relationship: %s to %s. Skipping.\n', nodeName, genName);
                        continue;
                    end

                    nodePricesCommonGen_local = nodePricesFull(validIdx);
                    genLevels_local = genLevelsFull(validIdx);
                    % commonTimestampsGen = masterTimestamps(validIdx); % Not directly used below but available

                    correlationGen = corr(nodePricesCommonGen_local, genLevels_local, 'rows', 'complete');
                    currentNodePatterns.genRelationships.(genName).correlation = correlationGen;
                    
                    nBins = 5;
                    minGen = min(genLevels_local);
                    maxGen = max(genLevels_local);
                    if minGen == maxGen % Handle case where all gen levels are the same
                         binEdges = linspace(minGen - eps(minGen), maxGen + eps(maxGen), nBins+1);
                    else
                         binEdges = linspace(minGen, maxGen, nBins+1);
                    end

                    if isempty(genLevels_local) || all(isnan(genLevels_local))
                        binStats = nan(nBins, 2);
                        binNumbers = [];
                    else
                        [~, ~, binNumbers] = histcounts(genLevels_local, binEdges);
                    end
                    
                    binStats = zeros(nBins, 2);
                    validBinsIdx = binNumbers > 0 & binNumbers <= nBins & ~isnan(nodePricesCommonGen_local(binNumbers > 0 & binNumbers <= nBins));


                    if any(validBinsIdx)
                        % Ensure binNumbers and nodePricesCommonGen_local used in accumarray are aligned
                        % and that binNumbers(validBinsIdx) only contains valid indices for accumarray
                        nodePricesForAccum = nodePricesCommonGen_local(validBinsIdx);
                        binNumbersForAccum = binNumbers(validBinsIdx);
                        
                        if ~isempty(binNumbersForAccum)
                           binStats(:, 1) = accumarray(binNumbersForAccum, nodePricesForAccum, [nBins 1], @mean, NaN);
                           binStats(:, 2) = accumarray(binNumbersForAccum, nodePricesForAccum, [nBins 1], @std, NaN);
                        else
                           binStats = nan(nBins,2);
                        end
                    else
                        binStats = nan(nBins, 2);
                    end
                    currentNodePatterns.genRelationships.(genName).binEdges = binEdges;
                    currentNodePatterns.genRelationships.(genName).binStats = binStats;
                    fprintf(' → Calculated generation relationship: %s to %s (correlation: %.4f)\n', nodeName, genName, correlationGen);
                end
            end
        end
        
        % === Ancillary Relationships (using alignedHistData) ===
        if hasAncillaryData % Check original ancillaryData presence
            currentNodePatterns.ancillaryRelationships = struct();
            % Iterate through the unique ancillary product names found during the join setup
            for s_idx = 1:length(allAncProductNames)
                ancName = allAncProductNames{s_idx}; % e.g., 'NonSpin_Price', 'RegUp_Central'
                
                if ismember(ancName, alignedHistData.Properties.VariableNames)
                    ancPricesFull = alignedHistData.(ancName);
                    validIdx = ~isnan(nodePricesFull) & ~isnan(ancPricesFull);

                    if sum(validIdx) < 5 % Need at least 5 observations for hourly correlation
                        fprintf(' → Insufficient common data for ancillary relationship: %s to %s. Skipping.\n', nodeName, ancName);
                        continue;
                    end
                    
                    nodePricesCommonAnc_local = nodePricesFull(validIdx);
                    ancPrices_local = ancPricesFull(validIdx);
                    commonTimestampsAnc = masterTimestamps(validIdx);
                            
                    correlationAnc = corr(nodePricesCommonAnc_local, ancPrices_local, 'rows', 'complete');
                    currentNodePatterns.ancillaryRelationships.(ancName).correlation = correlationAnc;
                    currentNodePatterns.ancillaryRelationships.(ancName).historicalData = ancPrices_local; 
                    currentNodePatterns.ancillaryRelationships.(ancName).timestamps = commonTimestampsAnc;
                    
                    [~, ~, ~, hoursAnc, ~, ~] = datevec(commonTimestampsAnc);
                    hourNumbers = hoursAnc + 1;
                    hourlyCorr = nan(24, 1);
                    if ~isempty(hourNumbers) && any(~isnan(nodePricesCommonAnc_local)) && any(~isnan(ancPrices_local))
                        for h_loop = 1:24 % Loop 1 to 24 for hourNumbers
                            hourMatchIdx = (hourNumbers == h_loop);
                            if sum(hourMatchIdx) > 5
                                nodeHourlyData = nodePricesCommonAnc_local(hourMatchIdx);
                                ancHourlyData = ancPrices_local(hourMatchIdx);
                                if ~all(isnan(nodeHourlyData)) && ~all(isnan(ancHourlyData))
                                    hourlyCorr(h_loop) = corr(nodeHourlyData, ancHourlyData, 'rows', 'complete');
                end
            end
        end
                    end
                    currentNodePatterns.ancillaryRelationships.(ancName).hourlyCorrelation = hourlyCorr;
                    fprintf(' → Calculated ancillary relationship: %s to %s (correlation: %.4f)\n', nodeName, ancName, correlationAnc);
                end
            end
        end
        
        fprintf(' → Extracted comprehensive patterns for node %s\n', nodeName);
        tempPatternsCell{i} = currentNodePatterns; 
    end

    % Reconstruct the 'patterns' struct from the cell array
    patterns = struct();
    for i = 1:numNodes % Use originalNodeNames for consistency
        nodeName = originalNodeNames{i};
        patterns.(nodeName) = tempPatternsCell{i};
    end
end
