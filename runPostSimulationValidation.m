% runPostSimulationValidation.m
% Orchestrates Sprint 6: Post-simulation validation and automated diagnostics

function runPostSimulationValidation(configFile)
%RUNPOSTSIMULATIONVALIDATION Run post-simulation validation and diagnostics for Sprint 6.
%   Loads simulated and historical data, compares stylized facts, generates reports and plots.

run(configFile); % Loads config
outputDir = config.validation.outputDir;
if ~exist(outputDir, 'dir'), mkdir(outputDir); end
load('Simulation_Results/simPaths.mat', 'simPaths');
load('Simulation_Results/regimePaths.mat', 'regimePaths');
load('Simulation_Results/pathDiagnostics.mat', 'pathDiagnostics');
load('EDA_Results/returnsTable.mat', 'returnsTable');
load('EDA_Results/regimeLabels.mat', 'regimeLabels');
products = fieldnames(simPaths);
nProducts = numel(products);
nPaths = size(simPaths.(products{1}),2);

flagged = {};
summary = {};
summary{end+1} = sprintf('Sprint 6 Validation Summary (%s)', datestr(now));
summary{end+1} = 'Diagnostics run:';
if config.validation.enableReturnDist, summary{end+1} = '  - Return distribution'; end
if config.validation.enableVolClustering, summary{end+1} = '  - Volatility clustering (ACF)'; end
if config.validation.enableJumpAnalysis, summary{end+1} = '  - Jump frequency/size'; end
if config.validation.enableRegimeDurations, summary{end+1} = '  - Regime durations/transitions'; end
if config.validation.enableCorrMatrix, summary{end+1} = '  - Cross-asset correlations'; end
summary{end+1} = '';
summary{end+1} = 'Flagged deviations:';

