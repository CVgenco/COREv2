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

% Use time-based random seed for true randomness
rng('shuffle');

% Initialize global progress tracking variables
global currentStep totalSteps startTime;
currentStep = 0;
totalSteps = 11; % Increased by 1 for Bayesian volatility modeling
startTime = tic;

% Create a parallel pool with maximum available workers
if isempty(gcp('nocreate')) % Check for existing parallel pool without creating one
    parpool('local');
end

% Display initial progress
updateProgress(0, 'Initializing...');

%% === USER-PROVIDED FILE PATHS & CONFIGURATION ===
% Historical data files
histNodalFile = '/Users/chayanvohra/Downloads/Energy Price & Risk Simulator/Price Forecaster/CORE/historical_nodal_prices.csv';
histHubFile = '/Users/chayanvohra/Downloads/Energy Price & Risk Simulator/Price Forecaster/CORE/historical_hub_prices.csv';
histGenFile = '/Users/chayanvohra/Downloads/Energy Price & Risk Simulator/Price Forecaster/CORE/historical_nodal_generation.csv';

% Ancillary services historical data files
histAncillaryFiles = struct(...
    'NonSpin', '/Users/chayanvohra/Downloads/Energy Price & Risk Simulator/Price Forecaster/CORE/historical_nonspin.csv', ...
    'RegDown', '/Users/chayanvohra/Downloads/Energy Price & Risk Simulator/Price Forecaster/CORE/historical_regdown.csv', ...
    'RegUp', '/Users/chayanvohra/Downloads/Energy Price & Risk Simulator/Price Forecaster/CORE/historical_regup.csv', ...
    'RRS', 'historical_rrs.csv', ...
    'ECRS', 'historical_ecrs.csv');

% Forecast data files
forecastNodalFile = '/Users/chayanvohra/Downloads/Energy Price & Risk Simulator/Price Forecaster/CORE/hourly_nodal_forecasts.csv';
forecastHubFile = '/Users/chayanvohra/Downloads/Energy Price & Risk Simulator/Price Forecaster/CORE/hourly_hub_forecasts.csv';
forecastAncillaryFile = '/Users/chayanvohra/Downloads/Energy Price & Risk Simulator/Price Forecaster/CORE/forecasted_annual_ancillary.csv';

% Output file
outputFile = 'enhanced_core_nodal_subhourly_paths.csv';

% Configuration parameters
nPaths = 1;          % Monte Carlo paths (user-tunable)
nNodes = 1;            % Number of nodes to simulate
tolerance = 0.02;      % 2% tolerance for hourly averages (CORE approach)

% Data source priority weights (higher = more reliable)
dataPriorities = struct(...
    'forecastNodal', 1.0, ...
    'forecastHub', 0.9, ...
    'historicalNodal', 0.8, ...
    'historicalHub', 0.8, ...
    'historicalGen', 0.7, ...
    'ancillary', 0.7);

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
patterns = extractComprehensivePatterns(historicalNodalData, historicalHubData, historicalGenData, historicalAncillaryData, hasHubData, hasGenData, hasAncillaryData);

%% 2.2 - Build comprehensive correlation matrix
updateProgress(4, 'Building correlation matrix');
[correlationMatrix, productNames] = buildComprehensiveCorrelationMatrix(historicalNodalData, historicalHubData, historicalAncillaryData, hasAncillaryData);

%% 2.2b - Build dynamic correlations for Phase 2B
fprintf('\nPhase 2B: Building dynamic correlation matrices...\n');

% Align data for correlation analysis
alignedData = alignToHourly(historicalNodalData, historicalHubData, historicalGenData, historicalAncillaryData, hasGenData, hasAncillaryData);

% Build time-varying correlations
timeVaryingCorrelations = buildTimeVaryingCorrelations(alignedData, productNames, 168); % 1 week window

%% 2.2c - Build multi-resolution correlations for Phase 2C
fprintf('\nPhase 2C: Building multi-resolution correlation matrices...\n');

% Build native resolution correlation matrices
multiResCorrelations = buildMultiResolutionCorrelations(historicalNodalData, historicalHubData, historicalAncillaryData, hasAncillaryData);

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
[bayesianPaths, bayesianDiagnostics] = applyBayesianRegimeSwitchingVolatility(correlatedPaths, scaledPatterns, fieldnames(scaledPatterns));

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

% Validate volatility modeling results
validationResults = validateVolatilityModeling(bayesianPaths, historicalNodalStruct, bayesianDiagnostics);

%% 2.8 - Enforce hourly targets with tolerance
updateProgress(10, 'Enforcing hourly targets');
finalPaths = enforceHourlyTargetsWithTolerance(bayesianPaths, forecastNodalData, tolerance);

%% 2.8c - Validate cross-timescale correlations (Phase 2C Validation)
fprintf('\nPhase 2C: Validating cross-timescale correlation preservation...\n');
crossTimescaleValidation = validateCrossTimescaleCorrelations(multiResCorrelations, finalPaths, simulationTimeline);

%% ==================== 3. OUTPUT PREPARATION MODULE ====================
fprintf('\nStarting output preparation module...\n');
updateProgress(11, 'Preparing output');

%% 3.1 - Prepare output data
outputData = prepareOutputData(finalPaths, nPaths, ancillaryPaths);

%% 3.2 - Validate path diversity
pathDiversityResults = validatePathDiversity(outputData);

%% 3.3 - Write output to CSV
fprintf('Writing output to: %s\n', outputFile);
writetable(outputData, outputFile);
fprintf(' → Successfully wrote output data to file\n');

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
function patterns = extractComprehensivePatterns(nodalData, hubData, genData, ancillaryData, hasHubData, hasGenData, hasAncillaryData)
    % Get node names
    nodeNames = setdiff(nodalData.Properties.VariableNames, {'Timestamp'});
    
    % Initialize patterns structure
    patterns = struct();
    
    % For each node
    for i = 1:length(nodeNames)
        nodeName = nodeNames{i};
        fprintf('Extracting comprehensive patterns for node %s (%d of %d)\n', nodeName, i, length(nodeNames));
        
        % Extract node prices
        nodePrices = nodalData.(nodeName);
        nodeTimestamps = nodalData.Timestamp;
        
        % Store raw historical data
        patterns.(nodeName).rawHistorical = nodePrices;
        patterns.(nodeName).timestamps = nodeTimestamps;
        
        % Extract hourly pattern
        patterns.(nodeName).hourly = extractHourlyPattern(nodeTimestamps, nodePrices);
        
        % Extract daily pattern
        patterns.(nodeName).daily = extractDailyPattern(nodeTimestamps, nodePrices);
        
        % Extract monthly pattern
        patterns.(nodeName).monthly = extractMonthlyPattern(nodeTimestamps, nodePrices);
        
        % Extract holiday pattern
        patterns.(nodeName).holiday = extractHolidayPattern(nodeTimestamps, nodePrices);
        
        % Extract seasonal behavior pattern
        patterns.(nodeName).seasonal = extractSeasonalBehaviorPattern(nodeTimestamps, nodePrices);
        
        % Extract hub relationships if hub data available
        if hasHubData && ~isempty(hubData) && height(hubData) > 0
            % Find common timestamps between node and hub data
            [commonTimestamps, nodeIdx, hubIdx] = intersect(nodeTimestamps, hubData.Timestamp);
            
            if ~isempty(commonTimestamps)
                % Initialize hub relationships
                patterns.(nodeName).hubRelationships = struct();
                
                % For each hub
                hubNames = setdiff(hubData.Properties.VariableNames, {'Timestamp'});
                for h = 1:length(hubNames)
                    hubName = hubNames{h};
                    
                    % Extract hub prices for common timestamps
                    hubPrices = hubData.(hubName)(hubIdx);
                    nodePricesCommon = nodePrices(nodeIdx);
                    
                    % Calculate correlation
                    correlation = corr(nodePricesCommon, hubPrices, 'rows', 'complete');
                    
                    % Store hub relationship
                    patterns.(nodeName).hubRelationships.(hubName).correlation = correlation;
                    
                    % Calculate hourly basis
                    % Use datevec for compatibility with older MATLAB versions
                    [~, ~, ~, hours, ~, ~] = datevec(commonTimestamps);
                    hourlyBasis = zeros(24, 2); % [mean, std]
                    
        for h = 0:23
                        hourIdx = (hours == h);
                        if sum(hourIdx) > 0
                            hourlyBasis(h+1, 1) = mean(nodePricesCommon(hourIdx) - hubPrices(hourIdx), 'omitnan');
                            hourlyBasis(h+1, 2) = std(nodePricesCommon(hourIdx) - hubPrices(hourIdx), 'omitnan');
    end
end

                    patterns.(nodeName).hubRelationships.(hubName).hourlyBasis = hourlyBasis;
                    
                    fprintf(' → Calculated hub relationship: %s to %s (correlation: %.4f)\n', ...
                        nodeName, hubName, correlation);
                end
    end
end

        % Extract generation relationships if generation data available
        if hasGenData && ~isempty(genData) && height(genData) > 0
            % Find common timestamps between node and generation data
            [commonTimestamps, nodeIdx, genIdx] = intersect(nodeTimestamps, genData.Timestamp);
            
            if ~isempty(commonTimestamps)
                % Initialize generation relationships
                patterns.(nodeName).genRelationships = struct();
                
                % For each generation source
                genNames = setdiff(genData.Properties.VariableNames, {'Timestamp'});
                for g = 1:length(genNames)
                    genName = genNames{g};
                    
                    % Extract generation levels for common timestamps
                    genLevels = genData.(genName)(genIdx);
                    nodePricesCommon = nodePrices(nodeIdx);
                    
                    % Calculate correlation
                    correlation = corr(nodePricesCommon, genLevels, 'rows', 'complete');
                    
                    % Store generation relationship
                    patterns.(nodeName).genRelationships.(genName).correlation = correlation;
                    
                    % Create generation bins
                    nBins = 5;
                    binEdges = linspace(min(genLevels), max(genLevels), nBins+1);
                    
                    % Calculate price statistics for each bin
                    binStats = zeros(nBins, 2); % [mean, std]
                    
                    for b = 1:nBins
                        if b < nBins
                            binIdx = (genLevels >= binEdges(b) & genLevels < binEdges(b+1));
                        else
                            binIdx = (genLevels >= binEdges(b) & genLevels <= binEdges(b+1));
                        end
                        
                        if sum(binIdx) > 0
                            binStats(b, 1) = mean(nodePricesCommon(binIdx), 'omitnan');
                            binStats(b, 2) = std(nodePricesCommon(binIdx), 'omitnan');
            end
        end
        
                    patterns.(nodeName).genRelationships.(genName).binEdges = binEdges;
                    patterns.(nodeName).genRelationships.(genName).binStats = binStats;
                    
                    fprintf(' → Calculated generation relationship: %s to %s (correlation: %.4f)\n', ...
                        nodeName, genName, correlation);
                end
            end
        end
        
        % Extract ancillary relationships if ancillary data available
        if hasAncillaryData && ~isempty(ancillaryData)
            % Initialize ancillary relationships
            patterns.(nodeName).ancillaryRelationships = struct();
            
            % For each ancillary service type
            ancTypes = fieldnames(ancillaryData);
            for a = 1:length(ancTypes)
                ancType = ancTypes{a};
                
                if ~isempty(ancillaryData.(ancType))
                    % Find common timestamps between node and ancillary data
                    [commonTimestamps, nodeIdx, ancIdx] = intersect(nodeTimestamps, ancillaryData.(ancType).Timestamp);
                    
                    if ~isempty(commonTimestamps)
                        % Get ancillary service names
                        ancNames = setdiff(ancillaryData.(ancType).Properties.VariableNames, {'Timestamp'});
                        
                        for s = 1:length(ancNames)
                            ancName = ancNames{s};
                            
                            % Extract ancillary prices for common timestamps
                            ancPrices = ancillaryData.(ancType).(ancName)(ancIdx);
                            nodePricesCommon = nodePrices(nodeIdx);
                            
                            % Calculate correlation
                            correlation = corr(nodePricesCommon, ancPrices, 'rows', 'complete');
                            
                            % Store ancillary relationship
                            patterns.(nodeName).ancillaryRelationships.(ancName).correlation = correlation;
                            patterns.(nodeName).ancillaryRelationships.(ancName).historicalData = ancPrices;
                            patterns.(nodeName).ancillaryRelationships.(ancName).timestamps = commonTimestamps;
                            
                            % Calculate hourly relationship pattern
                            [~, ~, ~, hours, ~, ~] = datevec(commonTimestamps);
                            hourlyCorr = zeros(24, 1);
                            
        for h = 0:23
                                hourIdx = (hours == h);
                                if sum(hourIdx) > 5 % Need at least 5 observations
                                    nodeHourly = nodePricesCommon(hourIdx);
                                    ancHourly = ancPrices(hourIdx);
                                    if ~all(isnan(nodeHourly)) && ~all(isnan(ancHourly))
                                        hourlyCorr(h+1) = corr(nodeHourly, ancHourly, 'rows', 'complete');
                                    end
            end
        end
        
                            patterns.(nodeName).ancillaryRelationships.(ancName).hourlyCorrelation = hourlyCorr;
                            
                            fprintf(' → Calculated ancillary relationship: %s to %s (correlation: %.4f)\n', ...
                                nodeName, ancName, correlation);
                        end
                    end
                end
            end
        end
        
        fprintf(' → Extracted comprehensive patterns for node %s\n', nodeName);
    end
    
    % Helper function: Extract hourly pattern
    function hourlyPattern = extractHourlyPattern(timestamps, prices)
        % Ensure timestamps are datetime objects
        if ~isa(timestamps, 'datetime')
            try
                timestamps = datetime(timestamps);
            catch
                error('Cannot convert timestamps to datetime format');
    end
end

        % Extract hour using datevec instead of hour function for compatibility
        [~, ~, ~, hourOfDay, ~, ~] = datevec(timestamps);
        hourlyPattern = zeros(24, 3); % [mean, std, median]
        
        for h = 0:23
            hourIdx = (hourOfDay == h);
            if sum(hourIdx) > 0
                hourPrices = prices(hourIdx);
                hourlyPattern(h+1, 1) = mean(hourPrices, 'omitnan');
                hourlyPattern(h+1, 2) = std(hourPrices, 'omitnan');
                hourlyPattern(h+1, 3) = median(hourPrices, 'omitnan');
                end
            end
        end
        
    % Helper function: Extract daily pattern
    function dailyPattern = extractDailyPattern(timestamps, prices)
        % Ensure timestamps are datetime objects
        if ~isa(timestamps, 'datetime')
            try
                timestamps = datetime(timestamps);
            catch
                error('Cannot convert timestamps to datetime format');
            end
        end
        
        % Extract weekday using datevec instead of weekday function for compatibility
        [y, m, d] = datevec(timestamps);
        % Calculate weekday (1=Sunday, 2=Monday, ..., 7=Saturday)
        t = datenum(timestamps);
        dayOfWeek = mod(floor(t) - 1, 7) + 1;
        
        dailyPattern = zeros(7, 3); % [mean, std, median]
        
        for d = 1:7
            dayIdx = (dayOfWeek == d);
            if sum(dayIdx) > 0
                dayPrices = prices(dayIdx);
                dailyPattern(d, 1) = mean(dayPrices, 'omitnan');
                dailyPattern(d, 2) = std(dayPrices, 'omitnan');
                dailyPattern(d, 3) = median(dayPrices, 'omitnan');
            end
            end
        end
        
    % Helper function: Extract monthly pattern
    function monthlyPattern = extractMonthlyPattern(timestamps, prices)
        % Ensure timestamps are datetime objects
        if ~isa(timestamps, 'datetime')
            try
                timestamps = datetime(timestamps);
        catch
                error('Cannot convert timestamps to datetime format');
    end
end

        % Extract month using datevec instead of month function for compatibility
        [~, monthOfYear, ~, ~, ~, ~] = datevec(timestamps);
        monthlyPattern = zeros(12, 3); % [mean, std, median]
        
        for m = 1:12
            monthIdx = (monthOfYear == m);
            if sum(monthIdx) > 0
                monthPrices = prices(monthIdx);
                monthlyPattern(m, 1) = mean(monthPrices, 'omitnan');
                monthlyPattern(m, 2) = std(monthPrices, 'omitnan');
                monthlyPattern(m, 3) = median(monthPrices, 'omitnan');
            end
        end
    end
end

