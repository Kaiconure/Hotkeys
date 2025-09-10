--------------------------------------------------------------------------------------
-- BEGIN subcommand handlers
local function listMounts()
    writeMessage('Preferred Mounts: ')
    for i, name in pairs(settings.preferredMounts) do
        writeMessage('  ' .. i .. ': ' .. text_mount(name))
    end
end

local function addMount(mountName)
    if mountName == nil then
        listMounts()
        return
    end

    local existingIndex = arrayIndexOfStrI(settings.preferredMounts, mountName)
    if existingIndex ~= nil then
        writeMessage('The mount ' .. text_mount(mountName) .. ' is already included!')
        return
    end

    settings.preferredMounts[#settings.preferredMounts + 1] = mountName
    saveSettings()

    listMounts()
end

local function removeMount(mountName)
    if mountName == nil then
        listMounts()
        return
    end

    local existingIndex = arrayIndexOfStrI(settings.preferredMounts, mountName)
    if existingIndex ~= nil then
        table.remove(settings.preferredMounts, existingIndex)
    end

    saveSettings()
    listMounts()
end

-- END subcommand handlers
--------------------------------------------------------------------------------------

--------------------------------------------------------------------------------------
-- Determine if a zone allows mounts
function isMountableZone(zone)
    -- Note: Many of the Adoulin areas don't have a proper mount flag set
    return zone.can_mount == true
        or zone.search == 'Ceizak'
        or zone.search == 'Yahse'
        or zone.search == 'Hennetiel'
        or zone.search == 'Yorcia'
        or zone.search == 'Yorcia_U'
        or zone.search == 'Morimar'
        or zone.search == 'Marjami'
        or zone.search == 'Kamihr'
        or zone.search == 'RoMaeve'
end

local syscommand_movementspeedall_executed = false
---------------------------------------------------------------------
-- Movement speed "all" handler
function syscommand_movementspeedall()
    if syscommand_movementspeedall_executed then
        windower.send_command('send @all //hk movementspeed')
    end

    syscommand_movementspeedall_executed = true
end

---------------------------------------------------------------------
-- Movement speed handler
function syscommand_movementspeed()
    local player = windower.ffxi.get_player()
	local playerStatus = player.status
    local main_job = player.main_job
	local sub_job = player.sub_job

    local zoneId = windower.ffxi.get_info().zone or 0
    local zone = resources.zones[zoneId]
    local zoneCanMount = isMountableZone(zone)

    if zoneCanMount then
        local isMounted = (playerStatus == 85 or playerStatus == 5) -- 85 is mount, 5 is chocobo
        

        if isMounted then
            writeMessage('Dismounting!')
            windower.send_command('input /dismount;')
        else
            local mountCount = #settings.preferredMounts
            local mountIndex = math.random(mountCount)
            local mount = settings.preferredMounts[mountIndex]

            writeMessage('Mounting ' .. text_mount(mount) .. '!')
            windower.send_command('input /mount "' .. mount .. '";')
        end
    else
        local speedCommand = ''

        if isJobLevel(player, 'DNC', 70) then
            speedCommand = 'input /ja "Chocobo Jig II" <me>;';
        elseif isJobLevel(player, 'DNC', 55) then
            speedCommand = 'input /ja "Chocobo Jig" <me>;';
        elseif isJobLevel(player, 'BRD', 73) then
            speedCommand = 'input /ma "Chocobo Mazurka" <me>;';
        elseif isJobLevel(player, 'BRD', 37) then
            speedCommand = 'input /ma "Raptor Mazurka" <me>;';
        elseif isJobLevel(player, 'THF', 25) then
            speedCommand = 'input /ja "Flee" <me>;';
        end

        if speedCommand ~= '' then
            writeMessage('Mounts unavailable, using movement speed job skill instead!')
            windower.send_command(speedCommand)
        else
            writeError('No movement speed options are available.')
        end
    end
end

---------------------------------------------------------------------
-- Mount management helper
function command_mount(command, args)
    command = (command or ''):lower()

    if command == 'add' then
        addMount(args[1])
    elseif command == 'remove' then
        removeMount(args[1])
    elseif command == 'list' then
        listMounts()
    else
        writeMessage('Help: Mount')
        writeMessage('  Manage the mount that is used via the movement speed hotkey.')
        writeMessage('Usage')
        writeMessage(text_command('  hotkeys mount <command> <command-arguments>'))       
        writeMessage('Commands')

        writeCommandInfo('add <mount-name>',
            'Adds a new entry to your list of preferred mounts.')
        writeCommandInfo('remove <mount-name>',
            'Removes an entry from your list of preferred mounts.')        
        writeCommandInfo('list',
            'Lists your preferred mounts.')
    end
end