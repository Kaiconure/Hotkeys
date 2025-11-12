--------------------------------------------------------------------------------------
-- Shift_JIS helper chacaters

CHAR_RIGHT_ARROW        = string.char(0x81, 0xA8) -- https://www.fileformat.info/info/charset/Shift_JIS/list.htm
CHAR_UP_ARROW           = string.char(0x81, 0xAA)
CHAR_BULLET             = string.char(0x81, 0x45)

--------------------------------------------------------------------------------------
-- Logging colors

Colors = {
    white = 1,
    green = 2,
    indigo = 3,
    magenta = 5,
    blue = 6,
    cornsilk = 109,
    salmon = 8,
    darkgray = 65,
    gray = 67,
    redbrick = 68,
    gold = 69,
    slateblue = 70,
    cornflowerblue = 71,
    purple = 72,
    violet = 73,
    red = 76,
    lightgray = 78,
    skyblue = 82,
    aquamarine = 83,
    mediumslateblue = 89,
    powderblue = 92,
    lightyellow = 96,
    yellow = 104,
    pink = 105,
    khaki = 109,
    dodgerblue = 112,
    deepskyblue = 113,
}

Colors.default = Colors.mediumslateblue
Colors.warning = Colors.yellow
Colors.error = Colors.red

--------------------------------------------------------------------------------------
-- Returns a color-formatted string for use with game logging
function colorize(color, message, returnColor)
    -- what is 0x1F for?

    color = color or Colors.default
    returnColor = returnColor or Colors.default

    return string.char(0x1E, tonumber(color)) 
        .. (message or '')
        .. string.char(0x1E, returnColor)
        --.. ((returnColor and string.char(0x1E, returnColor)) or '')
end

--------------------------------------------------------------------------------------
-- Text colorization helpers and semantics

function text_white(message, returnColor)
    return colorize(Colors.white, message, returnColor)
end

function text_green(message, returnColor)
    return colorize(Colors.green, message, returnColor)
end

function text_warning(message, returnColor)
    return colorize(Colors.warning, message, returnColor)
end

function text_error(message, returnColor)
    return colorize(Colors.error, message, returnColor)
end

function text_yellow(message, returnColor)
    return colorize(Colors.yellow, message, returnColor)
end

function text_red(message, returnColor)
    return colorize(Colors.red, message, returnColor)
end

function text_redbrick(message, returnColor)
    return colorize(Colors.redbrick, message, returnColor)
end

function text_gray(message, returnColor)
    return colorize(Colors.gray, message, returnColor)
end

function text_lightgray(message, returnColor)
    return colorize(Colors.lightgray, message, returnColor)
end

function text_magenta(message, returnColor)
    return colorize(Colors.magenta, message, returnColor)
end

function text_cornsilk(message, returnColor)
    return colorize(Colors.cornsilk, message, returnColor)
end

function text_gold(message, returnColor)
    return colorize(Colors.gold, message, returnColor)
end

function text_trustset(trustSetName, returnColor)
    local colorFunc = (trustSetName == settings.trust.current and text_trustset_active or text_trustset_inactive)
    --return '[' .. colorFunc(trustSetName, returnColor) .. ']'
    return colorFunc(trustSetName, returnColor)
end

function text_gearset(gearSetName, returnColor)
    return colorize(returnColor,
        '[' .. text_magenta(gearSetName, returnColor) .. ']',
        returnColor)
end

--------------------------------------------------------------------------------------
-- Text logging

function writeMessage(message, color, returnColor)
    windower.add_to_chat(1, 
        --colorize(color or Colors.default, '[Hotkeys] ' .. message, returnColor))
        colorize(color or Colors.default, ' ' .. message, returnColor))
end

function writeMessageSlim(message, color, returnColor)
    windower.add_to_chat(1, 
        colorize(color or Colors.default, message, returnColor))
end

function writeWarning(message) 
    writeMessage(text_warning(message, Colors.warning), Colors.warning)
end

function writeError(message) 
    writeMessage(text_error(message))
end

function writeCommandInfo(command, ...)
    local descriptionLines = {...}

    writeMessage('  ' .. text_command(command))
    
    if isArray(descriptionLines) then
        for i = 1, #descriptionLines do
           writeMessage('    ' .. text_description(descriptionLines[i]))
        end
    end
end

--------------------------------------------------------------------------------------
-- Semantic formatting helpers

function pluralize(count, ifOne, ifOther, returnColor)
    local word = (count == 1 and ifOne or ifOther)
    --return text_number(count, returnColor) .. ' ' .. colorize(returnColor, word, returnColor)
    return text_number(count .. ' ' .. word, returnColor)
end

--------------------------------------------------------------------------------------
-- Semantic formatting references
text_player               = text_white
text_mount                = text_green
text_trust                = text_magenta
text_inactive             = text_gray
text_trustset_inactive    = text_inactive
text_trustset_active      = text_green
text_spell                = text_gold
text_number               = text_cornsilk
text_target               = text_cornsilk
text_gearslot             = text_cornsilk
text_augment              = text_green
text_item                 = text_magenta
text_command              = text_green
text_description          = text_cornsilk
text_job                  = text_cornsilk