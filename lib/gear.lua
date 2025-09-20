---------------------------------------------------------------------
-- Slot is the name of the slot in-game; field is the windower
-- equipment property field
local OrderedGearSlots = 
{
	{slot = 'main', field = 'main', id = 0},
	{slot = 'range', field = 'range', id = 2},
	{slot = 'head', field = 'head', id = 4},
	{slot = 'neck', field = 'neck', id = 9},
	{slot = 'body', field = 'body', id = 5},
	{slot = 'hands', field = 'hands', id = 6},
	{slot = 'back', field = 'back', id = 15},
	{slot = 'waist', field = 'waist', id = 10},
	{slot = 'legs', field = 'legs', id = 7},
	{slot = 'feet', field = 'feet', id = 8},
    {slot = 'ear1', field = 'left_ear', id = 11},
	{slot = 'ear2', field = 'right_ear', id = 12},
    {slot = 'ring1', field = 'left_ring', id = 13},
	{slot = 'ring2', field = 'right_ring', id = 14},
	{slot = 'sub', field = 'sub', id = 1},
	{slot = 'ammo', field = 'ammo', id = 3},
}

---------------------------------------------------------------------
-- Maps bag id to field name
local BagsById = 
{
    [0] = { field = "inventory" },
    [8] = { field = "wardrobe" },
    [10] = { field = "wardrobe2" },
    [11] = { field = "wardrobe3" },
    [12] = { field = "wardrobe4" },
    [13] = { field = "wardrobe5" },
    [14] = { field = "wardrobe6" },
    [15] = { field = "wardrobe7" },
    [16] = { field = "wardrobe8" },
}

local function getEquippedGear()
    local items = windower.ffxi.get_items()

    local result = {}

    for i = 1, #OrderedGearSlots do
        local si = OrderedGearSlots[i]  -- slot info
        local resultIndex = #result + 1

        result[resultIndex] = {
            slot = si.slot,
            slotId = si.id,
            localId = nil,
            globalId = nil,
            bagId = nil,
            name = nil,
        }

        local localId = items.equipment[si.field]
        if localId ~= nil and type(localId) == 'number' and localId > 0 then
            
            -- There's an undocumented bag id indicator related to each equipable field name, which tells
            -- us where an equipped item is actually located (inventory, wardrobe2, etc). We'll need to
            -- use this to identify the specific items to equip.
            local bagId = items.equipment[si.field .. '_bag']

            if bagId ~= nil and type(bagId) == 'number' and bagId >= 0 then
                local bagInfo = BagsById[bagId]

                if bagInfo then
                    local bagItem = items[bagInfo.field][localId]
                    local item = bagItem and resources.items[bagItem.id]

                    if item ~= nil then
                        result[resultIndex].localId = localId
                        result[resultIndex].globalId = bagItem.id
                        result[resultIndex].bagId = bagId
                        result[resultIndex].name = item.name or nil
                    end
                end
            end
        end
    end

    return result
end

local function listGear(args)
    local equippedGear = getEquippedGear()

    for i = 1, #equippedGear do
        local current = equippedGear[i]

        if current.globalId ~= nil then
            local item = resources.items[current.globalId]
            local itemName = item.name
            writeMessage('  ' .. text_gearslot(current.slot) .. ': ' .. text_item(itemName))
        else
            writeMessage('  ' .. text_gearslot(current.slot) .. ': ' .. text_inactive('<empty>'))
        end
    end
end

local function saveGear(args)
    local setName = args[1]    
    if setName == nil then
        writeError('No save gear set name was specified.')
    end

    local overwrite = true --any('overwrite', args)    -- Flag indicating whether existing gear sets can be overwritten

    local player = windower.ffxi.get_player()
    local mainJob = player.main_job
    local setFullName = mainJob .. '/' .. setName

	settings.gear = settings.gear or {}
    settings.gear.sets = settings.gear.sets or {}
    settings.gear.sets[mainJob] = settings.gear.sets[mainJob] or {}

    if not overwrite and settings.gear.sets[mainJob][setName] ~= nil then
        writeWarning('The gear set ' .. text_gearset(setFullName, Colors.warning) .. ' already exists. Use the [overwrite] argument if you want to save over it.')
        return
    end

    local gear = getEquippedGear()
    local gearSet = {}

    for i = 1, #gear do
        local gi = gear[i]
        gearSet[gi.slot] = gi
    end

    settings.gear.sets[mainJob][setName] = gearSet

    saveSettings()

    writeMessage('Saved gear set ' .. text_gearset(setFullName) .. '!')
end

