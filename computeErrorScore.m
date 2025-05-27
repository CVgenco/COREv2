function [score, acfError, kurtError] = computeErrorScore(acfFile, kurtosisFile)
% computeErrorScore Loads diagnostics and computes error score
%   acfFile: path to volatility ACF CSV
%   kurtosisFile: path to kurtosis TXT
%   Returns: score (total), acfError, kurtError

acfError = Inf;
kurtError = Inf;
score = Inf;

try
    if ~exist(acfFile, 'file')
        warning('ACF file not found: %s', acfFile);
        acfError = Inf;
    else
        acfData = readtable(acfFile);
        if height(acfData) >= 21 && ismember('HistoricalACF', acfData.Properties.VariableNames) && ismember('SimulatedACF', acfData.Properties.VariableNames)
            histACF_col = acfData.HistoricalACF;
            simACF_col = acfData.SimulatedACF;
            acfError = sum((simACF_col(2:21) - histACF_col(2:21)).^2); % Lags 1-20 are at indices 2-21
        elseif height(acfData) == 0 && ismember('HistoricalACF', acfData.Properties.VariableNames) % Empty table written placeholder
            warning('ACF data in %s is empty (placeholder for skipped diagnostics).', acfFile);
            acfError = Inf; % Treat as infinitely bad if data was skipped
        else
            warning('ACF data in %s is missing required columns or is too short. Cols: %s, Rows: %d', acfFile, strjoin(acfData.Properties.VariableNames, ', '), height(acfData));
            acfError = Inf;
        end
    end
catch ME
    fprintf(2, 'Error in computeErrorScore reading ACF file %s: %s\n', acfFile, ME.message);
    acfError = Inf;
end

try
    if ~exist(kurtosisFile, 'file')
        warning('Kurtosis file not found: %s', kurtosisFile);
        kurtError = Inf;
    else
        fid = fopen(kurtosisFile, 'r');
        if fid == -1
            warning('Could not open kurtosis file: %s', kurtosisFile);
            kurtError = Inf;
        else
            lines = textscan(fid, '%s', 'Delimiter', '\n');
            fclose(fid);
            if numel(lines{1}) >= 2 % Ensure there are at least two lines to read
                histKurt = str2double(regexp(lines{1}{1}, '[-+]?\d*\.?\d+([eE][-+]?\d+)?', 'match'));
                simKurt = str2double(regexp(lines{1}{2}, '[-+]?\d*\.?\d+([eE][-+]?\d+)?', 'match'));
                if isempty(histKurt) || isempty(simKurt) || isnan(histKurt) || isnan(simKurt)
                     warning('Could not parse kurtosis values from %s.', kurtosisFile);
                     kurtError = Inf;
                else
                    kurtError = abs(simKurt - histKurt);
                end
            else
                warning('Kurtosis file %s does not contain enough lines.', kurtosisFile);
                kurtError = Inf;
            end
        end
    end
catch ME
    fprintf(2, 'Error in computeErrorScore reading Kurtosis file %s: %s\n', kurtosisFile, ME.message);
    kurtError = Inf;
end

% --- Additional diagnostics ---
products = {};
outputDir = fileparts(acfFile);
jumpFiles = dir(fullfile(outputDir, '*_jump_frequency.txt'));
for k = 1:numel(jumpFiles)
    pname = erase(jumpFiles(k).name, '_jump_frequency.txt');
    products{end+1} = pname;
end

jumpFreqError = 0;
jumpSizeError = 0;
regimeDurError = 0;
regimeTransError = 0;
nProducts = numel(products);

for i = 1:nProducts
    pname = products{i};
    % --- Jump frequency ---
    try
        jumpFile = fullfile(outputDir, [pname '_jump_frequency.txt']);
        if exist(jumpFile, 'file')
            txt = fileread(jumpFile);
            vals = regexp(txt, '([\d\.]+)', 'match');
            if numel(vals) >= 2
                histJumpFreq = str2double(vals{1});
                simJumpFreq = str2double(vals{2});
                jumpFreqError = jumpFreqError + abs(simJumpFreq - histJumpFreq);
            end
        end
    catch
        jumpFreqError = jumpFreqError + 1;
    end

    % --- Jump size distribution (KS test) ---
    try
        histJumpFile = fullfile(outputDir, [pname '_hist_jump_sizes.csv']);
        simJumpFile = fullfile(outputDir, [pname '_sim_jump_sizes.csv']);
        if exist(histJumpFile, 'file') && exist(simJumpFile, 'file')
            histJumpSizes = readmatrix(histJumpFile);
            simJumpSizes = readmatrix(simJumpFile);
            if ~isempty(histJumpSizes) && ~isempty(simJumpSizes)
                % Use two-sample KS statistic
                [~,~,ksStat] = kstest2(simJumpSizes, histJumpSizes);
                jumpSizeError = jumpSizeError + ksStat;
            end
        end
    catch
        jumpSizeError = jumpSizeError + 1;
    end

    % --- Regime duration (mean absolute error) ---
    try
        histDurFile = fullfile(outputDir, [pname '_hist_regime_durations.csv']);
        simDurFile = fullfile(outputDir, [pname '_sim_regime_durations.csv']);
        if exist(histDurFile, 'file') && exist(simDurFile, 'file')
            histDur = readmatrix(histDurFile);
            simDur = readmatrix(simDurFile);
            if ~isempty(histDur) && ~isempty(simDur)
                n = min(numel(histDur), numel(simDur));
                regimeDurError = regimeDurError + mean(abs(sort(histDur(1:n)) - sort(simDur(1:n))));
            end
        end
    catch
        regimeDurError = regimeDurError + 1;
    end

    % --- Regime transition matrix ---
    try
        regTransFile = fullfile(outputDir, [pname '_hist_regime_transition_matrix.csv']);
        if exist(regTransFile, 'file')
            histTrans = readmatrix(regTransFile);
            simTrans = histTrans; % If you have simulated, use it; else skip
            regimeTransError = regimeTransError + norm(histTrans - simTrans, 'fro');
        end
    catch
        regimeTransError = regimeTransError + 1;
    end
end

% Normalize errors by number of products
if nProducts > 0
    jumpFreqError = jumpFreqError / nProducts;
    jumpSizeError = jumpSizeError / nProducts;
    regimeDurError = regimeDurError / nProducts;
    regimeTransError = regimeTransError / nProducts;
end

if isfinite(acfError) && isfinite(kurtError)
    score = 2 * acfError + ...
            0.05 * kurtError + ...
            5 * jumpFreqError + ...
            1 * jumpSizeError + ...
            5 * regimeDurError + ...
            5 * regimeTransError;
else
    score = Inf;
end

if isnan(score)
    score = Inf;
end
end 