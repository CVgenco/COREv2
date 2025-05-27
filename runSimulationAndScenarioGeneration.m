% runSimulationAndScenarioGeneration.m
% Script to generate realistic, correlated Monte Carlo simulation paths using user config.

function runSimulationAndScenarioGeneration(configFile, outputDir)
% runSimulationAndScenarioGeneration Generate realistic, correlated Monte Carlo simulation paths using a config file and output directory.
%   configFile: path to the user config .m file
%   outputDir: output directory for simulation results

run(configFile); % Loads config into workspace
if ~exist('config', 'var')
    error('Config variable not found after running %s. Check your config file.', configFile);
end
% Robustly load alignedTable and info if not present
if ~exist('alignedTable', 'var') || ~exist('info', 'var')
    try
        load('EDA_Results/alignedTable.mat', 'alignedTable');
        load('EDA_Results/info.mat', 'info');
    catch
        error('Could not load alignedTable or info from EDA_Results. Run EDA and save these files.');
    end
end
if ~exist('alignedTable', 'var') || ~exist('info', 'var')
    error('Run alignment first to produce alignedTable and info.');
end
if ~exist(outputDir, 'dir'), mkdir(outputDir); end

nPaths = config.simulation.nPaths;
rng(config.simulation.randomSeed); % For reproducibility

% === Load required data ===
if ~exist('patterns', 'var')
    load('EDA_Results/all_patterns.mat', 'patterns');
end
if exist(fullfile('Correlation_Results', 'global_correlation_matrix.mat'), 'file')
    load(fullfile('Correlation_Results', 'global_correlation_matrix.mat'), 'Corr');
    corrMatrix = Corr;
else
    error('Global correlation matrix not found. Run correlation analysis first.');
end
productNames = info.productNames;

% === (Optional) Load forecasts and compute scaling factors ===
% [Removed: All logic related to the optional 'forecasts' variable and general scaling factors.]
scalingFactors = struct();
for i = 1:numel(productNames)
    scalingFactors.(productNames{i}) = 1.0;
end
fprintf('No general mean scaling applied. Only product-specific forecast scaling will be used.\n');

% === Always load regimeInfo if available ===
if exist('EDA_Results/regime_info.mat', 'file')
    load('EDA_Results/regime_info.mat', 'regimeInfo');
    fprintf('Loaded regimeInfo from EDA_Results/regime_info.mat\n');
else
    warning('regime_info.mat not found in EDA_Results. Regime volatility modulation may be skipped.');
end

% === Monte Carlo path generation ===
% Refactored: Returns-centric pipeline
nObs = height(alignedTable);
simReturns = struct();
histFirstPrices = struct();
productNames = info.productNames;
nProducts = numel(productNames);
nPaths = config.simulation.nPaths;

