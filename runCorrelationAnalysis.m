% runCorrelationAnalysis.m
% Script to compute global, regime-based, and exponentially weighted correlation matrices using user config.
% Uses alignedTable, info, and (optionally) regime labels from EDA/pattern extraction.

run('userConfig.m');
outputDir = config.outputDirs.correlation;
if ~exist(outputDir, 'dir'), mkdir(outputDir); end

% === Load aligned data (assume already in workspace) ===
if ~exist('alignedTable', 'var') || ~exist('info', 'var')
    error('Run alignment first to produce alignedTable and info.');
end
productNames = info.productNames;
displayNames = productNames; % Or use more descriptive names if available

% === 1. Global Correlation Matrix ===
try
    dataMatrix = [];
    for i = 1:numel(productNames)
        dataMatrix = [dataMatrix, alignedTable.(productNames{i})];
    end
    Corr = corr(dataMatrix, 'rows', 'pairwise');
    pNames = productNames;
    dNames = productNames;
    save(fullfile(outputDir, 'global_correlation_matrix.mat'), 'Corr', 'pNames', 'dNames');
    writematrix(Corr, fullfile(outputDir, 'global_correlation_matrix.csv'));
    fprintf('\n[Global] Correlation matrix saved to %s\n', fullfile(outputDir, 'global_correlation_matrix.csv'));
    % Overlap diagnostics
    overlapCounts = zeros(numel(productNames));
    for i = 1:numel(productNames)
        for j = 1:numel(productNames)
            overlapCounts(i,j) = sum(~isnan(alignedTable.(productNames{i})) & ~isnan(alignedTable.(productNames{j})));
        end
    end
    writematrix(overlapCounts, fullfile(outputDir, 'global_overlap_counts.csv'));
    fprintf('[Global] Overlap counts saved to %s\n', fullfile(outputDir, 'global_overlap_counts.csv'));
catch ME
    warning('Global correlation matrix calculation failed: %s', ME.message);
end

% === 2. Regime-Based Correlation Matrices (if regime labels available) ===
% Automatically select regimeStates and nRegimes for the main product (nodalPrices or first product)
mainProduct = 'nodalPrices';
if ismember(mainProduct, productNames)
    regimeVar = ['regimeStates_' mainProduct];
    nRegimesVar = ['nRegimes_' mainProduct];
else
    regimeVar = ['regimeStates_' productNames{1}];
    nRegimesVar = ['nRegimes_' productNames{1}];
end
if evalin('base', ['exist(''' regimeVar ''', ''var'')']) && evalin('base', ['exist(''' nRegimesVar ''', ''var'')'])
    regimeStates = evalin('base', regimeVar);
    nRegimes = evalin('base', nRegimesVar);
    try
        regimeCorrelations = struct();
        for r = 1:nRegimes
            regimeIdx = (regimeStates == r);
            if sum(regimeIdx) < 10
                fprintf('[Regime %d] Too few points (%d), skipping.\n', r, sum(regimeIdx));
                continue;
            end
            regimeData = alignedTable(regimeIdx, :);
            dataMatrix = [];
            for i = 1:numel(productNames)
                dataMatrix = [dataMatrix, alignedTable.(productNames{i})(regimeIdx)];
            end
            regCorr = corr(dataMatrix, 'rows', 'pairwise');
            regimeCorrelations.(sprintf('regime_%d', r)) = regCorr;
            writematrix(regCorr, fullfile(outputDir, sprintf('regime_%d_correlation_matrix.csv', r)));
            fprintf('[Regime %d] Correlation matrix saved.\n', r);
        end
        save(fullfile(outputDir, 'regime_correlations.mat'), 'regimeCorrelations');
    catch ME
        warning('Regime-based correlation calculation failed: %s', ME.message);
    end
else
    fprintf('[Regime] Regime labels not found for main product. Skipping regime-based correlations.\n');
end

% === 3. Exponentially Weighted/Time-Varying Correlations ===
try
    % Use config values for minOverlap and consistencyMode; let windowSize be dynamically selected
    tvCorr = buildTimeVaryingCorrelations(alignedTable, productNames, [], displayNames, ...
        'minOverlap', config.timeVaryingCorr.minOverlap, ...
        'consistencyMode', config.timeVaryingCorr.consistencyMode);
    save(fullfile(outputDir, 'time_varying_correlations.mat'), 'tvCorr');
    fprintf('[TimeVarying] Time-varying correlations saved to %s\n', fullfile(outputDir, 'time_varying_correlations.mat'));
catch ME
    warning('Time-varying correlation calculation failed: %s', ME.message);
end

disp('Correlation analysis complete. Results saved to Correlation_Results/'); 