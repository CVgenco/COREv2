% Test the robust fix
clc;

params = struct('jumpSigma', 0.1, 'regimeVar', 0.2);
paramFields = fieldnames(params);
ALL_DIAG_FIELDS = {'mean','std','kurtosis','skewness','jumpFreq','jumpSize','acfsq','regimeDuration','transitionMatrix','numCappedEvents','numCappedPricePathEvents'};

fprintf('Testing robust fix:\n');
try
    % Ensure all arrays are row vectors for concatenation
    paramFieldsRow = paramFields(:)';
    diagFieldsRow = ALL_DIAG_FIELDS(:)';
    statusFields = {'error','status'};
    combined = [paramFieldsRow, diagFieldsRow, statusFields];
    fprintf('Success! Combined size: %s\n', mat2str(size(combined)));
    fprintf('Total elements: %d\n', numel(combined));
catch ME
    fprintf('Error: %s\n', ME.message);
end
