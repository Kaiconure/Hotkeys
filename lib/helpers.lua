ADDON_NAME      = 'Hotkeys'
ADDON_COMMAND   = 'hotkeys'

--------------------------------------------------------------------------------------
-- Find the index of the specified array key, or nil
function arrayIndexOf(array, search)
    if array ~= nil then
        for index, value in ipairs(array) do
            if value == search then
                return index
            end
        end
    end
    
    return nil
end

--------------------------------------------------------------------------------------
-- Find the index of the specified array key, or nil
function arrayIndexOfStrI(array, search)
    if isArray(array) and search ~= nil then
        search = string.lower(search)
        for index, value in ipairs(array) do
            if string.lower(value) == search then
                return index
            end
        end
    end
    
    return nil
end

--------------------------------------------------------------------------------------
-- Determine whether a buff is active
function isBuffActive(buffs, buffId)
	return arrayIndexOf(buffs, buffId)
end

--------------------------------------------------------------------------------------
-- Determine whether the player has the specified job and minimum level
function isJobLevel(player, job, minimumLevel)
    job = tostring(job or ''):upper()

	return (player.main_job == job and player.main_job_level >= minimumLevel)
        or (player.sub_job == job and player.sub_job_level >= minimumLevel)
end

--------------------------------------------------------------------------------------
-- Check if an object is an array
function isArray(value)
    return value ~= nil and type(value) == 'table' and #value > 0
end

--------------------------------------------------------------------------------------
-- Return true if an input matches any values in an array
function any(input, values, equals)
    if isArray(values) then
        for i = 1, #values do
            if (equals and equals(input, values[i])) or (input == values[i]) then
                return true
            end
        end

        return false
    else
        return input == values
    end
end

function anyI(input, values)
    return any(input, values, AreStringsEqualI)
end

function AreStringsEqualI(a, b)
    if a == b then
        -- We have a direct match
        return true
    elseif a == nil or b == nil then
        -- At this point, only one or the other could possibly be nil
        return false
    else
        -- Perform the cast-insensitive comparison
        return a:lower() == b:lower()
    end
end

--------------------------------------------------------------------------------------
-- Build a command that can be executed against this addon
function buildSelfCommand(commandLine, excludeTrailingSemiColon)
    return ADDON_COMMAND .. ' ' .. (commandLine or '') .. (excludeTrailingSemiColon and '' or ';')
end

--------------------------------------------------------------------------------------
-- Sends a command to the hotkey addon
function sendSelfCommand(commandLine)
    windower.send_command(buildSelfCommand(commandLine))
end