for i = 1:nProducts
    pname = products{i};
    % Historical returns
    histReturns = returnsTable.(pname);
    % Simulated returns (all paths)
    simData = simPaths.(pname);
    simReturns = diff(simData,1,1);
    % --- 1. Return distributions ---
    if config.validation.enableReturnDist
        figure;
        histogram(histReturns, 50, 'Normalization', 'pdf'); hold on;
        histogram(simReturns(:), 50, 'Normalization', 'pdf');
        legend('Historical', 'Simulated');
        title(['Return Distribution: ' pname]);
        xlabel('Return'); ylabel('PDF');
        saveas(gcf, fullfile(outputDir, ['returns_dist_' pname '.png'])); close;
    end
    % Summary stats
    stats = @(x) [mean(x,'omitnan'), std(x,'omitnan'), skewness(x,'omitnan'), kurtosis(x,'omitnan')];
    histStats = stats(histReturns);
    simStats = stats(simReturns(:));
    fprintf('Return stats for %s: Hist [mean=%.3g std=%.3g skew=%.3g kurt=%.3g], Sim [mean=%.3g std=%.3g skew=%.3g kurt=%.3g]\n', ...
        pname, histStats, simStats);
    % --- 2. Volatility clustering (ACF of squared returns) ---
    if config.validation.enableVolClustering
        figure;
        acfHist = autocorr(histReturns.^2, 'NumLags', 50);
        acfSim = autocorr(simReturns(:).^2, 'NumLags', 50);
        plot(0:50, acfHist, 'b-', 0:50, acfSim, 'r--', 'LineWidth', 1.5);
        legend('Historical', 'Simulated');
        title(['ACF of Squared Returns: ' pname]); xlabel('Lag'); ylabel('ACF');
        saveas(gcf, fullfile(outputDir, ['acf2_' pname '.png'])); close;
    end
    % --- 3. Jump frequency and size ---
    if config.validation.enableJumpAnalysis
        jumpThresh = 4 * std(histReturns, 'omitnan');
        histJumps = abs(histReturns) > jumpThresh;
        simJumps = abs(simReturns(:)) > jumpThresh;
        figure;
        histogram(histReturns(histJumps), 30, 'Normalization', 'pdf'); hold on;
        histogram(simReturns(simJumps), 30, 'Normalization', 'pdf');
        legend('Historical', 'Simulated');
        title(['Jump Size Distribution: ' pname]); xlabel('Jump Size'); ylabel('PDF');
        saveas(gcf, fullfile(outputDir, ['jumps_' pname '.png'])); close;
        fprintf('Jump freq for %s: Hist %.3g, Sim %.3g\n', pname, mean(histJumps), mean(simJumps));
    end
    % --- 4. Regime durations and transitions ---
    if config.validation.enableRegimeDurations
        histRegimes = regimeLabels.(pname);
        simRegimes = regimePaths.(pname);
        for pathIdx = 1:nPaths
            simRegSeq = simRegimes(:,pathIdx);
            durs = diff(find([1; diff(simRegSeq)~=0; 1]));
            figure; histogram(durs, 'BinMethod', 'integers');
            title(sprintf('Simulated Regime Durations: %s Path %d', pname, pathIdx));
            xlabel('Duration'); ylabel('Count');
            saveas(gcf, fullfile(outputDir, sprintf('regime_durations_%s_path%d.png', pname, pathIdx)));
        end
    end
    % --- 5. Cross-asset correlations ---
    if config.validation.enableCorrMatrix
        histMat = nan(length(histReturns), nProducts);
        simMat = nan(numel(simReturns)/nPaths, nProducts);
        for j = 1:nProducts
            histMat(:,j) = returnsTable.(products{j});
            simMat(:,j) = reshape(diff(simPaths.(products{j}),1,1), [], 1);
        end
        histCorr = corr(histMat, 'rows', 'pairwise');
        simCorr = corr(simMat, 'rows', 'pairwise');
        figure;
        subplot(1,2,1); imagesc(histCorr); colorbar; title('Historical Correlation');
        set(gca, 'XTick', 1:nProducts, 'XTickLabel', products, 'YTick', 1:nProducts, 'YTickLabel', products);
        subplot(1,2,2); imagesc(simCorr); colorbar; title('Simulated Correlation');
        set(gca, 'XTick', 1:nProducts, 'XTickLabel', products, 'YTick', 1:nProducts, 'YTickLabel', products);
        saveas(gcf, fullfile(outputDir, ['correlation_' pname '.png'])); close;
    end
    % Automated flagging (collect for summary)
    if config.validation.enableReturnDist && abs(histStats(2) - simStats(2)) > config.validation.stdDeviationThreshold*histStats(2)
        msg = sprintf('Simulated std for %s deviates >%.0f%% from historical.', pname, 100*config.validation.stdDeviationThreshold);
        warning(msg);
        flagged{end+1} = msg;
    end
    if config.validation.enableJumpAnalysis && abs(mean(histJumps) - mean(simJumps)) > config.validation.jumpDeviationThreshold*mean(histJumps)
        msg = sprintf('Simulated jump freq for %s deviates >%.0f%% from historical.', pname, 100*config.validation.jumpDeviationThreshold);
        warning(msg);
        flagged{end+1} = msg;
    end
end
if isempty(flagged)
    summary{end+1} = '  None.';
else
    for k = 1:numel(flagged)
        summary{end+1} = ['  ' flagged{k}];
    end
end
summary{end+1} = '';
summary{end+1} = 'Next steps:';
summary{end+1} = '  - Review flagged diagnostics.';
summary{end+1} = '  - If needed, adjust simulation parameters and rerun.';
summary{end+1} = '  - Consider automated tuning loop for persistent deviations.';
summary{end+1} = '';
summary{end+1} = 'See plots and details in the validation output directory.';

% Save summary
fid = fopen(fullfile(outputDir, 'validation_summary.txt'), 'w');
for k = 1:numel(summary)
    fprintf(fid, '%s\n', summary{k});
end
fclose(fid);

fprintf('Sprint 6 complete: Validation results and diagnostics saved to %s.\n', outputDir);
end 