VHD Sherlock for the D programming language
================================================================

Analyze virtual hard disk files in the VHD image format based on the Microsoft specification (http://technet.microsoft.com/en-us/library/bb676673.aspx).

This began as a port of franciozzy's VHD Sherlock (https://github.com/franciozzy/VHD-Sherlock) to the D programming language, with some additional changes to get this to run on Windows.

Instructions
------------
1. Compile the program using a D compiler (only DMD has been tested).
2. Run on a VHD file.
3. Profit.

**NOTE: In order to support large files (> 2GB) on Windows, you should compile with the "-version=WindowsLargeFile" option.**
