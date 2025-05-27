function [productTables, diagnostics] = loadAndInventoryAllProducts(fileList, productNames, timestampVars)
% loadAndInventoryAllProducts Loads, cleans, and inventories all product datasets.
%   [productTables, diagnostics] = loadAndInventoryAllProducts(fileList, productNames, timestampVars)
%   Loads CSVs, uses explicit timestamp column mapping if provided, converts to timetables, standardizes timestamps, cleans,
%   and reports diagnostics for each product. Modular, robust, and ready for
%   multi-resolution energy price/risk simulation.
%
%   Inputs:
%     fileList      - cell array of file paths
%     productNames  - cell array of product names (same order as fileList)
%     timestampVars - struct mapping product names to timestamp column names
%
%   Outputs:
%     productTables - struct of cleaned timetables (one per product)
%     diagnostics   - struct of diagnostics for each product

productTables = struct();
diagnostics = struct();

for i = 1:numel(fileList)
    pname = productNames{i};
    fpath = fileList{i};
    % Use explicit timestamp column if provided, else auto-detect
    if isfield(timestampVars, pname)
        tvar = timestampVars.(pname);
    else
        tvar = detectTimestampColumn(readtable(fpath));
    end

    % Load CSV
    T = readtable(fpath);

    % === Handle non-time-series products (empty timestamp variable) ===
    if isempty(tvar)
        % Load as regular table, include in output, mark as non-time-series in diagnostics
        productTables.(pname) = T;
        diagnostics.(pname) = struct('nRows', height(T), 'isTimeSeries', false, 'note', 'Not a time series (no timestamp)');
        fprintf('\nProduct: %s\n  Rows: %d\n  Not a time series (no timestamp column)\n', pname, height(T));
        continue;
    end

    % Robust timestamp column matching (case-insensitive, trim whitespace)
    vars = T.Properties.VariableNames;
    matchIdx = find(strcmpi(strtrim(vars), strtrim(tvar)), 1);
    if isempty(matchIdx)
        warning('Product %s: Timestamp column "%s" not found. Skipping.', pname, tvar);
        continue;
    end
    tvar = vars{matchIdx}; % Use the actual column name as read

    try
        T.(tvar) = datetime(T.(tvar), 'InputFormat', inferDatetimeFormat(T.(tvar)), 'TimeZone', 'UTC');
    catch
        warning('Product %s: Could not convert column "%s" to datetime. Skipping.', pname, tvar);
        continue;
    end

    % Convert to timetable
    TT = table2timetable(T, 'RowTimes', tvar);

    % Sort and deduplicate
    TT = sortrows(TT);
    [~, ia] = unique(TT.Properties.RowTimes);
    TT = TT(ia, :);

    % Inventory and diagnostics (auto-infer native resolution)
    [diag, TT] = inventoryAndCleanTimetableAuto(TT, pname);

    productTables.(pname) = TT;
    diagnostics.(pname) = diag;
end
end

function tvar = detectTimestampColumn(T)
% Try to find a column with valid datetimes (case-insensitive)
    tvar = '';
    vars = T.Properties.VariableNames;
    for i = 1:numel(vars)
        col = T.(vars{i});
        try
            dt = datetime(col, 'InputFormat', inferDatetimeFormat(col), 'TimeZone', 'UTC');
            if sum(~isnat(dt)) > 0.9 * numel(dt) % At least 90% valid
                tvar = vars{i};
                return;
            end
        catch
            continue;
        end
    end
end

function fmt = inferDatetimeFormat(dtcol)
% Try to infer datetime format from a sample
    sample = string(dtcol(1:min(10, numel(dtcol))));
    try
        dt = datetime(sample, 'Format', '', 'TimeZone', '');
        fmt = dt.Format;
    catch
        fmt = 'yyyy-MM-dd HH:mm:ss'; % fallback
    end
end

function [diag, TT] = inventoryAndCleanTimetableAuto(TT, pname)
% Inventory, check for missing timestamps, gaps, and coverage (auto-infer resolution)
    times = TT.Properties.RowTimes;
    nRows = height(TT);
    tMin = min(times);
    tMax = max(times);
    % Infer native resolution
    if nRows > 1
        diffs = seconds(diff(times));
        modeStep = mode(diffs);
        res = seconds(modeStep);
        expectedRes = seconds(modeStep); % Use mode as expected
    else
        res = NaN;
        expectedRes = NaN;
    end
    % Find missing timestamps
    if ~isnan(expectedRes)
        allTimes = (tMin:seconds(expectedRes):tMax)';
        [missing, ~] = setdiff(allTimes, times);
        nMissing = numel(missing);
    else
        nMissing = NaN;
        allTimes = times;
    end
    % Largest gap
    if nRows > 1
        maxGap = max(diff(times));
    else
        maxGap = NaT;
    end
    % Diagnostics struct
    diag = struct('nRows', nRows, 'tMin', tMin, 'tMax', tMax, ...
        'nativeResolution', res, 'expectedResolution', expectedRes, ...
        'nMissingTimestamps', nMissing, 'largestGap', maxGap, ...
        'nDuplicates', nRows - numel(unique(times)));
    % Print diagnostics
    fprintf('\nProduct: %s\n', pname);
    fprintf('  Rows: %d\n', nRows);
    fprintf('  Time range: %s to %s\n', string(tMin), string(tMax));
    fprintf('  Native resolution: %.0f sec\n', seconds(res));
    fprintf('  Expected resolution: %.0f sec\n', seconds(expectedRes));
    fprintf('  Missing timestamps: %d\n', nMissing);
    fprintf('  Largest gap: %s\n', string(maxGap));
    fprintf('  Duplicate timestamps: %d\n', diag.nDuplicates);
    % Optionally: impute missing timestamps (add NaN rows)
    if nRows > 1 && nMissing > 0
        TT = retime(TT, allTimes, 'fillwithmissing');
    end
end 