local function equipGear(args)
    local setName = args[1]
    if setName == nil then
        writeError('No load gear set name was specified.')
        return
    end

    local player = windower.ffxi.get_player()
    local mainJob = player.main_job
    local setFullName = mainJob .. '/' .. setName

    local gearSet = settings.gear and
        settings.gear.sets and
        settings.gear.sets[mainJob] and
        settings.gear.sets[mainJob][setName]

    if gearSet == nil then
        writeError('A gear set named ' .. text_gearset(setName, Colors.error) .. ' was not found for ' .. text_job(mainJob) .. '.')
        return
    end

    local strict = anyI('strict', args)
    local silent = anyI('silent', args)
    local noWeapons = anyI('no-weapons', args) or anyI('save-tp', args)

    local command = ''

    for i = 1, #OrderedGearSlots do
        local slotInfo = OrderedGearSlots[i]
        local slot = gearSet[slotInfo.slot]

        if noWeapons and (slot.slot == 'main' or slot.slot == 'sub' or slot.slot == 'ranged') then
            -- Skip changes to weapon slots if we've been configured with no weapons
        else
            local isEquipped = slot.bagId ~= nil and slot.localId ~= nil

            if isEquipped then
                if strict then
                    -- With strict on, we will use the exact item id to perform the equipment change.
                    -- This shouldn't normally be used, as it is susceptible to problems if gear
                    -- is moved from one inventory to another, etc.

                    -- Local/Inventory ID; Slot ID (head, ammo, etc); Bag ID (Inventory, Wardrobe2, etc)
                    windower.ffxi.set_equip(slot.localId, slot.slotId, slot.bagId)
                else
                    local itemName = resources.items[slot.globalId].name or ''

                    -- For the sub weapon slot, we need to give the game a little bit of time
                    -- to register the change. Without this, going from a two-handed to
                    -- dual one-handed weapons could fail to equip the off hand.
                    if slot.slot == 'sub' then
                        command = command .. 'wait 1;'
                    end

                    -- Add double-quotes around the item name, if it was found
                    itemName = (itemName and '"' .. itemName .. '"') or ''

                    command = command ..
                        'input /equip ' .. slot.slot .. ' ' .. itemName .. ';'
                end

                --writeMessage('swapping ' .. slot.slot)
            else
                -- We can use the direct set_equip method on unequips, because the fickleness
                -- around local id's does not exist when simply removing gear
                windower.ffxi.set_equip(0, slot.slotId, 0)
            end
        end
    end

    if command ~= '' then
        windower.send_command(command)
    end

    if not silent then
        writeMessage('Gear set ' .. text_gearset(setName) .. ' equipped!')
    end
end

function listGearSets(args)
    local player = windower.ffxi.get_player()
    local mainJob = player.main_job

    local gearSets = settings.gear and
        settings.gear.sets and
        settings.gear.sets[mainJob]
    local hasGearSets = false

    writeMessage('Gear sets configured for ' .. text_job(mainJob) .. ': ')

    if gearSets ~= nil then
        for name, set in pairs(gearSets) do
            hasGearSets = true
            writeMessage('  ' .. text_gearset(name))
        end
    end

    if not hasGearSets then
        writeMessage('  No gear sets have been saved for ' .. text_job(mainJob) .. ' yet.')
    end
end


function command_gear(command, args)
    command = (command or ''):lower()

    if command == 'current' then
        listGear(args)
    elseif command == 'save' then
        saveGear(args)
    elseif command == 'load' or command == 'equip' then
        equipGear(args)
    elseif command == 'sets' then
        listGearSets(args)
    else
        writeMessage('Help: Gear')
        writeMessage('  Manage the gear sets available for your current job.')
        writeMessage('Usage')
        writeMessage(text_command('  hotkeys gear <command> <command-arguments>'))
        writeMessage('Commands')

        writeCommandInfo('current',
            'Shows all of your currently equipped gear.')
        
        writeCommandInfo('save <gear-set-name> [overwrite]',
            'Saves currently equipped gear to the specified set name.',
            '',
            'The overwrite flag indicates whether existing sets should',
            'be overwritten.')

        writeCommandInfo('load <gear-set-name> [strict] [no-weapons]',
            'Equips the specified gear set.',
            '',
            'The strict flag indicates that EXACT item/location matches',
            'are required. This may be necessary if you have more than',
            'one of the same item but with different augments.',
            '',
            'The no-weapons flag means that weapon swaps should be skipped.')

        writeCommandInfo('equip',
            'Identical to the "load" command.')

        writeCommandInfo('sets',
            'Lists all saved gear sets for your current job.')
    end
end

-- windower.ffxi.set_equip(inv_id, slot, bag)
--  inv_id integer - ID in the inventory
--  slot integer - Slot ID to equip to
--  bag integer - Inventory bag to equip from