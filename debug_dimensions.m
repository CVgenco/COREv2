% Debug script to check array dimensions
clc;

% Simulate the arrays
params = struct('jumpSigma', 0.1, 'regimeVar', 0.2); % Example params
paramFields = fieldnames(params);
ALL_DIAG_FIELDS = {'mean','std','kurtosis','skewness','jumpFreq','jumpSize','acfsq','regimeDuration','transitionMatrix','numCappedEvents','numCappedPricePathEvents'};

fprintf('paramFields size: %s\n', mat2str(size(paramFields)));
fprintf('paramFields'' size: %s\n', mat2str(size(paramFields')));
fprintf('ALL_DIAG_FIELDS size: %s\n', mat2str(size(ALL_DIAG_FIELDS)));
fprintf('ALL_DIAG_FIELDS'' size: %s\n', mat2str(size(ALL_DIAG_FIELDS')));
fprintf('{''error'',''status''} size: %s\n', mat2str(size({'error','status'})));

% Test concatenation
try
    combined = [paramFields'; ALL_DIAG_FIELDS; {'error','status'}];
    fprintf('Concatenation successful with size: %s\n', mat2str(size(combined)));
catch ME
    fprintf('Error: %s\n', ME.message);
end

% Alternative approach - ensure all are horizontal
try
    combined2 = [paramFields(:)'; ALL_DIAG_FIELDS(:)'; {'error','status'}];
    fprintf('Alternative concatenation successful with size: %s\n', mat2str(size(combined2)));
catch ME2
    fprintf('Alternative error: %s\n', ME2.message);
end
