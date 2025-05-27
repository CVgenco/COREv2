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
        optimizableVariable('jumpFreq',[0,0.2]), ...
        optimizableVariable('minJumpSize',[0,500]), ...
        optimizableVariable('maxVolRatio',[2,10]), ...
        optimizableVariable('capDiff',[1000,5000]), ...
        optimizableVariable('capAdj',[2000,10000]) ...
    ];

    % Fixed list of all diagnostic fields for logging
    ALL_DIAG_FIELDS = {'mean','std','kurtosis','skewness','jumpFreq','jumpSize','acfsq','regimeDuration','transitionMatrix','numCappedEvents','numCappedPricePathEvents'};
    assignin('base','ALL_DIAG_FIELDS',ALL_DIAG_FIELDS); % Make available to workers

    logFile = 'bayesopt_runlog.csv';

    % Run Bayesian optimization with parallelization
    results = bayesopt(@(params) simObjective(params, logFile), optimVars, ...
        'MaxObjectiveEvaluations', 40, ...
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
    config.jumpModeling.frequency = params.jumpFreq;
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
        logDiagnostics(params, struct(), 1e6, logFile, 'fail');
        return;
    end
    % Load diagnostics (assume runOutputAndValidation.m saves diagnostics)
    try
        runOutputAndValidation(outputDir);
        load(fullfile(outputDir,'diagnostics.mat'),'simDiagnostics','histDiagnostics');
    catch
        warning('Diagnostics failed.');
        err = 1e6;
        logDiagnostics(params, struct(), 1e6, logFile, 'fail');
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
    logDiagnostics(params, simDiagnostics, err, logFile, 'ok');
end

function logDiagnostics(params, simDiagnostics, err, logFile, status)
    % Use fixed list of diagnostic fields for consistent logging
    if evalin('base','exist(''ALL_DIAG_FIELDS'',''var'')')
        ALL_DIAG_FIELDS = evalin('base','ALL_DIAG_FIELDS');
    else
        ALL_DIAG_FIELDS = {'mean','std','kurtosis','skewness','jumpFreq','jumpSize','acfsq','regimeDuration','transitionMatrix','numCappedEvents','numCappedPricePathEvents'};
    end
    paramFields = fieldnames(params);
    row = cell2table(cell(1, numel(paramFields)+numel(ALL_DIAG_FIELDS)+2));
    row.Properties.VariableNames = [paramFields; ALL_DIAG_FIELDS'; {'error','status'}];
    for i = 1:numel(paramFields)
        row{1,i} = params.(paramFields{i});
    end
    for i = 1:numel(ALL_DIAG_FIELDS)
        field = ALL_DIAG_FIELDS{i};
        if isfield(simDiagnostics, field)
            row{1,numel(paramFields)+i} = simDiagnostics.(field);
        else
            row{1,numel(paramFields)+i} = NaN;
        end
    end
    row{1,end-1} = err;
    row{1,end} = status;
    if exist(logFile,'file')
        writetable(row, logFile, 'WriteMode','Append','WriteVariableNames',false);
    else
        writetable(row, logFile, 'WriteVariableNames',true);
    end
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