function generatePatternsFile()
%GENERATEPATTERNSFILE Creates the missing all_patterns.mat file for Sprint 4 simulation
%   This function extracts patterns and adds jump modeling fields required by
%   the simulation script runSimulationAndScenarioGeneration.m

fprintf('Generating missing all_patterns.mat file for Sprint 4...\n');

% Load configuration
run('userConfig.m');

% Check if we have the required data files from previous sprints
if ~exist('EDA_Results/returnsTable.mat', 'file')
    error('Missing EDA_Results/returnsTable.mat. Please run Sprint 1 first.');
end

if ~exist('EDA_Results/regimeLabels.mat', 'file')
    error('Missing EDA_Results/regimeLabels.mat. Please run Sprint 1 first.');
end

% Load returns and regime data
fprintf('Loading returns and regime data...\n');
load('EDA_Results/returnsTable.mat', 'returnsTable');
load('EDA_Results/regimeLabels.mat', 'regimeLabels');

% Get product names
if istable(returnsTable)
    productNames = returnsTable.Properties.VariableNames;
else
    productNames = fieldnames(returnsTable);
end

% Initialize patterns structure
patterns = struct();

fprintf('Processing %d products for jump modeling...\n', length(productNames));

for i = 1:length(productNames)
    pname = productNames{i};
    fprintf('  Processing %s (%d/%d)...\n', pname, i, length(productNames));
    
    % Get returns and regime labels for this product
    if istable(returnsTable)
        returns = returnsTable.(pname);
    else
        returns = returnsTable.(pname);
    end
    
    if isfield(regimeLabels, pname)
        regimes = regimeLabels.(pname);
    else
        % If no regime labels, create a single regime
        regimes = ones(size(returns));
    end
    
    % Remove NaN values
    validIdx = ~isnan(returns) & ~isnan(regimes);
    returns = returns(validIdx);
    regimes = regimes(validIdx);
    
    if isempty(returns)
        fprintf('    Warning: No valid data for %s, using default values\n', pname);
        patterns.(pname).jumpFrequency = 0.01;  % Default 1% jump frequency
        patterns.(pname).jumpSizes = [];
        patterns.(pname).jumpSizeFit = struct('mu', 0, 'sigma', 0.1);
        continue;
    end
    
    % Extract jump statistics using fit_jumps_per_regime function
    try
        regimeJumps = fit_jumps_per_regime(returns, regimes, config);
        
        % Aggregate jump statistics across all regimes
        allJumpSizes = [];
        totalObs = 0;
        totalJumps = 0;
        
        regimeNames = fieldnames(regimeJumps);
        for r = 1:length(regimeNames)
            regimeStats = regimeJumps.(regimeNames{r});
            if isfield(regimeStats, 'jumpSizes') && ~isempty(regimeStats.jumpSizes)
                allJumpSizes = [allJumpSizes; regimeStats.jumpSizes(:)];
            end
            if isfield(regimeStats, 'jumpFreq')
                % Weight by number of observations in this regime
                regimeIdx = (regimes == r);
                nRegimeObs = sum(regimeIdx);
                totalJumps = totalJumps + regimeStats.jumpFreq * nRegimeObs;
                totalObs = totalObs + nRegimeObs;
            end
        end
        
        % Calculate overall jump frequency
        if totalObs > 0
            overallJumpFreq = totalJumps / totalObs;
        else
            overallJumpFreq = 0.01; % Default
        end
        
        % Fit overall jump size distribution
        if ~isempty(allJumpSizes)
            jumpMu = mean(allJumpSizes, 'omitnan');
            jumpSigma = std(allJumpSizes, 'omitnan');
            
            % Remove extreme outliers (beyond 3 sigma)
            threshold = 3 * std(returns, 'omitnan');
            allJumpSizes = allJumpSizes(abs(allJumpSizes) <= threshold);
        else
            jumpMu = 0;
            jumpSigma = 0.1 * std(returns, 'omitnan'); % Default based on returns volatility
            allJumpSizes = [];
        end
        
        % Store in patterns structure
        patterns.(pname).jumpFrequency = overallJumpFreq;
        patterns.(pname).jumpSizes = allJumpSizes;
        patterns.(pname).jumpSizeFit = struct('mu', jumpMu, 'sigma', jumpSigma);
        
        fprintf('    Jump frequency: %.4f, Jump sizes: %d samples\n', overallJumpFreq, length(allJumpSizes));
        
    catch ME
        fprintf('    Warning: Error processing jumps for %s: %s\n', pname, ME.message);
        % Use fallback values based on volatility
        volEstimate = std(returns, 'omitnan');
        patterns.(pname).jumpFrequency = 0.01;  % 1% default
        patterns.(pname).jumpSizes = [];
        patterns.(pname).jumpSizeFit = struct('mu', 0, 'sigma', 2 * volEstimate);
    end
end

% Save the patterns file
outputDir = 'EDA_Results';
if ~exist(outputDir, 'dir')
    mkdir(outputDir);
end

outputFile = fullfile(outputDir, 'all_patterns.mat');
save(outputFile, 'patterns');

fprintf('\n✅ Successfully created %s with jump modeling data for %d products\n', outputFile, length(productNames));
fprintf('   File contains the following fields for each product:\n');
fprintf('   - jumpFrequency: Overall jump frequency\n');
fprintf('   - jumpSizes: Array of historical jump sizes\n');
fprintf('   - jumpSizeFit: Structure with mu and sigma for jump size distribution\n');

% Verify the file can be loaded correctly
fprintf('\nVerifying the generated file...\n');
try
    testLoad = load(outputFile, 'patterns');
    testPatterns = testLoad.patterns;
    
    % Check that all required fields exist for each product
    allFieldsPresent = true;
    for i = 1:length(productNames)
        pname = productNames{i};
        if ~isfield(testPatterns, pname)
            fprintf('❌ Missing product: %s\n', pname);
            allFieldsPresent = false;
            continue;
        end
        
        requiredFields = {'jumpFrequency', 'jumpSizes', 'jumpSizeFit'};
        for j = 1:length(requiredFields)
            field = requiredFields{j};
            if ~isfield(testPatterns.(pname), field)
                fprintf('❌ Missing field %s for product %s\n', field, pname);
                allFieldsPresent = false;
            end
        end
        
        % Check jumpSizeFit structure
        if isfield(testPatterns.(pname), 'jumpSizeFit')
            jumpFit = testPatterns.(pname).jumpSizeFit;
            if ~isfield(jumpFit, 'mu') || ~isfield(jumpFit, 'sigma')
                fprintf('❌ jumpSizeFit missing mu or sigma for product %s\n', pname);
                allFieldsPresent = false;
            end
        end
    end
    
    if allFieldsPresent
        fprintf('✅ File verification successful - all required fields present\n');
    else
        fprintf('⚠️  File verification found some issues\n');
    end
    
catch ME
    fprintf('❌ Error verifying file: %s\n', ME.message);
end

fprintf('\nThe all_patterns.mat file is now ready for Sprint 4 simulation.\n');
fprintf('You can now run runSimulationAndScenarioGeneration.m\n');

end
