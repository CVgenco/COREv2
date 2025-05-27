function seasonalPattern = extractSeasonalBehaviorPattern(timestamps, prices, months, daysOfWeek, hours)
    % Ensure timestamps are datetime objects
    if ~isa(timestamps, 'datetime')
        try
            timestamps = datetime(timestamps);
        catch
            error('Cannot convert timestamps to datetime format');
        end
    end

    % SPRINT 1: Use precomputed months, daysOfWeek, hours if provided
    if nargin < 3 || isempty(months)
        [~, months, ~, hours, ~, ~] = datevec(timestamps);
    end
    if nargin < 4 || isempty(daysOfWeek)
        t_num = datenum(timestamps);
        daysOfWeek = mod(floor(t_num) - 1, 7) + 1;
    end
    if nargin < 5 || isempty(hours)
        [~, ~, ~, hours, ~, ~] = datevec(timestamps);
    end

    seasonalPattern = struct();
    
    % Define seasons
    seasons = struct();
    seasons.Winter = [12, 1, 2];  % Dec, Jan, Feb
    seasons.Spring = [3, 4, 5];   % Mar, Apr, May
    seasons.Summer = [6, 7, 8];   % Jun, Jul, Aug
    seasons.Fall = [9, 10, 11];   % Sep, Oct, Nov
    
    seasonNames = fieldnames(seasons);
    
    % 1. Seasonal Weekend vs Weekday Effects
    seasonalPattern.weekendEffects = struct();
    for s = 1:length(seasonNames)
        season = seasonNames{s};
        monthsInSeason = seasons.(season);
        isSeason = ismember(months, monthsInSeason);
        isWeekend = (daysOfWeek == 1 | daysOfWeek == 7); % Sunday or Saturday
        seasonalPattern.weekendEffects.(season) = mean(prices(isSeason & isWeekend), 'omitnan') / mean(prices(isSeason & ~isWeekend), 'omitnan');
    end
    
    % 2. Hourly Shapes by Season
    seasonalPattern.hourlyShapes = struct();
    for s = 1:length(seasonNames)
        season = seasonNames{s};
        monthsInSeason = seasons.(season);
        isSeason = ismember(months, monthsInSeason);
        hourlyShape = zeros(24, 1);
        for h = 0:23
            idx = isSeason & (hours == h);
            hourlyShape(h+1) = mean(prices(idx), 'omitnan');
        end
        % Normalize shape
        if mean(hourlyShape, 'omitnan') ~= 0
            hourlyShape = hourlyShape / mean(hourlyShape, 'omitnan');
        end
        seasonalPattern.hourlyShapes.(season) = hourlyShape;
    end
    
    % 3. Cross-Seasonal Effects (example: Monday morning, Friday afternoon)
    seasonalPattern.crossEffects = struct();
    for s = 1:length(seasonNames)
        season = seasonNames{s};
        monthsInSeason = seasons.(season);
        isSeason = ismember(months, monthsInSeason);
        % Monday morning (6-10am)
        idxMon = isSeason & (daysOfWeek == 2) & (hours >= 6 & hours <= 10);
        if any(idxMon)
            seasonalPattern.crossEffects.([season '_MondayMorning']) = mean(prices(idxMon), 'omitnan') / mean(prices(isSeason), 'omitnan');
        end
        % Friday afternoon (2-6pm)
        idxFri = isSeason & (daysOfWeek == 6) & (hours >= 14 & hours <= 18);
        if any(idxFri)
            seasonalPattern.crossEffects.([season '_FridayAfternoon']) = mean(prices(idxFri), 'omitnan') / mean(prices(isSeason), 'omitnan');
        end
    end
end 