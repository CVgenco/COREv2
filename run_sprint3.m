% run_sprint3.m
% Simple script to run Sprint 3: Empirical Copula Bootstrapping

% Change to the correct directory
cd('/Users/chayanvohra/Downloads/COREv2');

% Add current directory to path if needed
addpath(pwd);

try
    fprintf('=== STARTING SPRINT 3: EMPIRICAL COPULA BOOTSTRAPPING ===\n');
    fprintf('Using configuration: userConfig.m\n');
    fprintf('Working directory: %s\n', pwd);
    
    % Run Sprint 3
    runEmpiricalCopulaBootstrapping('userConfig.m');
    
    fprintf('=== SPRINT 3 COMPLETED SUCCESSFULLY ===\n');
    
catch ME
    fprintf('=== ERROR IN SPRINT 3 ===\n');
    fprintf('Error message: %s\n', ME.message);
    fprintf('Error location: %s (line %d)\n', ME.stack(1).file, ME.stack(1).line);
    
    % Display the full error stack for debugging
    disp('Full error stack:');
    for i = 1:length(ME.stack)
        fprintf('  %d: %s (line %d)\n', i, ME.stack(i).name, ME.stack(i).line);
    end
    
    rethrow(ME);
end
