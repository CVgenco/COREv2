% checkBayesOptStatus.m
% Script to check the status of an ongoing Bayesian optimization run
% This script can be run separately to monitor the status while optimization is running

function checkBayesOptStatus()
    fprintf('=== Bayesian Optimization Status Check ===\n\n');
    
    % Check if results file exists
    resultsFile = 'bayesopt_results.mat';
    if ~exist(resultsFile, 'file')
        fprintf('❌ No optimization results file found. The optimization might not have started yet.\n');
        return;
    end
    
    % Load results file
    try
        data = load(resultsFile);
        if ~isfield(data, 'results')
            fprintf('❌ Results file exists but does not contain optimization results.\n');
            return;
        end
        
        results = data.results;
        
        % Display general information
        fprintf('Started at: %s\n', datestr(results.StartTime));
        fprintf('Elapsed time: %.2f minutes\n', results.RunTime * 24 * 60);
        fprintf('Iterations completed: %d / %d\n', results.NumObjectiveEvaluations, results.MaxObjectiveEvaluations);
        fprintf('Progress: %.1f%%\n\n', (results.NumObjectiveEvaluations / results.MaxObjectiveEvaluations) * 100);
        
        % Display best result so far
        fprintf('=== Best Solution So Far ===\n');
        if ~isempty(results.XAtMinEstimatedObjective)
            fprintf('Best parameters found (estimated):\n');
            fprintf('  blockSize: %d\n', results.XAtMinEstimatedObjective.blockSize);
            fprintf('  df (degrees of freedom): %d\n', results.XAtMinEstimatedObjective.df);
            fprintf('  jumpThreshold: %.4f\n', results.XAtMinEstimatedObjective.jumpThreshold);
            fprintf('  regimeAmpFactor: %.4f\n', results.XAtMinEstimatedObjective.regimeAmpFactor);
            fprintf('  Estimated objective value: %.4f\n\n', results.MinEstimatedObjective);
        end
        
        if ~isempty(results.XAtMinObjective)
            fprintf('Best parameters found (observed):\n');
            fprintf('  blockSize: %d\n', results.XAtMinObjective.blockSize);
            fprintf('  df (degrees of freedom): %d\n', results.XAtMinObjective.df);
            fprintf('  jumpThreshold: %.4f\n', results.XAtMinObjective.jumpThreshold);
            fprintf('  regimeAmpFactor: %.4f\n', results.XAtMinObjective.regimeAmpFactor);
            fprintf('  Observed objective value: %.4f\n\n', results.MinObjective);
        end
        
        % Display last 5 iterations
        fprintf('=== Recent Iterations ===\n');
        numIterations = results.NumObjectiveEvaluations;
        startIter = max(1, numIterations - 4);
        
        fprintf('| Iter |   blockSize |  df | jumpThreshold | regimeAmpFactor | Objective  |\n');
        fprintf('|------|-------------|-----|---------------|-----------------|------------|\n');
        
        for i = startIter:numIterations
            if i <= length(results.ObjectiveTrace)
                fprintf('| %4d | %11d | %3d | %13.4f | %15.4f | %10.4f |\n', ...
                    i, ...
                    results.XTrace.blockSize(i), ...
                    results.XTrace.df(i), ...
                    results.XTrace.jumpThreshold(i), ...
                    results.XTrace.regimeAmpFactor(i), ...
                    results.ObjectiveTrace(i));
            end
        end
        
        fprintf('\n=== Status ===\n');
        if results.NumObjectiveEvaluations < results.MaxObjectiveEvaluations
            fprintf('✓ Optimization is still running.\n');
        else
            fprintf('✓ Optimization is complete.\n');
        end
        
        % Check if all iterations have the same objective value
        allSameValue = all(results.ObjectiveTrace == results.ObjectiveTrace(1));
        if allSameValue && results.NumObjectiveEvaluations > 3
            fprintf('⚠️ Warning: All iterations have the same objective value (%.4f).\n', results.ObjectiveTrace(1));
            fprintf('   This might indicate a problem with the objective function or parameter constraints.\n');
        end
        
    catch ME
        fprintf('❌ Error checking optimization status: %s\n', ME.message);
    end
end

% Run the function when script is executed
checkBayesOptStatus();