% --- STAGE 1: Robust regime-based block bootstrapping ---
robustBlockSize = 12; % Use shorter blocks for robustness
maxBlockCumSumFactor = 2; % Reject blocks with |sum| > 2*std*sqrt(blockSize)
rollingMeanWindow = 24; % For rolling mean reversion
for i = 1:nProducts
    pname = productNames{i};
    histData = alignedTable.(pname);
    histFirstPrices.(pname) = histData(1);
    histReturns = diff(histData);
    histStd = std(histReturns, 'omitnan');
    nHistReturns = length(histReturns);
    simRet = nan(nObs-1, nPaths);
    % Regime info for this product
    if exist('regimeInfo', 'var') && isfield(regimeInfo, pname)
        histRegimes = regimeInfo.(pname).regimeStates;
    else
        histRegimes = nan(nHistReturns, 1);
    end
    for p = 1:nPaths
        t = 1;
        lastBlockEnd = 0;
        % Start simulated regime sequence at random historical regime
        if ~all(isnan(histRegimes))
            simRegimeSeq = nan(nObs-1, 1);
            simRegimeSeq(1) = histRegimes(randi(numel(histRegimes)));
        else
            simRegimeSeq = nan(nObs-1, 1);
        end
        while t <= nObs-1
            % Determine current regime for simulated path
            if ~all(isnan(simRegimeSeq)) && t > 1
                % For now, just copy previous regime (can add Markov transitions later)
                simRegimeSeq(t) = simRegimeSeq(t-1);
            end
            currentRegime = simRegimeSeq(t);
            % Find all valid block starts in historical data for this regime
            validBlockStarts = [];
            if ~all(isnan(histRegimes)) && ~isnan(currentRegime)
                for idx = 1:(nHistReturns - robustBlockSize + 1)
                    if all(histRegimes(idx:idx+robustBlockSize-1) == currentRegime)
                        validBlockStarts(end+1) = idx; %#ok<AGROW>
                    end
                end
            end
            % If not enough blocks, fall back to any block
            if isempty(validBlockStarts)
                windowStart = 1;
                windowEnd = nHistReturns - robustBlockSize + 1;
                blockStart = randi([windowStart, windowEnd]);
                blockEnd = blockStart + robustBlockSize - 1;
                block = histReturns(blockStart:blockEnd);
                blockRegimes = histRegimes(blockStart:blockEnd);
            else
                blockStart = validBlockStarts(randi(numel(validBlockStarts)));
                blockEnd = blockStart + robustBlockSize - 1;
                block = histReturns(blockStart:blockEnd);
                blockRegimes = histRegimes(blockStart:blockEnd);
            end
            blockLen = length(block);
            % Block filtering: reject if cumulative sum too large
            blockCumSum = sum(block);
            blockCumSumThresh = maxBlockCumSumFactor * histStd * sqrt(blockLen);
            if abs(blockCumSum) > blockCumSumThresh
                fprintf('Rejected block [%d:%d] for %s (cumSum=%.2f, thresh=%.2f)\n', blockStart, blockEnd, pname, blockCumSum, blockCumSumThresh);
                continue; % Resample
            end
            % Diagnostics: print block cumulative sum
            fprintf('Accepted block [%d:%d] for %s (cumSum=%.2f, regime=%s)\n', blockStart, blockEnd, pname, blockCumSum, mat2str(blockRegimes(1)));
            % Rolling mean reversion: subtract rolling mean from block
            if t > rollingMeanWindow
                rollingMean = mean(simRet(t-rollingMeanWindow:t-1,p), 'omitnan');
            else
                rollingMean = 0;
            end
            block = block - rollingMean;
            actualBlockLen = min(blockLen, (nObs-1) - t + 1);
            simRet(t : t + actualBlockLen - 1, p) = block(1:actualBlockLen);
            % Update simulated regime sequence for next block
            if ~all(isnan(simRegimeSeq)) && t + actualBlockLen - 1 <= nObs-1
                simRegimeSeq(t : t + actualBlockLen - 1) = blockRegimes(1:actualBlockLen);
            end
            t = t + actualBlockLen;
            lastBlockEnd = blockEnd;
        end
    end
    % Mean adjustment: subtract mean per path to prevent drift
    simRet = simRet - mean(simRet, 1, 'omitnan');
    simReturns.(pname) = simRet;
end

