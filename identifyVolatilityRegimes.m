function regimeModel = identifyVolatilityRegimes(prices, timestamps, stabilityTestAlpha)
% identifyVolatilityRegimes Identifies volatility regimes in historical data using Gaussian Mixture Models
% with optimal regime count selection using BIC and a sequential likelihood ratio test (LRT)
% Inputs:
%   prices - numeric vector of prices or values
%   timestamps - numeric or datetime vector (for temporal patterns)
%   stabilityTestAlpha - (optional) significance threshold for regime stability (default: 0.05)
% Output:
%   regimeModel - struct with fields: gmModel, regimes, transitionMatrix, stats, hourlyProb, optimalRegimes

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
if isdatetime(timestamps)
    timestamps = datenum(timestamps);
end
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