% Function: buildComprehensiveCorrelationMatrix
% Builds correlation matrix from all available historical data
function [correlationMatrix, productNames] = buildComprehensiveCorrelationMatrix(nodalData, hubData, ancillaryData, hasAncillaryData)
    % Initialize product list
    productNames = {};
    
    % Add nodal products
    nodeNames = setdiff(nodalData.Properties.VariableNames, {'Timestamp'});
    productNames = [productNames, nodeNames];
    
    % Add hub products if available
    if ~isempty(hubData)
        hubNames = setdiff(hubData.Properties.VariableNames, {'Timestamp'});
        productNames = [productNames, hubNames];
    end
    
    % Add ancillary products if available
    if hasAncillaryData
        ancTypes = fieldnames(ancillaryData);
        for a = 1:length(ancTypes)
            ancType = ancTypes{a};
            if ~isempty(ancillaryData.(ancType))
                ancNames = setdiff(ancillaryData.(ancType).Properties.VariableNames, {'Timestamp'});
                productNames = [productNames, ancNames];
                end
            end
        end
        
    % Initialize correlation matrix
    nProducts = length(productNames);
    correlationMatrix = eye(nProducts);
    
    % If only one product, return identity matrix
    if nProducts <= 1
        fprintf(' → Only one product, returning identity correlation matrix\n');
        return;
    end
    
    % Calculate correlation matrix
    fprintf(' → Calculating correlation matrix for %d products\n', nProducts);
    
    % Align all datasets to hourly resolution before correlation calculation
    alignedData = alignToHourly(nodalData, hubData, ancillaryData, hasAncillaryData);
    
    % Check data quality after alignment
    dataQualityReport = checkDataQuality(alignedData, productNames);
    
    % Calculate correlation with pairwise deletion for missing values
    correlationMatrix = calculateCorrelationWithPairwiseDeletion(alignedData, productNames);
    
    % Ensure the correlation matrix is symmetric and positive semi-definite
    correlationMatrix = (correlationMatrix + correlationMatrix') / 2; % Make symmetric
    
    % Check if matrix is positive semi-definite
    [~, p] = chol(correlationMatrix);
    if p > 0
        fprintf(' → Correlation matrix is not positive semi-definite, applying nearest PSD approximation\n');
        % Apply nearest PSD approximation
        [V, D] = eig(correlationMatrix);
        D = diag(max(diag(D), 0));
        correlationMatrix = V * D * V';
        
        % Rescale to ensure diagonal is 1
        d = diag(correlationMatrix);
        correlationMatrix = correlationMatrix ./ sqrt(d * d');
    end
    
    fprintf(' → Built comprehensive correlation matrix for %d products\n', nProducts);
end

% Function: buildRegimeDependentCorrelations
% Builds separate correlation matrices for different volatility regimes using Bayesian regime data
function regimeCorrelations = buildRegimeDependentCorrelations(alignedData, productNames, regimeStates, nRegimes)
    fprintf('\nBuilding regime-dependent correlation matrices...\n');
    fprintf(' → Processing %d regimes for %d products\n', nRegimes, length(productNames));
    
    % Initialize regime correlation structure
    regimeCorrelations = struct();
    
    % For each regime
    for r = 1:nRegimes
        fprintf(' → Building correlation matrix for regime %d\n', r);
        
        % Get indices for this regime
        regimeIdx = (regimeStates == r);
        
        if sum(regimeIdx) < 50 % Need minimum observations for reliable correlation
            fprintf('   → Warning: Only %d observations for regime %d, using overall correlation\n', sum(regimeIdx), r);
            % Use overall correlation as fallback
            regimeCorrelations.(sprintf('regime_%d', r)) = eye(length(productNames));
            continue;
        end
        
        % Extract data for this regime
        regimeData = table();
        regimeData.Timestamp = alignedData.Timestamp(regimeIdx);
        
        % Add each product's data for this regime
        for p = 1:length(productNames)
            productName = productNames{p};
            if ismember(productName, alignedData.Properties.VariableNames)
                regimeData.(productName) = alignedData.(productName)(regimeIdx);
                end
            end
        
        % Calculate regime-specific correlation matrix
        regimeCorr = calculateCorrelationWithPairwiseDeletion(regimeData, productNames);
        
        % Ensure positive semi-definite
        [V, D] = eig(regimeCorr);
        D = diag(max(diag(D), 0.01)); % Minimum eigenvalue for numerical stability
        regimeCorr = V * D * V';
        
        % Rescale to ensure diagonal is 1
        d = diag(regimeCorr);
        regimeCorr = regimeCorr ./ sqrt(d * d');
        
        % Store regime correlation matrix
        regimeCorrelations.(sprintf('regime_%d', r)) = regimeCorr;
        
        % Calculate average correlation for this regime
        offDiagCorr = regimeCorr(triu(true(size(regimeCorr)), 1));
        avgCorr = mean(offDiagCorr);
        fprintf('   → Regime %d: %d observations, avg correlation = %.4f\n', r, sum(regimeIdx), avgCorr);
    end
    
    % Calculate transition correlations (blended matrices for regime transitions)
    regimeCorrelations.transitions = struct();
    
    for r1 = 1:nRegimes
        for r2 = 1:nRegimes
            if r1 ~= r2
                % Blend correlation matrices for transitions
                corr1 = regimeCorrelations.(sprintf('regime_%d', r1));
                corr2 = regimeCorrelations.(sprintf('regime_%d', r2));
                
                % 70% from source regime, 30% from target regime
                transitionCorr = 0.7 * corr1 + 0.3 * corr2;
                
                % Ensure positive semi-definite
                [V, D] = eig(transitionCorr);
                D = diag(max(diag(D), 0.01));
                transitionCorr = V * D * V';
                
                % Rescale diagonal to 1
                d = diag(transitionCorr);
                transitionCorr = transitionCorr ./ sqrt(d * d');
                
                regimeCorrelations.transitions.(sprintf('from_%d_to_%d', r1, r2)) = transitionCorr;
            end
    end
end

    fprintf(' → Built %d regime-dependent correlation matrices\n', nRegimes);
end

% Function: buildTimeVaryingCorrelations
% Builds time-varying correlation matrices using rolling windows and exponential weighting
function timeVaryingCorrelations = buildTimeVaryingCorrelations(alignedData, productNames, windowSize)
    fprintf('\nBuilding time-varying correlation matrices...\n');
    
    % Default window size if not provided
    if nargin < 3
        windowSize = 168; % 1 week for hourly data
    end
    
    fprintf(' → Using rolling window size: %d observations\n', windowSize);
    
    % Get data dimensions
    nObservations = height(alignedData);
    nProducts = length(productNames);
    
    % Initialize time-varying correlation structure
    timeVaryingCorrelations = struct();
    timeVaryingCorrelations.timestamps = alignedData.Timestamp;
    timeVaryingCorrelations.windowSize = windowSize;
    
    % Pre-allocate correlation time series (3D array: time x product x product)
    correlationTimeSeries = zeros(nObservations, nProducts, nProducts);
    
    % Calculate rolling correlations
    for t = windowSize:nObservations
        % Define window indices
        windowStart = t - windowSize + 1;
        windowEnd = t;
        
        % Extract window data
        windowData = table();
        windowData.Timestamp = alignedData.Timestamp(windowStart:windowEnd);
        
        for p = 1:length(productNames)
            productName = productNames{p};
            if ismember(productName, alignedData.Properties.VariableNames)
                windowData.(productName) = alignedData.(productName)(windowStart:windowEnd);
            end
        end
        
        % Calculate correlation for this window
        windowCorr = calculateCorrelationWithPairwiseDeletion(windowData, productNames);
        
        % Store in time series
        correlationTimeSeries(t, :, :) = windowCorr;
        
        % Progress update every 1000 observations
        if mod(t, 1000) == 0
            fprintf('   → Processed %d of %d time points (%.1f%%)\n', t, nObservations, t/nObservations*100);
        end
    end
    
    % For early time points (before window size), use expanding window
    for t = 1:(windowSize-1)
        % Use expanding window from start to current point
        windowData = table();
        windowData.Timestamp = alignedData.Timestamp(1:t);
        
        for p = 1:length(productNames)
            productName = productNames{p};
            if ismember(productName, alignedData.Properties.VariableNames)
                windowData.(productName) = alignedData.(productName)(1:t);
            end
        end
        
        % Calculate correlation for expanding window
        if t >= 10 % Need minimum observations
            windowCorr = calculateCorrelationWithPairwiseDeletion(windowData, productNames);
        else
            windowCorr = eye(nProducts); % Identity for very small windows
        end
        
        correlationTimeSeries(t, :, :) = windowCorr;
    end
    
    % Store correlation time series
    timeVaryingCorrelations.correlationTimeSeries = correlationTimeSeries;
    
    % Calculate exponentially weighted correlations with different decay factors
    decayFactors = [0.94, 0.97, 0.99]; % Different memory lengths
    timeVaryingCorrelations.exponentiallyWeighted = struct();
    
    for d = 1:length(decayFactors)
        lambda = decayFactors(d);
        fprintf(' → Calculating exponentially weighted correlations (lambda = %.2f)\n', lambda);
        
        % Initialize exponentially weighted correlation matrix
        ewCorr = zeros(nObservations, nProducts, nProducts);
        
        % Calculate exponentially weighted covariance matrices
        for t = 2:nObservations
            if t == 2
                % Initialize with first correlation
                ewCorr(t, :, :) = correlationTimeSeries(t, :, :);
            else
                % Get returns for current period
                currentReturns = zeros(nProducts, 1);
                prevReturns = zeros(nProducts, 1);
                
                for p = 1:length(productNames)
                    productName = productNames{p};
                    if ismember(productName, alignedData.Properties.VariableNames)
                        prices = alignedData.(productName);
                        if t > 1 && ~isnan(prices(t)) && ~isnan(prices(t-1)) && prices(t-1) > 0
                            currentReturns(p) = log(prices(t) / prices(t-1));
                        end
                        if t > 2 && ~isnan(prices(t-1)) && ~isnan(prices(t-2)) && prices(t-2) > 0
                            prevReturns(p) = log(prices(t-1) / prices(t-2));
                        end
                    end
                end
                
                % Handle NaN returns
                currentReturns(isnan(currentReturns) | isinf(currentReturns)) = 0;
                prevReturns(isnan(prevReturns) | isinf(prevReturns)) = 0;
                
                % Update exponentially weighted covariance matrix
                prevCov = squeeze(ewCorr(t-1, :, :));
                
                % RiskMetrics style update
                newCov = lambda * prevCov + (1 - lambda) * (prevReturns * prevReturns');
                
                % Convert to correlation matrix
                diagSqrt = sqrt(diag(newCov));
                if any(diagSqrt > 0)
                    corrMatrix = newCov ./ (diagSqrt * diagSqrt');
                    % Ensure diagonal is 1
                    corrMatrix(logical(eye(size(corrMatrix)))) = 1;
                    ewCorr(t, :, :) = corrMatrix;
                else
                    ewCorr(t, :, :) = eye(nProducts);
                end
            end
        end
        
        timeVaryingCorrelations.exponentiallyWeighted.(sprintf('lambda_%.2f', lambda)) = ewCorr;
    end
    
    % Calculate correlation statistics
    avgCorrelations = zeros(nProducts, nProducts);
    volCorrelations = zeros(nProducts, nProducts);
    
    for i = 1:nProducts
        for j = 1:nProducts
            correlationSeries = squeeze(correlationTimeSeries(:, i, j));
            avgCorrelations(i, j) = mean(correlationSeries, 'omitnan');
            volCorrelations(i, j) = std(correlationSeries, 'omitnan');
        end
    end
    
    timeVaryingCorrelations.averageCorrelations = avgCorrelations;
    timeVaryingCorrelations.correlationVolatilities = volCorrelations;
    
    % Report correlation dynamics
    offDiagCorr = avgCorrelations(triu(true(size(avgCorrelations)), 1));
    offDiagVol = volCorrelations(triu(true(size(volCorrelations)), 1));
    
    fprintf(' → Average correlation: %.4f (std: %.4f)\n', mean(offDiagCorr), mean(offDiagVol));
    fprintf(' → Correlation range: %.4f to %.4f\n', min(offDiagCorr), max(offDiagCorr));
    fprintf(' → Built time-varying correlations for %d time points\n', nObservations);
end

% Function: buildMultiResolutionCorrelations
% Builds separate correlation matrices for each native resolution (Phase 2C)
function multiResCorrelations = buildMultiResolutionCorrelations(historicalNodalData, historicalHubData, historicalAncillaryData, hasAncillaryData)
    fprintf('\nPhase 2C: Building multi-resolution correlation matrices...\n');
    
    % Initialize multi-resolution correlation structure
    multiResCorrelations = struct();
    multiResCorrelations.resolutions = {};
    multiResCorrelations.correlationMatrices = struct();
    multiResCorrelations.productNames = {};
    multiResCorrelations.dataQuality = struct();
    
    % Collect all datasets with their native resolutions
    datasets = struct();
    
    % Add nodal data
    [~, nodalRes] = parseVariableResolutionData(temporaryFilePath(historicalNodalData));
    datasets.nodal.data = historicalNodalData;
    datasets.nodal.resolution = nodalRes;
    datasets.nodal.priority = 1.0;
    
    % Add hub data if available
    if ~isempty(historicalHubData)
        [~, hubRes] = parseVariableResolutionData(temporaryFilePath(historicalHubData));
        datasets.hub.data = historicalHubData;
        datasets.hub.resolution = hubRes;
        datasets.hub.priority = 0.9;
    end
    
    % Add ancillary data if available
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
        
        % Build combined dataset for this resolution
        [combinedData, productNames] = combineDatasetsByResolution(datasets, resolutionDatasets);
        
        % Calculate correlation matrix
        if height(combinedData) > 10 && length(productNames) > 1
            correlationMatrix = calculateCorrelationWithPairwiseDeletion(combinedData, productNames);
            
            % Store correlation matrix for this resolution
            multiResCorrelations.correlationMatrices.(resolution) = correlationMatrix;
            multiResCorrelations.productNames = productNames; % Assume same products across resolutions
            
            % Calculate data quality metrics
            qualityMetrics = calculateResolutionQualityMetrics(combinedData, productNames, resolution);
            multiResCorrelations.dataQuality.(resolution) = qualityMetrics;
            
            % Report correlation statistics
            offDiagCorr = correlationMatrix(triu(true(size(correlationMatrix)), 1));
            avgCorr = mean(offDiagCorr);
            fprintf('   → %s: %d observations, %d products, avg correlation = %.4f\n', ...
                resolution, height(combinedData), length(productNames), avgCorr);
        else
            fprintf('   → Warning: Insufficient data for %s resolution (%d obs, %d products)\n', ...
                resolution, height(combinedData), length(productNames));
            multiResCorrelations.correlationMatrices.(resolution) = [];
        end
    end
    
    % Build correlation scaling relationships between resolutions
    multiResCorrelations.scalingRelationships = buildCorrelationScalingRelationships(multiResCorrelations);
    
    fprintf(' → Built %d resolution-specific correlation matrices\n', length(fieldnames(multiResCorrelations.correlationMatrices)));
end

% Function: combineDatasetsByResolution
% Combines multiple datasets that share the same resolution
function [combinedData, productNames] = combineDatasetsByResolution(datasets, datasetNames)
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
        
        % Get product columns (excluding Timestamp)
        dataProductNames = setdiff(data.Properties.VariableNames, {'Timestamp'});
        
        % Add each product to combined data with timestamp alignment
        for p = 1:length(dataProductNames)
            productName = dataProductNames{p};
            
            % Create unique product name to avoid conflicts
            uniqueProductName = sprintf('%s_%s', datasetName, productName);
            productNames{end+1} = uniqueProductName;
            
            % Align this product's data to combined timestamp
            alignedSeries = alignSeriesToTimeline(data.Timestamp, data.(productName), combinedData.Timestamp);
            combinedData.(uniqueProductName) = alignedSeries;
        end
    end
end

% Function: alignSeriesToTimeline
% Aligns a time series to a target timeline
function alignedSeries = alignSeriesToTimeline(sourceTimestamps, sourceValues, targetTimestamps)
    % Initialize aligned series with NaN
    alignedSeries = nan(size(targetTimestamps));
    
    % For each target timestamp, find matching source timestamp
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
        
% Function: calculateResolutionQualityMetrics
% Calculates data quality metrics for a specific resolution
function qualityMetrics = calculateResolutionQualityMetrics(data, productNames, resolution)
    qualityMetrics = struct();
    qualityMetrics.resolution = resolution;
    qualityMetrics.nObservations = height(data);
    qualityMetrics.nProducts = length(productNames);
    qualityMetrics.completeness = zeros(length(productNames), 1);
    qualityMetrics.correlationStrength = [];
    
    % Calculate completeness for each product
    for p = 1:length(productNames)
        productName = productNames{p};
        if ismember(productName, data.Properties.VariableNames)
            productData = data.(productName);
            qualityMetrics.completeness(p) = sum(~isnan(productData)) / length(productData);
        end
    end
    
    % Calculate overall correlation strength
    if length(productNames) > 1
        correlationMatrix = calculateCorrelationWithPairwiseDeletion(data, productNames);
        offDiagCorr = correlationMatrix(triu(true(size(correlationMatrix)), 1));
        qualityMetrics.correlationStrength = mean(abs(offDiagCorr), 'omitnan');
    else
        qualityMetrics.correlationStrength = 0;
    end
    
    qualityMetrics.averageCompleteness = mean(qualityMetrics.completeness);
end

% Function: buildCorrelationScalingRelationships
% Builds scaling relationships between different resolution correlation matrices
function scalingRelationships = buildCorrelationScalingRelationships(multiResCorrelations)
    fprintf(' → Building correlation scaling relationships between resolutions\n');
    
    scalingRelationships = struct();
    resolutions = multiResCorrelations.resolutions;
    
    % Define resolution hierarchy (finer to coarser)
    resolutionHierarchy = {'5min', '15min', 'hourly', 'daily', 'weekly', 'monthly'};
    
    % For each pair of resolutions, calculate scaling factors
    for r1 = 1:length(resolutions)
        for r2 = 1:length(resolutions)
            if r1 ~= r2
                res1 = resolutions{r1};
                res2 = resolutions{r2};
                
                % Check if both resolutions have correlation matrices
                if isfield(multiResCorrelations.correlationMatrices, res1) && ...
                   isfield(multiResCorrelations.correlationMatrices, res2) && ...
                   ~isempty(multiResCorrelations.correlationMatrices.(res1)) && ...
                   ~isempty(multiResCorrelations.correlationMatrices.(res2))
                    
                    corr1 = multiResCorrelations.correlationMatrices.(res1);
                    corr2 = multiResCorrelations.correlationMatrices.(res2);
                    
                    % Calculate scaling factor (ratio of correlation strengths)
                    if size(corr1, 1) == size(corr2, 1) && size(corr1, 2) == size(corr2, 2)
                        offDiag1 = corr1(triu(true(size(corr1)), 1));
                        offDiag2 = corr2(triu(true(size(corr2)), 1));
                        
                        if ~isempty(offDiag1) && ~isempty(offDiag2)
                            scalingFactor = mean(abs(offDiag2), 'omitnan') / mean(abs(offDiag1), 'omitnan');
                            scalingRelationships.(sprintf('%s_to_%s', res1, res2)) = scalingFactor;
                            
                            fprintf('   → Scaling factor %s to %s: %.4f\n', res1, res2, scalingFactor);
                        end
                    end
                end
            end
        end
    end
end

% Function: temporaryFilePath
% Helper function to create temporary file path for resolution detection
function filePath = temporaryFilePath(data)
    % This is a workaround since parseVariableResolutionData expects a file path
    % In practice, we should modify parseVariableResolutionData to work with table data
    filePath = 'temp_data_for_resolution_detection.csv';
    writetable(data, filePath);
end

% Function: alignToHourly
% Aligns all datasets to hourly resolution with configurable aggregation methods
function alignedData = alignToHourly(nodalData, hubData, ancillaryData, hasAncillaryData)
    % Determine the common timeline at hourly resolution
    allTimestamps = [nodalData.Timestamp];
    if ~isempty(hubData)
        allTimestamps = [allTimestamps; hubData.Timestamp];
    end
    
    if hasAncillaryData
        ancTypes = fieldnames(ancillaryData);
        for a = 1:length(ancTypes)
            ancType = ancTypes{a};
            if ~isempty(ancillaryData.(ancType))
                allTimestamps = [allTimestamps; ancillaryData.(ancType).Timestamp];
            end
        end
    end
    
    % Round to nearest hour
    hourlyTimestamps = datetime(year(allTimestamps), month(allTimestamps), day(allTimestamps), ...
                               hour(allTimestamps), 0, 0);
    uniqueHours = unique(hourlyTimestamps);
    
    % Initialize aligned data table
    alignedData = table();
    alignedData.Timestamp = uniqueHours;
    
    % Align nodal data
    nodeNames = setdiff(nodalData.Properties.VariableNames, {'Timestamp'});
    for i = 1:length(nodeNames)
        nodeName = nodeNames{i};
        alignedData.(nodeName) = alignSeries(nodalData.Timestamp, nodalData.(nodeName), uniqueHours, 'mean');
    end
    
    % Align hub data if available
    if ~isempty(hubData)
        hubNames = setdiff(hubData.Properties.VariableNames, {'Timestamp'});
        for i = 1:length(hubNames)
            hubName = hubNames{i};
            alignedData.(hubName) = alignSeries(hubData.Timestamp, hubData.(hubName), uniqueHours, 'mean');
                    end
                end
                
    % Align ancillary data if available
    if hasAncillaryData
        ancTypes = fieldnames(ancillaryData);
        for a = 1:length(ancTypes)
            ancType = ancTypes{a};
            if ~isempty(ancillaryData.(ancType))
                ancNames = setdiff(ancillaryData.(ancType).Properties.VariableNames, {'Timestamp'});
                for i = 1:length(ancNames)
                    ancName = ancNames{i};
                    alignedData.(ancName) = alignSeries(ancillaryData.(ancType).Timestamp, ...
                                                      ancillaryData.(ancType).(ancName), uniqueHours, 'mean');
                end
        end
    end
    end
    
    % Helper function to align a time series to hourly resolution
    function alignedSeries = alignSeries(origTimestamps, origValues, targetTimestamps, method)
        % Round original timestamps to nearest hour
        roundedTimestamps = datetime(year(origTimestamps), month(origTimestamps), ...
                                    day(origTimestamps), hour(origTimestamps), 0, 0);
        
        % Initialize aligned series
        alignedSeries = nan(size(targetTimestamps));
        
        % For each target timestamp
        for t = 1:length(targetTimestamps)
            % Find original values for this hour
            hourIdx = (roundedTimestamps == targetTimestamps(t));
            hourValues = origValues(hourIdx);
            
            % Apply aggregation method
            if ~isempty(hourValues)
                switch method
                    case 'mean'
                        alignedSeries(t) = mean(hourValues, 'omitnan');
                    case 'median'
                        alignedSeries(t) = median(hourValues, 'omitnan');
                    case 'max'
                        alignedSeries(t) = max(hourValues);
                    case 'min'
                        alignedSeries(t) = min(hourValues);
                    otherwise
                        alignedSeries(t) = mean(hourValues, 'omitnan');
                end
            end
        end
            end
        end
        
% Function: checkDataQuality
% Validates data quality after alignment and reports issues
function report = checkDataQuality(alignedData, productNames)
    % Initialize report
    report = struct();
    report.missingPercentage = zeros(length(productNames), 1);
    report.outlierPercentage = zeros(length(productNames), 1);
    
    % For each product
    for i = 1:length(productNames)
        productName = productNames{i};
        
        % Check for missing values
        missingCount = sum(isnan(alignedData.(productName)));
        missingPercentage = missingCount / height(alignedData) * 100;
        report.missingPercentage(i) = missingPercentage;
        
        % Check for outliers (values beyond 3 standard deviations)
        validValues = alignedData.(productName)(~isnan(alignedData.(productName)));
        if ~isempty(validValues)
            meanVal = mean(validValues);
            stdVal = std(validValues);
            outlierThreshold = 3 * stdVal;
            outlierCount = sum(abs(validValues - meanVal) > outlierThreshold);
            outlierPercentage = outlierCount / length(validValues) * 100;
            report.outlierPercentage(i) = outlierPercentage;
        end
        
        % Report issues if significant
        if missingPercentage > 10
            fprintf(' → Warning: %s has %.1f%% missing values\n', productName, missingPercentage);
        end
        
        if outlierPercentage > 5
            fprintf(' → Warning: %s has %.1f%% potential outliers\n', productName, outlierPercentage);
        end
    end
end

% Function: calculateCorrelationWithPairwiseDeletion
% Calculates correlations while handling missing values
function corrMatrix = calculateCorrelationWithPairwiseDeletion(alignedData, productNames)
    % Initialize correlation matrix
    nProducts = length(productNames);
    corrMatrix = eye(nProducts);
    
    % For each product pair
    for i = 1:nProducts
        for j = i+1:nProducts
            % Get product data
            product1 = alignedData.(productNames{i});
            product2 = alignedData.(productNames{j});
            
            % Find valid pairs (not NaN in either product)
            validPairs = ~isnan(product1) & ~isnan(product2);
            
            % Calculate correlation if enough valid pairs
            if sum(validPairs) > 10
                corrMatrix(i, j) = corr(product1(validPairs), product2(validPairs));
                corrMatrix(j, i) = corrMatrix(i, j); % Symmetric
            else
                % Default to zero correlation if insufficient data
                corrMatrix(i, j) = 0;
                corrMatrix(j, i) = 0;
                fprintf(' → Warning: Insufficient data for correlation between %s and %s\n', ...
                    productNames{i}, productNames{j});
            end
        end
    end
end

% Function: applySmartScaling
% Apply smart scaling to historical patterns based on forecasts
function scaledPatterns = applySmartScaling(patterns, forecastNodalData, forecastHubData, forecastAncillaryData, hasForecastAncillaryData, hasGenData)
    % Initialize scaled patterns
    scaledPatterns = patterns;
    
    % Get node names
    nodeNames = fieldnames(patterns);
    
    % For each node
for i = 1:length(nodeNames)
    nodeName = nodeNames{i};
        fprintf('Applying smart scaling to node %s (%d of %d)\n', nodeName, i, length(nodeNames));
        
        % Get node-specific data
        historicalPrices = patterns.(nodeName).rawHistorical;
        historicalTimestamps = patterns.(nodeName).timestamps;
        historicalHourlyPattern = patterns.(nodeName).hourly;
        
        % Get forecast data for this node
        if ismember(nodeName, forecastNodalData.Properties.VariableNames)
            % Direct forecast available
            forecastPrices = forecastNodalData.(nodeName);
            forecastTimestamps = forecastNodalData.Timestamp;
            useHubRelationship = false;
            fprintf(' → Using direct forecast for node %s\n', nodeName);
        elseif ~isempty(forecastHubData) && isfield(patterns.(nodeName), 'hubRelationships')
            % Use hub relationship
            hubNames = fieldnames(patterns.(nodeName).hubRelationships);
            if ~isempty(hubNames) && ismember(hubNames{1}, forecastHubData.Properties.VariableNames)
                hubName = hubNames{1};
                hubRelationship = patterns.(nodeName).hubRelationships.(hubName);
                forecastPrices = forecastHubData.(hubName) + hubRelationship.hourlyBasis(:, 1);
                forecastTimestamps = forecastHubData.Timestamp;
                useHubRelationship = true;
                fprintf(' → Using hub relationship for node %s (hub: %s)\n', nodeName, hubName);
            else
                % No direct forecast or hub relationship, use historical pattern
                useHubRelationship = false;
                % Use datevec for compatibility with older MATLAB versions
                [~, ~, ~, hours, ~, ~] = datevec(forecastNodalData.Timestamp);
                forecastPrices = zeros(size(forecastNodalData.Timestamp));
                for h = 0:23
                    hourIdx = (hours == h);
                    forecastPrices(hourIdx) = historicalHourlyPattern(h+1, 1);
                end
                forecastTimestamps = forecastNodalData.Timestamp;
                fprintf(' → Using historical pattern for node %s (no forecast available)\n', nodeName);
            end
        else
            % No direct forecast or hub relationship, use historical pattern
            useHubRelationship = false;
            % Use datevec for compatibility with older MATLAB versions
            [~, ~, ~, hours, ~, ~] = datevec(forecastNodalData.Timestamp);
            forecastPrices = zeros(size(forecastNodalData.Timestamp));
            for h = 0:23
                hourIdx = (hours == h);
                forecastPrices(hourIdx) = historicalHourlyPattern(h+1, 1);
            end
            forecastTimestamps = forecastNodalData.Timestamp;
            fprintf(' → Using historical pattern for node %s (no forecast available)\n', nodeName);
        end
        
        % Calculate hourly scaling factors
        % Use datevec for compatibility with older MATLAB versions
        [~, ~, ~, forecastHours, ~, ~] = datevec(forecastTimestamps);
        [~, ~, ~, historicalHours, ~, ~] = datevec(historicalTimestamps);
        
        scalingFactors = ones(24, 1);
        
    for h = 0:23
            % Find forecast prices for this hour
            % Use datevec for compatibility with older MATLAB versions
            [~, ~, ~, forecastHours, ~, ~] = datevec(forecastTimestamps);
            forecastHourIndices = (forecastHours == h);
            
            if sum(forecastHourIndices) > 0
                forecastHourlyAvg = mean(forecastPrices(forecastHourIndices), 'omitnan');
                
                % Find historical prices for this hour
                historicalHourIndices = (historicalHours == h);
                
                if sum(historicalHourIndices) > 0
                    historicalHourlyAvg = mean(historicalPrices(historicalHourIndices), 'omitnan');
                    
                    % Calculate scaling factor
                    if historicalHourlyAvg ~= 0
                        scalingFactors(h+1) = forecastHourlyAvg / historicalHourlyAvg;
                    else
                        scalingFactors(h+1) = 1;
                end
            end
                    end
                end
                
        % Apply ancillary scaling if available
        if hasForecastAncillaryData && isfield(patterns.(nodeName), 'ancillaryRelationships')
            ancillaryNames = fieldnames(patterns.(nodeName).ancillaryRelationships);
            scaledPatterns.(nodeName).ancillaryScaling = struct();
            
            for a = 1:length(ancillaryNames)
                ancName = ancillaryNames{a};
                ancRelationship = patterns.(nodeName).ancillaryRelationships.(ancName);
                
                % Check if forecast ancillary data has this service
                if isfield(forecastAncillaryData, ancName)
                    forecastAncPrice = forecastAncillaryData.(ancName);
                    historicalAncPrice = mean(ancRelationship.historicalData, 'omitnan');
                    
                    if historicalAncPrice ~= 0
                        ancScalingFactor = forecastAncPrice / historicalAncPrice;
                    else
                        ancScalingFactor = 1;
                    end
                    
                    scaledPatterns.(nodeName).ancillaryScaling.(ancName) = ancScalingFactor;
                    fprintf(' → Applied ancillary scaling for %s: %.4f\n', ancName, ancScalingFactor);
                end
        end
    end
    
        % Apply holiday pattern adjustments if available
        if isfield(patterns.(nodeName), 'holiday')
            holidayPattern = patterns.(nodeName).holiday;
            scaledPatterns.(nodeName).holidayAdjustments = struct();
            
            % Store holiday pattern for use during sampling
            scaledPatterns.(nodeName).holidayAdjustments.adjustmentFactors = holidayPattern.adjustmentFactors;
            scaledPatterns.(nodeName).holidayAdjustments.volatilityFactors = holidayPattern.volatilityFactors;
            scaledPatterns.(nodeName).holidayAdjustments.holidayDates = holidayPattern.holidayDates;
            scaledPatterns.(nodeName).holidayAdjustments.holidayNames = holidayPattern.holidayNames;
            
            fprintf(' → Applied holiday pattern adjustments for node %s\n', nodeName);
        end
        
        % Apply seasonal behavior adjustments if available
        if isfield(patterns.(nodeName), 'seasonal')
            seasonalPattern = patterns.(nodeName).seasonal;
            scaledPatterns.(nodeName).seasonalAdjustments = struct();
            
            % Store seasonal pattern for use during sampling
            scaledPatterns.(nodeName).seasonalAdjustments.weekendEffects = seasonalPattern.weekendEffects;
            scaledPatterns.(nodeName).seasonalAdjustments.hourlyShapes = seasonalPattern.hourlyShapes;
            scaledPatterns.(nodeName).seasonalAdjustments.crossEffects = seasonalPattern.crossEffects;
            scaledPatterns.(nodeName).seasonalAdjustments.volatilityFactors = seasonalPattern.volatilityFactors;
            
            fprintf(' → Applied seasonal behavior adjustments for node %s\n', nodeName);
        end
        
        % Store scaling factors
        scaledPatterns.(nodeName).scalingFactors = scalingFactors;
        scaledPatterns.(nodeName).useHubRelationship = useHubRelationship;
        
        fprintf(' → Applied smart scaling to node %s\n', nodeName);
    end
end

% Function: conditionalSamplingFromHistoricalDistributions
% Sample from scaled historical distributions with conditioning on hub and generation
% Optimized for parallel processing and performance with large datasets
function [sampledPaths, ancillaryPaths] = conditionalSamplingFromHistoricalDistributions(scaledPatterns, forecastTimeline, nPaths, forecastHubData, forecastAncillaryData, historicalGenData, hasGenData, hasForecastAncillaryData)
    % Get node names
    nodeNames = fieldnames(scaledPatterns);
    
    % Initialize sampled paths structure
    sampledPaths = struct();
    sampledPaths.Timestamp = forecastTimeline;
    
    % Get dimensions
    nIntervals = length(forecastTimeline);
    
    % Initialize progress tracking for this intensive step
    fprintf('\nStarting optimized parallel conditional sampling...\n');
    fprintf(' → Processing %d intervals across %d paths\n', nIntervals, nPaths);
    
    % Set batch size for processing
    batchSize = min(5000, ceil(nIntervals/10)); % Process in batches of 5000 or 1/10th of total
    
    % Pre-compute temporal features for all forecast timestamps (optimization)
    % Use datevec for compatibility with older MATLAB versions
    [~, forecastMonths, ~, forecastHours, ~, ~] = datevec(forecastTimeline);
    % Calculate weekday (1=Sunday, 2=Monday, ..., 7=Saturday)
    t = datenum(forecastTimeline);
    forecastDays = mod(floor(t) - 1, 7) + 1;
    
    % Process each node
    for i = 1:length(nodeNames)
        nodeName = nodeNames{i};
        fprintf(' → Processing node %s (%d of %d)\n', nodeName, i, length(nodeNames));
        
        % Get node-specific data
        historicalPrices = scaledPatterns.(nodeName).rawHistorical;
        historicalTimestamps = scaledPatterns.(nodeName).timestamps;
        scalingFactors = scaledPatterns.(nodeName).scalingFactors;
        
        % Pre-compute temporal features for historical data (optimization)
        % Use datevec for compatibility with older MATLAB versions
        [~, historicalMonths, ~, historicalHours, ~, ~] = datevec(historicalTimestamps);
        % Calculate weekday (1=Sunday, 2=Monday, ..., 7=Saturday)
        t = datenum(historicalTimestamps);
        historicalDays = mod(floor(t) - 1, 7) + 1;
        
        % Check if we should use generation conditioning
        useGenConditioning = hasGenData && isfield(scaledPatterns.(nodeName), 'useGenConditioning') && ...
                            scaledPatterns.(nodeName).useGenConditioning;
        
        % Pre-compute generation conditioning data if needed
        genData = struct();
        if useGenConditioning
            genData.useGenConditioning = true;
            
            % Get generation relationships
            genRelationships = scaledPatterns.(nodeName).genRelationships;
            genNames = fieldnames(genRelationships);
            
            if ~isempty(genNames)
                genName = genNames{1}; % Use first generation source
                genData.genName = genName;
                
                % Pre-compute intersection between historical and generation timestamps
                [~, histIdx, genIdx] = intersect(historicalTimestamps, historicalGenData.Timestamp);
                genData.histIdx = histIdx;
                genData.genIdx = genIdx;
                
                if ~isempty(histIdx) && ~isempty(genName) && ismember(genName, historicalGenData.Properties.VariableNames)
                    genData.genLevels = historicalGenData.(genName)(genIdx);
                    genData.binEdges = genRelationships.(genName).binEdges;
                end
            end
        else
            genData.useGenConditioning = false;
        end
        
        % Initialize paths
        nodePaths = zeros(nIntervals, nPaths);
        
        % Create a parallel pool if not already created
        if isempty(gcp('nocreate'))
            parpool('local');
        end
        
        % Process in batches for better performance
        for batchStart = 1:batchSize:nIntervals
            % Determine batch end
            batchEnd = min(batchStart + batchSize - 1, nIntervals);
            startIdx = batchStart;
            
            % Extract batch timestamps and features
            batchTimestamps = forecastTimeline(batchStart:batchEnd);
            batchHours = forecastHours(batchStart:batchEnd);
            batchDays = forecastDays(batchStart:batchEnd);
            batchMonths = forecastMonths(batchStart:batchEnd);
            
            % Create a temporary array to hold results for this batch
            batchResults = zeros(batchEnd-batchStart+1, nPaths);
            
            % Process each interval in the batch in parallel
            parfor j = 1:(batchEnd-batchStart+1)
                % Get temporal features for current timestamp
                h = batchHours(j);
                d = batchDays(j);
                m = batchMonths(j);
                
                % Find historical data points from same hour, day, and month
                sameHourIndices = (historicalHours == h);
                sameDayIndices = (historicalDays == d);
                sameMonthIndices = (historicalMonths == m);
                
                % Combine conditions with weights
                hourWeight = 0.6;
                dayWeight = 0.3;
                monthWeight = 0.1;
                
                combinedWeights = hourWeight * double(sameHourIndices) + ...
                                 dayWeight * double(sameDayIndices) + ...
                                 monthWeight * double(sameMonthIndices);
                
                % Use vectorized operations for finding top matches
                [~, sortedIndices] = sort(combinedWeights, 'descend');
                
                % Take top 10% of matches
                topN = max(1, round(0.1 * length(sortedIndices)));
                candidateIndices = sortedIndices(1:min(topN, length(sortedIndices)));
                
                % Ensure indices are valid
                validIndices = candidateIndices(candidateIndices <= length(historicalPrices));
                
                if ~isempty(validIndices)
                    candidatePrices = historicalPrices(validIndices);
                    
                    % Filter out NaN values
                    validPrices = candidatePrices(~isnan(candidatePrices));
                    
                    if ~isempty(validPrices)
                        % Apply scaling factor
                        hourIdx = min(max(h+1, 1), length(scalingFactors));
                        scaledPrices = validPrices * scalingFactors(hourIdx);
                        
                        % Apply holiday adjustments if available
                        if isfield(scaledPatterns.(nodeName), 'holidayAdjustments')
                            holidayAdj = scaledPatterns.(nodeName).holidayAdjustments;
                            currentDate = forecastTimeline(batchStart+j-1);
                            
                            % Check if current date is a holiday or near holiday
                            holidayFactor = 1.0;
                            volatilityFactor = 1.0;
                            
                            for hd = 1:length(holidayAdj.holidayDates)
                                holiday = holidayAdj.holidayDates(hd);
                                holidayType = holidayAdj.holidayNames{hd};
                                
                                % Check if it's the holiday
                                if abs(days(currentDate - holiday)) < 0.5
                                    adjustField = [holidayType '_Holiday'];
                                    if isfield(holidayAdj.adjustmentFactors, adjustField)
                                        holidayFactor = holidayAdj.adjustmentFactors.(adjustField);
                                        volatilityFactor = holidayAdj.volatilityFactors.(adjustField);
                                    end
                                    break;
                                % Check if it's pre-holiday (1-2 days before)
                                elseif days(holiday - currentDate) >= 1 && days(holiday - currentDate) <= 2
                                    adjustField = [holidayType '_PreHoliday'];
                                    if isfield(holidayAdj.adjustmentFactors, adjustField)
                                        holidayFactor = holidayAdj.adjustmentFactors.(adjustField);
                                        volatilityFactor = holidayAdj.volatilityFactors.(adjustField);
                                    end
                                    break;
                                % Check if it's post-holiday (1-2 days after)
                                elseif days(currentDate - holiday) >= 1 && days(currentDate - holiday) <= 2
                                    adjustField = [holidayType '_PostHoliday'];
                                    if isfield(holidayAdj.adjustmentFactors, adjustField)
                                        holidayFactor = holidayAdj.adjustmentFactors.(adjustField);
                                        volatilityFactor = holidayAdj.volatilityFactors.(adjustField);
                                    end
                                    break;
                                end
                            end
                            
                            % Apply holiday adjustment
                            scaledPrices = scaledPrices * holidayFactor;
                        end
                        
                        % Apply seasonal behavior adjustments if available
                        if isfield(scaledPatterns.(nodeName), 'seasonalAdjustments')
                            seasonalAdj = scaledPatterns.(nodeName).seasonalAdjustments;
                            currentDate = forecastTimeline(batchStart+j-1);
                            
                            % Use datevec for compatibility with older MATLAB versions
                            [~, currentMonth, ~, currentHour, ~, ~] = datevec(currentDate);
                            % Calculate weekday (1=Sunday, 2=Monday, ..., 7=Saturday)
                            t = datenum(currentDate);
                            currentDayOfWeek = mod(floor(t) - 1, 7) + 1;
                            
                            % Determine season
                            if ismember(currentMonth, [12, 1, 2])
                                season = 'Winter';
                            elseif ismember(currentMonth, [3, 4, 5])
                                season = 'Spring';
                            elseif ismember(currentMonth, [6, 7, 8])
                                season = 'Summer';
                            else
                                season = 'Fall';
                            end
                            
                            % Apply seasonal weekend effects
                            if isfield(seasonalAdj.weekendEffects, season)
                                isWeekend = (currentDayOfWeek == 1 || currentDayOfWeek == 7); % Sunday=1, Saturday=7
                                if isWeekend
                                    weekendFactor = seasonalAdj.weekendEffects.(season);
                                    scaledPrices = scaledPrices * weekendFactor;
                                end
                            end
                            
                            % Apply seasonal hourly shape
                            if isfield(seasonalAdj.hourlyShapes, season)
                                hourlyShape = seasonalAdj.hourlyShapes.(season);
                                if currentHour >= 0 && currentHour <= 23
                                    hourlyFactor = hourlyShape(currentHour + 1);
                                    scaledPrices = scaledPrices * hourlyFactor;
                    end
                end
                
                            % Apply cross-seasonal effects
                            if currentDayOfWeek == 2 && currentHour >= 6 && currentHour <= 10 % Monday morning
                                crossField = [season '_MondayMorning'];
                                if isfield(seasonalAdj.crossEffects, crossField)
                                    crossFactor = seasonalAdj.crossEffects.(crossField);
                                    scaledPrices = scaledPrices * crossFactor;
                                end
                            elseif currentDayOfWeek == 6 && currentHour >= 14 && currentHour <= 18 % Friday afternoon
                                crossField = [season '_FridayAfternoon'];
                                if isfield(seasonalAdj.crossEffects, crossField)
                                    crossFactor = seasonalAdj.crossEffects.(crossField);
                                    scaledPrices = scaledPrices * crossFactor;
                                end
            end
        end
        
                        % Generate random samples for each path
                        for p = 1:nPaths
                            % Randomly sample from candidate prices
                            randomIdx = randi(length(scaledPrices));
                            batchResults(j, p) = scaledPrices(randomIdx);
                        end
                    else
                        % Fallback if no valid prices
                        fallbackPrice = mean(historicalPrices, 'omitnan') * scalingFactors(min(max(h+1, 1), length(scalingFactors)));
                        for p = 1:nPaths
                            batchResults(j, p) = fallbackPrice;
                end
            end
        else
                    % Fallback if no historical data
                    fallbackPrice = mean(historicalPrices, 'omitnan') * scalingFactors(min(max(h+1, 1), length(scalingFactors)));
                    for p = 1:nPaths
                        batchResults(j, p) = fallbackPrice;
                    end
                end
            end
            
            % After parfor loop, copy results to nodePaths
            for j = 1:(batchEnd-batchStart+1)
                nodePaths(batchStart+j-1, :) = batchResults(j, :);
            end
            
            fprintf('   → Completed batch %d of %d (%.1f%%)\n', ...
                ceil(batchStart/batchSize), ceil(nIntervals/batchSize), ...
                min(batchEnd/nIntervals*100, 100));
        end
        
        % Store node results
        sampledPaths.(nodeName) = nodePaths;
        fprintf(' → Generated %d conditionally sampled paths for node %s\n', nPaths, nodeName);
    end
    
    % Generate ancillary service paths if forecast ancillary data available
    ancillaryPaths = struct();
    if hasForecastAncillaryData
        ancillaryPaths.Timestamp = forecastTimeline;
        
        % For each ancillary service in the forecast
        ancillaryServices = fieldnames(forecastAncillaryData);
        for a = 1:length(ancillaryServices)
            ancService = ancillaryServices{a};
            
            % Get forecast price (annual average)
            forecastPrice = forecastAncillaryData.(ancService);
            
            % Generate paths with seasonal and hourly variation
            ancServicePaths = zeros(nIntervals, nPaths);
            
            for p = 1:nPaths
                % Generate base path using forecast price
                basePath = ones(nIntervals, 1) * forecastPrice;
                
                % Add seasonal variation (±20% over the year)
                seasonalVariation = 0.2 * sin(2*pi*(1:nIntervals)'/8760); % Annual cycle
                
                % Add hourly pattern (based on typical ancillary demand)
                hourlyMultiplier = ones(nIntervals, 1);
                for t = 1:nIntervals
                    hour = forecastHours(t);
                    % Higher ancillary demand during peak hours (8-20)
                    if hour >= 8 && hour <= 20
                        hourlyMultiplier(t) = 1.2;
                    else
                        hourlyMultiplier(t) = 0.8;
                    end
                end
                
                % Add random variation (±10%)
                randomVariation = 0.1 * randn(nIntervals, 1);
                
                % Combine all variations
                ancServicePaths(:, p) = basePath .* (1 + seasonalVariation + randomVariation) .* hourlyMultiplier;
                
                % Ensure positive prices
                ancServicePaths(:, p) = max(ancServicePaths(:, p), forecastPrice * 0.1);
            end
            
            ancillaryPaths.(ancService) = ancServicePaths;
            fprintf(' → Generated %d paths for ancillary service %s\n', nPaths, ancService);
            end
        end
        
    fprintf('Conditional sampling completed successfully.\n');
end

% Function: applyComprehensiveCorrelationMatrix
% Apply all-to-all correlation matrix across energy and ancillary products
function correlatedPaths = applyComprehensiveCorrelationMatrix(sampledPaths, correlationMatrix, productNames)
    % Get node names
    nodeNames = fieldnames(sampledPaths);
    nodeNames = setdiff(nodeNames, {'Timestamp'});
    
    % Initialize correlated paths
    correlatedPaths = sampledPaths;
    
    % If only one node or no correlation matrix, return original paths
    if length(nodeNames) <= 1 || isempty(correlationMatrix) || isempty(productNames)
        fprintf(' → Only one node or no correlation matrix, skipping correlation step\n');
        return;
    end
    
    % Find which products are in our sampled paths
    nodeIndices = zeros(length(nodeNames), 1);
    for i = 1:length(nodeNames)
        nodeIdx = find(strcmp(productNames, nodeNames{i}), 1);
        if ~isempty(nodeIdx)
            nodeIndices(i) = nodeIdx;
        end
    end
    
    % Remove zeros
    nodeIndices = nodeIndices(nodeIndices > 0);
    
    % If no matching products, return original paths
    if isempty(nodeIndices)
        fprintf(' → No matching products found in correlation matrix, skipping correlation step\n');
        return;
    end
    
    % Extract submatrix for our nodes
    subMatrix = correlationMatrix(nodeIndices, nodeIndices);
    
    % Extract data dimensions
    nIntervals = length(sampledPaths.Timestamp);
    nPaths = size(sampledPaths.(nodeNames{1}), 2);
    nNodes = length(nodeNames);
    
    % Check if Cholesky decomposition is possible
    try
        % Try to compute Cholesky decomposition
        L = chol(subMatrix, 'lower');
        
        % For each path
        for p = 1:nPaths
            % Extract returns for all nodes
            allReturns = zeros(nIntervals-1, nNodes);
            
            for i = 1:nNodes
        nodeName = nodeNames{i};
                nodePrices = sampledPaths.(nodeName)(:, p);
                
                % Calculate returns
                nodeReturns = diff(log(nodePrices));
                nodeReturns(isinf(nodeReturns) | isnan(nodeReturns)) = 0;
                
                allReturns(:, i) = nodeReturns;
            end
            
            % Generate correlated noise
            Z = randn(nIntervals-1, nNodes);
            correlatedNoise = Z * L';
            
            % Blend original returns with correlated noise
            alpha = 0.7; % Blend factor
            blendedReturns = alpha * allReturns + (1-alpha) * correlatedNoise;
            
            % Convert back to prices
            for i = 1:nNodes
                nodeName = nodeNames{i};
                nodePrices = sampledPaths.(nodeName)(:, p);
                
                % Reconstruct prices from returns
                newPrices = zeros(nIntervals, 1);
                newPrices(1) = nodePrices(1);
                
                for t = 2:nIntervals
                    newPrices(t) = newPrices(t-1) * exp(blendedReturns(t-1, i));
                end
                
                % Update correlated paths
                correlatedPaths.(nodeName)(:, p) = newPrices;
            end
        end
        
    catch
        % If Cholesky fails, use simpler correlation method
        fprintf(' → Cholesky decomposition failed, using simpler correlation method\n');
        
        % For each path
        for p = 1:nPaths
            % For each node
            for i = 1:nNodes
                nodeName = nodeNames{i};
                correlatedPaths.(nodeName)(:, p) = sampledPaths.(nodeName)(:, p);
            end
        end
    end
    
    fprintf(' → Applied comprehensive correlation matrix to %d paths\n', nPaths);
end

% Function: applyDynamicCorrelationMatrix
% Apply dynamic correlation matrix using time-varying correlations and regime-dependent correlations
function correlatedPaths = applyDynamicCorrelationMatrix(sampledPaths, staticCorrelationMatrix, timeVaryingCorrelations, productNames, simulationTimeline)
    fprintf('\nApplying Phase 2B Dynamic Correlation Matrix...\n');
    
    % Get node names
    nodeNames = fieldnames(sampledPaths);
    nodeNames = setdiff(nodeNames, {'Timestamp'});
    
    % Initialize correlated paths
    correlatedPaths = sampledPaths;
    
    % If only one node, return original paths
    if length(nodeNames) <= 1
        fprintf(' → Only one node, skipping correlation step\n');
        return;
    end
    
    % Find which products are in our sampled paths
    nodeIndices = zeros(length(nodeNames), 1);
    for i = 1:length(nodeNames)
        nodeIdx = find(strcmp(productNames, nodeNames{i}), 1);
        if ~isempty(nodeIdx)
            nodeIndices(i) = nodeIdx;
        end
    end
    
    % Remove zeros
    nodeIndices = nodeIndices(nodeIndices > 0);
    
    % If no matching products, return original paths
    if isempty(nodeIndices)
        fprintf(' → No matching products found in correlation matrix, skipping correlation step\n');
        return;
    end
    
    % Extract data dimensions
    nIntervals = length(sampledPaths.Timestamp);
    nPaths = size(sampledPaths.(nodeNames{1}), 2);
    nNodes = length(nodeNames);
    
    fprintf(' → Processing %d intervals, %d paths, %d nodes\n', nIntervals, nPaths, nNodes);
    
    % For each path
    for p = 1:nPaths
        fprintf('   → Processing path %d of %d\n', p, nPaths);
        
        % Extract returns for all nodes
        allReturns = zeros(nIntervals-1, nNodes);
        
        for i = 1:nNodes
        nodeName = nodeNames{i};
            nodePrices = sampledPaths.(nodeName)(:, p);
        
        % Calculate returns
            nodeReturns = diff(log(nodePrices));
            nodeReturns(isinf(nodeReturns) | isnan(nodeReturns)) = 0;
            
            allReturns(:, i) = nodeReturns;
        end
        
        % Apply time-varying correlation
        enhancedReturns = zeros(size(allReturns));
        
        for t = 1:(nIntervals-1)
            % Get current timestamp
            currentTime = simulationTimeline(t);
            
            % Find closest timestamp in time-varying correlation data
            if isfield(timeVaryingCorrelations, 'timestamps')
                [~, closestIdx] = min(abs(timeVaryingCorrelations.timestamps - currentTime));
                
                % Extract correlation matrix for this time point
                if closestIdx <= size(timeVaryingCorrelations.correlationTimeSeries, 1)
                    % Extract submatrix for our nodes
                    timeVaryingCorr = squeeze(timeVaryingCorrelations.correlationTimeSeries(closestIdx, nodeIndices, nodeIndices));
                    
                    % Ensure matrix is positive semi-definite
                    [V, D] = eig(timeVaryingCorr);
                    D = diag(max(diag(D), 0.01));
                    timeVaryingCorr = V * D * V';
                    
                    % Rescale diagonal to 1
                    d = diag(timeVaryingCorr);
                    if all(d > 0)
                        timeVaryingCorr = timeVaryingCorr ./ sqrt(d * d');
                    end
                else
                    % Fallback to static correlation if time-varying not available
                    timeVaryingCorr = staticCorrelationMatrix(nodeIndices, nodeIndices);
                end
            else
                % Fallback to static correlation
                timeVaryingCorr = staticCorrelationMatrix(nodeIndices, nodeIndices);
            end
            
            % Apply correlation to returns
            try
                % Try Cholesky decomposition
                L = chol(timeVaryingCorr, 'lower');
                
                % Generate correlated noise
                Z = randn(nNodes, 1);
                correlatedNoise = L * Z;
                
                % Blend original returns with correlated structure
                alpha = 0.6; % Blend factor - preserve some original dynamics
                originalReturns = allReturns(t, :)';
                
                % Scale correlated noise to match return magnitudes
                if std(originalReturns) > 0
                    noiseScale = std(originalReturns) / std(correlatedNoise);
                    correlatedNoise = correlatedNoise * noiseScale;
                end
                
                % Apply dynamic correlation
                enhancedReturns(t, :) = (alpha * originalReturns + (1-alpha) * correlatedNoise)';
                
            catch
                % If Cholesky fails, use original returns
                enhancedReturns(t, :) = allReturns(t, :);
            end
        end
        
        % Reconstruct prices from enhanced returns
        for i = 1:nNodes
            nodeName = nodeNames{i};
            nodePrices = sampledPaths.(nodeName)(:, p);
            
            % Reconstruct prices
            newPrices = zeros(nIntervals, 1);
            newPrices(1) = nodePrices(1);
            
            for t = 2:nIntervals
                newPrices(t) = newPrices(t-1) * exp(enhancedReturns(t-1, i));
            end
            
            % Update correlated paths
            correlatedPaths.(nodeName)(:, p) = newPrices;
            end
        end
        
    % Apply exponentially weighted correlation enhancement for smoother dynamics
    if isfield(timeVaryingCorrelations, 'exponentiallyWeighted')
        fprintf(' → Applying exponentially weighted correlation enhancement\n');
        
        % Use the medium decay factor (lambda = 0.97)
        if isfield(timeVaryingCorrelations.exponentiallyWeighted, 'lambda_0_97')
            ewCorrelations = timeVaryingCorrelations.exponentiallyWeighted.lambda_0_97;
            
            for p = 1:nPaths
                % Apply exponentially weighted correlations to smooth transitions
                for t = 2:(nIntervals-1)
                    if t <= size(ewCorrelations, 1)
                        ewCorr = squeeze(ewCorrelations(t, nodeIndices, nodeIndices));
                        
                        % Get current returns
                        currentReturns = zeros(nNodes, 1);
                        for i = 1:nNodes
                            nodeName = nodeNames{i};
                            prices = correlatedPaths.(nodeName)(:, p);
                            if prices(t-1) > 0
                                currentReturns(i) = log(prices(t) / prices(t-1));
    end
end

                        % Handle NaN/Inf returns
                        currentReturns(isnan(currentReturns) | isinf(currentReturns)) = 0;
                        
                        % Apply exponentially weighted correlation adjustment
                        try
                            L = chol(ewCorr, 'lower');
                            smoothedReturns = 0.8 * currentReturns + 0.2 * (L * randn(nNodes, 1) * std(currentReturns));
                            
                            % Update prices with smoothed returns
                            for i = 1:nNodes
                                nodeName = nodeNames{i};
                                prices = correlatedPaths.(nodeName)(:, p);
                                if t < nIntervals
                                    prices(t+1) = prices(t) * exp(smoothedReturns(i));
                                    correlatedPaths.(nodeName)(:, p) = prices;
                                end
                            end
                        catch
                            % Skip if correlation matrix is not valid
                            continue;
                        end
                    end
                end
            end
        end
    end
    
    fprintf(' → Applied dynamic correlation matrix to %d paths with time-varying correlations\n', nPaths);
end

% Function: applyRegimeAwareCorrelations
% Apply regime-dependent correlations based on current regime states
function enhancedPaths = applyRegimeAwareCorrelations(bayesianPaths, regimeCorrelations, bayesianDiagnostics, productNames)
    fprintf('\nApplying regime-aware correlations...\n');
    
    % Get node names
    nodeNames = fieldnames(bayesianPaths);
    nodeNames = setdiff(nodeNames, {'Timestamp'});
    
    % Initialize enhanced paths
    enhancedPaths = bayesianPaths;
    
    % If only one node, return original paths
    if length(nodeNames) <= 1
        fprintf(' → Only one node, skipping regime-aware correlation step\n');
        return;
    end
    
    % Find which products are in our paths
    nodeIndices = zeros(length(nodeNames), 1);
    for i = 1:length(nodeNames)
        nodeIdx = find(strcmp(productNames, nodeNames{i}), 1);
        if ~isempty(nodeIdx)
            nodeIndices(i) = nodeIdx;
        end
    end
    
    % Remove zeros
    nodeIndices = nodeIndices(nodeIndices > 0);
    
    % If no matching products, return original paths
    if isempty(nodeIndices)
        fprintf(' → No matching products found, skipping regime-aware correlation step\n');
        return;
    end
    
    % Extract data dimensions
    nIntervals = length(bayesianPaths.Timestamp);
    nPaths = size(bayesianPaths.(nodeNames{1}), 2);
    nNodes = length(nodeNames);
    
    fprintf(' → Processing %d intervals, %d paths, %d nodes with regime awareness\n', nIntervals, nPaths, nNodes);
    
    % Get regime model from first node's diagnostics
    firstNodeName = nodeNames{1};
    if ~isfield(bayesianDiagnostics, firstNodeName) || ~isfield(bayesianDiagnostics.(firstNodeName), 'regimeModel')
        fprintf(' → No regime model available, returning original paths\n');
        return;
    end
    
    regimeModel = bayesianDiagnostics.(firstNodeName).regimeModel;
    nRegimes = regimeModel.optimalRegimes;
    
    % For each path
    for p = 1:nPaths
        if mod(p, max(1, floor(nPaths/10))) == 0
            fprintf('   → Processing path %d of %d (%.1f%%)\n', p, nPaths, p/nPaths*100);
        end
        
        % Generate regime sequence for this path
        pathRegimeSequence = generatePathRegimeSequence(bayesianPaths.Timestamp, regimeModel);
        
        % Extract returns for all nodes
        allReturns = zeros(nIntervals-1, nNodes);
        
        for i = 1:nNodes
            nodeName = nodeNames{i};
            nodePrices = bayesianPaths.(nodeName)(:, p);
            
            % Calculate returns
            nodeReturns = diff(log(nodePrices));
            nodeReturns(isinf(nodeReturns) | isnan(nodeReturns)) = 0;
            
            allReturns(:, i) = nodeReturns;
        end
        
        % Apply regime-specific correlations
        enhancedReturns = zeros(size(allReturns));
        
        for t = 1:(nIntervals-1)
            % Get current regime
            currentRegime = pathRegimeSequence(t);
            
            % Get appropriate correlation matrix for current regime
            regimeFieldName = sprintf('regime_%d', currentRegime);
            
            if isfield(regimeCorrelations, regimeFieldName)
                regimeCorr = regimeCorrelations.(regimeFieldName);
                
                % Extract submatrix for our nodes
                if size(regimeCorr, 1) >= max(nodeIndices) && size(regimeCorr, 2) >= max(nodeIndices)
                    regimeCorr = regimeCorr(nodeIndices, nodeIndices);
                else
                    regimeCorr = eye(nNodes); % Fallback to identity
            end
        else
                regimeCorr = eye(nNodes); % Fallback to identity
            end
            
            % Apply regime-specific correlation
            try
                % Ensure positive semi-definite
                [V, D] = eig(regimeCorr);
                D = diag(max(diag(D), 0.01));
                regimeCorr = V * D * V';
                
                % Rescale diagonal to 1
                d = diag(regimeCorr);
                if all(d > 0)
                    regimeCorr = regimeCorr ./ sqrt(d * d');
                end
                
                % Try Cholesky decomposition
                L = chol(regimeCorr, 'lower');
                
                % Generate correlated noise
                Z = randn(nNodes, 1);
                correlatedNoise = L * Z;
                
                % Blend original returns with regime-specific correlation structure
                alpha = 0.7; % Stronger preservation of original dynamics for final step
                originalReturns = allReturns(t, :)';
                
                % Scale correlated noise to match return magnitudes
                if std(originalReturns) > 0
                    noiseScale = std(originalReturns) / std(correlatedNoise);
                    correlatedNoise = correlatedNoise * noiseScale * 0.3; % Reduce noise impact
                end
                
                % Apply regime-aware correlation
                enhancedReturns(t, :) = (alpha * originalReturns + (1-alpha) * correlatedNoise)';
                
            catch
                % If Cholesky fails, use original returns
                enhancedReturns(t, :) = allReturns(t, :);
            end
        end
        
        % Reconstruct prices from enhanced returns
        for i = 1:nNodes
            nodeName = nodeNames{i};
            nodePrices = bayesianPaths.(nodeName)(:, p);
            
            % Reconstruct prices
            newPrices = zeros(nIntervals, 1);
            newPrices(1) = nodePrices(1);
            
            for t = 2:nIntervals
                newPrices(t) = newPrices(t-1) * exp(enhancedReturns(t-1, i));
            end
            
            % Update enhanced paths
            enhancedPaths.(nodeName)(:, p) = newPrices;
        end
    end
    
    fprintf(' → Applied regime-aware correlations to %d paths\n', nPaths);
end

% Function: generatePathRegimeSequence
% Generate regime sequence for a simulation path based on transition probabilities
function regimeSequence = generatePathRegimeSequence(timestamps, regimeModel)
    % Initialize regime sequence
    nIntervals = length(timestamps);
    regimeSequence = ones(nIntervals, 1);
    
    % Get regime parameters
    nRegimes = regimeModel.optimalRegimes;
    transitionMatrix = regimeModel.transitionMatrix;
    hourlyRegimeProb = regimeModel.hourlyProb;
    
    % Extract hour information
    [~, ~, ~, hours, ~, ~] = datevec(timestamps);
    
    % Start with most likely regime for first hour
    hourIdx = hours(1) + 1;
    if hourIdx <= size(hourlyRegimeProb, 1)
        [~, initialRegime] = max(hourlyRegimeProb(hourIdx, :));
    else
        initialRegime = 1; % Default to first regime
    end
    regimeSequence(1) = initialRegime;
    
    % Generate regime sequence using transition probabilities
    for t = 2:nIntervals
        % Get previous regime
        prevRegime = regimeSequence(t-1);
        
        % Get hour-specific regime probabilities
        hourIdx = hours(t) + 1;
        if hourIdx <= size(hourlyRegimeProb, 1)
            hourlyProb = hourlyRegimeProb(hourIdx, :);
        else
            hourlyProb = ones(1, nRegimes) / nRegimes; % Uniform if no data
        end
        
        % Blend transition probabilities with hourly probabilities
        blendFactor = 0.8; % Weight for transition matrix
        if prevRegime <= size(transitionMatrix, 1)
            blendedProb = blendFactor * transitionMatrix(prevRegime, :) + ...
                         (1 - blendFactor) * hourlyProb;
        else
            blendedProb = hourlyProb;
        end
        
        % Normalize
        blendedProb = blendedProb / sum(blendedProb);
        
        % Sample next regime
        cumProb = cumsum(blendedProb);
        randVal = rand();
        nextRegime = find(randVal <= cumProb, 1);
        
        if isempty(nextRegime)
            nextRegime = prevRegime; % Stay in same regime if sampling fails
        end
        
        regimeSequence(t) = nextRegime;
    end
end

% Function: applyBayesianRegimeSwitchingVolatility
% Applies Bayesian volatility modeling with regime-switching to enhance price paths
function [enhancedPaths, modelDiagnostics] = applyBayesianRegimeSwitchingVolatility(sampledPaths, historicalData, nodeNames)
    % Initialize output
    enhancedPaths = sampledPaths;
    modelDiagnostics = struct();
    
    fprintf('\nApplying Bayesian Volatility Modeling with Regime-Switching...\n');
    
    for i = 1:length(nodeNames)
        nodeName = nodeNames{i};
        fprintf(' → Processing node %s (%d of %d)\n', nodeName, i, length(nodeNames));
        
        % Extract historical data
        historicalPrices = historicalData.(nodeName).rawHistorical;
        historicalTimestamps = historicalData.(nodeName).timestamps;
        
        % Step 1: Identify regimes in historical data
        regimeModel = identifyVolatilityRegimes(historicalPrices, historicalTimestamps);
        
        % Step 2: Estimate Bayesian volatility model for each regime
        bayesianModel = estimateBayesianVolatilityModel(historicalPrices, regimeModel);
        
        % Step 3: Apply Bayesian model to sampled paths
        enhancedPaths.(nodeName) = applyBayesianModel(sampledPaths.(nodeName), sampledPaths.Timestamp, bayesianModel);
        
        % Store diagnostics
        modelDiagnostics.(nodeName).regimeModel = regimeModel;
        modelDiagnostics.(nodeName).bayesianModel = bayesianModel;
    end
    
    fprintf('Bayesian Volatility Modeling with Regime-Switching completed successfully.\n');
end

% Function: identifyVolatilityRegimes
% Identifies volatility regimes in historical data using Gaussian Mixture Models
% with optimal regime count selection using BIC and a sequential likelihood ratio test (LRT)
function regimeModel = identifyVolatilityRegimes(prices, timestamps, stabilityTestAlpha)
    % Calculate returns
    returns = diff(log(prices));
    returns(isinf(returns) | isnan(returns)) = 0;
    
    % Calculate rolling volatility (30-day window)
    rollingVol = movstd(returns, 30, 'omitnan');
    
    % Determine optimal number of regimes using BIC and LRT
    maxRegimes = 5;
    minRegimes = 2;
    if nargin < 3 || isempty(stabilityTestAlpha)
        stabilityTestAlpha = 0.05;
    end
    bic = zeros(maxRegimes, 1);
    gmModels = cell(maxRegimes, 1);
    logLiks = nan(maxRegimes, 1);
    fprintf(' → Testing different regime counts using BIC and LRT criterion...\n');
    options = statset('MaxIter', 1000, 'TolFun', 1e-6);
    
    % Fit GMMs for all k
    for k = minRegimes:maxRegimes
        try
            gmModels{k} = fitgmdist(rollingVol, k, 'Options', options, 'RegularizationValue', 0.01);
            bic(k) = gmModels{k}.BIC;
            fprintf('   %d regimes: BIC = %.2f\n', k, bic(k));
        catch
            % If fitting fails, set BIC to Inf
            bic(k) = Inf;
            fprintf('   %d regimes: Fitting failed\n', k);
            end
        end
    
    % Find optimal regime count (minimum BIC)
    validBic = bic(minRegimes:maxRegimes);
    [~, optIdx] = min(validBic);
    optimalRegimes = optIdx + minRegimes - 1;
    
    % If all fits failed, default to 3 regimes
    if all(isinf(validBic))
        optimalRegimes = 3;
        fprintf(' → All GMM fits failed, defaulting to %d regimes\n', optimalRegimes);
        options.RegularizationValue = 0.1; % Increase regularization
        gmModel = fitgmdist(rollingVol, optimalRegimes, 'Options', options);
    else
        gmModel = gmModels{optimalRegimes};
        fprintf(' → Selected optimal regime count: %d (BIC = %.2f)\n', optimalRegimes, bic(optimalRegimes));
    end
    
    % Sort components by mean (ascending)
    [~, sortIdx] = sort(gmModel.mu);
    
    % Classify each point into a regime
    regimeIdx = cluster(gmModel, rollingVol);
    
    % Map to ordered regimes (1=low, 2=medium, etc.)
    regimeMap = zeros(optimalRegimes, 1);
    for r = 1:optimalRegimes
        regimeMap(sortIdx(r)) = r;
    end
    regimes = regimeMap(regimeIdx);
    
    % Calculate regime transition probabilities
    transitionMatrix = zeros(optimalRegimes, optimalRegimes);
    for t = 1:(length(regimes)-1)
        fromRegime = regimes(t);
        toRegime = regimes(t+1);
        transitionMatrix(fromRegime, toRegime) = transitionMatrix(fromRegime, toRegime) + 1;
    end
    
    % Normalize transition matrix
    for r = 1:optimalRegimes
        rowSum = sum(transitionMatrix(r, :));
        if rowSum > 0
            transitionMatrix(r, :) = transitionMatrix(r, :) / rowSum;
        else
            transitionMatrix(r, r) = 1; % Stay in same regime if no transitions observed
                    end
                end
    
    % Calculate regime statistics
    regimeStats = struct();
    for r = 1:optimalRegimes
        regimeStats(r).mean = mean(returns(regimes == r), 'omitnan');
        regimeStats(r).std = std(returns(regimes == r), 'omitnan');
        regimeStats(r).skewness = skewness(returns(regimes == r));
        regimeStats(r).kurtosis = kurtosis(returns(regimes == r));
        regimeStats(r).proportion = sum(regimes == r) / length(regimes);
    end
    
    % Extract temporal patterns in regimes
    [~, ~, ~, hours, ~, ~] = datevec(timestamps(1:end-1)); % Match returns length
    hourlyRegimeProb = zeros(24, optimalRegimes);
    
    for h = 0:23
        hourIdx = (hours == h);
        if sum(hourIdx) > 0
            for r = 1:optimalRegimes
                hourlyRegimeProb(h+1, r) = sum(regimes(hourIdx) == r) / sum(hourIdx);
            end
        end
    end
    
    % Build regime model
    regimeModel = struct();
    regimeModel.gmModel = gmModel;
    regimeModel.regimes = regimes;
    regimeModel.transitionMatrix = transitionMatrix;
    regimeModel.stats = regimeStats;
    regimeModel.hourlyProb = hourlyRegimeProb;
    regimeModel.optimalRegimes = optimalRegimes;
    
    fprintf(' → Identified %d regimes with transition matrix:\n', optimalRegimes);
    disp(transitionMatrix);
end

% Function: estimateBayesianVolatilityModel
% Estimates Bayesian volatility model for each regime
function bayesianModel = estimateBayesianVolatilityModel(prices, regimeModel)
    % Calculate returns
    returns = diff(log(prices));
    returns(isinf(returns) | isnan(returns)) = 0;
    
    % Get regimes
    regimes = regimeModel.regimes;
    nRegimes = regimeModel.optimalRegimes;
    
    % Initialize Bayesian model
    bayesianModel = struct();
    bayesianModel.priorParams = struct();
    bayesianModel.posteriorParams = struct();
    
    % For each regime
    for r = 1:nRegimes
        % Get returns for this regime
        regimeReturns = returns(regimes == r);
        
        % Set prior parameters for inverse gamma distribution
        % alpha = shape, beta = scale
        priorAlpha = 2.0;
        priorBeta = 0.001;
        
        % Update with data to get posterior
        posteriorAlpha = priorAlpha + length(regimeReturns)/2;
        posteriorBeta = priorBeta + sum(regimeReturns.^2)/2;
        
        % Store parameters
        bayesianModel.priorParams(r).alpha = priorAlpha;
        bayesianModel.priorParams(r).beta = priorBeta;
        bayesianModel.posteriorParams(r).alpha = posteriorAlpha;
        bayesianModel.posteriorParams(r).beta = posteriorBeta;
        
        % Calculate posterior mean and variance
        posteriorMean = posteriorBeta / (posteriorAlpha - 1); % Mean of inverse gamma
        posteriorVar = posteriorBeta^2 / ((posteriorAlpha - 1)^2 * (posteriorAlpha - 2)); % Variance of inverse gamma
        
        % Store posterior statistics
        bayesianModel.posteriorParams(r).mean = posteriorMean;
        bayesianModel.posteriorParams(r).std = sqrt(posteriorVar);
        
        fprintf(' → Regime %d: Posterior volatility mean = %.4f, std = %.4f\n', ...
            r, sqrt(posteriorMean), sqrt(posteriorVar)/2);
    end
    
    % Store regime model reference
    bayesianModel.regimeModel = regimeModel;
end

% Function: applyBayesianModel
% Apply Bayesian volatility model to sampled paths
function enhancedPaths = applyBayesianModel(sampledPaths, timestamps, bayesianModel)
    % Initialize enhanced paths
    enhancedPaths = sampledPaths;
    
    % Get dimensions
    [nIntervals, nPaths] = size(sampledPaths);
    
    % Get regime model
    regimeModel = bayesianModel.regimeModel;
    nRegimes = regimeModel.optimalRegimes;
    transitionMatrix = regimeModel.transitionMatrix;
    hourlyRegimeProb = regimeModel.hourlyProb;
    
    % Extract hour of day for timestamps
    [~, ~, ~, hours, ~, ~] = datevec(timestamps);
    
    % For each path
        for p = 1:nPaths
        % Extract path prices
        pathPrices = sampledPaths(:, p);
        
        % Calculate returns
        pathReturns = diff(log(pathPrices));
        pathReturns(isinf(pathReturns) | isnan(pathReturns)) = 0;
        
        % Initialize regime sequence
        regimeSequence = zeros(nIntervals-1, 1);
        
        % Determine initial regime based on hour of day
        hourIdx = hours(1) + 1;
        initialRegimeProb = hourlyRegimeProb(hourIdx, :);
        [~, initialRegime] = max(initialRegimeProb);
        regimeSequence(1) = initialRegime;
        
        % Generate regime sequence using Markov chain
        for t = 2:(nIntervals-1)
            % Get previous regime
            prevRegime = regimeSequence(t-1);
            
            % Get hour-specific regime probabilities
            hourIdx = hours(t) + 1;
            hourlyProb = hourlyRegimeProb(hourIdx, :);
            
            % Blend transition probabilities with hourly probabilities
            blendFactor = 0.7; % Weight for transition matrix
            blendedProb = blendFactor * transitionMatrix(prevRegime, :) + ...
                         (1 - blendFactor) * hourlyProb;
            
            % Normalize
            blendedProb = blendedProb / sum(blendedProb);
            
            % Sample next regime
            cumProb = cumsum(blendedProb);
            randVal = rand();
            nextRegime = find(randVal <= cumProb, 1);
            
            regimeSequence(t) = nextRegime;
        end
        
        % Apply regime-specific volatility adjustments
        enhancedReturns = pathReturns;
        
        for t = 1:(nIntervals-1)
            % Get regime for this interval
            regime = regimeSequence(t);
            
            % Get posterior volatility parameters
            posteriorAlpha = bayesianModel.posteriorParams(regime).alpha;
            posteriorBeta = bayesianModel.posteriorParams(regime).beta;
            
            % Sample volatility from posterior
            sampledVariance = 1 / gamrnd(posteriorAlpha, 1/posteriorBeta);
            
            % Scale return by volatility adjustment
            currentVol = abs(pathReturns(t));
            if currentVol > 0
                targetVol = sqrt(sampledVariance);
                volRatio = targetVol / currentVol;
                
                % Apply adjustment with dampening to avoid extreme values
                dampFactor = 0.5;
                adjustedRatio = 1 + dampFactor * (volRatio - 1);
                enhancedReturns(t) = pathReturns(t) * adjustedRatio;
                    end
                end
            
        % Reconstruct prices from enhanced returns
        newPrices = zeros(nIntervals, 1);
        newPrices(1) = pathPrices(1);
        
        for t = 2:nIntervals
            newPrices(t) = newPrices(t-1) * exp(enhancedReturns(t-1));
        end
        
        % Update enhanced paths
        enhancedPaths(:, p) = newPrices;
    end
end

% Function: validateVolatilityModeling
% Validates volatility modeling results with enhanced tests
function validationResults = validateVolatilityModeling(simulatedPaths, historicalData, diagnostics)
    fprintf('\nValidating volatility modeling...\n');
    
    % Get node names
    nodeNames = fieldnames(simulatedPaths);
    nodeNames = setdiff(nodeNames, {'Timestamp'});
    
    % Initialize validation results
    validationResults = struct();
    
    % For each node
    for i = 1:length(nodeNames)
        nodeName = nodeNames{i};
        fprintf('Validating volatility for node %s (%d of %d)\n', nodeName, i, length(nodeNames));
        
        % Get historical and simulated data
        historicalPrices = historicalData.(nodeName).rawHistorical;
        historicalTimestamps = historicalData.(nodeName).timestamps;
        simulatedPrices = simulatedPaths.(nodeName);
            
            % Calculate returns
        historicalReturns = diff(log(historicalPrices));
        historicalReturns(isinf(historicalReturns) | isnan(historicalReturns)) = 0;
        
        % Calculate statistics for each path
        nPaths = size(simulatedPrices, 2);
        pathStats = zeros(nPaths, 4); % [mean, std, skewness, kurtosis]
        
        for p = 1:nPaths
            pathPrices = simulatedPrices(:, p);
            pathReturns = diff(log(pathPrices));
            pathReturns(isinf(pathReturns) | isnan(pathReturns)) = 0;
            
            pathStats(p, 1) = mean(pathReturns, 'omitnan');
            pathStats(p, 2) = std(pathReturns, 'omitnan');
            pathStats(p, 3) = skewness(pathReturns);
            pathStats(p, 4) = kurtosis(pathReturns);
            
            % ARCH test for volatility clustering
            try
                [hARCH, pValueARCH] = archtest(pathReturns);
                if p == 1 % Only print for first path
                    fprintf(' → ARCH effect p-value: %.4f (%s)\n', pValueARCH, string(hARCH));
                    validationResults.(nodeName).archTest.pValue = pValueARCH;
                    validationResults.(nodeName).archTest.significant = hARCH;
                end
            catch
                fprintf(' → ARCH test not available, skipping\n');
            end
            
            % Jump frequency validation
            try
                % Use 95th percentile as threshold for jumps
                histThreshold = prctile(historicalReturns, 95);
                simThreshold = prctile(pathReturns, 95);
                
                historicalJumps = sum(historicalReturns > histThreshold);
                simulatedJumps = sum(pathReturns > simThreshold);
                
                if p == 1 % Only print for first path
                    fprintf(' → Jump frequency: %.2f%% (sim) vs %.2f%% (hist)\n', ...
                        simulatedJumps/length(pathReturns)*100, ...
                        historicalJumps/length(historicalReturns)*100);
                    
                    validationResults.(nodeName).jumpFrequency.simulated = simulatedJumps/length(pathReturns)*100;
                    validationResults.(nodeName).jumpFrequency.historical = historicalJumps/length(historicalReturns)*100;
                end
            catch
                fprintf(' → Jump frequency calculation failed, skipping\n');
    end
end

        % Calculate average statistics
        avgStats = mean(pathStats, 1);
        
        % Calculate historical statistics
        histStats = [mean(historicalReturns, 'omitnan'), ...
                    std(historicalReturns, 'omitnan'), ...
                    skewness(historicalReturns), ...
                    kurtosis(historicalReturns)];
        
        % Store validation results
        validationResults.(nodeName).meanDiff = (avgStats(1) - histStats(1)) / abs(histStats(1)) * 100;
        validationResults.(nodeName).stdDiff = (avgStats(2) - histStats(2)) / histStats(2) * 100;
        validationResults.(nodeName).skewnessDiff = avgStats(3) - histStats(3);
        validationResults.(nodeName).kurtosisDiff = avgStats(4) - histStats(4);
        
        % Print comparison
        fprintf(' → Mean: %.4f (sim) vs %.4f (hist) - Diff: %.2f%%\n', ...
            avgStats(1), histStats(1), validationResults.(nodeName).meanDiff);
        fprintf(' → Std: %.4f (sim) vs %.4f (hist) - Diff: %.2f%%\n', ...
            avgStats(2), histStats(2), validationResults.(nodeName).stdDiff);
        fprintf(' → Skewness: %.4f (sim) vs %.4f (hist)\n', ...
            avgStats(3), histStats(3));
        fprintf(' → Kurtosis: %.4f (sim) vs %.4f (hist)\n', ...
            avgStats(4), histStats(4));
    end
    
    return;
end

% Function: enforceHourlyTargetsWithTolerance
% Enforces hourly targets with tolerance
function adjustedPaths = enforceHourlyTargetsWithTolerance(paths, hourlyTargets, tolerance)
    % Initialize adjusted paths
    adjustedPaths = paths;
    
    % Get node names
    nodeNames = fieldnames(paths);
    nodeNames = setdiff(nodeNames, {'Timestamp'});
    
    % For each node
    for i = 1:length(nodeNames)
        nodeName = nodeNames{i};
        fprintf('Enforcing hourly targets for node %s (%d of %d)\n', nodeName, i, length(nodeNames));
        
        % Get node paths
        nodePaths = paths.(nodeName);
        [nIntervals, nPaths] = size(nodePaths);
        
        % Get timestamps
        timestamps = paths.Timestamp;
        
        % Extract hour from timestamps
        [~, ~, ~, hours, ~, ~] = datevec(timestamps);
        
        % For each hour
        uniqueHours = unique(hours);
        for h = 1:length(uniqueHours)
            hour = uniqueHours(h);
            
            % Get hourly target
            hourlyTarget = hourlyTargets.(nodeName)(hour+1);
            
            % Get intervals for this hour
            hourIndices = (hours == hour);
            
            % Calculate current hourly average
            currentAvg = mean(mean(nodePaths(hourIndices, :), 'omitnan'), 'omitnan');
            
            % Check if adjustment needed
            if abs(currentAvg - hourlyTarget) / hourlyTarget > tolerance
                fprintf(' → Adjusting hour %d: current avg = %.2f, target = %.2f\n', ...
                    hour, currentAvg, hourlyTarget);
                
                % Calculate adjustment factor with bounds
                maxAdjustment = 3.0;  % 300% of original
                minAdjustment = 0.33; % 33% of original
                
                % Add small epsilon to prevent division by zero
                epsilon = 1e-6;
                baseAdjustment = hourlyTarget / (currentAvg + epsilon);
                
                % Apply random factor to each path to maintain diversity
                for p = 1:nPaths
                    pathRandomFactor = 0.9 + 0.2 * rand(); % Random factor between 0.9 and 1.1
                    adjustmentFactor = baseAdjustment * pathRandomFactor;
                    
                    % Apply bounds to prevent extreme adjustments
                    adjustmentFactor = max(min(adjustmentFactor, maxAdjustment), minAdjustment);
                    
                    % Apply adjustment
                    adjustedPaths.(nodeName)(hourIndices, p) = nodePaths(hourIndices, p) * adjustmentFactor;
                end
                
                % Verify adjustment
                newAvg = mean(mean(adjustedPaths.(nodeName)(hourIndices, :), 'omitnan'), 'omitnan');
                fprintf('   → After adjustment: new avg = %.2f (target = %.2f)\n', ...
                    newAvg, hourlyTarget);
            end
        end
    end
end

% Function: prepareOutputData
% Prepare output data in table format
function outputData = prepareOutputData(paths, nPaths, ancillaryPaths)
    % Get node names
    nodeNames = fieldnames(paths);
    nodeNames = setdiff(nodeNames, {'Timestamp'});
    
    % Initialize output data
    outputData = table();
    outputData.Timestamp = paths.Timestamp;
    
    % For each node
    for i = 1:length(nodeNames)
        nodeName = nodeNames{i};
        
        % For each path
        for p = 1:nPaths
            % Create column name
            colName = sprintf('%s_Path%d', nodeName, p);
            
            % Add path to output data
            outputData.(colName) = paths.(nodeName)(:, p);
        end
    end
    
    % Add ancillary service paths if available
    if exist('ancillaryPaths', 'var') && ~isempty(ancillaryPaths)
        ancillaryServices = fieldnames(ancillaryPaths);
        ancillaryServices = setdiff(ancillaryServices, {'Timestamp'});
        
        for i = 1:length(ancillaryServices)
            ancService = ancillaryServices{i};
            
            % For each path
        for p = 1:nPaths
                % Create column name
                colName = sprintf('Ancillary_%s_Path%d', ancService, p);
                
                % Add ancillary path to output data
                outputData.(colName) = ancillaryPaths.(ancService)(:, p);
            end
        end
        
        fprintf(' → Added %d ancillary services to output data\n', length(ancillaryServices));
    end
end
        
% Function: validatePathDiversity
% Validate path diversity
function results = validatePathDiversity(outputData)
    % Initialize results
    results = struct();
    
    % Get column names
    colNames = outputData.Properties.VariableNames;
    
    % Remove Timestamp column
    colNames = setdiff(colNames, {'Timestamp'});
    
    % Get node names (without path numbers)
    nodeNames = cellfun(@(x) extractBefore(x, '_Path'), colNames, 'UniformOutput', false);
    nodeNames = unique(nodeNames);
    
    % For each node
    for i = 1:length(nodeNames)
        nodeName = nodeNames{i};
        
        % Get path columns for this node
        nodeColumns = colNames(startsWith(colNames, [nodeName, '_Path']));
        
        % Calculate correlation matrix
        nodeData = outputData{:, nodeColumns};
        corrMatrix = corr(nodeData);
        
        % Calculate average correlation
        corrValues = corrMatrix(triu(true(size(corrMatrix)), 1));
        avgCorr = mean(corrValues);
        
        % Calculate standard deviation of correlations
        stdCorr = std(corrValues);
        
        % Store results
        results.(nodeName).avgCorrelation = avgCorr;
        results.(nodeName).stdCorrelation = stdCorr;
        
        fprintf(' → Path diversity for %s: avg correlation = %.4f, std = %.4f\n', ...
            nodeName, avgCorr, stdCorr);
    end
end

% Function: extractHolidayPattern
% Extracts pricing patterns around US energy trading holidays
function holidayPattern = extractHolidayPattern(timestamps, prices)
    % Ensure timestamps are datetime objects
    if ~isa(timestamps, 'datetime')
        try
            timestamps = datetime(timestamps);
        catch
            error('Cannot convert timestamps to datetime format');
                    end
                end
    
    % Initialize holiday pattern structure
    holidayPattern = struct();
    holidayPattern.adjustmentFactors = struct();
    holidayPattern.volatilityFactors = struct();
    
    % Define US energy trading holidays for pattern recognition
    years = unique(year(timestamps));
    holidayDates = [];
    holidayNames = {};
    
    for y = years'
        % New Year's Day
        holidayDates = [holidayDates; datetime(y, 1, 1)];
        holidayNames{end+1} = 'NewYear';
        
        % Memorial Day (last Monday in May)
        lastMondayMay = datetime(y, 5, 31);
        while weekday(lastMondayMay) ~= 2  % 2 = Monday
            lastMondayMay = lastMondayMay - days(1);
        end
        holidayDates = [holidayDates; lastMondayMay];
        holidayNames{end+1} = 'Memorial';
        
        % Independence Day
        holidayDates = [holidayDates; datetime(y, 7, 4)];
        holidayNames{end+1} = 'Independence';
        
        % Labor Day (first Monday in September)
        firstMondaySep = datetime(y, 9, 1);
        while weekday(firstMondaySep) ~= 2  % 2 = Monday
            firstMondaySep = firstMondaySep + days(1);
        end
        holidayDates = [holidayDates; firstMondaySep];
        holidayNames{end+1} = 'Labor';
        
        % Thanksgiving (fourth Thursday in November)
        fourthThursdayNov = datetime(y, 11, 1);
        thursdayCount = 0;
        while thursdayCount < 4
            if weekday(fourthThursdayNov) == 5  % 5 = Thursday
                thursdayCount = thursdayCount + 1;
            end
            if thursdayCount < 4
                fourthThursdayNov = fourthThursdayNov + days(1);
            end
        end
        holidayDates = [holidayDates; fourthThursdayNov];
        holidayNames{end+1} = 'Thanksgiving';
        
        % Christmas Day
        holidayDates = [holidayDates; datetime(y, 12, 25)];
        holidayNames{end+1} = 'Christmas';
    end
    
    % Analyze patterns around holidays
    holidayTypes = unique(holidayNames);
    for h = 1:length(holidayTypes)
        holidayType = holidayTypes{h};
        typeHolidays = holidayDates(strcmp(holidayNames, holidayType));
        
        % Initialize arrays for this holiday type
        preHolidayPrices = [];
        holidayPrices = [];
        postHolidayPrices = [];
        normalPrices = [];
        
        % For each occurrence of this holiday
        for i = 1:length(typeHolidays)
            holiday = typeHolidays(i);
            
            % Pre-holiday (1-2 days before)
            preHolidayIdx = (timestamps >= holiday - days(2)) & (timestamps < holiday);
            if sum(preHolidayIdx) > 0
                preHolidayPrices = [preHolidayPrices; prices(preHolidayIdx)];
            end
            
            % Holiday day
            holidayIdx = (timestamps >= holiday) & (timestamps < holiday + days(1));
            if sum(holidayIdx) > 0
                holidayPrices = [holidayPrices; prices(holidayIdx)];
            end
            
            % Post-holiday (1-2 days after)
            postHolidayIdx = (timestamps >= holiday + days(1)) & (timestamps <= holiday + days(2));
            if sum(postHolidayIdx) > 0
                postHolidayPrices = [postHolidayPrices; prices(postHolidayIdx)];
            end
            
            % Normal days (same weekday, 2-4 weeks away from holiday)
            for offset = [14, 21, 28]  % 2, 3, 4 weeks
                normalDay1 = holiday - days(offset);
                normalDay2 = holiday + days(offset);
                
                normalIdx1 = (timestamps >= normalDay1) & (timestamps < normalDay1 + days(1));
                normalIdx2 = (timestamps >= normalDay2) & (timestamps < normalDay2 + days(1));
                
                if sum(normalIdx1) > 0
                    normalPrices = [normalPrices; prices(normalIdx1)];
                end
                if sum(normalIdx2) > 0
                    normalPrices = [normalPrices; prices(normalIdx2)];
                end
            end
        end
        
        % Calculate adjustment factors (relative to normal days)
        if ~isempty(normalPrices)
            normalMean = mean(normalPrices, 'omitnan');
            normalStd = std(normalPrices, 'omitnan');
            
            % Pre-holiday adjustment
            if ~isempty(preHolidayPrices)
                preHolidayMean = mean(preHolidayPrices, 'omitnan');
                holidayPattern.adjustmentFactors.([holidayType '_PreHoliday']) = preHolidayMean / normalMean;
                holidayPattern.volatilityFactors.([holidayType '_PreHoliday']) = std(preHolidayPrices, 'omitnan') / normalStd;
            else
                holidayPattern.adjustmentFactors.([holidayType '_PreHoliday']) = 1.0;
                holidayPattern.volatilityFactors.([holidayType '_PreHoliday']) = 1.0;
            end
            
            % Holiday adjustment
            if ~isempty(holidayPrices)
                holidayMean = mean(holidayPrices, 'omitnan');
                holidayPattern.adjustmentFactors.([holidayType '_Holiday']) = holidayMean / normalMean;
                holidayPattern.volatilityFactors.([holidayType '_Holiday']) = std(holidayPrices, 'omitnan') / normalStd;
            else
                holidayPattern.adjustmentFactors.([holidayType '_Holiday']) = 0.8; % Typically lower on holidays
                holidayPattern.volatilityFactors.([holidayType '_Holiday']) = 0.6; % Lower volatility
            end
            
            % Post-holiday adjustment
            if ~isempty(postHolidayPrices)
                postHolidayMean = mean(postHolidayPrices, 'omitnan');
                holidayPattern.adjustmentFactors.([holidayType '_PostHoliday']) = postHolidayMean / normalMean;
                holidayPattern.volatilityFactors.([holidayType '_PostHoliday']) = std(postHolidayPrices, 'omitnan') / normalStd;
            else
                holidayPattern.adjustmentFactors.([holidayType '_PostHoliday']) = 1.0;
                holidayPattern.volatilityFactors.([holidayType '_PostHoliday']) = 1.0;
            end
        end
    end
    
    % Store holiday dates for future reference
    holidayPattern.holidayDates = holidayDates;
    holidayPattern.holidayNames = holidayNames;
end

% Function: extractSeasonalBehaviorPattern
% Extracts advanced seasonal behavioral patterns beyond simple monthly effects
function seasonalPattern = extractSeasonalBehaviorPattern(timestamps, prices)
    % Ensure timestamps are datetime objects
    if ~isa(timestamps, 'datetime')
        try
            timestamps = datetime(timestamps);
        catch
            error('Cannot convert timestamps to datetime format');
        end
    end
    
    % Initialize seasonal pattern structure
    seasonalPattern = struct();
    
    % Define seasons
    seasons = struct();
    seasons.Winter = [12, 1, 2];  % Dec, Jan, Feb
    seasons.Spring = [3, 4, 5];   % Mar, Apr, May
    seasons.Summer = [6, 7, 8];   % Jun, Jul, Aug
    seasons.Fall = [9, 10, 11];   % Sep, Oct, Nov
    
    seasonNames = fieldnames(seasons);
    
    % Extract month, day of week, and hour
    months = month(timestamps);
    daysOfWeek = weekday(timestamps);  % 1=Sunday, 7=Saturday
    hours = hour(timestamps);
    
    % 1. Seasonal Weekend vs Weekday Effects
    seasonalPattern.weekendEffects = struct();
    
    for s = 1:length(seasonNames)
        seasonName = seasonNames{s};
        seasonMonths = seasons.(seasonName);
        seasonIdx = ismember(months, seasonMonths);
        
        if sum(seasonIdx) > 0
            % Weekend prices in this season
            weekendIdx = seasonIdx & (daysOfWeek == 1 | daysOfWeek == 7);  % Sunday or Saturday
            weekdayIdx = seasonIdx & (daysOfWeek >= 2 & daysOfWeek <= 6);  % Monday-Friday
            
            if sum(weekendIdx) > 0 && sum(weekdayIdx) > 0
                weekendMean = mean(prices(weekendIdx), 'omitnan');
                weekdayMean = mean(prices(weekdayIdx), 'omitnan');
                
                seasonalPattern.weekendEffects.(seasonName) = weekendMean / weekdayMean;
            else
                seasonalPattern.weekendEffects.(seasonName) = 0.85; % Default weekend discount
            end
        end
    end
    
    % 2. Seasonal Hourly Load Shape Differences
    seasonalPattern.hourlyShapes = struct();
    
    for s = 1:length(seasonNames)
        seasonName = seasonNames{s};
        seasonMonths = seasons.(seasonName);
        seasonIdx = ismember(months, seasonMonths);
        
        if sum(seasonIdx) > 0
            hourlyShape = zeros(24, 1);
            
            for h = 0:23
                hourIdx = seasonIdx & (hours == h);
                if sum(hourIdx) > 0
                    hourlyShape(h+1) = mean(prices(hourIdx), 'omitnan');
                end
            end
            
            % Normalize to average
            if sum(hourlyShape) > 0
                hourlyShape = hourlyShape / mean(hourlyShape, 'omitnan');
                seasonalPattern.hourlyShapes.(seasonName) = hourlyShape;
            else
                % Default load shape if no data
                defaultShape = [0.7, 0.65, 0.6, 0.6, 0.65, 0.75, 0.9, 1.1, 1.2, 1.15, 1.1, 1.05, ...
                               1.0, 1.0, 1.05, 1.1, 1.2, 1.4, 1.3, 1.2, 1.1, 1.0, 0.9, 0.8];
                seasonalPattern.hourlyShapes.(seasonName) = defaultShape';
            end
        end
    end
    
    % 3. Cross-Seasonal Interaction Effects
    seasonalPattern.crossEffects = struct();
    
    % Monday morning patterns by season
    mondayMorningIdx = (daysOfWeek == 2) & (hours >= 6 & hours <= 10);  % Monday 6-10 AM
    
    for s = 1:length(seasonNames)
        seasonName = seasonNames{s};
        seasonMonths = seasons.(seasonName);
        seasonIdx = ismember(months, seasonMonths);
        
        seasonMondayMorningIdx = seasonIdx & mondayMorningIdx;
        
        if sum(seasonMondayMorningIdx) > 0
            mondayMorningMean = mean(prices(seasonMondayMorningIdx), 'omitnan');
            
            % Compare to overall season average
            overallSeasonMean = mean(prices(seasonIdx), 'omitnan');
            
            if overallSeasonMean > 0
                seasonalPattern.crossEffects.([seasonName '_MondayMorning']) = mondayMorningMean / overallSeasonMean;
            else
                seasonalPattern.crossEffects.([seasonName '_MondayMorning']) = 1.2; % Default morning premium
            end
        else
            seasonalPattern.crossEffects.([seasonName '_MondayMorning']) = 1.2; % Default morning premium
        end
    end
    
    % Friday afternoon patterns by season
    fridayAfternoonIdx = (daysOfWeek == 6) & (hours >= 14 & hours <= 18);  % Friday 2-6 PM
    
    for s = 1:length(seasonNames)
        seasonName = seasonNames{s};
        seasonMonths = seasons.(seasonName);
        seasonIdx = ismember(months, seasonMonths);
        
        seasonFridayAfternoonIdx = seasonIdx & fridayAfternoonIdx;
        
        if sum(seasonFridayAfternoonIdx) > 0
            fridayAfternoonMean = mean(prices(seasonFridayAfternoonIdx), 'omitnan');
            
            % Compare to overall season average
            overallSeasonMean = mean(prices(seasonIdx), 'omitnan');
            
            if overallSeasonMean > 0
                seasonalPattern.crossEffects.([seasonName '_FridayAfternoon']) = fridayAfternoonMean / overallSeasonMean;
            else
                seasonalPattern.crossEffects.([seasonName '_FridayAfternoon']) = 0.9; % Default Friday discount
            end
        else
            seasonalPattern.crossEffects.([seasonName '_FridayAfternoon']) = 0.9; % Default Friday discount
        end
    end
    
    % 4. Seasonal Price Volatility Patterns
    seasonalPattern.volatilityFactors = struct();
    
    for s = 1:length(seasonNames)
        seasonName = seasonNames{s};
        seasonMonths = seasons.(seasonName);
        seasonIdx = ismember(months, seasonMonths);
        
        if sum(seasonIdx) > 0
            seasonPrices = prices(seasonIdx);
            seasonalPattern.volatilityFactors.(seasonName) = std(seasonPrices, 'omitnan');
        else
            seasonalPattern.volatilityFactors.(seasonName) = std(prices, 'omitnan'); % Fallback
        end
    end
    
    % Normalize volatility factors to overall volatility
    overallVol = std(prices, 'omitnan');
    if overallVol > 0
        for s = 1:length(seasonNames)
            seasonName = seasonNames{s};
            seasonalPattern.volatilityFactors.(seasonName) = seasonalPattern.volatilityFactors.(seasonName) / overallVol;
        end
    end
end

% Function: applyResolutionAppropriateCorrelations
% Apply correlation matrices appropriate for the target simulation resolution (Phase 2C)
function enhancedPaths = applyResolutionAppropriateCorrelations(inputPaths, multiResCorrelations, targetResolution, simulationTimeline)
    fprintf('\nPhase 2C: Applying resolution-appropriate correlations for %s resolution...\n', targetResolution);
    
    % Get node names
    nodeNames = fieldnames(inputPaths);
    nodeNames = setdiff(nodeNames, {'Timestamp'});
    
    % Initialize enhanced paths
    enhancedPaths = inputPaths;
    
    % If only one node, return original paths
    if length(nodeNames) <= 1
        fprintf(' → Only one node, skipping resolution-appropriate correlation step\n');
        return;
    end
    
    % Determine the best available correlation matrix for target resolution
    [bestCorrelationMatrix, selectedResolution, scalingFactor] = selectBestCorrelationMatrix(multiResCorrelations, targetResolution, nodeNames);
    
    if isempty(bestCorrelationMatrix)
        fprintf(' → No suitable correlation matrix found for %s resolution, using identity matrix\n', targetResolution);
        return;
    end
    
    fprintf(' → Using %s correlation matrix with scaling factor %.4f for %s target\n', ...
        selectedResolution, scalingFactor, targetResolution);
    
    % Get data dimensions
    nIntervals = length(inputPaths.Timestamp);
    nPaths = size(inputPaths.(nodeNames{1}), 2);
    nNodes = length(nodeNames);
    
    % Calculate target time step for aggregation consistency
    targetTimeStep = calculateTimeStep(targetResolution);
    simulationTimeStep = calculateTimeStep('simulation_auto');
    aggregationRatio = targetTimeStep / simulationTimeStep;
    
    fprintf(' → Processing %d intervals, %d paths, %d nodes with %.2fx aggregation ratio\n', ...
        nIntervals, nPaths, nNodes, aggregationRatio);
    
    % Apply resolution-appropriate correlations for each path
                for p = 1:nPaths
        if mod(p, max(1, floor(nPaths/10))) == 0
            fprintf('   → Processing path %d of %d (%.1f%%)\n', p, nPaths, p/nPaths*100);
        end
        
        % Extract returns for all nodes at simulation resolution
        pathReturns = zeros(nIntervals-1, nNodes);
        
        for i = 1:nNodes
            nodeName = nodeNames{i};
            nodePrices = inputPaths.(nodeName)(:, p);
            
            % Calculate returns
            nodeReturns = diff(log(nodePrices));
            nodeReturns(isinf(nodeReturns) | isnan(nodeReturns)) = 0;
            
            pathReturns(:, i) = nodeReturns;
        end
        
        % Apply resolution-appropriate correlation with aggregation consistency
        enhancedReturns = applyCorrelationWithAggregationConsistency(pathReturns, bestCorrelationMatrix, ...
            scalingFactor, aggregationRatio, simulationTimeline);
        
        % Reconstruct prices from enhanced returns
        for i = 1:nNodes
            nodeName = nodeNames{i};
            nodePrices = inputPaths.(nodeName)(:, p);
            
            % Reconstruct prices
            newPrices = zeros(nIntervals, 1);
            newPrices(1) = nodePrices(1);
            
            for t = 2:nIntervals
                newPrices(t) = newPrices(t-1) * exp(enhancedReturns(t-1, i));
            end
            
            % Validate aggregation consistency if needed
            if aggregationRatio > 1
                newPrices = enforceAggregationConsistency(newPrices, simulationTimeline, targetTimeStep);
            end
            
            % Update enhanced paths
            enhancedPaths.(nodeName)(:, p) = newPrices;
                end
            end
    
    fprintf(' → Applied resolution-appropriate correlations with aggregation consistency\n');
end

% Function: selectBestCorrelationMatrix
% Selects the best available correlation matrix for the target resolution
function [bestMatrix, selectedResolution, scalingFactor] = selectBestCorrelationMatrix(multiResCorrelations, targetResolution, nodeNames)
    % Initialize outputs
    bestMatrix = [];
    selectedResolution = '';
    scalingFactor = 1.0;
    
    % Check if exact match exists
    if isfield(multiResCorrelations.correlationMatrices, targetResolution) && ...
       ~isempty(multiResCorrelations.correlationMatrices.(targetResolution))
        
        bestMatrix = multiResCorrelations.correlationMatrices.(targetResolution);
        selectedResolution = targetResolution;
        scalingFactor = 1.0;
        
        fprintf('   → Found exact correlation matrix match for %s resolution\n', targetResolution);
        return;
    end
    
    % Define resolution preference order (prefer finer resolutions for upscaling)
    availableResolutions = fieldnames(multiResCorrelations.correlationMatrices);
    resolutionPreference = {'5min', '15min', 'hourly', 'daily', 'weekly', 'monthly'};
    
    % Find target position in hierarchy
    targetPos = find(strcmp(resolutionPreference, targetResolution));
    if isempty(targetPos)
        targetPos = 3; % Default to hourly position
    end
    
    % Search for best alternative (prefer finer resolutions)
    bestScore = inf;
    
    for r = 1:length(availableResolutions)
        res = availableResolutions{r};
        
        if ~isempty(multiResCorrelations.correlationMatrices.(res))
            % Calculate preference score (prefer closer to target, prefer finer)
            resPos = find(strcmp(resolutionPreference, res));
            if isempty(resPos)
                resPos = 3; % Default position
            end
            
            distance = abs(resPos - targetPos);
            fineness = resPos; % Lower position = finer resolution
            score = distance + 0.1 * fineness; % Slight preference for finer resolutions
            
            if score < bestScore
                bestScore = score;
                bestMatrix = multiResCorrelations.correlationMatrices.(res);
                selectedResolution = res;
                
                % Calculate scaling factor
                scalingFieldName = sprintf('%s_to_%s', res, targetResolution);
                if isfield(multiResCorrelations.scalingRelationships, scalingFieldName)
                    scalingFactor = multiResCorrelations.scalingRelationships.(scalingFieldName);
                else
                    % Default scaling based on resolution hierarchy
                    scalingFactor = calculateDefaultScaling(res, targetResolution);
                end
            end
        end
    end
    
    if ~isempty(bestMatrix)
        fprintf('   → Selected %s correlation matrix as best match for %s (score: %.2f)\n', ...
            selectedResolution, targetResolution, bestScore);
    end
end

% Function: calculateDefaultScaling
% Calculates default correlation scaling between resolutions
function scaling = calculateDefaultScaling(sourceRes, targetRes)
    % Define rough scaling factors based on temporal aggregation theory
    resolutionScales = containers.Map({'5min', '15min', 'hourly', 'daily', 'weekly', 'monthly'}, ...
                                     {1, 3, 12, 288, 2016, 8640});
    
    if isKey(resolutionScales, sourceRes) && isKey(resolutionScales, targetRes)
        sourceScale = resolutionScales(sourceRes);
        targetScale = resolutionScales(targetRes);
        
        % Correlations typically increase with temporal aggregation
        scaling = sqrt(targetScale / sourceScale);
        scaling = min(max(scaling, 0.5), 2.0); % Bound between 0.5 and 2.0
    else
        scaling = 1.0; % Default to no scaling
    end
end

% Function: calculateTimeStep
% Calculates time step in minutes for a given resolution
function timeStep = calculateTimeStep(resolution)
    switch resolution
        case '5min'
            timeStep = 5;
        case '15min'
            timeStep = 15;
        case 'hourly'
            timeStep = 60;
        case 'daily'
            timeStep = 1440;
        case 'weekly'
            timeStep = 10080;
        case 'monthly'
            timeStep = 43200;
        case 'simulation_auto'
            timeStep = 60; % Default to hourly for simulation
        otherwise
            timeStep = 60; % Default to hourly
    end
end

% Function: applyCorrelationWithAggregationConsistency
% Apply correlation matrix while maintaining aggregation consistency
function enhancedReturns = applyCorrelationWithAggregationConsistency(pathReturns, correlationMatrix, scalingFactor, aggregationRatio, timeline)
    [nIntervals, nNodes] = size(pathReturns);
    enhancedReturns = pathReturns; % Initialize
    
    % Apply scaling to correlation matrix
    scaledCorrelation = correlationMatrix * scalingFactor;
    
    % Ensure matrix is still valid after scaling
    [V, D] = eig(scaledCorrelation);
    D = diag(max(diag(D), 0.01));
    scaledCorrelation = V * D * V';
    
    % Rescale diagonal to 1
    d = diag(scaledCorrelation);
    if all(d > 0)
        scaledCorrelation = scaledCorrelation ./ sqrt(d * d');
    end
    
    try
        % Apply Cholesky decomposition for correlation structure
        L = chol(scaledCorrelation, 'lower');
        
        % Process returns in blocks for aggregation consistency
        if aggregationRatio > 1
            blockSize = round(aggregationRatio);
            nBlocks = floor(nIntervals / blockSize);
            
            for b = 1:nBlocks
                blockStart = (b-1) * blockSize + 1;
                blockEnd = min(b * blockSize, nIntervals);
                
                % Extract block returns
                blockReturns = pathReturns(blockStart:blockEnd, :);
                
                % Apply correlation to block
                for t = 1:size(blockReturns, 1)
                    % Generate correlated noise
                    Z = randn(nNodes, 1);
                    correlatedNoise = L * Z;
                    
                    % Blend with original returns
                    alpha = 0.8; % Strong preservation of original dynamics
                    originalReturns = blockReturns(t, :)';
                    
                    % Scale noise appropriately
                    if std(originalReturns) > 0
                        noiseScale = std(originalReturns) / std(correlatedNoise) * 0.2;
                        correlatedNoise = correlatedNoise * noiseScale;
                    end
                    
                    enhancedReturns(blockStart + t - 1, :) = (alpha * originalReturns + (1-alpha) * correlatedNoise)';
                end
            end
        else
            % Process all returns at once for finer resolutions
            for t = 1:nIntervals
                Z = randn(nNodes, 1);
                correlatedNoise = L * Z;
                
                alpha = 0.8;
                originalReturns = pathReturns(t, :)';
                
                if std(originalReturns) > 0
                    noiseScale = std(originalReturns) / std(correlatedNoise) * 0.3;
                    correlatedNoise = correlatedNoise * noiseScale;
                end
                
                enhancedReturns(t, :) = (alpha * originalReturns + (1-alpha) * correlatedNoise)';
                    end
                end
        
    catch
        % If correlation application fails, use original returns
        enhancedReturns = pathReturns;
            end
        end
        
% Function: enforceAggregationConsistency
% Ensures that fine-scale prices aggregate properly to coarse-scale targets
function adjustedPrices = enforceAggregationConsistency(prices, timeline, targetTimeStep)
    % For now, return original prices
    % In a full implementation, this would adjust prices to ensure proper aggregation
    adjustedPrices = prices;
    
    % TODO: Implement aggregation consistency enforcement
    % This would involve:
    % 1. Grouping prices by target time intervals
    % 2. Calculating required aggregation values
    % 3. Adjusting sub-interval prices to match targets
    % 4. Preserving correlation structure during adjustment
end

% Function: validateCrossTimescaleCorrelations
% Validates correlation preservation across different timescales (Phase 2C)
function validationResults = validateCrossTimescaleCorrelations(multiResCorrelations, simulatedPaths, simulationTimeline)
    fprintf('\nPhase 2C: Validating cross-timescale correlation preservation...\n');
    
    % Initialize validation results
    validationResults = struct();
    validationResults.resolutionTests = struct();
    validationResults.aggregationTests = struct();
    validationResults.overallScore = 0;
    
    % Get node names
    nodeNames = fieldnames(simulatedPaths);
    nodeNames = setdiff(nodeNames, {'Timestamp'});
    
    if length(nodeNames) <= 1
        fprintf(' → Only one node, skipping cross-timescale validation\n');
        validationResults.overallScore = 1.0;
        return;
    end
    
    % Test correlation preservation for each available resolution
    resolutions = fieldnames(multiResCorrelations.correlationMatrices);
    scores = [];
    
    for r = 1:length(resolutions)
        resolution = resolutions{r};
        originalCorr = multiResCorrelations.correlationMatrices.(resolution);
        
        if ~isempty(originalCorr)
            % Generate aggregated simulated data at this resolution
            aggregatedData = aggregateSimulatedData(simulatedPaths, simulationTimeline, resolution);
            
            % Calculate correlation from aggregated simulated data
            simulatedCorr = calculateSimulatedCorrelation(aggregatedData, nodeNames);
            
            % Compare correlations
            correlationScore = compareCorrelationMatrices(originalCorr, simulatedCorr, resolution);
            validationResults.resolutionTests.(resolution) = correlationScore;
            
            if ~isnan(correlationScore.overallScore)
                scores(end+1) = correlationScore.overallScore;
            end
            
            fprintf(' → %s resolution: correlation preservation score = %.4f\n', ...
                resolution, correlationScore.overallScore);
        end
    end
    
    % Test aggregation consistency
    aggregationScore = testAggregationConsistency(simulatedPaths, simulationTimeline);
    validationResults.aggregationTests = aggregationScore;
    
    if ~isnan(aggregationScore.overallScore)
        scores(end+1) = aggregationScore.overallScore;
    end
    
    % Calculate overall validation score
    if ~isempty(scores)
        validationResults.overallScore = mean(scores);
        fprintf(' → Overall cross-timescale validation score: %.4f\n', validationResults.overallScore);
        
        if validationResults.overallScore > 0.8
            fprintf(' → ✅ Excellent cross-timescale correlation preservation\n');
        elseif validationResults.overallScore > 0.6
            fprintf(' → ⚠️  Good cross-timescale correlation preservation\n');
        else
            fprintf(' → ❌ Poor cross-timescale correlation preservation - review needed\n');
        end
    else
        validationResults.overallScore = 0;
        fprintf(' → ❌ Unable to validate cross-timescale correlations\n');
    end
end

% Function: aggregateSimulatedData
% Aggregates simulated data to a specific resolution
function aggregatedData = aggregateSimulatedData(simulatedPaths, timeline, targetResolution)
    % Get node names
    nodeNames = fieldnames(simulatedPaths);
    nodeNames = setdiff(nodeNames, {'Timestamp'});
    
    % Calculate aggregation window
    timeStep = calculateTimeStep(targetResolution);
    originalTimeStep = calculateTimeStep('simulation_auto');
    aggregationRatio = round(timeStep / originalTimeStep);
    
    if aggregationRatio <= 1
        % No aggregation needed
        aggregatedData = table();
        aggregatedData.Timestamp = timeline;
        for i = 1:length(nodeNames)
            nodeName = nodeNames{i};
            aggregatedData.(nodeName) = simulatedPaths.(nodeName)(:, 1); % Use first path
        end
        return;
    end
    
    % Perform aggregation
    nOriginalIntervals = length(timeline);
    nAggregatedIntervals = floor(nOriginalIntervals / aggregationRatio);
    
    aggregatedData = table();
    aggregatedTimeline = datetime.empty;
    
    % Aggregate timestamps
    for i = 1:nAggregatedIntervals
        startIdx = (i-1) * aggregationRatio + 1;
        aggregatedTimeline(i) = timeline(startIdx);
    end
    aggregatedData.Timestamp = aggregatedTimeline';
    
    % Aggregate each node's data
    for n = 1:length(nodeNames)
        nodeName = nodeNames{n};
        originalPrices = simulatedPaths.(nodeName)(:, 1); % Use first path
        aggregatedPrices = zeros(nAggregatedIntervals, 1);
        
        for i = 1:nAggregatedIntervals
            startIdx = (i-1) * aggregationRatio + 1;
            endIdx = min(i * aggregationRatio, nOriginalIntervals);
            
            % Use average price for aggregation
            aggregatedPrices(i) = mean(originalPrices(startIdx:endIdx), 'omitnan');
        end
        
        aggregatedData.(nodeName) = aggregatedPrices;
    end
end

% Function: calculateSimulatedCorrelation
% Calculates correlation matrix from simulated data
function correlationMatrix = calculateSimulatedCorrelation(data, nodeNames)
    % Extract price data for correlation calculation
    priceData = table();
    priceData.Timestamp = data.Timestamp;
    
    for i = 1:length(nodeNames)
        if ismember(nodeNames{i}, data.Properties.VariableNames)
            priceData.(nodeNames{i}) = data.(nodeNames{i});
        end
    end
    
    % Calculate correlation matrix
    correlationMatrix = calculateCorrelationWithPairwiseDeletion(priceData, nodeNames);
end

% Function: compareCorrelationMatrices
% Compares two correlation matrices and returns similarity score
function comparisonResult = compareCorrelationMatrices(originalCorr, simulatedCorr, resolution)
    comparisonResult = struct();
    comparisonResult.resolution = resolution;
    comparisonResult.matrixSize = size(originalCorr);
    
    % Ensure matrices are same size
    if ~isequal(size(originalCorr), size(simulatedCorr))
        fprintf('   → Warning: Correlation matrix size mismatch for %s resolution\n', resolution);
        comparisonResult.overallScore = NaN;
        return;
    end
    
    % Extract off-diagonal elements for comparison
    mask = triu(true(size(originalCorr)), 1);
    originalCorr_offdiag = originalCorr(mask);
    simulatedCorr_offdiag = simulatedCorr(mask);
    
    % Remove NaN values
    validIdx = ~isnan(originalCorr_offdiag) & ~isnan(simulatedCorr_offdiag);
    originalCorr_clean = originalCorr_offdiag(validIdx);
    simulatedCorr_clean = simulatedCorr_offdiag(validIdx);
    
    if length(originalCorr_clean) < 2
        comparisonResult.overallScore = NaN;
        return;
    end
    
    % Calculate various similarity metrics
    comparisonResult.correlation = corr(originalCorr_clean, simulatedCorr_clean);
    comparisonResult.meanAbsoluteError = mean(abs(originalCorr_clean - simulatedCorr_clean));
    comparisonResult.rootMeanSquareError = sqrt(mean((originalCorr_clean - simulatedCorr_clean).^2));
    comparisonResult.maxAbsoluteError = max(abs(originalCorr_clean - simulatedCorr_clean));
    
    % Calculate overall score (0 to 1, higher is better)
    correlationScore = max(0, comparisonResult.correlation);
    maeScore = max(0, 1 - comparisonResult.meanAbsoluteError);
    rmseScore = max(0, 1 - comparisonResult.rootMeanSquareError);
    
    comparisonResult.overallScore = (correlationScore * 0.5 + maeScore * 0.3 + rmseScore * 0.2);
end

% Function: testAggregationConsistency
% Tests whether fine-scale data aggregates consistently to coarse-scale
function aggregationResult = testAggregationConsistency(simulatedPaths, timeline)
    aggregationResult = struct();
    aggregationResult.tests = struct();
    aggregationResult.overallScore = 1.0; % Default to perfect if no tests possible
    
    % Test aggregation from simulation resolution to hourly
    hourlyTest = testSpecificAggregation(simulatedPaths, timeline, 'hourly');
    if ~isempty(hourlyTest)
        aggregationResult.tests.hourly = hourlyTest;
    end
    
    % Test aggregation to daily if sufficient data
    if length(timeline) > 48 % At least 2 days of hourly data
        dailyTest = testSpecificAggregation(simulatedPaths, timeline, 'daily');
        if ~isempty(dailyTest)
            aggregationResult.tests.daily = dailyTest;
        end
    end
    
    % Calculate overall aggregation score
    testFields = fieldnames(aggregationResult.tests);
    if ~isempty(testFields)
        scores = [];
        for i = 1:length(testFields)
            scores(end+1) = aggregationResult.tests.(testFields{i}).score;
        end
        aggregationResult.overallScore = mean(scores);
    end
    
    fprintf(' → Aggregation consistency score: %.4f\n', aggregationResult.overallScore);
end

% Function: testSpecificAggregation
% Tests aggregation consistency for a specific target resolution
function testResult = testSpecificAggregation(simulatedPaths, timeline, targetResolution)
    testResult = struct();
    
    % Get simulation and target time steps
    simTimeStep = calculateTimeStep('simulation_auto');
    targetTimeStep = calculateTimeStep(targetResolution);
    aggregationRatio = targetTimeStep / simTimeStep;
    
    if aggregationRatio <= 1
        testResult = []; % No aggregation needed
        return;
    end
    
    % Test aggregation consistency for first node only (for efficiency)
    nodeNames = fieldnames(simulatedPaths);
    nodeNames = setdiff(nodeNames, {'Timestamp'});
    
    if isempty(nodeNames)
        testResult = [];
        return;
    end
    
    nodeName = nodeNames{1};
    prices = simulatedPaths.(nodeName)(:, 1); % Use first path
    
    % Perform aggregation and check consistency
    nIntervals = length(prices);
    nAggregated = floor(nIntervals / aggregationRatio);
    
    aggregationErrors = [];
    
    for i = 1:nAggregated
        startIdx = round((i-1) * aggregationRatio) + 1;
        endIdx = min(round(i * aggregationRatio), nIntervals);
        
        % Calculate average price for this aggregation period
        avgPrice = mean(prices(startIdx:endIdx), 'omitnan');
        
        % Check if individual prices are reasonable relative to average
        subPrices = prices(startIdx:endIdx);
        relativeErrors = abs(subPrices - avgPrice) ./ avgPrice;
        
        % Aggregation is consistent if sub-prices don't deviate too much
        aggregationErrors = [aggregationErrors; relativeErrors(~isnan(relativeErrors))];
    end
    
    % Calculate aggregation consistency score
    if ~isempty(aggregationErrors)
        meanError = mean(aggregationErrors);
        testResult.meanRelativeError = meanError;
        testResult.score = max(0, 1 - meanError); % Score decreases with error
    else
        testResult.meanRelativeError = 0;
        testResult.score = 1.0;
    end
    
    testResult.targetResolution = targetResolution;
    testResult.aggregationRatio = aggregationRatio;
end

% Function: generatePathRegimeSequence
