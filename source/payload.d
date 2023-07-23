module payload;
import core.sys.windows.core;
import std.stdio;
import core.sys.windows.tlhelp32;
import std.conv;

version(payload) {
    pragma(lib, "user32.lib");

    struct Window {
        HANDLE hWnd;
        string title;
    }

    private __gshared HANDLE[] iHWnds;
    Window[] getThreadWindows(DWORD[] threads) {
        Window[] windows;

        foreach(thread; threads) {
            EnumThreadWindows(
                thread, 
                cast(WNDENUMPROC)(hwnd, lparam) { 
                    iHWnds ~= hwnd;
                    return true;
                }, 
                0
            );
        }

        foreach(window; iHWnds) {
            int len = GetWindowTextLengthW(window);
            if (len > 0) {
                wchar[] winTitle = new wchar[len];
                GetWindowTextW(window, winTitle.ptr, len+1);

                string utf8Str = (winTitle.idup).to!string;
                windows ~= Window(window, utf8Str);
            }
        }
        iHWnds.length = 0;

        return windows;
    }

    Window getMainWindow(Window[] windows) {
        foreach(window; windows) {
            if (!GetWindow(window.hWnd, GW_OWNER) && IsWindowVisible(window.hWnd)) {
                return window;
            }
        }
        return Window.init;
    }

    void pmain() {
        assert(openConsole());
        setConsoleTitle("unknown");
        
        writeln("Hello from whatever application this is, first we enumerate its threads!...");
        DWORD[] threads = getThreads();
        writefln("I found %s...", threads);

        writefln("Let's try finding some windows!");
        Window[] windows = getThreadWindows(threads);
        writefln("I found %s...", windows);

        Window mainWindow = getMainWindow(windows);
        writefln("Main Window is %s, called %s", mainWindow.hWnd, mainWindow.title);
        setConsoleTitle(mainWindow.title.to!wstring);
        
        MessageBoxW(null, ":3!"w.ptr, "Haha!"w.ptr, 0);
    }

    bool openConsole() {
        bool console = cast(bool)AllocConsole();

        if (console) {
            freopen("CON", "w", stdout.getFP);
            freopen("CON", "r", stdin.getFP);

        }
        return console;
    }

    void setConsoleTitle(wstring name) {
        SetConsoleTitleW(("Hello, "w~name~"!\0"w).ptr);
    }

    DWORD[] getThreads() {
        DWORD[] tids;
        
        DWORD pid = GetCurrentProcessId();
        DWORD selfId = GetCurrentThreadId();
        HANDLE snap = CreateToolhelp32Snapshot(TH32CS_SNAPTHREAD, 0);
        THREADENTRY32 entry;
        entry.dwSize = entry.sizeof;
        if (Thread32First(snap, &entry)) {
            do {

                // Not owned by us
                if (entry.th32OwnerProcessID != pid) continue;

                // Ourselves.
                if (entry.th32ThreadID == selfId) continue;

                tids ~= entry.th32ThreadID;

            } while(Thread32Next(snap, &entry));
        }

        // Close handle to Toolhelp32
        CloseHandle(snap);

        return tids;
    }
}