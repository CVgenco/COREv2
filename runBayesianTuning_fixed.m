% runBayesianTuning.m
% Enhanced Bayesian optimization for simulation parameter tuning
% Includes more parameters, diagnostics, and parallelization

function runBayesianTuning()
    % Define parameter search space (add more as needed)
    optimVars = [ ...
        optimizableVariable('anchorWeight',[0,0.3]), ...
        optimizableVariable('capReturn',[500,3000]), ...
        optimizableVariable('capJump',[500,3000]), ...
        optimizableVariable('volAmp',[0.5,2]), ...
        optimizableVariable('blockSize',[12,168],'Type','integer'), ...
        optimizableVariable('jumpFreq',[0,0.2]), ... % Will be unused temporarily
        optimizableVariable('minJumpSize',[0,500]), ...
        optimizableVariable('maxVolRatio',[2,8]), ... % Conservative range to prevent volatility explosions
        optimizableVariable('capDiff',[1000,5000]), ...
        optimizableVariable('capAdj',[2000,10000]) ...
    ];

    % Fixed list of all diagnostic fields for logging
    ALL_DIAG_FIELDS = {'mean','std','kurtosis','skewness','jumpFreq','jumpSize','acfsq','regimeDuration','transitionMatrix','numCappedEvents','numCappedPricePathEvents'};
    assignin('base','ALL_DIAG_FIELDS',ALL_DIAG_FIELDS); % Make available to workers

    logFile = 'bayesopt_runlog.csv';

    % Run Bayesian optimization with parallelization
    results = bayesopt(@(params) simObjective(params, logFile), optimVars, ...
        'MaxObjectiveEvaluations', 10, ... % Changed from 40 to 10
        'IsObjectiveDeterministic', true, ...
        'AcquisitionFunctionName', 'expected-improvement-plus', ...
        'UseParallel', true);

    % Save best parameters
    bestParams = results.XAtMinObjective;
    save('bayesopt_results.mat','results','bestParams');
    fprintf('Best parameters found:\n');
    disp(bestParams);
end

function err = simObjective(params, logFile)
    % Load and update config
    configFile = 'userConfig.m';
    outputDir = 'BayesOpt_Results';
    if ~exist(outputDir,'dir'), mkdir(outputDir); end
    run(configFile); % loads config
    
    % Convert params table to struct if needed
    if istable(params)
        paramStruct = struct();
        varNames = params.Properties.VariableNames;
        for i = 1:length(varNames)
            paramStruct.(varNames{i}) = params{1, varNames{i}};
        end
        params = paramStruct;
    end
    
    % Set parameters
    config.simulation.randomSeed = 42; % for reproducibility
    config.blockBootstrapping.blockSize = params.blockSize;
    config.blockBootstrapping.enabled = true;
    config.regimeVolatilityModulation.amplificationFactor = params.volAmp;
    config.regimeVolatilityModulation.enabled = true;
    config.regimeVolatilityModulation.maxVolRatio = params.maxVolRatio;
    config.anchorWeight = params.anchorWeight;
    config.capReturn = params.capReturn;
    config.capJump = params.capJump;
    config.capDiff = params.capDiff;
    config.capAdj = params.capAdj;
    % config.jumpModeling.frequency = params.jumpFreq; % Temporarily commented out
    config.jumpModeling.minJumpSize = params.minJumpSize;
    % Save updated config to temp file
    tempConfigFile = fullfile(outputDir,'tempConfig.m');
    saveUserConfig(config, tempConfigFile);
    % Run simulation
    try
        runSimulationAndScenarioGeneration(tempConfigFile, outputDir);
    catch ME
        warning('Simulation failed: %s', ME.message);
        err = 1e6; % Penalize failed runs
        logDiagnosticsSimple(params, struct(), 1e6, logFile, 'fail');
        return;
    end
    % Load diagnostics (assume runOutputAndValidation.m saves diagnostics)
    try
        runOutputAndValidation(outputDir);
        load(fullfile(outputDir,'diagnostics.mat'),'simDiagnostics','histDiagnostics');
    catch
        warning('Diagnostics failed.');
        err = 1e6;
        logDiagnosticsSimple(params, struct(), 1e6, logFile, 'fail');
        return;
    end
    % Compute error (sum of squared differences in diagnostics)
    err = 0;
    fields = {'mean','std','kurtosis','skewness','jumpFreq','jumpSize','acfsq','regimeDuration','transitionMatrix'};
    for f = 1:numel(fields)
        field = fields{f};
        if isfield(simDiagnostics,field) && isfield(histDiagnostics,field)
            err = err + sum((simDiagnostics.(field) - histDiagnostics.(field)).^2,'all','omitnan');
        end
    end
    % Add penalty for excessive capping
    if isfield(simDiagnostics,'numCappedEvents')
        err = err + 0.1*simDiagnostics.numCappedEvents;
    end
    % Add penalty for capped price path events
    if isfield(simDiagnostics,'numCappedPricePathEvents')
        err = err + 0.1*simDiagnostics.numCappedPricePathEvents;
    end
    % Log diagnostics and parameters
    logDiagnosticsSimple(params, simDiagnostics, err, logFile, 'ok');
