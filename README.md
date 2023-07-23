# D Win32 hijack example

This example shows how to hijack a running process in Windows by asking it nicely to load a payload DLL with `CreateRemoteThread` calling `LoadLibraryW`.

To use this repo have a D compiler installed on Windows and run:
```
dub --config=payload
dub -- <process to hijack>
```

Note that window iteration may freeze if the window is interacted with while it's scanning.  
This could be alleviated but this is just a basic example.