% --- STAGE 2: Robust jump injection with decorrelation ---
jumpWindow = 12; % Limit to 1 jump per 12 steps
for i = 1:nProducts
    pname = productNames{i};
    histReturns = diff(alignedTable.(pname));
    histStd = std(histReturns, 'omitnan');
    jumpCap = 3 * histStd;
    if isfield(config, 'jumpModeling') && isfield(config.jumpModeling, 'enabled') && config.jumpModeling.enabled
        fprintf('Injecting jumps into simulated returns (robust decorrelation)...\n');
        if ~isfield(patterns, pname) || ~isfield(simReturns, pname), continue; end
        simRet = simReturns.(pname);
        jumpCfg = config.jumpModeling;
        jumpFreq = patterns.(pname).jumpFrequency;
        jumpSizes = patterns.(pname).jumpSizes;
        jumpSizes = max(min(jumpSizes, jumpCap), -jumpCap);
        jumpSizeFit = patterns.(pname).jumpSizeFit;
        if isstruct(jumpSizeFit) && isfield(jumpSizeFit, 'mu') && isfield(jumpSizeFit, 'sigma')
            jumpSizeFit.mu = mean(jumpSizes, 'omitnan');
            jumpSizeFit.sigma = std(jumpSizes, 'omitnan');
        end
        for p = 1:nPaths
            lastJumpIdx = -jumpWindow;
            for t = 1:(nObs-1)
                % Only allow one jump per jumpWindow
                if t - lastJumpIdx < jumpWindow
                    continue;
                end
                if rand < jumpFreq && (~isempty(jumpSizes) || ~isnan(jumpSizeFit.mu))
                    if jumpCfg.useEmpiricalDistribution && ~isempty(jumpSizes)
                        jump = jumpSizes(randi(numel(jumpSizes)));
                    else
                        jump = jumpSizeFit.mu + jumpSizeFit.sigma * randn();
                        jump = max(min(jump, jumpCap), -jumpCap);
                    end
                    if abs(jump) >= jumpCfg.minJumpSize
                        simRet(t,p) = simRet(t,p) + jump;
                        lastJumpIdx = t;
                    end
                end
            end
        end
        simReturns.(pname) = simRet;
    end
end

% --- STAGE 3: Correlate returns across products (BYPASSED for ACF test) ---
% if isfield(config, 'correlation') && config.correlation.enabled
%     % [Correlation code block is commented out for this test]
%     ...
% end
% fprintf('NOTE: Correlation step is BYPASSED for this test.\n');
% The correlation logic (Cholesky/standardization block) below always runs.

% --- STAGE 4: (Optional) Heavy-tailed innovations (skip if block bootstrapping is on) ---
if isfield(config, 'innovationDistribution') && isfield(config.innovationDistribution, 'enabled') && config.innovationDistribution.enabled && ...
   ~(isfield(config, 'blockBootstrapping') && config.blockBootstrapping.enabled)
    fprintf('Injecting heavy-tailed innovations into simulated returns...\n');
    for i = 1:nProducts
        pname = productNames{i};
        simRet = simReturns.(pname);
        for p = 1:nPaths
            for t = 1:(nObs-1)
                switch lower(config.innovationDistribution.type)
                    case 'gaussian'
                        innov = randn();
                    case 't'
                        dof = config.innovationDistribution.degreesOfFreedom;
                        if isempty(dof), dof = 5; end
                        innov = trnd(dof);
                    otherwise
                        innov = randn();
                end
                simRet(t,p) = simRet(t,p) + innov;
            end
        end
        % DIAGNOSTIC: After heavy-tailed innovations
        fprintf('Diagnostics after heavy-tailed innovations for %s:\n', pname);
        fprintf('  min: %g, max: %g, mean: %g, std: %g\n', min(simRet(:)), max(simRet(:)), mean(simRet(:)), std(simRet(:)));
        fprintf('  NaN count: %d, Inf count: %d\n', sum(isnan(simRet(:))), sum(isinf(simRet(:))));
        if max(abs(simRet(:))) > 1e6 || any(isnan(simRet(:))) || any(isinf(simRet(:)))
            error('STOP: Problem detected after heavy-tailed innovations for %s', pname);
        end
        simReturns.(pname) = simRet;
    end
end

% --- STAGE 4: Correlate returns (Cholesky on standardized returns) ---
L = chol(corrMatrix + 1e-9*eye(nProducts), 'lower');
tempReturnsMatrix = zeros(nObs-1, nProducts, nPaths);
for i=1:nProducts
    pname = productNames{i};
    tempReturnsMatrix(:,i,:) = simReturns.(pname);
