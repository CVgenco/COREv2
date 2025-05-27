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
    % Diagnostic: print NaN summary for input returnsTable
    nanIdx = find(isnan(data));
    if ~isempty(nanIdx)
        fprintf('Input to regime detection, %s has %d NaNs at indices: ', v, numel(nanIdx));
        if numel(nanIdx) <= 10
            fprintf('%s\n', mat2str(nanIdx));
        else
            fprintf('%s ...\n', mat2str(nanIdx(1:10)));
        end
    else
        fprintf('Input to regime detection, %s has no NaNs.\n', v);
    end
    % Winsorize data to reduce outlier effect
    dataWins = data;
    validIdx = ~isnan(data) & isfinite(data) & isreal(data);
    if any(validIdx)
        p = prctile(data(validIdx), [1 99]);
        dataWins(validIdx) = min(max(data(validIdx), p(1)), p(2));
    end
    data = dataWins;
    switch lower(method)
        case 'hmm'
            % Use MATLAB's hmmtrain/hmmdecode or fitgmdist for GMM-HMM
            nRegimes = 2;
            if isfield(config.regimeDetection, 'nRegimes')
                nRegimes = config.regimeDetection.nRegimes;
            end
            % Only use valid (non-NaN) data
            validData = data(~isnan(data));
            numUnique = numel(unique(validData));
            numValid = numel(validData);

            fprintf('detect_regimes: %d valid data points, %d unique values\n', numValid, numUnique);

            if ischar(nRegimes) && strcmpi(nRegimes, 'auto')
                nRegimes = 2;
            end

            if numUnique < nRegimes
                warning('Not enough unique values (%d) for %d regimes. Skipping regime detection.', numUnique, nRegimes);
                regimeLabels = NaN(size(data));
                info.method = 'GMM';
                info.status = 'skipped';
                info.reason = 'not enough unique values';
                continue;
            end

            try
                gm = fitgmdist(validData, nRegimes, 'RegularizationValue', 1e-2);
                idx = cluster(gm, validData);
                regimeLabels = NaN(size(data));
                regimeLabels(~isnan(data)) = idx;
                info.method = 'GMM';
                info.status = 'success';
            catch ME
                warning('GMM fitting failed: %s', ME.message);
                regimeLabels = NaN(size(data));
                info = struct('method', 'GMM', 'status', 'failed', 'error', ME.message);
            end

            % --- Plotting diagnostics ---
            try
                % Use timetable row times for x-axis if available
                if istimetable(returnsTable)
                    timeIndex = returnsTable.Properties.RowTimes;
                elseif ismember('Timestamp', returnsTable.Properties.VariableNames)
                    timeIndex = returnsTable.Timestamp;
                else
                    timeIndex = (1:length(data))';
                end
                % Use real part of data
                dataPlot = real(data);
                % Align lengths (returnsTable is usually 1 shorter than cleanedTable)
                n = min(length(timeIndex), length(dataPlot));
                timeIndex = timeIndex(1:n);
                dataPlot = dataPlot(1:n);
                if (isdatetime(timeIndex) || isnumeric(timeIndex)) && isnumeric(dataPlot)
                    figure; plot(timeIndex, dataPlot, 'k-'); hold on;
                else
                    warning('Skipping plot: incompatible types. timeIndex: %s, data: %s', class(timeIndex), class(dataPlot));
                end
            catch plotME
                warning('Plotting failed: %s', plotME.message);
            end
        case 'rollingvol'
            validIdx = ~isnan(data) & isfinite(data) & isreal(data);
            if sum(validIdx) < 10
                warning('Not enough valid data for regime detection in %s. Skipping.', v);
                regimeLabels = NaN(size(data));
                info.method = 'rollingvol';
                info.status = 'skipped';
                info.reason = 'not enough valid data';
                continue;
            end
            % --- Window size selection ---
            if isfield(config.regimeDetection, 'windowSize')
                win = config.regimeDetection.windowSize;
            elseif isfield(config.regimeDetection, 'window')
                win = config.regimeDetection.window;
            else
                win = 24;
            end
            if ischar(win) && strcmpi(win, 'auto')
                % Auto window: use autocorrelation decay (first lag where acf < 1/e)
                acf = autocorr(data(validIdx), 'NumLags', min(100, sum(validIdx)-1));
                decayIdx = find(acf < 1/exp(1), 1, 'first');
                if isempty(decayIdx) || decayIdx < 5
                    win = max(12, round(0.05*sum(validIdx))); % fallback: 5% of data, min 12
                else
                    win = decayIdx;
                end
                info.autoWindow = win;
            end
            % --- Rolling volatility ---
            vol = movstd(data, win, 'omitnan');
            % --- Threshold selection ---
            if isfield(config.regimeDetection, 'threshold')
                thresh = config.regimeDetection.threshold;
            else
                thresh = 'auto';
            end
            if ischar(thresh) && strcmpi(thresh, 'auto')
                % Otsu's method (if Image Processing Toolbox), else 75th percentile
                try
                    if exist('graythresh', 'file') == 2
                        % Normalize vol to [0,1] for graythresh
                        vnorm = (vol - min(vol(validIdx))) / (max(vol(validIdx)) - min(vol(validIdx)) + eps);
                        level = graythresh(vnorm(validIdx));
                        thresh = min(vol(validIdx)) + level * (max(vol(validIdx)) - min(vol(validIdx)));
                        info.autoThresh = {'otsu', thresh};
                    else
                        thresh = quantile(vol(validIdx), 0.75);
                        info.autoThresh = {'quantile75', thresh};
                    end
                catch
                    thresh = median(vol(validIdx), 'omitnan');
                    info.autoThresh = {'median', thresh};
                end
            end
            regimeLabels = double(vol > thresh) + 1;
            info.volThreshold = thresh;
            dataPlot = real(data);
        otherwise
            error('Unknown regime detection method');
    end
    % After regimeLabels assignment, print NaN summary
    nanRegimeIdx = find(isnan(regimeLabels));
    if ~isempty(nanRegimeIdx)
        fprintf('After regime detection, %s regimeLabels has %d NaNs at indices: ', v, numel(nanRegimeIdx));
        if numel(nanRegimeIdx) <= 10
            fprintf('%s\n', mat2str(nanRegimeIdx));
        else
            fprintf('%s ...\n', mat2str(nanRegimeIdx(1:10)));
        end
    else
        fprintf('After regime detection, %s regimeLabels has no NaNs.\n', v);
    end
    % Plot regime assignment
    figure; plot(timeIndex, dataPlot, 'k-'); hold on;
    scatter(timeIndex, dataPlot, 20, regimeLabels, 'filled');
    title(['Regime Assignment: ' v]); xlabel('Time'); ylabel('Return');
    saveas(gcf, ['EDA_Results/regime_' v '.png']); close;
    % Volatility by regime
    for r = 1:max(regimeLabels)
        regVol = std(data(regimeLabels==r), 'omitnan');
        fprintf('Regime %d for %s: volatility=%.4g\n', r, v, regVol);
    end
    % Regime durations
    durs = diff(find([1; diff(regimeLabels)~=0; 1]));
    info.regimeDurations = durs;
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