% Test the duplicate handling fix
clc;

params = struct('jumpFreq', 0.1, 'regimeVar', 0.2);
paramFields = fieldnames(params);
ALL_DIAG_FIELDS = {'mean','std','kurtosis','skewness','jumpFreq','jumpSize','acfsq','regimeDuration','transitionMatrix','numCappedEvents','numCappedPricePathEvents'};

fprintf('Testing duplicate handling fix:\n');
try
    % Ensure all arrays are row vectors for concatenation
    paramFieldsRow = paramFields(:)';
    diagFieldsRow = ALL_DIAG_FIELDS(:)';
    statusFields = {'error','status'};
    
    % Handle duplicate field names by adding suffix to diagnostic fields
    allFieldNames = [paramFieldsRow, diagFieldsRow, statusFields];
    [uniqueNames, ~, idx] = unique(allFieldNames, 'stable');
    if length(uniqueNames) < length(allFieldNames)
        % There are duplicates, add suffix to diagnostic fields
        for i = 1:length(diagFieldsRow)
            if any(strcmp(diagFieldsRow{i}, paramFieldsRow))
                diagFieldsRow{i} = [diagFieldsRow{i} '_diag'];
            end
        end
    end
    
    finalNames = [paramFieldsRow, diagFieldsRow, statusFields];
    fprintf('Success! Final names count: %d\n', length(finalNames));
    fprintf('Unique names count: %d\n', length(unique(finalNames)));
    
    % Test table creation
    testTable = cell2table(cell(1, length(finalNames)));
    testTable.Properties.VariableNames = finalNames;
    fprintf('Table creation successful!\n');
    
catch ME
    fprintf('Error: %s\n', ME.message);
end
