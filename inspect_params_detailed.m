% Detailed script to inspect the parameter results structure
load('EDA_Results/paramResults.mat');

% Get product names
products = fieldnames(paramResults);
fprintf('Products in paramResults: %s\n', strjoin(products, ', '));

% Check first product for reference
p1 = products{1};
fprintf('\nDetailed examination of product %s:\n', p1);

% Check all fields
if isstruct(paramResults.(p1))
    fields = fieldnames(paramResults.(p1));
    fprintf('Fields: %s\n', strjoin(fields, ', '));
    
    % For each field, examine contents
    for i = 1:length(fields)
        field = fields{i};
        fprintf('\n- Field: %s\n', field);
        
        if strcmp(field, 'garchModels')
            if isempty(paramResults.(p1).garchModels)
                fprintf('  Empty garchModels.\n');
            else
                fprintf('  garchModels has %d elements.\n', length(paramResults.(p1).garchModels));
                
                % Look at each regime model
                for r = 1:length(paramResults.(p1).garchModels)
                    fprintf('\n  Regime %d GARCH model:\n', r);
                    garch_model = paramResults.(p1).garchModels(r);
                    
                    if isstruct(garch_model)
                        model_fields = fieldnames(garch_model);
                        for j = 1:length(model_fields)
                            mf = model_fields{j};
                            fprintf('    %s: ', mf);
                            
                            value = garch_model.(mf);
                            if isempty(value)
                                fprintf('empty %s\n', class(value));
                            elseif isnumeric(value)
                                fprintf('%s\n', mat2str(value, 2));
                            elseif ischar(value) || isstring(value)
                                fprintf('%s\n', value);
                            else
                                fprintf('(%s)\n', class(value));
                            end
                        end
                        
                        % Check if we have all the fields we need for inference
                        if ~isfield(garch_model, 'type') || isempty(garch_model.type)
                            fprintf('    WARNING: Missing model type\n');
                        end
                        
                        if ~isfield(garch_model, 'model') || isempty(garch_model.model)
                            fprintf('    WARNING: Empty model field - this is the root cause of infer errors\n');
                            fprintf('    SOLUTION NEEDED: GARCH parameters need to be stored differently\n');
                        end
                    else
                        fprintf('    Not a structure: %s\n', class(garch_model));
                    end
                end
            end
        end
    end
    
    % Look at markov models as an alternative
    if isfield(paramResults.(p1), 'markovModel')
        fprintf('\n- Examining Markov model instead:\n');
        if isstruct(paramResults.(p1).markovModel)
            markov_fields = fieldnames(paramResults.(p1).markovModel);
            fprintf('  Markov model fields: %s\n', strjoin(markov_fields, ', '));
            
            % Focus on transition matrix - this can help us with regimes
            if isfield(paramResults.(p1).markovModel, 'transitionMatrix')
                fprintf('  Transition matrix: %s\n', mat2str(paramResults.(p1).markovModel.transitionMatrix, 3));
            end
        end
    else
        fprintf('\n- No Markov model found.\n');
    end
    
    % Look at jump models
    if isfield(paramResults.(p1), 'jumpModels')
        fprintf('\n- Examining jump models:\n');
        if ~isempty(paramResults.(p1).jumpModels)
            for r = 1:length(paramResults.(p1).jumpModels)
                fprintf('  Regime %d jump parameters:\n', r);
                jump_model = paramResults.(p1).jumpModels(r);
                jump_fields = fieldnames(jump_model);
                
                for jf = 1:length(jump_fields)
                    fprintf('    %s: ', jump_fields{jf});
                    value = jump_model.(jump_fields{jf});
                    if isnumeric(value) && numel(value) < 10
                        fprintf('%s\n', mat2str(value, 3));
                    else
                        fprintf('(%s with %d elements)\n', class(value), numel(value));
                    end
                end
            end
        else
            fprintf('  Empty jump models.\n');
        end
    end
else
    fprintf('Not a struct.\n');
end
