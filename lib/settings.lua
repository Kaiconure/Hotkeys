settings = {}

function getSettingsFolder(playerName)
    return '.\\settings\\' .. playerName .. '\\'
end

function getSettingsFileName(playerName)
    return getSettingsFolder(playerName) .. 'settings.json'
end