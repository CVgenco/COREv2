function test_garch_fitting()
% Unit test for fit_garch_per_regime using synthetic returns and regimes
% Saves diagnostic plot to tests/diagnostics/

if ~exist('tests/diagnostics', 'dir'), mkdir('tests/diagnostics'); end

% Generate synthetic returns: 2 regimes
n = 200;
regimes = [ones(n,1); 2*ones(n,1)];
returns = [0.01*randn(n,1); 0.05*randn(n,1)];
garchModels = fit_garch_per_regime(returns, regimes);

% Assert models exist for both regimes
assert(isfield(garchModels, 'regime_1') && isfield(garchModels, 'regime_2'), 'Missing GARCH models for regimes');

% Plot volatility per regime
figure;
plot(returns, 'k'); hold on;
plot(regimes * 0.1, 'r');
title('Synthetic Returns and Regimes');
legend('Returns','Regimes');
saveas(gcf, 'tests/diagnostics/test_garch_fitting.png'); close;

disp('test_garch_fitting passed');
end 