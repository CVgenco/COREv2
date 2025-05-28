% Test comprehensive fix
clc;

% Test with potentially problematic names
params = struct('jumpFreq', 0.1, 'Properties', 0.2, 'Variables', 0.3);
paramFields = fieldnames(params);
ALL_DIAG_FIELDS = {'mean','std','kurtosis','skewness','jumpFreq','jumpSize','Properties','Variables','Row'};

fprintf('Testing comprehensive fix:\n');
fprintf('Original param fields: '); disp(paramFields');
fprintf('Original diag fields: '); disp(ALL_DIAG_FIELDS);

try
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
    
    finalNames = [paramFieldsRow, diagFieldsRow, statusFields];
    fprintf('Final field names: '); disp(finalNames);
    
    % Test table creation
    testTable = cell2table(cell(1, length(finalNames)));
    testTable.Properties.VariableNames = finalNames;
    fprintf('Table creation successful!\n');
    
catch ME
    fprintf('Error: %s\n', ME.message);
end
