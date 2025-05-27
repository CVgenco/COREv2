function stats = extractVolatilityAndJumps(timestamps, values, varargin)
% extractVolatilityAndJumps Extracts volatility and jump statistics from a time series.
%   stats = extractVolatilityAndJumps(timestamps, values, ...)
%   Computes rolling and global volatility, jump frequency, and descriptive stats.
%   Inputs:
%     timestamps - datetime vector (optional, for plotting)
%     values     - numeric vector (time series values)
%     'Window'   - rolling window size (default: 24)
%   Output:
%     stats - struct with fields:
%         .globalVolatility
%         .rollingVolatility
%         .jumpFrequency (fraction of returns > 95th percentile)
%         .mean, .std, .min, .max, .skewness, .kurtosis
%         .nJumps, .nObs
%         .rollingWindow

p = inputParser;
p.addParameter('Window', 24, @(x) isnumeric(x) && isscalar(x) && x > 1);
p.parse(varargin{:});
window = p.Results.Window;

values = values(:);
if nargin > 0 && ~isempty(timestamps)
    timestamps = timestamps(:);
else
    timestamps = (1:length(values))';
end

% Remove NaNs for all calculations
valuesValid = values(~isnan(values));
timestampsValid = timestamps(~isnan(values));
n = numel(valuesValid);
if n < 2
    stats = struct('volatility', NaN, 'skewness', NaN, 'kurtosis', NaN, 'nJumps', 0, 'jumpIndices', [], 'jumpSizes', []);
    return;
end

% Volatility (std of returns)
returns = diff(valuesValid);
stats.volatility = std(returns);

% Skewness and kurtosis
stats.skewness = skewness(valuesValid);
stats.kurtosis = kurtosis(valuesValid);

% Jumps: define as returns > 4*std
jumpThresh = 4 * stats.volatility;
jumpIdx = find(abs(returns) > jumpThresh);
stats.nJumps = numel(jumpIdx);
stats.jumpIndices = jumpIdx + 1; % Index in valuesValid
stats.jumpSizes = returns(jumpIdx);

% Global volatility
stats.globalVolatility = std(returns, 'omitnan');

% Rolling volatility
if length(valuesValid) >= window
    stats.rollingVolatility = movstd(returns, window, 'omitnan');
else
    stats.rollingVolatility = nan(size(returns));
end
stats.rollingWindow = window;

% Descriptive stats
stats.mean = mean(valuesValid, 'omitnan');
stats.std = std(valuesValid, 'omitnan');
stats.min = min(valuesValid);
stats.max = max(valuesValid);
stats.nObs = length(returns);
stats.jumpFrequency = stats.nJumps / max(1, stats.nObs);

% Optionally, plot rolling volatility and jumps
if nargout == 0 || any(strcmp(varargin, 'plot'))
    figure;
    subplot(2,1,1);
    plot(timestampsValid(2:end), abs(returns)); hold on;
    yline(jumpThresh, 'r--', '4*std');
    title('Absolute Returns and Jump Threshold'); ylabel('Abs(Return)');
    subplot(2,1,2);
    plot(timestampsValid(2:end), stats.rollingVolatility);
    title(sprintf('Rolling Volatility (window=%d)', window)); ylabel('Volatility');
    xlabel('Time');
end

end 