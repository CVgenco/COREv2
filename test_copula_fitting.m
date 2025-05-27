function test_copula_fitting()
% Unit test for fit_copula_per_regime using synthetic residuals and regimes
% Saves diagnostic plot to tests/diagnostics/

if ~exist('tests/diagnostics', 'dir'), mkdir('tests/diagnostics'); end

% Generate synthetic residuals: 2 products, 2 regimes
n = 200;
regimes = [ones(n,1); 2*ones(n,1)];
resid1 = [randn(n,1); 0.5*randn(n,1)];
resid2 = [randn(n,1); 0.5*randn(n,1)];
residuals = [resid1, resid2];
copulaModels = fit_copula_per_regime(residuals, regimes);

% Assert copula models exist for both regimes
assert(isfield(copulaModels, 'regime_1') && isfield(copulaModels, 'regime_2'), 'Missing copula models for regimes');

% Plot scatter for each regime
figure;
scatter(resid1(regimes==1), resid2(regimes==1), 'b.'); hold on;
scatter(resid1(regimes==2), resid2(regimes==2), 'r.');
title('Synthetic Residuals by Regime');
legend('Regime 1','Regime 2');
saveas(gcf, 'tests/diagnostics/test_copula_fitting.png'); close;

disp('test_copula_fitting passed');
end 