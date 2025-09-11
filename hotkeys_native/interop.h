#pragma once

class Interop
{
public:
    static bool ActivateWindow(lua_State* L, const std::string& processName, const std::string& title);

public:
    /// <summary>
    /// Activates a windower with a given title in a given process. Lua params are:
    ///     1. Window title
    ///     2. Process executable file name
    /// </summary>
    static int lua_activate_window(lua_State* L);

    /// <summary>
    /// Prints a message to the Windower console (calls print in Lua)
    /// </summary>
    static void windower_print(lua_State* L, const std::string& message);

private:
};