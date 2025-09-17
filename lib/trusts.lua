--res.spells:type('BlueMagic')
local AllTrustSpells = resources.spells:type('Trust')

---------------------------------------------------------------------
-- Loads the trusts in a set
local function getTrustsInSet(setName)
    local trust = settings.trust
    if trust ~= nil then
        local setName = setName or settings.trust.current

        if setName ~= nil then
            local set = settings.trust.sets[setName]
            if set ~= nil then
                return set
            end
        end
    end
    
    return nil
end

---------------------------------------------------------------------
-- Call out all trusts in the set
local function doCallTrusts(setName)
    setName = setName or settings.trust.current

    local trusts  = getTrustsInSet(setName)

    if trusts == nil then
        writeWarning('No matching trust set is configured. Use %s for available commands.':format(
            text_command('//hk trust', Colors.warning)
        ))
        return
    end

    writeMessage('Attempting to call ' .. text_trustset(setName) .. ' trusts: ')

    local trustCount = #trusts
    if trustCount == 0 then
        writeMessage('No trusts have been configured. Use [//hotkeys trust help] to learn more.')
        return
    end

    local command = ''

    for i, name in pairs(trusts) do
        writeMessage('  ' .. i .. ': ' .. text_trust(name))
        command = command ..
            'input /ma "' .. name .. '";' ..
            'wait 6;'
    end

    windower.send_command(command);
end

---------------------------------------------------------------------
-- Release all active trusts
function doReleaseTrusts()
    writeMessage('Releasing all trusts!')
    windower.send_command('input /returnfaith all;');
end

---------------------------------------------------------------------
-- Gets the spells associated with all trusts in the party
local function getSpellsForTrustsFromParty(party)
    local spells = {}

    if party ~= nil then
        for i = 1, 5 do
            local member = party['p' .. i]
            if member ~= nil then
                local name = member.name
                local modelId = member.mob and member.mob.models and member.mob.models[1]
                
                if modelId ~= nil then
                    local modelMatches = AllTrustSpells:model(modelId)
                    if modelMatches ~= nil and type(modelMatches) == 'table' then
                        for i, spell in pairs(modelMatches) do
                            if spell.party_name == name then
                                spells[#spells + 1] = spell
                            end
                        end
                    end
                end
            end
        end
    end

    return spells
end

---------------------------------------------------------------------
-- Identify the current trusts 
local function saveCurrentTrusts(setName)
    local party = windower.ffxi.get_party()

    setName = setName or settings.trust.current or 'default'

    local trustSpells = getSpellsForTrustsFromParty(party)
    local numTrusts = #trustSpells
    if numTrusts > 0 then
        writeMessage('Saving ' .. pluralize(numTrusts, 'trust', 'trusts') .. ' to ' .. text_trustset(setName))

        local trusts = {}
        for i, spell in pairs(trustSpells) do
            if spell ~= nil then
                local spellName = spell.name
                trusts[#trusts + 1] = spellName
                writeMessage('  ' .. i .. ': ' .. text_trust(spellName))
            end
        end

        settings.trust.sets[setName] = trusts
        settings.trust.current = setName
        saveSettings()
    else
        writeMessage('No trusts were found in your party!')
    end
end

---------------------------------------------------------------------
-- System: calltrusts
function syscommand_calltrusts()
    doCallTrusts()
end

---------------------------------------------------------------------
-- System: releasetrusts
function syscommand_releasetrusts()
    doReleaseTrusts()
end

---------------------------------------------------------------------
-- Command: trust
function command_trust(command, args)
    command = (command or ''):lower()

    if command == 'call' then
        doCallTrusts(args[1])
    elseif command == 'release' or command == 'return' then
        doReleaseTrusts()
    elseif command == 'save' then
        saveCurrentTrusts(args[1])
    elseif command == 'set' then
        local set = args[1]

        if set == nil then
            --writeWarning('A set name must be provided')
            windower.send_command('hk trust list')
            return
        end

        settings.trust.current = set
        if settings.trust.sets[set] == nil then
            settings.trust.sets[set] = {}
        end

        writeMessage('Trust set ' .. text_trustset(set) .. ' is now active.')
        saveSettings()

        windower.send_command('hk trust list')
    elseif command == 'list' then
        local set = args[1] or settings.trust.current        
        local trusts = getTrustsInSet(set)

        if trusts == nil then
            writeWarning('  There no set named ' .. text_trustset(set))
        elseif #trusts == 0 then
            writeWarning('  The set ' .. text_trustset(set) .. ' is empty')
        else
            writeMessage('There are ' .. pluralize(#trusts, 'trust', 'trusts') .. ' in set ' .. text_trustset(set) .. ': ')
            for i, trust in pairs(trusts) do
                writeMessage('  ' .. i .. ': ' .. text_trust(trust))
            end
        end
    elseif command == 'sets' then
        writeMessage('Your trust sets: ')
        for set, trusts in pairs(settings.trust.sets) do
            local count = #trusts
            writeMessage('  - ' .. text_trustset(set) .. ': ' .. pluralize(count, 'trust', 'trusts'))
        end
    elseif command == 'delete' then
        local set = args[1]
        if type(set) ~= 'string' then
            writeWarning('You must specify the name of the set to delete.')
            return
        end

        if not settings.trust.sets[set] then
            writeWarning('Could not find trust set: %s':format(text_trustset(set, Colors.warning)))
            return
        end

        if set == 'default' then
            writeWarning('The default trust set cannot be deleted.')
            return
        end

        settings.trust.sets[set] = nil
        if settings.trust.current == set then
            settings.trust.current = 'default'
        end
        
        saveSettings()

        writeMessage('Successfully deleted trust set: %s':format(text_trustset(set)))

    else -- if command == 'help' then
        writeMessage('Help: Trust')
        writeMessage('  Description: Manage named sets of trusts to be called on demand.')
        writeMessage('Usage')
        writeMessage(text_command('  hotkeys trust <command> <command-arguments>'))
        writeMessage('Commands')

        writeCommandInfo('call [<set-name>]',
            'Calls all trusts in the current set, or the specified set.')
        writeCommandInfo('release | return',
            'Releases all summoned trusts.')
        writeCommandInfo('set <set-name>',
            'Switch to the specified set, creating an empty set if necessary.')
        writeCommandInfo('save [<set-name>]',
            'Saves active trusts in your party to the current set, or to the',
            'set that is specified. A new set will be created if necessary.')
        writeCommandInfo('list [<set-name>]',
            'Lists all trusts in the current set, or in the specified set.')
        writeCommandInfo('delete <set-name>',
            'Deletes the trust set with the specified name.')
        writeCommandInfo('sets',
            'Lists all configured sets.')
    end
end