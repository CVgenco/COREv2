function [alignedTable, info] = alignAndSynchronizeProducts(productTables, diagnostics, config, varargin)
% alignAndSynchronizeProducts Aligns selected product timetables to a common resolution and timeline.
%   [alignedTable, info] = alignAndSynchronizeProducts(productTables, diagnostics, config, ...)
%   Uses smart logic: aligns at the finest (min) resolution if all products are subhourly (<=900 sec),
%   or at the coarsest (max) resolution if any product is hourly or coarser. User override is only allowed
%   if 'ForceResolution' is set to true. Forecast products are always excluded from alignment.
%   Optionally, user can specify 'TargetResolution' and 'ForceResolution'.
%   
%   IMPORTANT: Only align historical products for EDA/correlation. Do NOT include future forecast products
%   (e.g., hourlyHubForecasts, hourlyNodalForecasts) in alignment. These are used for simulation guidance only.
%   Pass only the products you want to align in productTables/diagnostics.
%
%   Inputs:
%     productTables - struct of timetables (from loadAndInventoryAllProducts), only historical products
%     diagnostics   - struct of diagnostics (from loadAndInventoryAllProducts), only historical products
%     config        - struct with configuration settings
%     'TargetResolution' (optional) - duration, e.g., minutes(15)
%     'ForceResolution' (optional) - logical, only allow user override if true
%
%   Outputs:
%     alignedTable - timetable with all products aligned and resampled
%     info         - struct with chosen resolution, warnings, and mapping

if nargin < 3 || isempty(config)
    config = userConfig();
end

% Parse optional arguments
p = inputParser;
p.addParameter('TargetResolution', [], @(x) isempty(x) || isduration(x));
p.addParameter('ForceResolution', false, @(x) islogical(x) || isnumeric(x));
p.parse(varargin{:});
targetRes = p.Results.TargetResolution;
forceRes = p.Results.ForceResolution;

% Get product names
productNames = fieldnames(productTables);

% === Exclude future forecast products from alignment ===
forecastProducts = {'hourlyHubForecasts', 'hourlyNodalForecasts'};
excludeIdx = ismember(productNames, forecastProducts);
if any(excludeIdx)
    warning('The following forecast products are excluded from alignment: %s', strjoin(productNames(excludeIdx), ', '));
    productNames = productNames(~excludeIdx);
end

% === Filter to only time series products (those with nativeResolution in diagnostics) ===
isTimeSeries = false(size(productNames));
for i = 1:numel(productNames)
    diagFields = fieldnames(diagnostics.(productNames{i}));
    isTimeSeries(i) = ismember('nativeResolution', diagFields);
end
productNames = productNames(isTimeSeries);

% Get native resolutions from diagnostics
nativeRes = zeros(numel(productNames),1);
for i = 1:numel(productNames)
    nativeRes(i) = seconds(diagnostics.(productNames{i}).nativeResolution);
end

% Smart resolution selection (default)
if all(nativeRes <= 900)
    chosenRes = min(nativeRes);
    resSource = 'finest (all subhourly)';
elseif any(nativeRes > 900)
    chosenRes = max(nativeRes);
    resSource = 'coarsest (at least one hourly)';
end

% Only override if ForceResolution is true and targetRes is not empty
if forceRes && ~isempty(targetRes)
    chosenRes = seconds(targetRes);
    resSource = 'user-forced';
    if any(nativeRes < chosenRes)
        error('Requested resolution (%.0f sec) is coarser than some products'' native resolution (min %.0f sec).', chosenRes, min(nativeRes));
    end
end

fprintf('\n[alignAndSynchronizeProducts] Chosen alignment resolution: %.0f sec (%s)\n', chosenRes, resSource);

% Resample all products to chosen resolution using 'mean' aggregation
resampledTables = cell(numel(productNames),1);
for i = 1:numel(productNames)
    TT = productTables.(productNames{i});
    % Retime to chosen resolution
    newTimes = (TT.Properties.RowTimes(1):seconds(chosenRes):TT.Properties.RowTimes(end))';
    resampledTT = retime(TT, newTimes, 'mean');
    % Rename all variables in this timetable to the product name
    resampledTT = renamevars(resampledTT, resampledTT.Properties.VariableNames, productNames{i});
    resampledTables{i} = resampledTT;
end

% Synchronize all tables
alignedTable = resampledTables{1};
for i = 2:numel(resampledTables)
    alignedTable = synchronize(alignedTable, resampledTables{i}, 'intersection', 'mean');
end

% Clean up variable names (add product name as prefix if needed)
% (Optional: can be extended for more robust naming)

% Output info struct
info = struct();
info.chosenResolution = chosenRes;
info.resolutionSource = resSource;
info.nativeResolutions = nativeRes;
info.productNames = productNames;

end