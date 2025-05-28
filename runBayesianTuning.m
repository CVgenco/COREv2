% runBayesianTuning.m
% Enhanced Bayesian optimization for robust simulation parameter tuning
% Integrated with enhanced data preprocessing and safety validation
% 
% This version uses the new robust parameter set and enhanced preprocessing pipeline

function runBayesianTuning()
    % Define parameter search space for robust Bayesian optimization
    % These parameters match our enhanced robust system
    optimVars = [ ...
        optimizableVariable('blockSize',[12,168],'Type','integer'), ...
        optimizableVariable('df',[3,15],'Type','integer'), ...
        optimizableVariable('jumpThreshold',[0.01,0.15]), ...
        optimizableVariable('regimeAmpFactor',[0.5,1.5]) ...
    ];

    % Fixed list of all diagnostic fields for logging
    ALL_DIAG_FIELDS = {'mean','std','kurtosis','skewness','jumpFreq','jumpSize','acfsq','regimeDuration','transitionMatrix','numCappedEvents','numCappedPricePathEvents'};
    assignin('base','ALL_DIAG_FIELDS',ALL_DIAG_FIELDS); % Make available to workers

    logFile = 'bayesopt_runlog.csv';
    
    fprintf('Starting robust Bayesian optimization with enhanced preprocessing...\n');
    fprintf('Parameter ranges:\n');
    fprintf('  blockSize: [12, 168]\n');
    fprintf('  df (degrees of freedom): [3, 15]\n');
    fprintf('  jumpThreshold: [0.01, 0.15]\n');
    fprintf('  regimeAmpFactor: [0.5, 1.5]\n');

    % Run Bayesian optimization using the enhanced objective function
    results = bayesopt(@bayesoptSimObjective, optimVars, ...
        'MaxObjectiveEvaluations', 10, ...
        'IsObjectiveDeterministic', false, ...  % Set to false for more robust exploration
        'AcquisitionFunctionName', 'expected-improvement-plus', ...
        'UseParallel', false, ...
        'Verbose', 1, ...
        'PlotFcn', []);

    % Save best parameters
    bestParams = results.XAtMinObjective;
    save('bayesopt_results.mat','results','bestParams');
    fprintf('Robust Bayesian optimization completed!\n');
    fprintf('Best parameters found:\n');
    disp(bestParams);
    
    % Apply best parameters to userConfig.m
    fprintf('Updating userConfig.m with best parameters...\n');
    updateUserConfig(bestParams.blockSize, bestParams.df, bestParams.jumpThreshold, bestParams.regimeAmpFactor);
    fprintf('userConfig.m updated successfully.\n');
end

function logDiagnostics(params, simDiagnostics, err, logFile, status)
    % Use fixed list of diagnostic fields for consistent logging
    if evalin('base','exist(''ALL_DIAG_FIELDS'',''var'')')
        ALL_DIAG_FIELDS = evalin('base','ALL_DIAG_FIELDS');
    else
        ALL_DIAG_FIELDS = {'mean','std','kurtosis','skewness','jumpFreq','jumpSize','acfsq','regimeDuration','transitionMatrix','numCappedEvents','numCappedPricePathEvents'};
    end
    
    % Convert params to struct if it's a table (from Bayesian optimization)
    if istable(params)
        paramFields = params.Properties.VariableNames;
        paramStruct = struct();
        for i = 1:length(paramFields)
            paramStruct.(paramFields{i}) = params{1, paramFields{i}};
        end
        params = paramStruct;
        % paramFields already set above
    else
        paramFields = fieldnames(params);
    end
    row = cell2table(cell(1, numel(paramFields)+numel(ALL_DIAG_FIELDS)+2));
    % Ensure all arrays are row vectors for concatenation
    paramFieldsRow = paramFields(:)';
    diagFieldsRow = ALL_DIAG_FIELDS(:)';
    statusFields = {'error','status'};
    
    % MATLAB table reserved names
    reservedNames = {'Properties', 'Row', 'Variables'};
    
    % Handle duplicate field names and reserved names
    for i = 1:length(diagFieldsRow)
        % Check for duplicates with parameter fields
        if any(strcmp(diagFieldsRow{i}, paramFieldsRow))
            diagFieldsRow{i} = [diagFieldsRow{i} '_diag'];
        end
        % Check for reserved names
        if any(strcmpi(diagFieldsRow{i}, reservedNames))
            diagFieldsRow{i} = [diagFieldsRow{i} '_field'];
        end
    end
    
    % Also check parameter fields for reserved names
    for i = 1:length(paramFieldsRow)
        if any(strcmpi(paramFieldsRow{i}, reservedNames))
            paramFieldsRow{i} = [paramFieldsRow{i} '_param'];
        end
    end
    
    % Check status fields
    for i = 1:length(statusFields)
        if any(strcmpi(statusFields{i}, reservedNames))
            statusFields{i} = [statusFields{i} '_status'];
        end
    end
    
    row.Properties.VariableNames = [paramFieldsRow, diagFieldsRow, statusFields];
    for i = 1:numel(paramFields)
        val = params.(paramFields{i});
        % Ensure the value is a scalar for table assignment
        if isnumeric(val) && numel(val) == 1
            row{1,i} = val;
        elseif isnumeric(val) && numel(val) > 1
            row{1,i} = val(1); % Take first element if it's an array
        else
            row{1,i} = double(val); % Convert to double if possible
        end
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