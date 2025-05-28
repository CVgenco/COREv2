% runBayesianTuning_conservative.m
% Conservative Bayesian optimization with stricter bounds to prevent volatility explosions

function runBayesianTuning_conservative()
    % Conservative parameter ranges to prevent volatility explosions
    optimVars = [ ...
        optimizableVariable('blockSize',[24,72],'Type','integer'), ...      % Smaller range, avoid very small blocks
        optimizableVariable('df',[5,15],'Type','integer'), ...              % Conservative t-distribution degrees
        optimizableVariable('jumpThreshold',[0.05,0.3]), ...                % More conservative jump thresholds
        optimizableVariable('regimeAmpFactor',[0.8,1.2]) ...                % Much tighter regime amplification
    ];

    % Run Bayesian optimization
    results = bayesopt(@bayesoptSimObjective, optimVars, ...
        'MaxObjectiveEvaluations', 10, ...
        'IsObjectiveDeterministic', false, ...  % Changed to false due to stochastic nature
        'AcquisitionFunctionName', 'expected-improvement', ...
        'UseParallel', false, ...  % Disable parallel to avoid conflicts
        'Verbose', 1, ...
        'PlotFcn', []);

    % Save results
    save('bayesopt_conservative_results.mat', 'results');
    
    % Display best parameters
    fprintf('Conservative Bayesian Optimization Complete\n');
    fprintf('Best objective value: %.6f\n', results.MinObjective);
    disp('Best parameters:');
    disp(results.XAtMinObjective);
end
