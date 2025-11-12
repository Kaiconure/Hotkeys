-------------------------------------------------------------------------------
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

-- Set up the other indexed gear slot mappings
local GearSlotsById = {}
local GearSlotsBySlot = {}
local GearSlotsByField = {}
for _, slotInfo in ipairs(OrderedGearSlots) do
    GearSlotsById[slotInfo.id] = slotInfo
    GearSlotsBySlot[slotInfo.slot] = slotInfo
    GearSlotsByField[slotInfo.field] = slotInfo
end

-------------------------------------------------------------------------------
-- Maps bag id to field name
local BagsById = 
{
    [0] = { field = "inventory", id = 0 },
    [8] = { field = "wardrobe", id = 8 },
    [10] = { field = "wardrobe2", id = 10 },
    [11] = { field = "wardrobe3", id = 11 },
    [12] = { field = "wardrobe4", id = 12 },
    [13] = { field = "wardrobe5", id = 13 },
    [14] = { field = "wardrobe6", id = 14 },
    [15] = { field = "wardrobe7", id = 15 },
    [16] = { field = "wardrobe8", id = 16 },
}

-- Set up a reverse lookup of bag field names to bag info
local BagIdsByField = {}
for _, bagInfo in ipairs(BagsById) do
    BagIdsByField[bagInfo.field] = bagInfo
end

-------------------------------------------------------------------------------
-- Some relevant item statuses
local ITEM_STATUS_NONE          = 0
local ITEM_STATUS_EQUIPPED      = 5
local ITEM_STATUS_LS_EQUIPPED   = 19
local ITEM_STATUS_BAZAAR        = 25

-------------------------------------------------------------------------------
-- Examine any augments on the item extdata value, stripping any
-- invalid/empty values. Returns true only if there were valid
-- augments found in the extdata entry.
local function sanitizeAugments(ext)
    if
        ext and
        type(ext) == 'table' and
        type(ext.augments) == 'table' and
        #ext.augments > 0
    then
        while true do
            local found = false
            for i, augment in ipairs(ext.augments) do
                
                if augment == 'none' or augment == nil then
                    found = true
                    table.remove(ext.augments, i)
                    break
                end
            end

            if not found then
                break 
            end
        end

        -- If we still have augments left, return true
        if #ext.augments > 0 then
            return true
        end
    end
end

-------------------------------------------------------------------------------
-- Look through a list of required augment names, and verify that each
-- of those appears in a list of available augments for a given item.
-- Returns true only if all required augments are available.
local function hasRequiredAugments(allRequired, allAvailable)
    for i, required in ipairs(allRequired) do
        local hasMatch = false

        for j, available in ipairs(allAvailable) do
            if required == available then
                hasMatch = true
                break
            end
        end

        if not hasMatch then
            return false
        end
    end

    return true
end

-------------------------------------------------------------------------------
-- Find an equipable item based on a gear set item info entry
local function findEquipableItem(itemInfo, all_items)
    -- Cannot proceed if we don't have an item to look for
    if not itemInfo or not itemInfo.globalId then
        return
    end

    -- We will get the live item list if a pre-cached value was not provided in the call
    all_items = all_items or windower.ffxi.get_items()

    -- Iterate over all equipable bags
    for bagId, bagInfo in pairs(BagsById) do
        -- Get the current bag
        local bag = all_items[bagInfo.field]

        -- Note: The bag keys are the local id's, starting from 1, of all items in the bag.
        -- There are also the scalar keys:
        --  - max:      The total number of slots available in the bag
        --  - count:    The number of occupied slots in the bag
        --  - enabled:  A flag indicating whether the bag is usable (locked wardrobes, etc)

        if bag and bag.enabled then
            for _, bagItem in pairs(bag) do
                -- If the current bag item matches the global id of the item we're looking for
                if
                    type(bagItem) == 'table' and
                    bagItem.status == ITEM_STATUS_NONE and 
                    bagItem.id == itemInfo.globalId
                then
                    local check_augments = type(itemInfo.augments) == 'table' and #itemInfo.augments > 0
                    local has_all_augments = false
                    
                    if check_augments then                
                        local ext = check_augments and extdata.decode(bagItem)
                        if sanitizeAugments(ext) then
                            if hasRequiredAugments(itemInfo.augments, ext.augments) then
                                has_all_augments = true
                            end
                        end
                    end

                    if not check_augments or has_all_augments then
                        -- We've found our match, let's create the candidate result
                        local candidate = {
                            bagId = bagId,
                            localId = bagItem.slot,
                            globalId = bagItem.id
                        }

                        return candidate
                    end 
                end
            end
        end
    end
