function window_slot_to_key_bind(slot)
    if type(slot) ~= 'number' or slot < 0 or slot >= 30 then
        return
    end

    -- ^	Ctrl
    -- !	Alt
    -- @	Win
    -- #	Apps
    -- ~	Shift

    if slot < 10 then       -- Win+Shift
        return '@~%d':format(slot), 'Win+Shift+%d':format(slot)
    elseif slot < 20 then   -- Win+Alt
        return '!~%d':format(slot), 'Win+Alt+%d':format(slot)
    elseif slot < 30 then   -- Win+Ctrl
        return '^~%d':format(slot), 'Win+Ctrl+%d':format(slot)
    end
end

function window_bind_keys(skip_clear)
    shared_settings.windows = shared_settings.windows or {}
    shared_settings.windows.binds = shared_settings.windows.binds or {}

    for slot = 0, 29 do
        local key = window_slot_to_key_bind(slot)
        if key then
            local bind = shared_settings.windows.binds[tostring(slot)]
            if bind and type(bind) == 'table' and bind.names then
                windower.send_command('bind %s hk window activate %s':format(key, bind.names))
            else
                if not skip_clear then
                    windower.send_command('unbind %s;':format(key))
                end
            end
        end
    end
end

function command_window(command, args)
    command = (command or ''):lower()
    args = args or {}

    if command == 'activate' then
        for i, name in ipairs(args) do
            if name then
                local success = hotkeys_native.activate_window(name, "pol.exe")
                if success then
                    writeMessage('Sending activation notification to: %s':format(text_player(name)))
                    return
                end
            end

            -- Let's not take over the entire CPU here
            if i % 4 == 0 then
                coroutine.sleep(0.1)
            end
        end

        writeMessage(text_warning('Could not evaluate the success of your activation.'))
    elseif command == 'show' then
        shared_settings.windows = shared_settings.windows or {}
        shared_settings.windows.binds = shared_settings.windows.binds or {}

        local sorted_keys = {}
        for key in pairs(shared_settings.windows.binds) do
            local num = tonumber(key)
            if num then
                table.insert(sorted_keys, num)
            end
        end

        table.sort(sorted_keys)

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
        shared_settings.windows = shared_settings.windows or {}
        shared_settings.windows.binds = {}

        saveSettings()
        writeMessage('Successfully cleared all window slots!')

    elseif command == 'clear' then
        local num = tonumber(args[1]) or -1
        if num < 0 or num >= 30 then
            writeMessage(text_warning('The window clear command requires a slot number from 0-29.'))
            return
        end

        shared_settings.windows = shared_settings.windows or {}
        shared_settings.windows.binds = shared_settings.windows.binds or {}

        shared_settings.windows.binds[tostring(num)] = nil
        
        saveSettings()
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

        local names = { table.unpack(args, 2) }

        shared_settings.windows = shared_settings.windows or {}
        shared_settings.windows.binds = shared_settings.windows.binds or {}

        shared_settings.windows.binds[tostring(num)] = { names = table.concat(names, ' ') }
        saveSettings()

        -- Force other logged in alts to reload
        windower.send_command('send @others hk reload')

        writeMessage('Successfully set window slot %s to [%s]':format(
            text_number('#' .. num),
            text_player(shared_settings.windows.binds[tostring(num)].names)
        ))
    end
end