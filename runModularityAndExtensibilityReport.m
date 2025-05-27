function runModularityAndExtensibilityReport()
% Checks for modularity, documentation, and test coverage in the codebase
% Prints a report and suggests next steps if gaps are found

modules = {'data_cleaning', 'calculate_returns', 'detect_regimes', ...
    'fit_garch_per_regime', 'fit_jumps_per_regime', 'fit_copula_per_regime', ...
    'runEDAandPatternExtraction', 'runParameterEstimation', ...
    'runEmpiricalCopulaBootstrapping', 'runSimulationAndScenarioGeneration', ...
    'runPostSimulationValidation'};
missing = {};
docMissing = {};
for i = 1:numel(modules)
    fname = [modules{i} '.m'];
    if ~isfile(fname)
        warning('Module missing: %s', fname);
        missing{end+1} = fname;
    else
        lines = fileread(fname);
        if ~contains(lines, 'Inputs:') || ~contains(lines, 'Outputs:')
            warning('Missing docstring in %s', fname);
            docMissing{end+1} = fname;
        end
    end
end
% Check for tests
if ~isfolder('tests')
    warning('No tests/ directory found');
else
    testFiles = dir('tests/test_*.m');
    if isempty(testFiles)
        warning('No test_*.m files found in tests/');
    else
        disp('All tests present:');
        for k = 1:numel(testFiles)
            disp(['  ' testFiles(k).name]);
        end
    end
end
% Print summary
fprintf('\n==== Modularity & Extensibility Report ====');
if isempty(missing)
    fprintf('\nAll modules present.');
else
    fprintf('\nMissing modules: %s', strjoin(missing, ', '));
end
if isempty(docMissing)
    fprintf('\nAll modules have docstrings.');
else
    fprintf('\nModules missing docstrings: %s', strjoin(docMissing, ', '));
end
fprintf('\nRun all tests in the tests/ directory to check for edge cases and integration.');
fprintf('\nReview README.md and userConfig.m for extension instructions.');
end 