import std.stdio;
import core.sys.windows.dll;
import core.sys.windows.windef;
import core.sys.windows.winbase;
import std.conv;
import std.bitmanip;
import std.file;

version(injector) {
	void main(string[] args)
	{
		import std.path : setExtension;
		wstring target = (args[0].setExtension("dll")).to!wstring;
		ubyte[] targetBytes = (cast(ubyte[])target)~new ubyte[0];

		if (args.length != 2) {
			writefln("Invalid usage!");
			return;
		}

		if (!exists(target)) {
			writefln("%s does not exist!");
			return;
		}

		HANDLE proc = OpenProcess(
			PROCESS_CREATE_THREAD |
			PROCESS_VM_OPERATION |
			PROCESS_VM_READ |
			PROCESS_VM_WRITE,
			FALSE,
			args[1].to!uint
		);
		assert(proc, "Process not found!");
		writefln("Process Handle: %s", proc);

		PVOID targetAddr = VirtualAllocEx(
			proc,
			null,
			1024,
			MEM_RESERVE | MEM_COMMIT,
			PAGE_READWRITE
		);
		writefln("Target Addr: %s", targetAddr);

		// Write in our arguments
		size_t written = 0;
		WriteProcessMemory(proc, targetAddr, targetBytes.ptr, targetBytes.length, &written);
		assert(written > 0, "Did not write neccesary bytes!");

		writefln("Wrote %s bytes for %s...", written, target);
		

		// Get LoadLibraryW
		HANDLE kernel32 = GetModuleHandleW("kernel32.dll\0"w.ptr);
		assert(kernel32, "kernel32 not found?!");
		FARPROC procaddr = GetProcAddress(kernel32, "LoadLibraryW\0".ptr);
		assert(procaddr, "LoadLibraryW not found!");

		writefln("Kernel32 Addr: %s", kernel32);
		writefln("ProcAddr: %s", procaddr);

		// Call LoadLibraryW in external program.
		uint tid;
		CreateRemoteThread(
			proc,
			NULL,
			0,
			cast(LPTHREAD_START_ROUTINE)procaddr,
			targetAddr,
			0,
			&tid
		);
		writefln("Spawned TID: %s!", tid);
	}
}

//
// PAYLOAD BOOTSTRAPPER
//
// Following code sets up DllMain for Windows to call in to, to bootstrap the
// injected code, pmain in payload is called.
//	
version(payload) {
	import core.sys.windows.windef : HINSTANCE, BOOL, DWORD, LPVOID;

	extern(Windows)
	BOOL DllMain(HINSTANCE hInstance, DWORD ulReason, LPVOID reserved)
	{
		import core.sys.windows.winnt;
		import core.sys.windows.dll :
			dll_process_attach, dll_process_detach,
			dll_thread_attach, dll_thread_detach;
		
		import payload : pmain;
		switch (ulReason)
		{
			default: assert(0);
			case DLL_PROCESS_ATTACH:

				// Try to init libphobos
				bool ret = dll_process_attach( hInstance, true );
				if (ret) {

					// Call main if libphobos could be loaded
					pmain();
				}

				// Automatically unload
				return false;

			case DLL_PROCESS_DETACH:

				// Unload phobos now that we're done.
				dll_process_detach( hInstance, true );
				return true;

			case DLL_THREAD_ATTACH:
				return dll_thread_attach( true, true );

			case DLL_THREAD_DETACH:
				return dll_thread_detach( true, true );
		}
	}
}