function adaptiveWindowSize = determineAdaptiveCorrelationWindow(alignedData, productNames, adaptiveWindowParams)
    % determineAdaptiveCorrelationWindow Determines an adaptive window size for correlation calculations
    % based on the ACF decay of absolute returns of a primary product.
    
    fprintf(' → Determining adaptive correlation window using method: %s\n', adaptiveWindowParams.method);
    
    if isempty(alignedData) || isempty(productNames)
        fprintf('   → Warning: alignedData or productNames is empty. Using default minWindow.\n');
        adaptiveWindowSize = adaptiveWindowParams.minWindow;
        return;
    end

    % Select the primary product for ACF analysis
    productIdx = adaptiveWindowParams.primaryProductIndex;
    if productIdx > length(productNames) || productIdx < 1
        fprintf('   → Warning: primaryProductIndex is out of bounds. Using first product.\n');
        productIdx = 1;
    end
    primaryProductName = productNames{productIdx};
    
    if ~ismember(primaryProductName, alignedData.Properties.VariableNames)
        fprintf('   → Warning: Primary product %s not found in alignedData. Using default minWindow.\n', primaryProductName);
        adaptiveWindowSize = adaptiveWindowParams.minWindow;
        return;
    end
    
    prices = alignedData.(primaryProductName);
    prices = prices(~isnan(prices) & ~isinf(prices)); % Clean non-finite values
    
    if length(prices) < 20 % Need a minimum number of observations
        fprintf('   → Warning: Not enough observations for product %s after cleaning (count: %d). Using default minWindow.\n', primaryProductName, length(prices));
        adaptiveWindowSize = adaptiveWindowParams.minWindow;
        return;
    end
    
    % Calculate absolute returns
    returns = diff(log(prices));
    returns = returns(~isnan(returns) & ~isinf(returns)); % Clean non-finite returns
    absReturns = abs(returns);
    
    if length(absReturns) < 20
        fprintf('   → Warning: Not enough absolute returns for ACF analysis (count: %d). Using default minWindow.\n', length(absReturns));
        adaptiveWindowSize = adaptiveWindowParams.minWindow;
        return;
    end
    
    % Calculate ACF
    maxLag = min(adaptiveWindowParams.maxLagForACF, length(absReturns) - 1);
    if maxLag <= 0
        fprintf('   → Warning: maxLagForACF is too small or not enough data. Using default minWindow.\n');
        adaptiveWindowSize = adaptiveWindowParams.minWindow;
        return;
    end

    [acfValues, lags, bounds] = autocorr(absReturns, 'NumLags', maxLag);
    
    % Find the lag where ACF first crosses the upper significance bound
    % bounds(1) is the upper significance bound
    significantLag = find(acfValues(2:end) < bounds(1), 1, 'first'); % Start from acfValues(2) as acfValues(1) is lag 0 (corr=1)
    
    if isempty(significantLag)
        fprintf('   → ACF did not drop below significance within maxLag. Using maxLagForACF or maxWindow.\n');
        estimatedWindow = maxLag; % Or adaptiveWindowParams.maxLagForACF
    else
        estimatedWindow = lags(significantLag + 1); % +1 because we searched from acfValues(2:end)
        fprintf('   → ACF for %s (abs returns) dropped below significance at lag: %d\n', primaryProductName, estimatedWindow);
    end
    
    % Apply min/max bounds from config
    adaptiveWindowSize = max(adaptiveWindowParams.minWindow, estimatedWindow);
    adaptiveWindowSize = min(adaptiveWindowParams.maxWindow, adaptiveWindowSize);
    
    fprintf('   → Final adaptive correlation window size: %d\n', adaptiveWindowSize);

end 