end

function logDiagnosticsSimple(params, simDiagnostics, err, logFile, status)
    % Simple logging using fprintf to avoid table issues
    
    % Get parameter names and values
    paramNames = fieldnames(params);
    paramValues = cell(length(paramNames), 1);
    for i = 1:length(paramNames)
        val = params.(paramNames{i});
        if isnumeric(val) && isscalar(val)
            paramValues{i} = val;
        else
            paramValues{i} = val(1); % Take first element
        end
    end
    
    % Fixed diagnostic fields
    diagFields = {'mean','std','kurtosis','skewness','jumpFreq','jumpSize','acfsq','regimeDuration','transitionMatrix','numCappedEvents','numCappedPricePathEvents'};
    diagValues = cell(length(diagFields), 1);
    for i = 1:length(diagFields)
        if isfield(simDiagnostics, diagFields{i})
            val = simDiagnostics.(diagFields{i});
            if isnumeric(val) && isscalar(val)
                diagValues{i} = val;
            elseif isnumeric(val) && numel(val) > 0
                diagValues{i} = val(1);
            else
                diagValues{i} = NaN;
            end
        else
            diagValues{i} = NaN;
        end
    end
    
    % Write header if file doesn't exist
    if ~exist(logFile, 'file')
        fid = fopen(logFile, 'w');
        % Write header
        for i = 1:length(paramNames)
            fprintf(fid, '%s,', paramNames{i});
        end
        for i = 1:length(diagFields)
            fprintf(fid, '%s_diag,', diagFields{i});
        end
        fprintf(fid, 'error,status\n');
        fclose(fid);
    end
    
    % Append data
    fid = fopen(logFile, 'a');
    for i = 1:length(paramValues)
        fprintf(fid, '%.6g,', paramValues{i});
    end
    for i = 1:length(diagValues)
        if isnan(diagValues{i})
            fprintf(fid, 'NaN,');
        else
            fprintf(fid, '%.6g,', diagValues{i});
        end
    end
    fprintf(fid, '%.6g,%s\n', err, status);
    fclose(fid);
end

function saveUserConfig(config, filename)
    % Save config struct as a .m file for use by simulation
    fid = fopen(filename,'w');
    fprintf(fid,'config = struct();\n');
    fields = fieldnames(config);
    for i = 1:numel(fields)
        val = config.(fields{i});
        if isnumeric(val) && isscalar(val)
            fprintf(fid,'config.%s = %g;\n',fields{i},val);
        elseif isnumeric(val)
            fprintf(fid,'config.%s = [%s];\n',fields{i},num2str(val));
        elseif ischar(val)
            fprintf(fid,'config.%s = ''%s'';\n',fields{i},val);
        elseif islogical(val)
            fprintf(fid,'config.%s = %d;\n',fields{i},val);
        elseif isstruct(val)
            % Recursively save struct fields
            subfields = fieldnames(val);
            for j = 1:numel(subfields)
                subval = val.(subfields{j});
                if isnumeric(subval) && isscalar(subval)
                    fprintf(fid,'config.%s.%s = %g;\n',fields{i},subfields{j},subval);
                elseif isnumeric(subval)
                    fprintf(fid,'config.%s.%s = [%s];\n',fields{i},subfields{j},num2str(subval));
                elseif ischar(subval)
                    fprintf(fid,'config.%s.%s = ''%s'';\n',fields{i},subfields{j},subval);
                elseif islogical(subval)
                    fprintf(fid,'config.%s.%s = %d;\n',fields{i},subfields{j},subval);
                end
            end
        end
    end
    fclose(fid);
end
