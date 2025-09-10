local CATEGORY_SPELL_START          = 8     -- action.category=8, action.param = 24931
local CATEGORY_SPELL_INTERRUPT      = 8     -- action.category=8, action.param = 28787
local CATEGORY_SPELL_END            = 4

local PARAM_STARTED                 = 24931 -- Normal start
local PARAM_INTERRUPTED             = 28787 -- Interrupted before completion

local SPAWN_TYPE_PLAYER             = 1     -- It's a player
local SPAWN_TYPE_SELF               = 13    -- You yourself
local SPAWN_TYPE_TRUST              = 14    -- It's a trust
local SPAWN_TYPE_MOB                = 16    -- It's a mob (enemy, monster, etc)

---------------------------------------------------------------------
--
local function translateGearSetName(triggerGearSet, defaultGearSet)
    if triggerGearSet then
        if triggerGearSet == ':default' then
            return defaultGearSet
        end

        return triggerGearSet
    end

    return nil
end

local function getMatchingTarget(action, targetType)
    -- No match if we don't have any targets at all
    if not action or action.target_count < 1 then
        return nil
    end

    for i = 1, action.target_count do
        local target = action.targets[i]
        local mob = windower.ffxi.get_mob_by_id(target.id)
        
        if mob then
            -- Return the first target if we're looking for anything
            if (targetType == nil or targetType == '*' or targetType == 'any') then
                return mob
            end

            if mob then
                local spawnType = mob.spawn_type

                if 
                    (targetType == 'party' and (mob.in_party or mob.in_alliance)) or        -- Party or alliance member
                    (targetType == 'mob' and spawnType == SPAWN_TYPE_MOB) or                -- An actual mob (monster, enemy)
                    (targetType == 'player' and spawnType == SPAWN_TYPE_PLAYER) or          -- Any player
                    (targetType == 'trust' and spawnType == SPAWN_TYPE_TRUST) or            -- A summoned trust
                    ((targetType == 'self' or targetType == 'me')
                         and mob.id == windower.ffxi.get_player().id)                       -- Yourself
                then
                    return mob
                end
            end
        end
    end

    return nil
end

local function executeTriggerCommands(commands)
    if isArray(commands) then
        --local fullCommands = ''
        for i, command in ipairs(commands) do
            windower.send_command(command)
            --fullCommands = fullCommands .. 
            --    command ..
            --    ';'
        end

        --windower.send_command(fullCommands)
    end
end

local spellTriggerState = {
    canGearSwap = false,
    initialMatch = nil
}

local function triggers_SpellCastBySelf(action)
    -- writeJsonToFile('.\\sample-data\\action.spell--' .. action.category .. '-' .. action.param .. '.json', action)
    -- local targetId = action.targets and action.targets[1] and action.targets[1].id
    -- if targetId then
    --     writeJsonToFile('.\\sample-data\\target.' .. targetId .. '.json', windower.ffxi.get_mob_by_id(targetId))
    -- end

    local isSpellStart              = action.category == CATEGORY_SPELL_START and action.param == PARAM_STARTED
    local isSpellInterrupted        = action.category == CATEGORY_SPELL_START and action.param == PARAM_INTERRUPTED
    local isSpellSuccessful         = action.category == CATEGORY_SPELL_END
    local isSpellCastingComplete    = isSpellInterrupted or isSpellSuccessful
    
    local spellId = (isSpellSuccessful and action.param) or ((action.targets[1] and action.targets[1].actions[1] and action.targets[1].actions[1].param) or 0)
    local spell = resources.spells[spellId]

    -- The spell could not be found
    if spell == nil then
        return
    end

    local spellName = spell.name

    local player = windower.ffxi.get_player()
    local mainJob = player.main_job
    local playerId = player.id
    local actorId = action.actor_id
    local isSelf = actorId == playerId
    local actor = windower.ffxi.get_mob_by_id(actorId)

    -- No triggers configured for this job
    local jobTriggers = settings.triggers and settings.triggers[mainJob]
    if not jobTriggers then
        return
    end

    -- No triggers configured for this spell type
    local typeTriggers = jobTriggers.spells and jobTriggers.spells[spell.type]
    if not typeTriggers then
        return
    end

    if isSpellInterrupted then
        writeJsonToFile('sample-data\\spell-interrupt-action.json', action)
    end

    -- Find a match
    local match = nil
    if not isSpellCastingComplete then
        for i = 1, #typeTriggers do
            local trigger = typeTriggers[i]

            local hasNameMatch = (trigger.name == nil or trigger.name == "*" or trigger.name == 'any') or string.find(spellName, trigger.name)
            local matchingTarget = getMatchingTarget(action, trigger.target)

            --writeMessage('has name match: ' .. tostring(hasNameMatch))
            --writeMessage('has target match: ' .. tostring(matchingTarget and 'yes' or 'no'))

            -- If we found a match, handle it and we're done -- first match only!
            if hasNameMatch and matchingTarget ~= nil then
                match = {
                    trigger = trigger,
                    target = matchingTarget
                }

                break
            end
        end
    else
        -- If we're completing a spell (interruption or success), we'll for the original
        -- match that got us here as our post-action trigger.
        match = spellTriggerState.initialMatch
    end

    --writeMessage('Match: ' .. (match and 'yes' or 'no'))

    -- Handle the match (if any)
    if match then
        if isSpellStart then    -- Casting starts
            spellTriggerState.canGearSwap = settings.canGearSwap and spell.cast_time > 0.9

            if spellTriggerState.canGearSwap then
                local gearSet = spellTriggerState.canGearSwap
                    and match.trigger.pre
                    and translateGearSetName(match.trigger.pre.gear, jobTriggers.defaults.gear)

                if gearSet then
                    sendSelfCommand('gear load ' .. gearSet)
                end

                executeTriggerCommands(match.trigger.pre and match.trigger.pre.commands)
            end

            -- Store the match that triggered this action so we can do the proper post-action trigger later
            spellTriggerState.initialMatch = match

        elseif isSpellCastingComplete then  -- Casting ends (success or interrupted)

            if spellTriggerState.canGearSwap then
                local gearSet = spellTriggerState.canGearSwap
                    and match.trigger.post
                    and translateGearSetName(match.trigger.post.gear, jobTriggers.defaults.gear)

                if gearSet then
                    sendSelfCommand('gear load ' .. gearSet)
                end
            end

            spellTriggerState.canGearSwap = false
            spellTriggerState.initialMatch = nil

            executeTriggerCommands(match.trigger.post and match.trigger.post.commands)
        end
    end
end

function triggers_onAction(action)
    local player = windower.ffxi.get_player()
    local playerId = player.id
    local actorId = action.actor_id
    local isActorSelf = actorId == playerId
    local isSpell = any(action.category, {CATEGORY_SPELL_START, CATEGORY_SPELL_INTERRUPT, CATEGORY_SPELL_END}) 

    -- For now, we only handle self-initiated triggers
    if isActorSelf then
        if isSpell then
            triggers_SpellCastBySelf(action)
        end
    end
end