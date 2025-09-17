local function do_activate(args)
    local player = windower.ffxi.get_player()

    if player == nil or player.status ~= 0 then
        writeMessage(text_warning('Activation can only proceed when idle.'))
        return
    end

    local t = windower.ffxi.get_mob_by_target('t')
    local id = arrayIndexOfStrI(args, '-id')
    local index = arrayIndexOfStrI(args, '-index')
    
    if id then
        id = id and tonumber(args[id + 1])
        if not id then
            writeMessage(text_warning('A valid activation id was not specified.'))
            return
        end

        t = windower.ffxi.get_mob_by_id(id)
    elseif index then
        index = index and tonumber(args[index + 1])
        if not index then
            writeMessage(text_warning('A valid activation index was not specified.'))
            return
        end

        t = windower.ffxi.get_mob_by_id(index)
    end

    if
        t == nil
        or not t.valid_target
        or t.distance >= (6 * 6)                        -- Distance must be less than 6 for activation to proceed
        or (t.spawn_type ~= 2 and t.spawn_type ~= 34)   -- 2 is npcs, 32 is certain dorways/levers/portal points
    then
        --writeMessage(text_warning('A valid activation target could not be determined.'))
        return
    end

    writeMessage('Activating target: %s [%s/%s]':format(
        text_green(t.name),
        text_number(t.id),
        text_number('%03X':format(t.index))
    ))

    local start = os.clock()

    -- NOTE: The game seems to lose packets in certain cases, particularly
    -- in high lag environments. This is particularly exacerbated by you
    -- yourself having a large number of alts meant to receive the packets.
    -- The more alts you have, the  more likely it is that any one of them
    -- will have the packet get lost.
    --
    -- The following loop ensures that we send packets and give them some time
    -- to actualy be received before we give up. 
    --
    while (os.clock() - start) < 5 do
        local packet = packets.new('outgoing', 0x01A, {
            ["Target"] = t.id,
            ["Target Index"] = t.index,
            ["Category"] = 0,
            ["Param"] = 0,
            ["_unknown1"] = 0
        })

        packets.inject(packet)
        coroutine.sleep(1.0)
        if globals.latest_npc_activation > start then
            -- An activation packet was received after we started, we're done activating
            return true
        end

        local player = windower.ffxi.get_player()
        if player.status == 4 then
            -- Switched to event status, we're done activating
            return true
        end
    end

    writeMessage(text_warning('Warning: Activation timed out for %s [%s/%s]':format(
        text_green(t.name, Colors.warning),
        text_number(t.id, Colors.warning),
        text_number('%03X':format(t.index, Colors.warning))
    )))
end

local function do_activateall(args)
    local t = windower.ffxi.get_mob_by_target('t')
    if
        t == nil
        or not t.valid_target
        or (t.spawn_type ~= 2 and t.spawn_type ~= 34)   -- 2 is npcs, 32 is certain dorways/levers/portal points
    then
        writeMessage(text_warning('A valid NPC or doorway/transition point must be targeted for activation to proceed.'))
        return
    end

    windower.send_command('send @all hk targeting activate -id %s':format(t.id))

end

function command_targeting(command, args)
    command = (command or ''):lower()
    args = args or {}

    if command == 'activate' or command == 'a' then
        do_activate(args)
    elseif command == 'activateall' or command == 'aa' then
        do_activateall(args)
    end
end