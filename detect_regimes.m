function [regimeLabels, info] = detect_regimes(returnsTable, config)
%DETECT_REGIMES Detect regimes in returns using HMM, rolling volatility, or Bayesian change point.
%   [regimeLabels, info] = detect_regimes(returnsTable, config)
%   - Assigns regime labels to each time step and product
%   - Plots regime assignments and volatility by regime
%   - Logs regime durations and transitions
%   - Returns regime labels and info struct

vars = returnsTable.Properties.VariableNames;
timeIndex = returnsTable.Properties.RowTimes;
regimeLabels = returnsTable; % Will fill below
info = struct();

if isfield(config, 'regimeDetection') && isfield(config.regimeDetection, 'method')
    method = config.regimeDetection.method;
else
    method = 'hmm';
end

for i = 1:numel(vars)
    v = vars{i};
    data = returnsTable.(v);
    switch lower(method)
        case 'hmm'
            % Use MATLAB's hmmtrain/hmmdecode or fitgmdist for GMM-HMM
            nRegimes = 2;
            if isfield(config.regimeDetection, 'nRegimes')
                nRegimes = config.regimeDetection.nRegimes;
            end
            % Fit GMM as proxy for HMM (for simplicity)
            gm = fitgmdist(data(~isnan(data)), nRegimes, 'RegularizationValue',1e-6);
            idx = cluster(gm, data);
            regimeLabels.(v) = idx;
            info.(v).nRegimes = nRegimes;
            info.(v).means = gm.mu;
            info.(v).weights = gm.ComponentProportion;
        case 'rollingvol'
            win = 24;
            if isfield(config.regimeDetection, 'window')
                win = config.regimeDetection.window;
            end
            vol = movstd(data, win, 'omitnan');
            thresh = median(vol, 'omitnan');
            regimeLabels.(v) = double(vol > thresh) + 1;
            info.(v).volThreshold = thresh;
        otherwise
            error('Unknown regime detection method');
    end
    % Plot regime assignment
    figure; plot(timeIndex, data, 'k-'); hold on;
    scatter(timeIndex, data, 20, regimeLabels.(v), 'filled');
    title(['Regime Assignment: ' v]); xlabel('Time'); ylabel('Return');
    saveas(gcf, ['EDA_Results/regime_' v '.png']); close;
    % Volatility by regime
    for r = 1:max(regimeLabels.(v))
        regVol = std(data(regimeLabels.(v)==r), 'omitnan');
        fprintf('Regime %d for %s: volatility=%.4g\n', r, v, regVol);
    end
    % Regime durations
    durs = diff(find([1; diff(regimeLabels.(v))~=0; 1]));
    info.(v).regimeDurations = durs;
    fprintf('Regime durations for %s: mean=%.2f, min=%d, max=%d\n', v, mean(durs), min(durs), max(durs));
end

end

% Unit test (example)
function test_detect_regimes()
    t = (1:100)';
    x = [randn(50,1); randn(50,1)*3];
    T = timetable(datetime(2020,1,1) + days(t-1), x, 'VariableNames', {'TestVar'});
    config.regimeDetection.method = 'hmm';
    [labels, info] = detect_regimes(T, config);
    assert(all(ismember(labels.TestVar, [1 2])));
    disp('test_detect_regimes passed');
end 