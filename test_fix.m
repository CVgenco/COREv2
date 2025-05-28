% Test the corrected concatenation
clc;

params = struct('jumpSigma', 0.1, 'regimeVar', 0.2);
paramFields = fieldnames(params);
ALL_DIAG_FIELDS = {'mean','std','kurtosis','skewness','jumpFreq','jumpSize','acfsq','regimeDuration','transitionMatrix','numCappedEvents','numCappedPricePathEvents'};

fprintf('Testing corrected concatenation:\n');
try
    combined = [paramFields'; ALL_DIAG_FIELDS; {'error','status'}];
    fprintf('Success! Combined size: %s\n', mat2str(size(combined)));
    fprintf('Variable names: ');
    disp(combined);
catch ME
    fprintf('Error: %s\n', ME.message);
end
