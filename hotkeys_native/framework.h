#pragma once

#define WIN32_LEAN_AND_MEAN             // Exclude rarely-used stuff from Windows headers
// Windows Header Files
#include <windows.h>
#include <Psapi.h>

#include <string>

#define LUA_BUILD_AS_DLL

#include "lua.h"
#include "lauxlib.h"

#pragma comment(lib, "LuaCore_exports.lib")

