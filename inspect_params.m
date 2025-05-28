% Script to inspect the parameter results structure
load('EDA_Results/paramResults.mat');

% Get product names
products = fieldnames(paramResults);
fprintf('Products in paramResults: %s\n', strjoin(products, ', '));

% Check first product for reference
p1 = products{1};
fprintf('\nDetails for product %s:\n', p1);

% Check GARCH models
if isfield(paramResults.(p1), 'garchModels')
    fprintf('GARCH models found.\n');
    garch_model = paramResults.(p1).garchModels(1);
    
    % Display model fields
    fprintf('Fields in GARCH model:\n');
    model_fields = fieldnames(garch_model);
    for i = 1:numel(model_fields)
        field = model_fields{i};
        fprintf('  - %s: ', field);
        
        if isnumeric(garch_model.(field))
            fprintf('%s\n', mat2str(garch_model.(field)));
        elseif ischar(garch_model.(field)) || isstring(garch_model.(field))
            fprintf('%s\n', garch_model.(field));
        elseif isstruct(garch_model.(field))
            fprintf('struct with fields: %s\n', strjoin(fieldnames(garch_model.(field)), ', '));
        else
            fprintf('(type: %s)\n', class(garch_model.(field)));
        end
    end
    
    % Check if model field exists
    if isfield(garch_model, 'model')
        fprintf('\nGARCH model details:\n');
        if isobject(garch_model.model)
            fprintf('  - Class: %s\n', class(garch_model.model));
            
            % Try to access key properties
            try
                fprintf('  - Parameters: %s\n', mat2str(garch_model.model.Parameters));
            catch
                fprintf('  - Parameters: Could not access\n');
            end
        else
            fprintf('  - Not an object (type: %s)\n', class(garch_model.model));
        end
    else
        fprintf('\nNo model field found. Available fields: %s\n', strjoin(model_fields, ', '));
    end
end

% Save to log file
diary('model_inspection.log');
disp('FULL STRUCTURE DETAILS:');
disp(paramResults);
diary off;

fprintf('\nFull structure details saved to model_inspection.log\n');
