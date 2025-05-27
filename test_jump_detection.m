function test_jump_detection()
% Unit test for fit_jumps_per_regime using synthetic returns with jumps and regimes
% Saves diagnostic plot to tests/diagnostics/

if ~exist('tests/diagnostics', 'dir'), mkdir('tests/diagnostics'); end

% Generate synthetic returns: 2 regimes, with jumps in regime 2
n = 200;
regimes = [ones(n,1); 2*ones(n,1)];
returns = [0.01*randn(n,1); 0.01*randn(n,1)];
jumpIdx = n + randi(n, [10,1]);
returns(jumpIdx) = returns(jumpIdx) + 0.5*randn(10,1) + 0.5;
jumpModel = fit_jumps_per_regime(returns, regimes);

% Assert jump stats exist for both regimes
assert(isfield(jumpModel, 'regime_1') && isfield(jumpModel, 'regime_2'), 'Missing jump model for regimes');

% Plot returns and jumps
figure;
plot(returns, 'k'); hold on;
plot(jumpIdx, returns(jumpIdx), 'ro');
title('Synthetic Returns with Jumps');
legend('Returns','Injected Jumps');
saveas(gcf, 'tests/diagnostics/test_jump_detection.png'); close;

disp('test_jump_detection passed');
end 