#include "pch.h"

#define MAX_WINDOW_TITLE    64

struct WINDOW_INFO
{
    lua_State* L;
    const char* process;
    const char* title;
    
    HWND hWndResult;
};

BOOL CALLBACK EnumWindowsProc(HWND hWnd, LPARAM lParam) {
    char szTitle[MAX_WINDOW_TITLE];

    if (IsWindowVisible(hWnd))
    {
        WINDOW_INFO* wi = (WINDOW_INFO*)lParam;

        if (GetWindowTextA(hWnd, szTitle, MAX_WINDOW_TITLE - 1) > 0)
        {
            if (_stricmp(szTitle, wi->title) == 0)
            {
                DWORD dwProcessId;
                if (GetWindowThreadProcessId(hWnd, &dwProcessId) > 0)
                {
                    HANDLE hProcess = OpenProcess(PROCESS_QUERY_INFORMATION | PROCESS_VM_READ, FALSE, dwProcessId);
                    if (hProcess)
                    {
                        CHAR szPath[MAX_PATH];
                        DWORD dwPathSize = MAX_PATH;

                        if (GetModuleFileNameExA(hProcess, NULL, szPath, MAX_PATH))
                        {
                            CloseHandle(hProcess);
                            const char *lastSlash = strrchr(szPath, '\\');
                            if (lastSlash)
                            {
                                if (_stricmp(lastSlash + 1, wi->process) == 0)
                                {
                                    wi->hWndResult = hWnd;
                                    return FALSE;
                                }
                            }
                        }
                        else
                        {
                            CloseHandle(hProcess);
                        }
                    }
                }
            }
        }
    }

    return TRUE;
}

void Interop::windower_print(lua_State* L, const std::string& message)
{
    // This function can be used to print messages to the Windower console
    lua_getglobal(L, "print");
    lua_pushlstring(L, message.c_str(), message.length());

    lua_call(L, 1, 0);
}

bool Interop::ActivateWindow(lua_State* L, const std::string& processName, const std::string& title)
{
    WINDOW_INFO wi;

    wi.L = L;
    wi.process = processName.c_str();
    wi.title = title.c_str();
    wi.hWndResult = NULL;

    EnumWindows(EnumWindowsProc, (LPARAM)&wi);
    if (wi.hWndResult)
    {
        // Restore the window first if it is minimized ("iconic" in win32 speak)
        if (IsIconic(wi.hWndResult))
        {
            ShowWindow(wi.hWndResult, SW_RESTORE);
        }

        BringWindowToTop(wi.hWndResult);
        SetForegroundWindow(wi.hWndResult);
        return true;
    }

    return false;
}

int Interop::lua_activate_window(lua_State* L)
{
    try
    {
        int num_args = lua_gettop(L);
        if (num_args < 2 || lua_type(L, 1) != LUA_TSTRING || lua_type(L, 2) != LUA_TSTRING)
        {
            lua_pushboolean(L, false);
            return 1;
        }

        //Interop::windower_print(L, "Entering activate window!");

        const char* windowTitle = lua_tostring(L, 1);
        const char* processFileName = lua_tostring(L, 2);

        bool success = Interop::ActivateWindow(L, processFileName, windowTitle);

        lua_pushboolean(L, success);
    }
    catch(...)
    {
        lua_pushboolean(L, false);
    }

    return 1;
}