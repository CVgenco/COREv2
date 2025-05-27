function regimeJumps = fit_jumps_per_regime(returns, regimeLabels, config)
%FIT_JUMPS_PER_REGIME Detect and fit jumps for each regime.
%   regimeJumps = fit_jumps_per_regime(returns, regimeLabels, config)
%   - returns: vector or table of returns
%   - regimeLabels: vector or table of regime labels
%   - config: struct with jump detection options
%   - regimeJumps: struct array with jump params and diagnostics

if istable(returns), returns = table2array(returns); end
if istable(regimeLabels), regimeLabels = table2array(regimeLabels); end
returns = returns(:); regimeLabels = regimeLabels(:);
regimes = unique(regimeLabels(~isnan(regimeLabels)));
nRegimes = numel(regimes);
regimeJumps = struct();

for r = 1:nRegimes
    idx = regimeLabels == regimes(r);
    ret_r = returns(idx);
    % Jump detection: threshold method (configurable)
    if isfield(config, 'jumpThreshold')
        thresh = config.jumpThreshold * std(ret_r, 'omitnan');
    else
        thresh = 4 * std(ret_r, 'omitnan');
    end
    jumps = abs(ret_r) > thresh;
    jumpSizes = ret_r(jumps);
    jumpFreq = sum(jumps) / numel(ret_r);
    % Fit parametric (normal) and empirical
    mu_jump = mean(jumpSizes, 'omitnan');
    sigma_jump = std(jumpSizes, 'omitnan');
    regimeJumps(r).jumpFreq = jumpFreq;
    regimeJumps(r).jumpSizes = jumpSizes;
    regimeJumps(r).jumpSizeFit = struct('mu', mu_jump, 'sigma', sigma_jump);
    % Plot
    figure; histogram(jumpSizes, 30); title(sprintf('Jump Sizes (Regime %d)', r));
    saveas(gcf, sprintf('EDA_Results/jump_sizes_regime%d.png', r)); close;
    figure; plot(jumps); title(sprintf('Jump Occurrences (Regime %d)', r));
    saveas(gcf, sprintf('EDA_Results/jump_occurrences_regime%d.png', r)); close;
end

end

% Unit test
function test_fit_jumps_per_regime()
    t = (1:200)';
    x = [randn(100,1); 2*randn(100,1)];
    x([10, 120]) = 8; % Known jumps
    labels = [ones(100,1); 2*ones(100,1)];
    config.jumpThreshold = 4;
    jumps = fit_jumps_per_regime(x, labels, config);
    assert(numel(jumps) == 2);
    disp('test_fit_jumps_per_regime passed');
end 