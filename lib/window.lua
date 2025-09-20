local BINDS_TO_KEY_NAME = 
{
    ['^'] = 'Ctrl',
    ['!'] = 'Alt',
    ['@'] = 'Win',
    ['#'] = 'Apps',
    ['~'] = 'Shift'
}

local KEY_NAMES_TO_BIND = 
{
    ['ctrl']  = '^',
    ['alt']   = '!',
    ['win']   = '@',
    ['apps']  = '#',
    ['shift'] = '~'
}

function make_human_readable_key(bind)
    for k, v in pairs(BINDS_TO_KEY_NAME) do
        --print('%s: sub %s with %s':format(bind, k, v))

        bind = bind:gsub(
            (k == '^' and '%' or '') .. k, 
            (v .. '+')
        )
    end

    return bind
end

function window_slot_to_key_bind(slot)
    if type(slot) ~= 'number' or slot < 0 or slot >= 30 then
        return
    end

    -- ^	Ctrl
    -- !	Alt
    -- @	Win
    -- #	Apps
    -- ~	Shift

    shared_settings.windows = shared_settings.windows or {}
    shared_settings.windows.groupkeys = shared_settings.windows.groupkeys or {}
    shared_settings.windows.binds = shared_settings.windows.binds or {}

    local slot_key = slot % 10
    local base = nil

    if slot < 10 then      
        base = shared_settings.windows.groupkeys[1] or '@~' -- Win+Shift   
    elseif slot < 20 then   
        base = shared_settings.windows.groupkeys[2] or '@!' -- Win+Alt
    elseif slot < 30 then
        base = shared_settings.windows.groupkeys[3] or '@^' -- Win+Ctrl
    end

    if base then
        local bind = '%s%d':format(base, slot)
        return bind, make_human_readable_key(bind)
    end
end

function window_unbind_keys(skip_bound, skip_unbound)
    return window_bind_keys('clear', skip_bound, skip_unbound)
end

function window_bind_keys(mode, skip_bound, skip_unbound)
    -- This sleep is required due to a commands race condition. Occasionally, the unbinds from a
    -- previous step would get executed after the binds from this step. I don't understand.
    coroutine.sleep(1)

    shared_settings.windows = shared_settings.windows or {}
    shared_settings.windows.groupkeys = shared_settings.windows.groupkeys or {}
    shared_settings.windows.binds = shared_settings.windows.binds or {}

    local clearing = mode == 'clear'

    -- Experiment: If no actual value was provided for skip_unbound, we will behave
    -- as if skip was configured. This is to avoid removing keys that we did not set.
    if skip_unbound == nil then
        skip_unbound = true
    end

    for slot = 0, 29 do
        local command = nil
        local key = window_slot_to_key_bind(slot)
        if key then
            local bind = shared_settings.windows.binds[tostring(slot)]
            if 
                bind and
                type(bind) == 'table' and
                bind.names 
            then
                if clearing then
                    -- Clear mode: We take all the binds and remove them
                    command = 'unbind %s':format(key)
                elseif not skip_bound then
                    -- Bind mode: We bind keys to their respective command
                    command = 'bind %s hk window activate %s':format(key, bind.names)
                end
            else
                if not skip_unbound then
                    -- This key is not bound, we will unbind it (unless told to skip unbinds)
                    command = 'unbind %s;':format(key)
                end
            end
        end

        if command then
            --print('command: [%s]':format(command))
            windower.send_command(command)
        end
    end
end

