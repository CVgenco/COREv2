% checkBayesOptProgress.m
% Monitor the progress of the currently running Bayesian optimization
% This script looks for output files and provides a status summary

% Create a log file for the output
logFile = fopen('bayesopt_progress_report.txt', 'w');
if logFile == -1
    error('Could not open log file for writing');
end

% Function to write to both console and log file
function teeOutput(fmt, varargin)
    fprintf(fmt, varargin{:});
    fprintf(logFile, fmt, varargin{:});
end

teeOutput('=== Bayesian Optimization Progress Report ===\n\n');

% Check MATLAB processes running Bayesian optimization
[status, result] = system('ps aux | grep -i "runBayesianTuning" | grep -v grep');
if status == 0
    teeOutput('✓ Bayesian optimization is RUNNING\n');
    teeOutput('  Process info: %s\n', result);
else
    teeOutput('⚠ No active Bayesian optimization process found!\n');
end

% Check for recently updated files
teeOutput('\nRecent simulation output files:\n');
[status, result] = system('find /Users/chayanvohra/Downloads/COREv2/BayesOpt_Results -type f -name "*.csv" -mmin -30 | wc -l');
numRecentFiles = str2double(strtrim(result));
teeOutput('  %d files created/updated in the last 30 minutes\n', numRecentFiles);

% Look for specific optimization output files
teeOutput('\nChecking optimization status files:\n');

% Look for latest iteration log file
latestLogFile = '';
if exist('bayesopt_progress.csv', 'file')
    latestLogFile = 'bayesopt_progress.csv';
elseif exist('bayesopt_runlog.csv', 'file')
    latestLogFile = 'bayesopt_runlog.csv';
elseif exist('bayesopt_safe_runlog.csv', 'file')
    latestLogFile = 'bayesopt_safe_runlog.csv';
end

if ~isempty(latestLogFile)
    teeOutput('  Found log file: %s\n', latestLogFile);
    
    % Read iterations from the log file
    try
        data = readtable(latestLogFile);
        numIterations = height(data);
        teeOutput('  Completed iterations: %d\n', numIterations);
        
        % Check for successful iterations
        if ismember('Objective', data.Properties.VariableNames)
            successfulIters = sum(data.Objective < 1e5);
            teeOutput('  Successful iterations: %d (%.1f%%)\n', ...
                successfulIters, 100*successfulIters/numIterations);
            
            % Get best parameters if any successful iterations
            if successfulIters > 0
                bestIdx = find(data.Objective == min(data.Objective), 1, 'last');
                teeOutput('\nBest parameters so far (iteration %d):\n', bestIdx);
                paramNames = setdiff(data.Properties.VariableNames, ...
                    {'Iter', 'Objective', 'ObjectiveEvaluation', 'ConstraintViolation', ...
                     'ConstraintEvaluation', 'BestSoFar', 'BestFeasibleSoFar'});
                for i = 1:length(paramNames)
                    teeOutput('  %s: %.4f\n', paramNames{i}, data.(paramNames{i})(bestIdx));
                end
                teeOutput('\n  Best objective value: %.4f\n', data.Objective(bestIdx));
            else
                teeOutput('\n⚠ No successful iterations yet\n');
            end
        end
    catch ME
        teeOutput('  Error reading log file: %s\n', ME.message);
    end
else
    teeOutput('  ⚠ No log file found to track iterations\n');
end

% Check userConfig.m for latest best parameters
try
    teeOutput('\nLatest parameters in userConfig.m:\n');
    run('userConfig.m');
    teeOutput('  Block size: %d\n', config.blockBootstrapping.blockSize);
    teeOutput('  Degrees of freedom: %d\n', config.innovationDistribution.degreesOfFreedom);
    teeOutput('  Jump threshold: %.4f\n', config.jumpModeling.threshold);
    teeOutput('  Regime amp factor: %.4f\n', config.regimeVolatilityModulation.amplificationFactor);
catch ME
    teeOutput('  Error reading userConfig.m: %s\n', ME.message);
end

teeOutput('\n=== Progress Report Generated at %s ===\n', datetime('now'));

% Close the log file
fclose(logFile);
