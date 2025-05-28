% run_sprint2_fixed.m
% Run Sprint 2 with proper parameter saving

% Change to the correct directory
cd('/Users/chayanvohra/Downloads/COREv2');

% Add current directory to path if needed
addpath(pwd);

try
    fprintf('=== STARTING SPRINT 2: PARAMETER ESTIMATION (FIXED VERSION) ===\n');
    fprintf('Using configuration: userConfig.m\n');
    fprintf('Working directory: %s\n', pwd);
    
    % Run Sprint 2
    runParameterEstimation('userConfig.m');
    
    fprintf('=== SPRINT 2 COMPLETED SUCCESSFULLY ===\n');
    fprintf('Ready to proceed to Sprint 3\n');
    
catch ME
    fprintf('=== ERROR IN SPRINT 2 ===\n');
    fprintf('Error message: %s\n', ME.message);
    fprintf('Error location: %s (line %d)\n', ME.stack(1).file, ME.stack(1).line);
    rethrow(ME);
end