end

-------------------------------------------------------------------------------
-- Find all equipped gear. If a specific slot is given, only the item in that
-- slot will be returned (or nil if nothing is equipped to that slot).
local function getEquippedGear(slot)
    local all_items = windower.ffxi.get_items()
    local result = {}

    local slots = OrderedGearSlots
    if slot then
        if type(slot) == 'number' and GearSlotsById[slot] then
            slots = { GearSlotsById[slot] }
        elseif type(slot) == 'string' then
            if GearSlotsBySlot[slot] then
                slots = { GearSlotsBySlot[slot] }
            elseif GearSlotsByField[slot] then
                slots = { GearSlotsByField[slot] }
            end
        end
    end

    for i, slotInfo in ipairs(slots) do
        local resultIndex = #result + 1

        result[resultIndex] = {
            slot = slotInfo.slot,
            slotId = slotInfo.id,
            localId = nil,
            globalId = nil,
            bagId = nil,
            name = nil,
            augments = nil
        }

        local localId = all_items.equipment[slotInfo.field]
        if localId ~= nil and type(localId) == 'number' and localId > 0 then
            
            -- There's an undocumented bag id indicator related to each equipable field name, which tells
            -- us where an equipped item is actually located (inventory, wardrobe2, etc). We'll need to
            -- use this to identify the specific items to equip.
            local bagId = all_items.equipment[slotInfo.field .. '_bag']

            if bagId ~= nil and type(bagId) == 'number' and bagId >= 0 then
                local bagInfo = BagsById[bagId]

                if bagInfo then
                    local bagItem = all_items[bagInfo.field][localId]
                    if bagItem then
                        local item = resources.items[bagItem.id]
                        local ext = extdata.decode(bagItem)

                        -- print('extdata: %s':format(ext and 'yes' or 'no'))
                        -- print('# augments: %d':format(ext and ext.augments and #ext.augments or -1))

                        augments = sanitizeAugments(ext) and ext.augments or {}

                        --print('  # augments: %d':format(ext and ext.augments and #ext.augments or -1))

                        if item ~= nil then
                            result[resultIndex].localId = localId
                            result[resultIndex].globalId = bagItem.id
                            result[resultIndex].bagId = bagId
                            result[resultIndex].name = item.name or nil
                            result[resultIndex].augments = augments
                        end
                    end
                end
            end
        end
    end

    -- If we're only looking at a specific slot, just return the one and only result
    if #slots == 1 then
        return result and result[1]
    end

    return result
end

local function removeGearSet(args)
    local setName = args[1]    
    if setName == nil or setName == 'force' then
        writeError('No removal gear set name was specified.')
        return
    end

    local force = any('force', args)

    local player = windower.ffxi.get_player()
    local mainJob = player.main_job
    local setFullName = mainJob .. '/' .. setName

	settings.gear = settings.gear or {}
    settings.gear.sets = settings.gear.sets or {}

    if not settings.gear.sets[mainJob] or not settings.gear.sets[mainJob][setName] then
        writeError('The gear set %s does not exist.':format(
            text_gearset(setFullName)
        ))
        return
    end

    if not force then
        writeError('You must add \'force\' after the gear set name for removal to proceed.')
        return
    end

    settings.gear.sets[mainJob][setName] = nil

    saveSettings()

    writeMessage('Removed gear set %s!':format(
        text_gearset(setFullName)
    ))
end

local function listGear(args)
    local equippedGear = getEquippedGear()

    writeMessage('Currently equipped gear:')

    for i = 1, #equippedGear do
        local current = equippedGear[i]

        if current.globalId ~= nil then
            local item = resources.items[current.globalId]
            local itemName = item.name
            writeMessage('  ' .. text_gearslot(current.slot) .. ': ' .. text_item(itemName))
            if type(current.augments) == 'table' and #current.augments > 0 then
                for i, augment in ipairs(current.augments) do
                    writeMessage('    %s: %s':format(
                        text_gearslot('augment #%d':format(i)),
                        text_augment(augment)
                    ))
                end
            end
        else
            writeMessage('  ' .. text_gearslot(current.slot) .. ': ' .. text_inactive('<empty>'))
        end
    end
end

local function saveGear(args)
    local setName = args[1]    
    if setName == nil then
        writeError('No save gear set name was specified.')
        return
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

    local silent = anyI('silent', args)
    local noWeapons = anyI('no-weapons', args) or anyI('save-tp', args)

    local command = ''

    local num_slots_changed = 0

    local all_items = windower.ffxi.get_items()

    --for i = 1, #OrderedGearSlots do
    for i, slotInfo in ipairs(OrderedGearSlots) do
        local itemInfo = gearSet[slotInfo.slot] -- The gear set item for this slot

        if 
            noWeapons and
            (slotInfo.slot == 'main' or slotInfo.slot == 'sub' or slotInfo.slot == 'ranged') 
        then
            -- Skip changes to weapon slots if we've been configured with no weapons
        else
            -- Determine whether a gear item is defined for this slot
            local isDefined = itemInfo and type(itemInfo.globalId) == 'number' and itemInfo.globalId > 0
            
            if isDefined then
                local item = isDefined and resources.items[itemInfo.globalId]
                local canEquipInSlot = item and item.slots and item.slots[slotInfo.id]

                if canEquipInSlot then
                    local result = findEquipableItem(itemInfo, all_items)
                    if result then

                        -- Lastly, we will make sure that we're not doing an unnecessary gear change
                        -- by replacing one item with an exactly equivalent one already in the slot.
                        local itemInSlot = getEquippedGear(slotInfo.slot)
                        if 
                            itemInSlot == nil or 
                            itemInSlot.globalId ~= result.globalId or
                            not hasRequiredAugments(itemInfo.augments, itemInSlot.augments)
                        then
                            windower.ffxi.set_equip(result.localId, slotInfo.id, result.bagId)

                            -- print('%s: Swapped in %d/%s(%d/%d) for %d/%s(%d/%d)':format(
                            --     slotInfo.slot,
                            --     item.id,
                            --     item.name,
                            --     result.bagId,
                            --     result.localId,
                            --     itemInSlot and itemInSlot.globalId or -1,
                            --     itemInSlot and itemInSlot.name or 'nil',
                            --     itemInSlot and itemInSlot.bagId or -1,
                            --     itemInSlot and itemInSlot.localId or -1
                            -- ))

                            num_slots_changed = num_slots_changed + 1

                            -- Clear the status of the item we just removed. This is just to get our item database
                            -- in sync with the equipment actions we are taking while going through the set.
                            if itemInSlot and itemInSlot.bagId and itemInSlot.localId then
                                all_items[BagsById[itemInSlot.bagId].field][itemInSlot.localId].status = ITEM_STATUS_NONE
                            end

                            -- Set the status of the item we just equipped. This is just to get our item database
                            -- in sync with the equipment actions we are taking while going through the set.
                            all_items[BagsById[result.bagId].field][result.localId].status = ITEM_STATUS_EQUIPPED
                        end
                    end
                end
            else
                -- Remove
                windower.ffxi.set_equip(0, slotInfo.id, 0)
            end
        end
    end

    if command ~= '' then
        windower.send_command(command)
    end

    if not silent then
        writeMessage("Successfully equipped %s with %s swapped!":format(
            text_gearset(setFullName),
            pluralize(num_slots_changed, 'gear item', 'gear items')
        ))
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

    if command == 'current' or command == 'list' then
        listGear(args)
    elseif command == 'save' then
        saveGear(args)
    elseif command == 'load' or command == 'equip' then
        equipGear(args)
    elseif command == 'sets' then
        listGearSets(args)
    elseif command == 'remove' or command == 'delete' then
        removeGearSet(args)
    else
        writeMessage('Help: Gear')
        writeMessage('  Manage the gear sets available for your current job.')
        writeMessage('Usage')
        writeMessage(text_command('  hotkeys gear <command> <command-arguments>'))
        writeMessage('Commands')

        writeCommandInfo('current | list',
            'Shows all of your currently equipped gear.')

        writeCommandInfo('remove | delete <gear-set-name> force',
            'Removes/deletes the specified gear set. You MUST add force to the command.'
        )
        
        writeCommandInfo('save <gear-set-name>',
            'Saves currently equipped gear to the specified set name.'
        )

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