function command_window(command, args)
    command = (command or ''):lower()
    args = args or {}

    shared_settings.windows = shared_settings.windows or {}
    shared_settings.windows.groupkeys = shared_settings.windows.groupkeys or {}
    shared_settings.windows.binds = shared_settings.windows.binds or {}

    if command == 'activate' then
        for i, name in ipairs(args) do
            if name then
                --print('evaluating name: %s':format(name))
                local success = hotkeys_native.activate_window(name, "pol.exe")
                if success then
                    writeMessage('Sending activation notification to: %s':format(text_player(name)))
                    windower.send_command('send %s hk echo ===== Window Activation Received from Hotkeys =====':format(name))
                    return
                end
            end

            -- Let's not take over the entire CPU here
            if i % 4 == 0 then
                coroutine.sleep(0.1)
            end
        end

        --writeMessage(text_warning('Could not evaluate the success of your activation.'))
    elseif command == 'show' or command == 'list' then
        local sorted_keys = {}
        for key in pairs(shared_settings.windows.binds) do
            local num = tonumber(key)
            if num then
                table.insert(sorted_keys, num)
            end
        end

        table.sort(sorted_keys)

        if #sorted_keys == 0 then
            writeWarning('No keybinds have been configured yet.')
            return
        end

        for i = 1, #sorted_keys do
            local num = sorted_keys[i]
            local bind = shared_settings.windows.binds[tostring(num)]

            if bind and type(bind) == 'table' and bind.names then
                local names = bind.names
                local wbind, hbind = window_slot_to_key_bind(num)

                writeMessage('  Slot #%s [%s]: %s':format(
                    text_number(num), 
                    text_number(hbind or '???'),
                    text_player(names)
                ))
            end
        end
    elseif command == 'reset' then
        shared_settings.windows.binds = {}
        shared_settings.windows.groupkeys = {}

        saveSettings()

        -- Force other logged in alts to reload
        windower.send_command('send @others hk reload')

        writeMessage('Successfully cleared all window slots!')

    elseif command == 'unset' or command == 'clear' then
        local num = tonumber(args[1]) or -1
        if num < 0 or num >= 30 then
            writeMessage(text_warning('This command requires a slot number from 0-29.'))
            return
        end

        shared_settings.windows.binds[tostring(num)] = nil        
        saveSettings()

        -- Force other logged in alts to reload
        windower.send_command('send @others hk reload')

        writeMessage('Successfully cleared window slot %s':format(text_number('#' .. num)))

    elseif command == 'set' then
        if #args < 2 then
            writeMessage(text_warning('The window set command requires at least a slot number and a character/toon name.'))
            return
        end

        local num = tonumber(args[1]) or -1
        if num < 0 or num >= 30 then
            writeMessage(text_warning('The window set command requires a slot number from 0-39.'))
            return
        end

        local names = { table.unpack(args, 2, #args) }

        shared_settings.windows.binds[tostring(num)] = { names = table.concat(names, ' ') }

        saveSettings()

        -- Force other logged in alts to reload
        windower.send_command('send @others hk reload')

        writeMessage('Successfully set window slot %s to [%s]':format(
            text_number('#' .. num),
            text_player(shared_settings.windows.binds[tostring(num)].names)
        ))
    elseif command == 'groupkey' or command == 'gk' then
        local group = tonumber(args[1])
        if not group then
            writeMessage('Binds can be built by combining the following base keys: ')
            for key, name in pairs(BINDS_TO_KEY_NAME) do
                writeMessage('  %s for %s':format(
                    text_yellow(key),
                    text_green(name)))
            end

            return
        end

        if group ~= 1 and group ~= 2 and group ~= 3 then
            writeWarning('A group value of 1, 2, or 3 must be specified.')
            return
        end

        local base_bind = args[2]
        if type(base_bind) ~= 'string' then
            writeWarning('A binding string for the group must be specified.')
            return
        end

        window_unbind_keys()

        if group == 1 then
            shared_settings.windows.groupkeys[1] = base_bind
        elseif group == 2 then
            shared_settings.windows.groupkeys[2] = base_bind
        elseif group == 3 then
            shared_settings.windows.groupkeys[3] = base_bind
        else
        end

        saveSettings()

        -- Force other logged in alts to reload
        windower.send_command('send @others hk reload')

        local hk = make_human_readable_key(base_bind)
        writeMessage('Bound group %s to key [%s] [%s]':format(
            text_number('#' .. group),
            text_green(hk),
            text_yellow(base_bind)
        ))
    end
end