end
for p = 1:nPaths
    pathReturns = tempReturnsMatrix(:,:,p);
    standardized = zeros(size(pathReturns));
    means = mean(pathReturns,1);
    stds = std(pathReturns,0,1);
    stds(stds<1e-9) = 1; % avoid div by zero
    for i = 1:nProducts
        standardized(:,i) = (pathReturns(:,i) - means(i)) / stds(i);
    end
    correlated = (L * standardized')';
    for i = 1:nProducts
        tempReturnsMatrix(:,i,p) = correlated(:,i) * stds(i) + means(i);
    end
end
for i=1:nProducts
    pname = productNames{i};
    simRet = simReturns.(pname);
    % CAP ALL RETURNS at ±3*histStd before price path reconstruction
    histStd = std(diff(alignedTable.(pname)), 'omitnan');
    capRet = 3 * histStd;
    simRet = max(min(simRet, capRet), -capRet);
    simReturns.(pname) = simRet;
end

% After correlation, simReturns is updated for all products
for i=1:nProducts
    pname = productNames{i};
    simRet = simReturns.(pname);
    % DIAGNOSTIC: After correlation
    fprintf('Diagnostics after correlation for %s:\n', pname);
    fprintf('  min: %g, max: %g, mean: %g, std: %g\n', min(simRet(:)), max(simRet(:)), mean(simRet(:)), std(simRet(:)));
    fprintf('  NaN count: %d, Inf count: %d\n', sum(isnan(simRet(:))), sum(isinf(simRet(:))));
    if max(abs(simRet(:))) > 1e6 || any(isnan(simRet(:))) || any(isinf(simRet(:)))
        error('STOP: Problem detected after correlation for %s', pname);
    end
end

% --- STAGE 5: Reconstruct price paths from returns ---
simPaths = struct();
for i = 1:nProducts
    pname = productNames{i};
    simRet = simReturns.(pname);
    simData = nan(nObs, nPaths);
    simData(1,:) = histFirstPrices.(pname);
    for p = 1:nPaths
        for t = 2:nObs
            simData(t,p) = simData(t-1,p) + simRet(t-1,p);
        end
    end
    simPaths.(pname) = simData;
end

% After price path reconstruction (optional)
for i = 1:nProducts
    pname = productNames{i};
    simData = simPaths.(pname);
    % DIAGNOSTIC: After price path reconstruction for %s
    fprintf('Diagnostics after price path reconstruction for %s:\n', pname);
    fprintf('  min: %g, max: %g, mean: %g, std: %g\n', min(simData(:)), max(simData(:)), mean(simData(:)), std(simData(:)));
    fprintf('  NaN count: %d, Inf count: %d\n', sum(isnan(simData(:))), sum(isinf(simData(:))));
    if max(abs(simData(:))) > 1e6 || any(isnan(simData(:))) || any(isinf(simData(:)))
        error('STOP: Problem detected after price path reconstruction for %s', pname);
    end
end

% === Regime-Switching Volatility Modulation (Sprint 4) ===
if isfield(config, 'regimeVolatilityModulation') && config.regimeVolatilityModulation.enabled
    fprintf('Applying regime-switching volatility modulation (Sprint 4)...\n');
    amp = config.regimeVolatilityModulation.amplificationFactor;
    % Mean reversion/anchoring parameters
    anchorWeight = 0.8; % Stronger mean reversion for debugging
    for i = 1:numel(productNames)
        pname = productNames{i};
        if ~exist('regimeInfo', 'var') || ~isfield(regimeInfo, pname) || all(isnan(regimeInfo.(pname).regimeStates))
            warning('No regime info for %s, skipping regime volatility modulation.', pname);
            continue;
        end
        simData = simPaths.(pname);
        nObs = size(simData,1);
        nPaths = size(simData,2);
        regimeSeq = regimeInfo.(pname).regimeStates;
        nRegimes = regimeInfo.(pname).nRegimes;
        % Get regime-specific volatility from EDA (use std of returns per regime)
        if exist('patterns', 'var') && isfield(patterns, pname) && isfield(patterns.(pname), 'regimeJumpStats')
            regimeStats = patterns.(pname).regimeJumpStats;
            regimeVols = arrayfun(@(r) std(r.jumpSizes, 'omitnan'), regimeStats);
            globalHistStd = std(diff(alignedTable.(pname)), 'omitnan');
            if isnan(globalHistStd) || globalHistStd == 0, globalHistStd = 1e-6; end
            for r_idx = 1:numel(regimeVols)
                if isnan(regimeVols(r_idx)) || regimeVols(r_idx) == 0
                    if isfield(regimeInfo, pname) && isfield(regimeInfo.(pname), 'averageVolatilityPerRegime') && numel(regimeInfo.(pname).averageVolatilityPerRegime) >= r_idx && ~isnan(regimeInfo.(pname).averageVolatilityPerRegime(r_idx)) && regimeInfo.(pname).averageVolatilityPerRegime(r_idx) > 0
                        regimeVols(r_idx) = regimeInfo.(pname).averageVolatilityPerRegime(r_idx);
                        fprintf('INFO: Used regimeInfo.averageVolatilityPerRegime for %s regime %d, Vol: %.4f\n', pname, r_idx, regimeVols(r_idx));
                    else
                        regimeVols(r_idx) = globalHistStd;
                        fprintf('WARNING: regimeVols for %s regime %d was NaN/zero, reset to globalHistStd: %.4f\n', pname, r_idx, globalHistStd);
                    end
                end
            end
            if any(isnan(regimeVols))
                regimeVols(isnan(regimeVols)) = globalHistStd;
            end
        else
            globalHistStd = std(diff(alignedTable.(pname)), 'omitnan');
            if isnan(globalHistStd) || globalHistStd == 0, globalHistStd = 1e-6; end
            regimeVols = globalHistStd * ones(1, nRegimes);
            fprintf('WARNING: No regimeJumpStats for %s. Using globalHistStd for all regimes: %.4f\n', pname, globalHistStd);
        end
        % Set anchor (mean) for mean reversion
        anchor = mean(alignedTable.(pname), 'omitnan');
        histMean = anchor;
        histStd = std(alignedTable.(pname), 'omitnan');
        capPrice = histMean + 5 * histStd;
        minPrice = histMean - 5 * histStd;
        for p = 1:nPaths
            currentPathSimReturns = diff(simData(:,p));
            currentSimVol = std(currentPathSimReturns, 'omitnan');
            for t = 2:nObs
                if t > numel(regimeSeq) || isnan(regimeSeq(t))
                    continue;
                end
                r = regimeSeq(t);
                if r < 1 || r > numel(regimeVols) || isnan(r)
                    continue;
                end
                targetVol = regimeVols(r) * amp;
                if isnan(currentSimVol) || currentSimVol <= 1e-9
                    volRatio = 1.0;
                    if isnan(currentSimVol) || currentSimVol <= 0
                        warning('currentSimVol is %.4f for %s path %d. Setting volRatio to 1.', currentSimVol, pname, p);
                    end
                else
                    volRatio = targetVol / currentSimVol;
                end
                % Cap volRatio to prevent extreme values
                maxVolRatio = 5; % More conservative cap
                if volRatio > maxVolRatio
                    volRatio = maxVolRatio;
                elseif volRatio < (1/maxVolRatio) && volRatio ~= 0
                    volRatio = 1/maxVolRatio;
                elseif volRatio == 0 && targetVol ~=0
                    volRatio = 1e-6;
                end
                if isnan(volRatio) || ~isfinite(volRatio)
                    warning('volRatio became NaN/Inf for %s path %d t %d (targetVol: %.4f, currentSimVol: %.4f). Setting to 1.', pname, p, t, targetVol, currentSimVol);
                    volRatio = 1.0;
                end
                % Compute original return
                originalReturn = simData(t,p) - simData(t-1,p);
                % Cap originalReturn before scaling
                capDiff = 2000;
                if abs(originalReturn) > capDiff
                    warning('Capping originalReturn for %s path %d t %d from %.4e to %.4e', pname, p, t, originalReturn, sign(originalReturn)*capDiff);
                    originalReturn = sign(originalReturn) * capDiff;
                end
                % Apply volatility scaling
                adjReturn = originalReturn * volRatio;
                % Cap adjReturn after scaling
                capAdj = 5000;
                if abs(adjReturn) > capAdj
                    warning('Capping adjReturn for %s path %d t %d from %.4e to %.4e', pname, p, t, adjReturn, sign(adjReturn)*capAdj);
                    adjReturn = sign(adjReturn) * capAdj;
                end
                % Adaptive mean reversion: if price is outside mean ± 3*std, set anchorWeight to 1.0
                anchorWeight = 0.8;
                if abs(simData(t-1,p) - histMean) > 3*histStd
                    anchorWeight = 1.0;
                end
                if anchorWeight > 0
                    anchorPull = anchorWeight * (anchor - simData(t-1,p));
                    adjReturn = adjReturn + anchorPull;
                end
                % Check for NaN/Inf in adjReturn before applying
                if isnan(adjReturn) || ~isfinite(adjReturn)
                    warning('adjReturn became NaN/Inf for %s path %d t %d (originalReturn: %.4f, volRatio: %.4f). Skipping adjustment for this step.', pname, p, t, originalReturn, volRatio);
                else
                    simData(t,p) = simData(t-1,p) + adjReturn;
                end
                % Hard reset/clipping: if price exceeds mean ± 5*std, reset to bound and set next value to same bound
                if simData(t,p) > capPrice
                    warning('HARD RESET: Price for %s path %d t %d exceeded +5*std, resetting to cap.', pname, p, t);
                    simData(t,p) = capPrice;
                    if t < nObs
                        simData(t+1,p) = capPrice; % zero next return
                        simReturns.(pname)(t,p) = 0; % zero out next return
                    end
                elseif simData(t,p) < minPrice
                    warning('HARD RESET: Price for %s path %d t %d exceeded -5*std, resetting to cap.', pname, p, t);
                    simData(t,p) = minPrice;
                    if t < nObs
                        simData(t+1,p) = minPrice; % zero next return
                        simReturns.(pname)(t,p) = 0; % zero out next return
                    end
                end
                % --- Diagnostics: Print sequence of returns before each hard reset ---
                if t > 10
                    fprintf('Returns before hard reset for %s path %d t %d: ', pname, p, t);
                    disp(simReturns.(pname)(t-10:t-1,p)');
                end
            end
        end
        simPaths.(pname) = simData;
    end
end

% === Check for NaNs/Infs in Simulated Data ===
for i = 1:numel(productNames)
    pname = productNames{i};
    if any(~isfinite(simPaths.(pname)), 'all')
        warning('Simulated data for %s contains NaN or Inf values after simulation.', pname);
    end
end

% === Scale simulated ancillary services to match annual forecast ===
ancillaryFields = {'NonSpin','RegDown','RegUp'};
try
    ancillaryAnnual = readtable(config.dataFiles.ancillaryForecast);
    for i = 1:numel(ancillaryFields)
        field = ancillaryFields{i};
        if isfield(simPaths, field) && any(strcmp(ancillaryAnnual.Properties.VariableNames, field))
            simData = simPaths.(field); % [nObs x nPaths]
            % Compute annual mean for each path
            simAnnualMean = mean(simData, 1, 'omitnan');
            targetAnnual = ancillaryAnnual.(field)(1); % Use first row (assume single year)
            scalingFactor = targetAnnual ./ simAnnualMean;
            simPaths.(field) = simData .* scalingFactor; % Scale each path
            fprintf('Scaled %s simulated paths to match annual forecast: %.2f\n', field, targetAnnual);
        end
    end
catch ME
    warning('Could not scale ancillary simulated paths to annual forecast: %s', ME.message);
end

% === Scale simulated hubPrices to match hourly hub forecasts ===
try
    if isfield(config.dataFiles, 'hourlyHubForecasts') && isfield(simPaths, 'hubPrices')
        hubForecasts = readtable(config.dataFiles.hourlyHubForecasts);
        simTimes = alignedTable.Properties.RowTimes;
        forecastTimes = datetime(hubForecasts.Timestamp, 'InputFormat', 'yyyy-MM-dd HH:mm:ss');
        % Harmonize time zones to avoid comparison errors
        if isdatetime(simTimes) && isdatetime(forecastTimes)
            if ~isempty(simTimes.TimeZone) || ~isempty(forecastTimes.TimeZone)
                simTimes.TimeZone = '';
                forecastTimes.TimeZone = '';
            end
        end
        [lia, locb] = ismember(simTimes, forecastTimes);
        forecastVec = nan(size(simTimes));
        forecastVec(lia) = hubForecasts.Price(locb(lia));
        simData = simPaths.hubPrices;
        simMean = mean(simData, 2, 'omitnan');
        scaling = forecastVec ./ simMean;
        for t = 1:length(scaling)
            if ~isnan(scaling(t)) && scaling(t) > 0
                simData(t,:) = simData(t,:) * scaling(t);
            end
        end
        simPaths.hubPrices = simData;
        fprintf('Scaled hubPrices simulated paths to match hourly forecasts.\n');
    end
catch ME
    warning('Could not scale hubPrices to hourly forecasts: %s', ME.message);
end

% === Scale simulated nodalPrices to match hourly nodal forecasts ===
try
    if isfield(config.dataFiles, 'hourlyNodalForecasts') && isfield(simPaths, 'nodalPrices')
        nodalForecasts = readtable(config.dataFiles.hourlyNodalForecasts);
        simTimes = alignedTable.Properties.RowTimes;
        forecastTimes = datetime(nodalForecasts.Timestamp, 'InputFormat', 'yyyy-MM-dd HH:mm:ss');
        % Harmonize time zones to avoid comparison errors
        if isdatetime(simTimes) && isdatetime(forecastTimes)
            if ~isempty(simTimes.TimeZone) || ~isempty(forecastTimes.TimeZone)
                simTimes.TimeZone = '';
                forecastTimes.TimeZone = '';
            end
        end
        [lia, locb] = ismember(simTimes, forecastTimes);
        forecastVec = nan(size(simTimes));
        forecastVec(lia) = nodalForecasts.Price(locb(lia));
        simData = simPaths.nodalPrices;
        simMean = mean(simData, 2, 'omitnan');
        scaling = forecastVec ./ simMean;
        for t = 1:length(scaling)
            if ~isnan(scaling(t)) && scaling(t) > 0
                simData(t,:) = simData(t,:) * scaling(t);
            end
        end
        simPaths.nodalPrices = simData;
        fprintf('Scaled nodalPrices simulated paths to match hourly forecasts.\n');
    end
catch ME
    warning('Could not scale nodalPrices to hourly forecasts: %s', ME.message);
end

% === Save results ===
save(fullfile(outputDir, 'simulated_paths.mat'), 'simPaths', 'productNames');
for i = 1:numel(productNames)
    writematrix(simPaths.(productNames{i}), fullfile(outputDir, [productNames{i} '_simulated_paths.csv']));
end

% === Custom output: One file for all nodalPrices paths with timestamps ===
if isfield(simPaths, 'nodalPrices')
    timestamps = alignedTable.Properties.RowTimes;
    nodalData = simPaths.nodalPrices;
    T = array2table(nodalData, 'VariableNames', strcat('Path_', string(1:size(nodalData,2))));
    T = addvars(T, timestamps, 'Before', 1, 'NewVariableNames', 'Timestamp');
    writetable(T, fullfile(outputDir, 'nodalPrices_allpaths.csv'));
end

% === Custom output: Separate file for each ancillary product with timestamps ===
ancillaryFields = {'NonSpin','RegDown','RegUp'};
for i = 1:numel(ancillaryFields)
    field = ancillaryFields{i};
    if isfield(simPaths, field)
        timestamps = alignedTable.Properties.RowTimes;
        ancData = simPaths.(field);
        T = array2table(ancData, 'VariableNames', strcat('Path_', string(1:size(ancData,2))));
        T = addvars(T, timestamps, 'Before', 1, 'NewVariableNames', 'Timestamp');
        writetable(T, fullfile(outputDir, [field '_allpaths.csv']));
    end
end

% Add diagnostic before volatility modulation
for i = 1:numel(productNames)
    pname = productNames{i};
    simData = simPaths.(pname);
    diffs = diff(simData, 1, 1);
    if max(abs(diffs(:))) > 1e6 || any(isnan(diffs(:))) || any(isinf(diffs(:)))
        error('STOP: Problem detected in price differences before volatility modulation for %s', pname);
    end
end

fprintf('Simulation complete. Results saved to %s\n', outputDir);
end 