% checkOptStatus.m
% Simple script to check the status of the running Bayesian optimization

fprintf('=== Bayesian Optimization Status Check ===\n\n');

% Check for running optimization process
[status, result] = system('ps aux | grep -i "runBayesianTuning" | grep -v grep');
if status == 0
    fprintf('✓ Bayesian optimization is RUNNING\n');
    fprintf('  Process info: %s\n', result);
else
    fprintf('⚠ No active Bayesian optimization process found!\n');
end

% Check for recently updated files
fprintf('\nRecent simulation output files:\n');
[status, result] = system('find /Users/chayanvohra/Downloads/COREv2/BayesOpt_Results -type f -name "*.csv" -mmin -30 | wc -l');
numRecentFiles = str2double(strtrim(result));
fprintf('  %d files created/updated in the last 30 minutes\n', numRecentFiles);

% Look for latest iteration log file
fprintf('\nChecking optimization log files:\n');
logFiles = {'bayesopt_progress.csv', 'bayesopt_runlog.csv', 'bayesopt_safe_runlog.csv'};
foundLog = false;

for i = 1:length(logFiles)
    currentFile = logFiles{i};
    if exist(currentFile, 'file')
        foundLog = true;
        fprintf('  Found log file: %s\n', currentFile);
        
        % Get file modification time
        fileInfo = dir(currentFile);
        fprintf('  Last modified: %s\n', datestr(fileInfo.datenum));
        
        % Read the log file
        try
            data = readtable(currentFile);
            numIterations = height(data);
            fprintf('  Completed iterations: %d\n', numIterations);
            
            % Look for the objective column
            if ismember('Objective', data.Properties.VariableNames)
                % Find successful iterations (not penalty values)
                successfulIdx = find(data.Objective < 1e5);
                fprintf('  Successful iterations: %d of %d (%.1f%%)\n', ...
                    length(successfulIdx), numIterations, 100*length(successfulIdx)/numIterations);
                
                if ~isempty(successfulIdx)
                    % Find best iteration
                    [bestVal, bestRelIdx] = min(data.Objective(successfulIdx));
                    bestIdx = successfulIdx(bestRelIdx);
                    
                    fprintf('\n  Best result (iteration %d): %.4f\n', bestIdx, bestVal);
                    
                    % Show parameters from best iteration
                    if ismember('blockSize', data.Properties.VariableNames)
                        fprintf('  Best parameters:\n');
                        fprintf('    blockSize: %d\n', data.blockSize(bestIdx));
                        fprintf('    df: %d\n', data.df(bestIdx));
                        fprintf('    jumpThreshold: %.4f\n', data.jumpThreshold(bestIdx));
                        fprintf('    regimeAmpFactor: %.4f\n', data.regimeAmpFactor(bestIdx));
                    end
                else
                    fprintf('\n  ⚠ No successful iterations yet\n');
                end
            end
        catch ME
            fprintf('  Error reading log file: %s\n', ME.message);
        end
    end
end

if ~foundLog
    fprintf('  ⚠ No log file found\n');
end

% Check userConfig.m for latest parameters
fprintf('\nCurrent parameters in userConfig.m:\n');
try
    userConfig = fileread('userConfig.m');
    
    % Extract block size
    matches = regexp(userConfig, 'blockBootstrapping\.blockSize\s*=\s*(\d+)', 'tokens');
    if ~isempty(matches) && ~isempty(matches{1})
        fprintf('  Block size: %s\n', matches{1}{1});
    else
        fprintf('  Block size: not found\n');
    end
    
    % Extract degrees of freedom
    matches = regexp(userConfig, 'innovationDistribution\.degreesOfFreedom\s*=\s*(\d+)', 'tokens');
    if ~isempty(matches) && ~isempty(matches{1})
        fprintf('  Degrees of freedom: %s\n', matches{1}{1});
    else
        fprintf('  Degrees of freedom: not found\n');
    end
    
    % Extract jump threshold
    matches = regexp(userConfig, 'jumpModeling\.threshold\s*=\s*([\d\.]+)', 'tokens');
    if ~isempty(matches) && ~isempty(matches{1})
        fprintf('  Jump threshold: %s\n', matches{1}{1});
    else
        fprintf('  Jump threshold: not found\n');
    end
    
    % Extract regime amplification factor
    matches = regexp(userConfig, 'regimeVolatilityModulation\.amplificationFactor\s*=\s*([\d\.]+)', 'tokens');
    if ~isempty(matches) && ~isempty(matches{1})
        fprintf('  Regime amplification factor: %s\n', matches{1}{1});
    else
        fprintf('  Regime amplification factor: not found\n');
    end
catch ME
    fprintf('  Error reading userConfig.m: %s\n', ME.message);
end

fprintf('\n=== Status Check Complete at %s ===\n', datestr(now));
