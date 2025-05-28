% Check for problematic field names
clc;

% Parameter fields from the optimization variables
optimVars = {'anchorWeight','capReturn','capJump','volAmp','blockSize','jumpFreq','minJumpSize','maxVolRatio','capDiff','capAdj'};

% Diagnostic fields
ALL_DIAG_FIELDS = {'mean','std','kurtosis','skewness','jumpFreq','jumpSize','acfsq','regimeDuration','transitionMatrix','numCappedEvents','numCappedPricePathEvents'};

% Status fields
statusFields = {'error','status'};

% Combine all fields
allFields = [optimVars, ALL_DIAG_FIELDS, statusFields];

fprintf('All field names:\n');
for i = 1:length(allFields)
    fprintf('%d: %s\n', i, allFields{i});
end

% Check for reserved names
reservedNames = {'Properties', 'Row', 'Variables'};
for i = 1:length(reservedNames)
    if any(strcmpi(allFields, reservedNames{i}))
        fprintf('\nWARNING: Found reserved name: %s\n', reservedNames{i});
    end
end

% Test table creation with these names
try
    testTable = cell2table(cell(1, length(allFields)));
    testTable.Properties.VariableNames = allFields;
    fprintf('\nTable creation successful!\n');
catch ME
    fprintf('\nTable creation failed: %s\n', ME.message);
end
