% runDataInventory.m
% Script to load, clean, and inventory all product datasets using auto-detection and user config.
% Assumes all timestamps are UTC and timestamp column is auto-detected.

run('userConfig.m');

% List your files from config
fileList = struct2cell(config.dataFiles);

% Optionally, specify product names (otherwise inferred from file names)
productNames = fieldnames(config.dataFiles);
timestampVars = config.timestampVars;

% Call the loader (with productNames and timestampVars)
[productTables, diagnostics] = loadAndInventoryAllProducts(fileList, productNames, timestampVars);

% The script will print diagnostics for each product and return tables/diagnostics in workspace. 

% === Print time range for each product for overlap diagnostics ===
productNames = fieldnames(productTables);
for i = 1:numel(productNames)
    pname = productNames{i};
    TT = productTables.(pname);
    diag = diagnostics.(pname);
    if istimetable(TT) && height(TT) > 0
        tmin = min(TT.Properties.RowTimes);
        tmax = max(TT.Properties.RowTimes);
        fprintf('Product: %s | Time range: %s to %s | Rows: %d\n', pname, string(tmin), string(tmax), height(TT));
    elseif isfield(diag, 'isTimeSeries') && ~diag.isTimeSeries
        fprintf('Product: %s | Rows: %d | Not a time series (no timestamp column)\n', pname, diag.nRows);
    else
        fprintf('Product: %s | No data loaded\n', pname);
    end
end 