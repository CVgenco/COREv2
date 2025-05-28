% run_sprint4.m
% Simple script to run Sprint 4: Simulation Engine and Scenario Generation

% Change to the correct directory
cd('/Users/chayanvohra/Downloads/COREv2');

% Add current directory to path if needed
addpath(pwd);

try
    fprintf('=== STARTING SPRINT 4: SIMULATION ENGINE ===\n');
    fprintf('Using configuration: userConfig.m\n');
    fprintf('Working directory: %s\n', pwd);
    fprintf('NOTE: Using robust implementation with improved parameter handling\n');
    
    % Check required files from previous sprints
    requiredFiles = {'EDA_Results/returnsTable.mat', 'EDA_Results/regimeLabels.mat', ...
                     'EDA_Results/paramResults.mat', 'EDA_Results/innovationsStruct.mat', ...
                     'EDA_Results/copulaStruct.mat'};
    
    for i = 1:length(requiredFiles)
        if ~exist(requiredFiles{i}, 'file')
            error('Required file missing: %s. Please run previous sprints first.', requiredFiles{i});
        else
            fprintf('✓ Found: %s\n', requiredFiles{i});
        end
    end
    
    % Create output directory for simulation results
    outputDir = 'Simulation_Results';
    if ~exist(outputDir, 'dir')
        mkdir(outputDir);
        fprintf('Created output directory: %s\n', outputDir);
    end
    
    % Run Sprint 4
    runSimulationAndScenarioGeneration('userConfig.m', outputDir);
    
    fprintf('=== SPRINT 4 COMPLETED SUCCESSFULLY ===\n');
    fprintf('Ready to proceed to Sprint 5: Robustness & Diagnostics\n');
    
catch ME
    fprintf('=== ERROR IN SPRINT 4 ===\n');
    fprintf('Error message: %s\n', ME.message);
    if ~isempty(ME.stack)
        fprintf('Error location: %s (line %d)\n', ME.stack(1).name, ME.stack(1).line);
        
        % Display the full error stack for debugging
        fprintf('Full error stack:\n');
        for i = 1:length(ME.stack)
            fprintf('  %d: %s (line %d)\n', i, ME.stack(i).name, ME.stack(i).line);
        end
    end
    
    rethrow(ME);
end
