% fix_regime_labels_structure.m
% Simple script to combine individual regimeLabels_*.mat files into single struct

fprintf('=== Fixing Regime Labels Data Structure ===\n');

% Define the known products from the workspace
products = {'nodalPrices', 'hubPrices', 'nodalGeneration', 'regup', 'regdown', 'nonspin', 'hourlyHubForecasts', 'hourlyNodalForecasts'};

% Initialize the combined regimeLabels struct
regimeLabels = struct();

% Load each individual regime labels file
for i = 1:length(products)
    pname = products{i};
    filename = ['EDA_Results/regimeLabels_' pname '.mat'];
    
    if exist(filename, 'file')
        fprintf('Loading %s... ', filename);
        try
            data = load(filename);
            
            % Check what variables are in the file
            varNames = fieldnames(data);
            fprintf('Variables: %s', varNames{1});
            
            % Use the first variable (should be regimeLabels)
            firstVar = data.(varNames{1});
            regimeLabels.(pname) = firstVar;
            
            % Get some stats
            if isnumeric(firstVar)
                validRegimes = firstVar(~isnan(firstVar));
                uniqueRegimes = unique(validRegimes);
                fprintf(' -> %d observations, regimes: [%s]\n', length(firstVar), num2str(uniqueRegimes'));
            else
                fprintf(' -> Non-numeric data\n');
            end
            
        catch ME
            fprintf('ERROR: %s\n', ME.message);
            regimeLabels.(pname) = [];
        end
    else
        fprintf('File not found: %s\n', filename);
        regimeLabels.(pname) = [];
    end
end

% Save the combined regimeLabels struct
fprintf('\nSaving combined regimeLabels.mat...\n');
save('EDA_Results/regimeLabels.mat', 'regimeLabels');

fprintf('✅ Regime labels structure fixed! Ready for Sprint 2.\n');
