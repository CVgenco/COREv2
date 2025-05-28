% run_sprint3_fixed.m
% Run Sprint 3 with proper infer implementation

% Change to the correct directory
cd('/Users/chayanvohra/Downloads/COREv2');

% Add current directory to path if needed
addpath(pwd);

try
    fprintf('=== STARTING SPRINT 3: EMPIRICAL COPULA BOOTSTRAPPING (FIXED VERSION) ===\n');
    fprintf('Using configuration: userConfig.m\n');
    fprintf('Working directory: %s\n', pwd);
    
    % Run Sprint 3
    runEmpiricalCopulaBootstrapping('userConfig.m');
    
    fprintf('=== SPRINT 3 COMPLETED SUCCESSFULLY ===\n');
    fprintf('Ready to proceed to Sprint 4\n');
    
catch ME
    fprintf('=== ERROR IN SPRINT 3 ===\n');
    fprintf('Error message: %s\n', ME.message);
    fprintf('Error location: %s (line %d)\n', ME.stack(1).file, ME.stack(1).line);
    rethrow(ME);
end
