% combine_regime_labels.m
% Combine individual regime labels into struct format

disp('=== Combining Regime Labels ===');

% List of products
products = {'nodalPrices', 'hubPrices', 'nodalGeneration', 'regup', 'regdown', 'nonspin', 'hourlyHubForecasts', 'hourlyNodalForecasts'};

regimeLabels = struct();

for i = 1:length(products)
    pname = products{i};
    filename = ['EDA_Results/regimeLabels_' pname '.mat'];
    
    if exist(filename, 'file')
        fprintf('Loading %s... ', filename);
        data = load(filename);
        varNames = fieldnames(data);
        
        % Use the first variable (should be regimeLabels)
        regimeLabels.(pname) = data.(varNames{1});
        fprintf('done\n');
    else
        fprintf('Missing: %s\n', filename);
        regimeLabels.(pname) = [];
    end
end

% Save combined file
save('EDA_Results/regimeLabels.mat', 'regimeLabels');
disp('✅ Combined regimeLabels.mat saved');
