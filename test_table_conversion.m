% Test table to struct conversion
clc;

% Test with table input (as would come from Bayesian optimization)
paramTable = table(0.1, 1000, 'VariableNames', {'jumpFreq', 'capReturn'});
fprintf('Testing table input:\n');
fprintf('Input is table: %d\n', istable(paramTable));

% Convert params to struct if it's a table
if istable(paramTable)
    paramFields = paramTable.Properties.VariableNames;
    paramStruct = struct();
    for i = 1:length(paramFields)
        paramStruct.(paramFields{i}) = paramTable{1, paramFields{i}};
    end
    params = paramStruct;
    fprintf('Converted to struct successfully\n');
    fprintf('Fields: '); disp(fieldnames(params));
    fprintf('Values: jumpFreq=%g, capReturn=%g\n', params.jumpFreq, params.capReturn);
else
    fprintf('Input was not a table\n');
end

% Test with struct input
paramStruct2 = struct('volAmp', 1.5, 'blockSize', 24);
fprintf('\nTesting struct input:\n');
fprintf('Input is table: %d\n', istable(paramStruct2));
if istable(paramStruct2)
    fprintf('Would convert to struct\n');
else
    fprintf('Already a struct - no conversion needed\n');
    fprintf('Fields: '); disp(fieldnames(paramStruct2));
end
