% analyzeRawBootstrappedACF.m
% Analyze ACF of squared returns from raw bootstrapped returns (pre-correlation)
config = userConfig();
outputDir = config.outputDirs.simulation;
load(fullfile(outputDir, 'raw_bootstrapped_returns.mat'), 'rawBootstrappedReturns', 'productNames');

acfResults = struct();
nLags = 50;

for i = 1:numel(productNames)
    pname = productNames{i};
    fprintf('Analyzing ACF for raw bootstrapped returns of: %s\n', pname);
    returns = rawBootstrappedReturns.(pname); % [nObs-1, nPaths]
    squaredReturns = returns.^2;
    meanSimulatedACF = zeros(nLags + 1, 1);
    for p = 1:size(squaredReturns, 2)
        pathSquaredReturns = squaredReturns(:,p);
        if all(isnan(pathSquaredReturns)) || numel(pathSquaredReturns) < 2
            tempACF = nan(nLags + 1, 1);
        else
            tempACF = autocorr(pathSquaredReturns, 'NumLags', nLags);
        end
        if all(isnan(tempACF))
            tempACF = zeros(nLags + 1, 1);
        end
        meanSimulatedACF = meanSimulatedACF + tempACF;
    end
    meanSimulatedACF = meanSimulatedACF / size(squaredReturns, 2);
    acfResults.(pname).Lags = (0:nLags)';
    acfResults.(pname).SimulatedACF = meanSimulatedACF;
    figure;
    plot(acfResults.(pname).Lags, acfResults.(pname).SimulatedACF, 'b--', 'LineWidth', 1.5);
    title(sprintf('ACF of Squared RAW Bootstrapped Returns: %s', pname));
    xlabel('Lag');
    ylabel('ACF');
    grid on;
    saveas(gcf, fullfile(outputDir, [pname '_raw_bootstrapped_acf.png']));
end
save(fullfile(outputDir, 'raw_bootstrapped_acf_results.mat'), 'acfResults');
fprintf('ACF analysis of raw bootstrapped returns complete.\n'); 