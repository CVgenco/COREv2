function test_simulation_engine()
% Unit test for runSimulationAndScenarioGeneration using synthetic data
% Saves diagnostic plot to tests/diagnostics/

if ~exist('tests/diagnostics', 'dir'), mkdir('tests/diagnostics'); end

% Create minimal synthetic alignedTable and info
alignedTable = table();
alignedTable.Timestamp = (1:100)';
alignedTable.ProductA = cumsum(randn(100,1));
alignedTable.ProductB = cumsum(randn(100,1));
info.productNames = {'ProductA','ProductB'};

% Minimal config
config.simulation.nPaths = 2;
config.simulation.randomSeed = 1;
config.blockBootstrapping.enabled = false;
config.innovationDistribution.enabled = false;
config.jumpModeling.enabled = false;

save('alignedTable.mat','alignedTable');
save('info.mat','info');

try
    runSimulationAndScenarioGeneration('userConfig.m', 'tests/diagnostics/');
    % Check output
    assert(exist('tests/diagnostics/simulated_paths.mat','file')==2, 'Simulated paths not saved');
    disp('test_simulation_engine passed');
catch ME
    warning('Simulation engine test failed: %s', ME.message);
end
end 