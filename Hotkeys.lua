_addon.version = '0.1.4'
_addon.name = 'Hotkeys'
_addon.author = 'LeileDev'
_addon.commands = { 'hotkeys', 'hk' }

resources = require('resources')
files = require('files')
json = require('jsonlua')

require('lib\\helpers')
require('lib\\settings')
require('lib\\logging')
require('lib\\gear')
require('lib\\mounts')
require('lib\\trusts')
require('lib\\triggers')

local BLU_BATTLE_COMMAND    = buildSelfCommand('gear load battle no-weapons')
local BLU_CASTING_COMMAND   = buildSelfCommand('gear load cleave-mab no-weapons')
local BLU_PULLING_COMMAND   = buildSelfCommand('gear load cleave-dt no-weapons')

--------------------------------------------------------------------------------------
-- Write an object to a file as JSON
function writeJsonToFile(fileName, obj)
    local file = files.new(fileName)
    file:write(json.stringify(obj))
end

--------------------------------------------------------------------------------------
-- Saves settings. If no settings are provided, the global will be used.
function saveSettings(settingsToSave)
    local player = windower.ffxi.get_player()
    local fileName = getSettingsFileName(player.name)
    writeJsonToFile(fileName, settingsToSave or settings)
end

function unbindKeys(skipExecute)

    local command = ''
    
    command = command
        .. 'unbind @m;'     -- Windows+M
        .. 'unbind @~m;'    -- Windows+Shift+M
        .. 'unbind @t;'     -- Windows+T
        .. 'unbind @~t;'    -- Windows+Shift+T
        
        .. 'unbind @~1;'    -- Windows+Shift+1
        .. 'unbind @~2;'    -- Windows+Shift+2
        .. 'unbind @~3;'    -- Windows+Shift+3

    if not skipExecute then
        windower.send_command(command)
    end

    return command
end

function bindKeys()
    local commands = {}

    -- Add the binds
    table.insert(commands, 'bind @m '   .. buildSelfCommand('movementspeed'))     -- Windows+M
    table.insert(commands, 'bind @~m '  .. buildSelfCommand('movementspeedall'))  -- Windows+Shift+M
    table.insert(commands, 'bind @t '   .. buildSelfCommand('calltrusts'))        -- Windows+T
    table.insert(commands, 'bind @~t '  .. buildSelfCommand('releasetrusts'))     -- Windows+Shift+T

    table.insert(commands, 'bind @~1 ' .. BLU_BATTLE_COMMAND)       -- Windows+Shift+1: Default gear for BLU (TEMP)
    table.insert(commands, 'bind @~2 ' .. BLU_CASTING_COMMAND)      -- Windows+Shift+2: Magic accuracy bonus gear for BLU (TEMP)
    table.insert(commands, 'bind @~3 ' .. BLU_PULLING_COMMAND)      -- Windows+Shift+3: Pulling gear for BLU (TEMP)

    for i, command in ipairs(commands) do
        windower.send_command(command)
    end
end

---------------------------------------------------------------------
-- Load handler
function load()
    local player = windower.ffxi.get_player()
    if player == nil then
        return
    end

    local fileName = getSettingsFileName(player.name)
    local newSettings = {
        canGearSwap = true,
        language = windower.ffxi.get_info().language,
        preferredMounts = {
            'Raptor'
        },
        trust = {
            current = 'default',
            sets = {
                default = {
                    'Kupipi',
                    'Valaineral',
                }
            }
        }
    }

    file = files.new(fileName)
    if not file:exists() then
        writeMessage('No existing settings found for player [' .. text_player(player.name) .. '], defaults will be loaded')
        --saveSettings(newSettings)
    else
        writeMessage('Loading configured settings for [' .. text_player(player.name) .. ']')
        newSettings = json.parse(file:read())
    end

    settings = newSettings

    -- For now we're forcing the settings language to English
    settings.language = (settings.language or 'en') -- windower.ffxi.get_info().language

    bindKeys()
end

---------------------------------------------------------------------
-- Unload handler
function unload()
    unbindKeys()
end

---------------------------------------------------------------------
-- Reload when the addon is loaded
windower.register_event('load', function()
    --writeJsonToFile('_party.json', windower.ffxi.get_party())

    -- windower.send_command('alias hotkeys lua c hotkeys')
	-- windower.send_command('alias hk lua c hotkeys')

    load()
end)

---------------------------------------------------------------------
-- Clear when the addon is unloaded
windower.register_event('unload', function()
    unload()
end)

---------------------------------------------------------------------
-- Reload when a a command is received
windower.register_event('addon command', function (command, ...)
    local args = {...}
	
	command = (command or ''):lower()

    -- local target = windower.ffxi.get_mob_by_index(windower.ffxi.get_player().target_index)
    -- writeJsonToFile('target.json', target)

    -------------------------------------------------------------------------------------
    -- Bind commands
    if command == 'movementspeed' or command == 'ms' then
        syscommand_movementspeed()
    elseif command == 'movementspeedall' or command == 'msa' then
        syscommand_movementspeedall()
    elseif command == 'calltrusts' or command == 'ct' then
        syscommand_calltrusts()
    elseif command == 'releasetrusts' or command == 'rt' then
        syscommand_releasetrusts()
    end

    local handler = nil

    -------------------------------------------------------------------------------------
    -- Addon commands
    if command == 'reload' then
        handler = load
    elseif command == 'mount' then
        handler = command_mount
    elseif command == 'trust' or command == 'trusts' then
        handler = command_trust
    elseif command == 'gear' then
        handler = command_gear
    end

    if handler ~= nil then
        handler(args[1], { unpack(args, 2, #args) })
    end

    -- local data = windower.ffxi.get_mjob_data()
    -- writeJsonToFile('sample-data\\_mjob_data_blu.json', data)
end)

---------------------------------------------------------------------
-- Reload when a job change occurs
windower.register_event('job change', function ()
	-- load()
end)

---------------------------------------------------------------------
-- Reload when a status change occurs
windower.register_event('status change', function(new_id, previous_id)
    --writeMessage('Changing from ' .. text_number(previous_id) .. ' to ' .. text_number(new_id))
end)

---------------------------------------------------------------------
-- Reload when a zone change occurs
windower.register_event('zone change', function (zone_id)
    --writeMessage('Entering zone: ' .. zone_id)
end)

---------------------------------------------------------------------
-- Reload when a login change occurs
windower.register_event('login', function (name)
	load()
end)

---------------------------------------------------------------------
-- Clear everything on logout
windower.register_event('logout', function (name)
    unbindKeys()
end)

---------------------------------------------------------------------
-- Reload when an action is performed
windower.register_event('action', function(action)
    triggers_onAction(action)
end)
