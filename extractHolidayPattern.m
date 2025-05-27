function holidayPattern = extractHolidayPattern(timestamps, prices)
    % Ensure timestamps are datetime objects
    if ~isa(timestamps, 'datetime')
        try
            timestamps = datetime(timestamps);
        catch
            error('Cannot convert timestamps to datetime format');
        end
    end
    
    % Initialize holiday pattern structure
    holidayPattern = struct();
    holidayPattern.adjustmentFactors = struct();
    
    % Define US energy trading holidays for pattern recognition
    years = unique(year(timestamps));
    holidayDates = [];
    holidayNames = {};
    
    for y = years'
        % New Year's Day
        holidayDates = [holidayDates; datetime(y, 1, 1)];
        holidayNames{end+1} = 'NewYear';
        
        % Memorial Day (last Monday in May)
        lastMondayMay = datetime(y, 5, 31);
        while weekday(lastMondayMay) ~= 2  % 2 = Monday
            lastMondayMay = lastMondayMay - days(1);
        end
        holidayDates = [holidayDates; lastMondayMay];
        holidayNames{end+1} = 'Memorial';
        
        % Independence Day
        holidayDates = [holidayDates; datetime(y, 7, 4)];
        holidayNames{end+1} = 'Independence';
        
        % Labor Day (first Monday in September)
        firstMondaySep = datetime(y, 9, 1);
        while weekday(firstMondaySep) ~= 2  % 2 = Monday
            firstMondaySep = firstMondaySep + days(1);
        end
        holidayDates = [holidayDates; firstMondaySep];
        holidayNames{end+1} = 'Labor';
        
        % Thanksgiving (fourth Thursday in November)
        fourthThursdayNov = datetime(y, 11, 1);
        thursdayCount = 0;
        while thursdayCount < 4
            if weekday(fourthThursdayNov) == 5  % 5 = Thursday
                thursdayCount = thursdayCount + 1;
            end
            if thursdayCount < 4
                fourthThursdayNov = fourthThursdayNov + days(1);
            end
        end
        holidayDates = [holidayDates; fourthThursdayNov];
        holidayNames{end+1} = 'Thanksgiving';
        
        % Christmas Day
        holidayDates = [holidayDates; datetime(y, 12, 25)];
        holidayNames{end+1} = 'Christmas';
    end
    
    % Analyze patterns around holidays
    holidayTypes = unique(holidayNames);
    for h = 1:length(holidayTypes)
        holidayType = holidayTypes{h};
        typeHolidays = holidayDates(strcmp(holidayNames, holidayType));
        
        % Initialize arrays for this holiday type
        preHolidayPrices = [];
        holidayPrices = [];
        postHolidayPrices = [];
        normalPrices = [];
        
        % For each occurrence of this holiday
        for i = 1:length(typeHolidays)
            holiday = typeHolidays(i);
            
            % Ensure both timestamps and holiday have the same timezone
            if isdatetime(timestamps) && isdatetime(holiday)
                if ~isempty(timestamps.TimeZone) && isempty(holiday.TimeZone)
                    holiday.TimeZone = timestamps.TimeZone;
                elseif isempty(timestamps.TimeZone) && ~isempty(holiday.TimeZone)
                    timestamps.TimeZone = holiday.TimeZone;
                end
            end
            
            % Pre-holiday (1-2 days before)
            preHolidayIdx = (timestamps >= holiday - days(2)) & (timestamps < holiday);
            if sum(preHolidayIdx) > 0
                preHolidayPrices = [preHolidayPrices; prices(preHolidayIdx)];
            end
            
            % Holiday day
            holidayIdx = (timestamps >= holiday) & (timestamps < holiday + days(1));
            if sum(holidayIdx) > 0
                holidayPrices = [holidayPrices; prices(holidayIdx)];
            end
            
            % Post-holiday (1-2 days after)
            postHolidayIdx = (timestamps >= holiday + days(1)) & (timestamps <= holiday + days(2));
            if sum(postHolidayIdx) > 0
                postHolidayPrices = [postHolidayPrices; prices(postHolidayIdx)];
            end
            
            % Normal days (same weekday, 2-4 weeks away from holiday)
            for offset = [14, 21, 28]  % 2, 3, 4 weeks
                normalDay1 = holiday - days(offset);
                normalDay2 = holiday + days(offset);
                
                normalIdx1 = (timestamps >= normalDay1) & (timestamps < normalDay1 + days(1));
                normalIdx2 = (timestamps >= normalDay2) & (timestamps < normalDay2 + days(1));
                
                if sum(normalIdx1) > 0
                    normalPrices = [normalPrices; prices(normalIdx1)];
                end
                if sum(normalIdx2) > 0
                    normalPrices = [normalPrices; prices(normalIdx2)];
                end
            end
        end
        
        % Calculate adjustment factors (relative to normal days)
        if ~isempty(normalPrices)
            normalMean = mean(normalPrices, 'omitnan');
            
            % Pre-holiday adjustment
            if ~isempty(preHolidayPrices)
                preHolidayMean = mean(preHolidayPrices, 'omitnan');
                if normalMean ~= 0
                    holidayPattern.adjustmentFactors.([holidayType '_PreHoliday']) = preHolidayMean / normalMean;
                else
                    holidayPattern.adjustmentFactors.([holidayType '_PreHoliday']) = 1.0;
                end
            else
                holidayPattern.adjustmentFactors.([holidayType '_PreHoliday']) = 1.0;
            end
            
            % Holiday adjustment
            if ~isempty(holidayPrices)
                holidayMean = mean(holidayPrices, 'omitnan');
                if normalMean ~= 0
                    holidayPattern.adjustmentFactors.([holidayType '_Holiday']) = holidayMean / normalMean;
                else
                     holidayPattern.adjustmentFactors.([holidayType '_Holiday']) = 0.8; % Default if normalMean is zero
                end
            else
                holidayPattern.adjustmentFactors.([holidayType '_Holiday']) = 0.8; % Typically lower on holidays
            end
            
            % Post-holiday adjustment
            if ~isempty(postHolidayPrices)
                postHolidayMean = mean(postHolidayPrices, 'omitnan');
                if normalMean ~= 0
                    holidayPattern.adjustmentFactors.([holidayType '_PostHoliday']) = postHolidayMean / normalMean;
                else
                    holidayPattern.adjustmentFactors.([holidayType '_PostHoliday']) = 1.0;
                end
            else
                holidayPattern.adjustmentFactors.([holidayType '_PostHoliday']) = 1.0;
            end
        else % If normalPrices is empty, use default factors
            holidayPattern.adjustmentFactors.([holidayType '_PreHoliday']) = 1.0;
            holidayPattern.adjustmentFactors.([holidayType '_Holiday']) = 0.8;
            holidayPattern.adjustmentFactors.([holidayType '_PostHoliday']) = 1.0;
        end
    end
    
    % Store holiday dates for future reference
    holidayPattern.holidayDates = holidayDates;
    holidayPattern.holidayNames = holidayNames;
end 