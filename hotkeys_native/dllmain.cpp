// dllmain.cpp : Defines the entry point for the DLL application.
#include "pch.h"

HANDLE g_hDetaching = NULL;

extern "C" {
    __declspec(dllexport) int luaopen_hotkeys_native(lua_State* L)
    {
        struct luaL_Reg kaiconure_windower_funcs[] = {
            /*{"configure_logging", WindowerInterop::lua_configure_logging},
            {"set_default_request_timeout", WindowerInterop::lua_set_default_request_timeout},
            {"send_http_request", WindowerInterop::lua_send_http_request},*/
            {"activate_window", Interop::lua_activate_window},

            // Sentinel to mark the end of the array
            {NULL, NULL}
        };
        luaL_register(L, "hotkeys_native", kaiconure_windower_funcs);

        if (g_hDetaching == NULL)
        {
            g_hDetaching = CreateEvent(NULL, TRUE, FALSE, NULL);
        }

        return 1; // Return the number of results
    }
}

BOOL APIENTRY DllMain( HMODULE hModule,
                       DWORD  ul_reason_for_call,
                       LPVOID lpReserved
                     )
{
    switch (ul_reason_for_call)
    {
    case DLL_PROCESS_ATTACH:
        break;
    case DLL_THREAD_ATTACH:
        break;
    case DLL_THREAD_DETACH:
        break;
    case DLL_PROCESS_DETACH:
        {
            if (g_hDetaching)
            {
                SetEvent(g_hDetaching);
            }
            break;
        }
    }
    return TRUE;
}

