% Test Sprint 5 execution
try
    fprintf('Testing Sprint 5: Robust Simulation Engine...\n');
    runSimulationEngine('userConfig.m');
    fprintf('Sprint 5 completed successfully!\n');
catch ME
    fprintf('Sprint 5 failed with error: %s\n', ME.message);
    fprintf('Error occurred in: %s at line %d\n', ME.stack(1).name, ME.stack(1).line);
end