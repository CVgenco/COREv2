function prepareValidationData()
% prepareValidationData Prepare required data files for validation
% Ensures alignedTable.mat and other required files are in the working directory

fprintf('Preparing validation data files...\n');

% Copy alignedTable to working directory if needed
if ~exist('alignedTable.mat', 'file') && exist('EDA_Results/alignedTable.mat', 'file')
    copyfile('EDA_Results/alignedTable.mat', 'alignedTable.mat');
    fprintf(' ✓ Copied alignedTable.mat to working directory\n');
end

% Copy info.mat if needed
if ~exist('info.mat', 'file') && exist('EDA_Results/info.mat', 'file')
    copyfile('EDA_Results/info.mat', 'info.mat');
    fprintf(' ✓ Copied info.mat to working directory\n');
end

% Copy regimeInfo.mat if needed
if ~exist('regimeInfo.mat', 'file') && exist('EDA_Results/regimeInfo.mat', 'file')
    copyfile('EDA_Results/regimeInfo.mat', 'regimeInfo.mat');
    fprintf(' ✓ Copied regimeInfo.mat to working directory\n');
end

fprintf('Validation data preparation complete.\n');
end
