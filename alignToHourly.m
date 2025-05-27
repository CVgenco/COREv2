function alignedData = alignToHourly(nodalData, hubData, genData, ancillaryData, hasGenData, hasAncillaryData, targetResolution)
% Vectorized alignment using timetables and retime
% Inputs:
%   nodalData: table with Timestamp and node columns
%   hubData: table with Timestamp and hub columns (can be empty)
%   genData: table with Timestamp and generation columns (can be empty)
%   ancillaryData: struct of tables with Timestamp and ancillary columns (can be empty)
%   hasGenData: logical, true if genData is present
%   hasAncillaryData: logical, true if ancillaryData is present
%   targetResolution: string, e.g., 'hourly', '5min', '15min' (default: 'hourly')
% Output:
%   alignedData: table with Timestamp and all products aligned to target timeline

    if nargin < 7 || isempty(targetResolution)
        targetResolution = 'hourly';
    end

    % --- Rename columns in each table to ensure uniqueness and match productNames logic ---
    % Nodal data: append _nodal
    nodeNames = setdiff(nodalData.Properties.VariableNames, {'Timestamp'});
    for i = 1:length(nodeNames)
        newName = sprintf('%s_nodal', nodeNames{i});
        nodalData = renamevars(nodalData, nodeNames{i}, newName);
    end
    % Hub data: append _hub
    if ~isempty(hubData)
        hubNames = setdiff(hubData.Properties.VariableNames, {'Timestamp'});
        for i = 1:length(hubNames)
            newName = sprintf('%s_hub', hubNames{i});
            hubData = renamevars(hubData, hubNames{i}, newName);
        end
    end
    % Gen data: append _gen
    if hasGenData && ~isempty(genData)
        genNames = setdiff(genData.Properties.VariableNames, {'Timestamp'});
        for i = 1:length(genNames)
            newName = sprintf('%s_gen', genNames{i});
            genData = renamevars(genData, genNames{i}, newName);
        end
    end
    % Ancillary data: append _<lower(ancType)>
    if hasAncillaryData
        ancTypes = fieldnames(ancillaryData);
        for a = 1:length(ancTypes)
            ancType = ancTypes{a};
            if ~isempty(ancillaryData.(ancType))
                ancNames = setdiff(ancillaryData.(ancType).Properties.VariableNames, {'Timestamp'});
                for i = 1:length(ancNames)
                    newName = sprintf('%s_%s', ancNames{i}, lower(ancType));
                    ancillaryData.(ancType) = renamevars(ancillaryData.(ancType), ancNames{i}, newName);
                end
            end
        end
    end

    % --- Convert to timetables and align ---
    nodalTT = table2timetable(nodalData, 'RowTimes', nodalData.Timestamp);
    nodalTT = retime(nodalTT, targetResolution, 'mean');
    tts = {nodalTT};

    if ~isempty(hubData)
        hubTT = table2timetable(hubData, 'RowTimes', hubData.Timestamp);
        hubTT = retime(hubTT, targetResolution, 'mean');
        tts{end+1} = hubTT;
    end

    if hasGenData && ~isempty(genData)
        genTT = table2timetable(genData, 'RowTimes', genData.Timestamp);
        genTT = retime(genTT, targetResolution, 'mean');
        tts{end+1} = genTT;
    end

    if hasAncillaryData
        ancTypes = fieldnames(ancillaryData);
        for a = 1:length(ancTypes)
            ancType = ancTypes{a};
            if ~isempty(ancillaryData.(ancType))
                ancTT = table2timetable(ancillaryData.(ancType), 'RowTimes', ancillaryData.(ancType).Timestamp);
                ancTT = retime(ancTT, targetResolution, 'mean');
                tts{end+1} = ancTT;
            end
        end
    end

    % Check that all timetables have data at the requested resolution
    for k = 1:numel(tts)
        if height(tts{k}) == 0
            error('Not all products have data at the requested resolution (%s).', targetResolution);
        end
    end

    % Synchronize all timetables to a master timeline (union of all times)
    masterTT = synchronize(tts{:}, 'union', 'mean');
    alignedData = timetable2table(masterTT, 'ConvertRowTimes', true);
    alignedData.Properties.VariableNames{1} = 'Timestamp';

    % All columns are now uniquely named and match productNames
end 