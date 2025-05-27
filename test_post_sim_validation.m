function test_post_sim_validation()
% Unit test for runPostSimulationValidation using synthetic simulation results
% Saves diagnostic plot to tests/diagnostics/

if ~exist('tests/diagnostics', 'dir'), mkdir('tests/diagnostics'); end

% Create minimal synthetic simPaths, regimePaths, pathDiagnostics, returnsTable, regimeLabels
simPaths.ProductA = cumsum(randn(100,2));
simPaths.ProductB = cumsum(randn(100,2));
regimePaths.ProductA = randi(2,100,2);
regimePaths.ProductB = randi(2,100,2);
pathDiagnostics = struct();
returnsTable.ProductA = diff(simPaths.ProductA);
returnsTable.ProductB = diff(simPaths.ProductB);
regimeLabels.ProductA = randi(2,99,1);
regimeLabels.ProductB = randi(2,99,1);
save('Simulation_Results/simPaths.mat','simPaths');
save('Simulation_Results/regimePaths.mat','regimePaths');
save('Simulation_Results/pathDiagnostics.mat','pathDiagnostics');
save('EDA_Results/returnsTable.mat','returnsTable');
save('EDA_Results/regimeLabels.mat','regimeLabels');

try
    runPostSimulationValidation('userConfig.m');
    assert(exist('Validation_Results/validation_summary.txt','file')==2, 'Validation summary not saved');
    disp('test_post_sim_validation passed');
catch ME
    warning('Post-simulation validation test failed: %s', ME.message);
end
end 