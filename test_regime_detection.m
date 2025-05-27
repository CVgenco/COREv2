function test_regime_detection()
% Unit test for identifyVolatilityRegimes using synthetic data with known regimes
% Saves diagnostic plot to tests/diagnostics/

if ~exist('tests/diagnostics', 'dir'), mkdir('tests/diagnostics'); end

% Generate synthetic data: 3 regimes
n = 100;
data = [ones(n,1); 5*ones(n,1); -2*ones(n,1)] + 0.5*randn(3*n,1);
timestamps = (1:3*n)';
regimeModel = identifyVolatilityRegimes(data, timestamps);

% Assert at least 2 regimes detected
assert(numel(unique(regimeModel.regimes)) >= 2, 'Failed to detect multiple regimes');

% Plot regimes
figure;
plot(data, 'k'); hold on;
plot(regimeModel.regimes * 2, 'r');
title('Synthetic Data and Detected Regimes');
legend('Data','Detected Regimes');
saveas(gcf, 'tests/diagnostics/test_regime_detection.png'); close;

disp('test_regime_detection passed');
end 