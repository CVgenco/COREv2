function runParameterEstimation_Modified(configFile)
%RUNPARAMETERESTIMATION_MODIFIED Run parameter estimation pipeline for Sprint 2 
%   Modified to work with individual product files from current data structure

if nargin < 1
    configFile = 'userConfig.m';
end

run(configFile); % Loads config

% Define products list
products = {'nodalPrices', 'hubPrices', 'nodalGeneration', 'regup', 'regdown', ...
           'nonspin', 'hourlyHubForecasts', 'hourlyNodalForecasts'};

% Load combined regime labels
load('EDA_Results/regimeLabels.mat', 'regimeLabels');

paramResults = struct();

fprintf('=== Sprint 2: Parameter Estimation ===\n');

for i = 1:numel(products)
    pname = products{i};
    fprintf('Processing %s... ', pname);
    
    try
        % Load individual returns table for this product
        returnsFile = ['EDA_Results/returnsTable_' pname '.mat'];
        if ~exist(returnsFile, 'file')
            fprintf('❌ Returns file not found\n');
            continue;
        end
        
        % Load returns data
        returnsData = load(returnsFile);
        fieldNames = fieldnames(returnsData);
        
        % Find the returns data (usually the main variable)
        ret = [];
        for j = 1:length(fieldNames)
            if ~startsWith(fieldNames{j}, '__') % Skip MATLAB metadata
                ret = returnsData.(fieldNames{j});
                break;
            end
        end
        
        if isempty(ret)
            fprintf('❌ No returns data found\n');
            continue;
        end
        
        % Extract returns values if it's a table/timetable
        if istable(ret) || istimetable(ret)
            % Get the data column (should be the product name or similar)
            varNames = ret.Properties.VariableNames;
            if ismember(pname, varNames)
                ret = ret.(pname);
            else
                % Use the first non-timestamp variable
                dataVars = varNames(~contains(lower(varNames), {'time', 'date'}));
                if ~isempty(dataVars)
                    ret = ret.(dataVars{1});
                else
                    ret = ret.(varNames{1});
                end
            end
        end
        
        % Get regime labels for this product
        reg = regimeLabels.(pname);
        
        % Ensure both are column vectors and same length
        ret = ret(:);
        reg = reg(:);
        minLen = min(length(ret), length(reg));
        ret = ret(1:minLen);
        reg = reg(1:minLen);
        
        fprintf('(%d observations) ', length(ret));
        
        % Fit regime Markov model
        fprintf('Markov... ');
        markovModel = fit_regime_markov_model(reg);
        
        % Fit GARCH/EGARCH per regime
        fprintf('GARCH... ');
        garchModels = fit_garch_per_regime(ret, reg, config);
        
        % Fit jumps per regime
        fprintf('Jumps... ');
        jumpModels = fit_jumps_per_regime(ret, reg, config);
        
        % Store results
        paramResults.(pname).markovModel = markovModel;
        paramResults.(pname).garchModels = garchModels;
        paramResults.(pname).jumpModels = jumpModels;
        paramResults.(pname).dataInfo = struct('nObs', length(ret), 'nRegimes', length(unique(reg(~isnan(reg)))));
        
        fprintf('✅ Complete\n');
        
    catch ME
        fprintf('❌ Error: %s\n', ME.message);
        paramResults.(pname) = struct('error', ME.message);
    end
end

% Save results
fprintf('\nSaving parameter estimation results...\n');
save('EDA_Results/paramResults.mat', 'paramResults');

% Summary
fprintf('\n=== Sprint 2 Complete: Parameter Estimation ===\n');
successCount = 0;
for i = 1:numel(products)
    pname = products{i};
    if isfield(paramResults, pname) && ~isfield(paramResults.(pname), 'error')
        fprintf('✅ %s: Success\n', pname);
        successCount = successCount + 1;
    else
        fprintf('❌ %s: Failed\n', pname);
    end
end

fprintf('\nResults: %d/%d products successfully processed\n', successCount, numel(products));
fprintf('Parameter estimation results saved to EDA_Results/paramResults.mat\n');
fprintf('🚀 Ready for Sprint 3: Copula/Innovation Bootstrapping\n');

end
