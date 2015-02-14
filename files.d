/*
 *  files.d
 *
 * Helper functions for reading/writing VHD files.
 *
 * On Windows, fseek is limited to offsets of 32-bits (~2GB), so reading
 * large VHD files requires using a different file API.
 *
 * To compile with large file support, pass in:
 *     -version=WindowsLargeFile
 *
 */

module vhd.files;

/*
import vhd.structs;
import std.bitmanip; // bigEndianToNative
import std.getopt; // getopt
import std.file;
*/
import std.stdio; // File, SEEK_* (move into else block once traces are sorted out.)

version(WindowsLargeFile)
{
    import std.c.windows.windows;
    alias HANDLE FileType;

    alias FILE_BEGIN SEEK_FROM_START;
    alias FILE_CURRENT SEEK_FROM_CURRENT;
    alias FILE_END SEEK_FROM_END;
}
else
{
    alias File FileType;

    alias SEEK_SET SEEK_FROM_START;
    alias SEEK_CUR SEEK_FROM_CURRENT;
    alias SEEK_END SEEK_FROM_END;
}

FileType openFile(string fileName)
{
    version(WindowsLargeFile)
    {
        // Make sure it's zero-terminated for using it as a pointer.
        fileName ~= 0;
        HANDLE hFile = CreateFileA(fileName.ptr, GENERIC_READ, 0, null, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, null);
        //writefln("hFile: %s", hFile);
        if (hFile == INVALID_HANDLE_VALUE)
        {
            writeln("Failed to open file!");
            DWORD err = GetLastError();
            switch (err)
            {
                case 32: /* ERROR_SHARING_VIOLATION */
                {
                    writeln("File in use.");
                    break;
                }
                default:
                {
                    writeln(GetLastError());
                }
            }
            throw new Exception("Failed to open file!");
            return null;
        }

        return hFile;
    }
    else
    {
        return File(fileName);
    }
}

void seekFile(FileType file, long offset, int method)
{
    version(WindowsLargeFile)
    {
        union u
        {
            long val;
            struct
            {
                int low;
                int high;
            }
        };
        u uval;
        uval.val = offset;
        //writefln("offset: %s", offset);
        //writefln("val: %s", uval.val);
        //writefln("low: %s", uval.low);
        //writefln("high: %s", uval.high);
        DWORD result = SetFilePointer(file, uval.low, &uval.high, method);
        if (result == INVALID_SET_FILE_POINTER)
        {
            writeln("Failed to set file pointer!");
            //writeln(FormatMessageA(GetLastError()));
            writeln(GetLastError());
            throw new Exception("Failed to open file!");
        }
        else
        {
            //writefln("SetFilePointer: %s", result);
        }
    }
    else
    {
        //int result = fseek(vhdFile.getFP(), offset, method);
        //int result = _fseeki64(vhdFile.getFP(), offset, method);
        file.seek(offset, method);
    }
}

void readArray(T)(FileType file, T[] arrayToFill)
{
    version(WindowsLargeFile)
    {
        DWORD numRead;
        int numBytes = arrayToFill.length * T.sizeof;
        ReadFile(file, arrayToFill.ptr, numBytes, &numRead, null);
        if (numRead != numBytes)
        {
            throw new Exception("Didn't read a full array!");
        }
    }
    else
    {
        T[] result;
        result = file.rawRead(arrayToFill);
        if ((result.length != arrayToFill.length) || (result != arrayToFill))
        {
            throw new Exception("Failed to read array correctly!");
        }
    }
}

void readStruct(T)(FileType file, out T structToFill)
{
    version(WindowsLargeFile)
    {
        DWORD numRead;
        ReadFile(file, &structToFill, structToFill.sizeof, &numRead, null);
        if (numRead != structToFill.sizeof)
        {
            //fprintf(stderr.getFP(), "Expecting %d bytes. Read %d bytes.\n", structToFill.sizeof, numRead);
            throw new Exception("Didn't read a full struct!");
        }
    }
    else
    {
        T[] result;
        result = file.rawRead((&structToFill)[0..1]);
        if ((result.length != 1) || (result[0] != structToFill))
        {
            throw new Exception("Failed to read struct correctly!");
        }
    }
}

void closeFile(FileType file)
{
    version(WindowsLargeFile)
    {
        //TODO: CloseHandle(file);
    }
    else
    {
        file.close();
    }
}
