/*
 * --------------------------------------------
 *  VHD Sherlock for the D Programming Language
 * --------------------------------------------
 *  sherlock.d
 * -----------
 *
 * Analyze virtual hard disk files in the VHD image format based on
 * the Microsoft specification (http://technet.microsoft.com/en-us/library/bb676673.aspx).
 *
 * This began as a port of franciozzy's VHD Sherlock
 * (https://github.com/franciozzy/VHD-Sherlock) to the D programming language,
 * with some additional changes to get this to run on Windows.
 *
 *
 *  This program is free software: you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation, either version 3 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * Read the README file for the changelog and information on how to
 * compile and use this program.
 */

// Global definitions (don't mess with those)

const string MT_PROGNAME = "VHD Sherlock";
const int MT_PROGNAME_LEN = MT_PROGNAME.length;

import vhd.files;
import vhd.structs;
import std.stdio; // printf
import std.bitmanip; // bigEndianToNative
import std.getopt; // getopt
import std.file;

// Global definitions
const int MT_SECS = 512; // Size of a sector

alias ubyte u_char;
alias ubyte u_int8_t;
alias ushort u_int16_t;
alias uint u_int32_t;
alias ulong u_int64_t;

uint be32toh(uint x)
{
    // Feels like I should be able to do this using std.bitmanip.write,
    // but not working right now.
    union u
    {
        ubyte[4] bytes;
        uint val;
    }
    u uval;
    uval.val = x;
    debug(endian) writefln("be32toh: %s", x);
    debug(endian) writefln("be32toh: %s", uval.bytes);
    debug(endian) writefln("be32toh: %s", bigEndianToNative!uint(uval.bytes));
    //ubyte[4] bytes = cast(ubyte[]) x;
    //ubyte[] bytes = [0, 0, 0, 0];
    //std.bitmanip.write!uint(bytes, x);
    //return bigEndianToNative!(uint, 4)(bytes);
    return bigEndianToNative!uint(uval.bytes);
}

// Auxiliary functions

// Print help
void usage(string progname)
{
    // Print help
    foreach (i; 0 .. MT_PROGNAME_LEN) { write("-"); }
    writef("\n%s\n", MT_PROGNAME);
    foreach (i; 0 .. MT_PROGNAME_LEN) { write("-"); }
    writefln("\nUsage: %s [ -h ] [ -v[v] ] <file>", progname);
    writefln("       -h        Print this help message and quit.");
    writefln("       -v        Increase verbose level (may be used multiple times).");
    writefln("       -c        Read VHD footer *copy* only (for corrupted VHDs with no footer)");
    writefln("       <file>        VHD file to examine");
}

// Main function
int main(string[] args)
{
    // Local variables

    // VHD File specific
    FileType             vhdFile;         // VHD file
    VHDFooter            vhd_footer_copy; // VHD footer copy (beginning of file)
    VHDFooter            vhd_footer;      // VHD footer (end of file)
    char copyonly = 0;

    // General
    int verbose = 0; // Verbose level

    // Fetch arguments
    bool help;
    bool copy;
    // Without "bundling", you have to pass multiple -v separately.
    getopt(args,
           std.getopt.config.passThrough,
           std.getopt.config.bundling,
           "h", &help, "v+", &verbose, "c", &copy);

    if (help)
    {
        // Print help
        usage(args[0]);
        return(0);
    }
    else if (copy)
    {
        // Read VHD footer copy only
        if (copyonly)
        {
            stderr.writeln("Error! -c can only be used once.");
            usage(args[0]);
            return(1);
        }
        copyonly = 1;
    }

    if (verbose)
    {
        writefln("verbose = %d", verbose);
    }

    //temp
    int optind = args.length - 1;
    // Validate there is a filename
    if (optind != 1)
    {
        // Print help
        writeln("error: filename expected");
        usage(args[0]);
        return(0);
    }

    // Open VHD file
    try
    {
        if (verbose)
        {
            writeln("Opening VHD file...");
        }
        vhdFile = openFile(args[optind]);
    }
    catch (Exception e)
    {
        perror("open");
        stderr.writefln("%s: Error opening VHD file \"%s\".", args[0], args[optind]);
        return(1);
    }
    scope(exit)
    {
        if (verbose)
        {
            writeln("Closing VHD file...");
        }
        closeFile(vhdFile);
        if (verbose)
        {
            writeln("...ok");
        }
    }
    if (verbose)
    {
        printf("...ok\n\n");
    }

    // Read the VHD footer
    if (copyonly)
    {
        if (verbose)
        {
            printf("Reading VHD footer copy exclusively...\n");
        }
        try
        {
            readStruct(vhdFile, vhd_footer_copy);
        }
        catch
        {
            stderr.writeln("Corrupt disk detected whilst reading VHD footer copy.");
            return(1);
        }
        if (vhd_footer_copy.cookie != "conectix")
        {
            stderr.writeln("Corrupt disk detect whilst reading VHD footer copy.");
            stderr.writeln("Expected cookie (\"conectix\") missing or corrupt.");
            return(1);
        }
        vhd_footer = vhd_footer_copy;
        if (verbose)
        {
            printf("...ok\n\n");
        }
        //if (verbose > 1)
        //{
        //    dump_vhdfooter(&vhd_footer);
        //}
    }
    else
    {
        if (verbose)
        {
            printf("Positioning descriptor to VHD footer...\n");
        }
        try
        {
            // Seek to footer at the end of the file.
            int pos = -(cast(int)vhd_footer.sizeof);
            //writeln(pos);
            seekFile(vhdFile, pos, SEEK_FROM_END);
        }
        catch (Exception e)
        {
            writeln(e);
            perror("lseek");
            stderr.writeln("Corrupt disk detected whilst reading VHD footer.");
            stderr.writeln("Error repositioning VHD descriptor to the footer.");
            return(1);
        }
        if (verbose)
        {
            printf("...ok\n\n");
            printf("Reading VHD footer...\n");
        }
        try
        {
            readStruct(vhdFile, vhd_footer);
        }
        catch
        {
            stderr.writeln("Corrupt disk detected whilst reading VHD footer.");
            return(1);
        }

        if (vhd_footer.cookie != "conectix")
        {
            stderr.writeln("Corrupt disk detected after reading VHD footer.");
            stderr.writeln("Expected cookie (\"conectix\") missing or corrupt.");
            return(1);
        }
        if (verbose)
        {
            printf("...ok\n\n");
        }

        // Dump footer
        if (verbose > 1)
        {
            dump_vhdfooter(&vhd_footer);
        }
    }

    // Check type of disk
    if (verbose)
    {
        printf("Detecting disk type...\n");
    }
    bool isDynamicDisk = false;
    switch(vhd_footer.disktype)
    {
        case 2:
            if (verbose)
            {
                printf("===> Fixed hard disk detected.\n...ok\n\n");
            }
            break;
        case 3:
            if (verbose)
            {
                printf("===> Dynamic hard disk detected.\n...ok\n\n");
            }
            isDynamicDisk = true;
            break;
        case 4:
            if (verbose)
            {
                printf("===> Differencing hard disk detected.\n...ok\n\n");
            }
            isDynamicDisk = true;
            break;
        default:
            printf("===> Unknown VHD disk type: %d\n", vhd_footer.disktype);
            break;
    }

    int result = 0;
    if (isDynamicDisk)
    {
        result = HandleDynamicDisk(verbose, vhdFile, vhd_footer_copy, vhd_footer);
    }

    // Return final result code.
    return(result);
}

int HandleDynamicDisk(const int verbose, ref FileType vhdFile, ref VHDFooter vhd_footer_copy, ref VHDFooter vhd_footer)
{
    // VHD File specific
    VHDDynamicDiskHeader vhd_dyndiskhdr;  // VHD Dynamic Disk Header
    u_int32_t[]          batmap;          // Block allocation table map
    char[MT_SECS]        secbitmap;       // Sector bitmap temporary buffer

    // Read the VHD footer copy
    if (verbose)
    {
        printf("Positioning descriptor to read VHD footer copy...\n");
    }
    try
    {
        //vhdFile.rewind();
        seekFile(vhdFile, 0, SEEK_FROM_START);
    }
    catch
    {
        perror("lseek");
        stderr.writeln("Error repositioning VHD descriptor to the file start.");
        return(1);
    }
    if (verbose)
    {
        printf("...ok\n\n");
        printf("Reading VHD footer copy...\n");
    }
    try
    {
        readStruct(vhdFile, vhd_footer_copy);
    }
    catch
    {
        stderr.writeln("Corrupt disk detected whilst reading VHD footer copy.");
        return(1);
    }
    if (vhd_footer_copy.cookie != "conectix")
    {
        stderr.writeln("Corrupt disk detect whilst reading VHD footer copy.");
        stderr.writeln("Expected cookie (\"conectix\") missing or corrupt.");
        return(1);
    }
    if (verbose)
    {
        printf("...ok\n\n");
    }

    // Dump footer copy
    if (verbose > 1)
    {
        dump_vhdfooter(&vhd_footer);
    }

    // Read the VHD dynamic disk header
    if (verbose)
    {
        printf("Reading VHD dynamic disk header...\n");
    }
    try
    {
        readStruct(vhdFile, vhd_dyndiskhdr);
    }
    catch
    {
        stderr.writeln("Corrupt disk detected whilst reading VHD Dynamic Disk Header.");
        return(1);
    }
    if (vhd_dyndiskhdr.cookie != "cxsparse")
    {
        stderr.writeln("Corrupt disk detect whilst reading Dynamic Disk Header.");
        stderr.writeln("Expected cookie (\"cxsparse\") missing or corrupt.");
        return(1);
    }
    if (verbose)
    {
        printf("...ok\n\n");
    }

    // Dump VHD dynamic disk header
    if (verbose > 1)
    {
        dump_vhd_dyndiskhdr(&vhd_dyndiskhdr);
    }

    //TODO: Better diff
    assert(vhd_footer == vhd_footer_copy);

    // Allocate Batmap
    if (verbose)
    {
        printf("Allocating batmap...\n");
    }
    int numEntries = vhd_dyndiskhdr.maxtabentries;
    if (numEntries % 128 != 0)
    {
        // "The BAT is always extended to a sector boundary."
        // but it's not really necessary to print it, since the maxtabentries
        // is the max usable, and it contains sector offsets into
        // to the data blocks.
        if (verbose)
        {
            writeln("Extending BAT size to a sector boundary...");
            writef("from %d (%d bytes) ", numEntries, 4*numEntries);
        }
        numEntries += (128 - (numEntries % 128));
        if (verbose)
        {
            writefln("to %d (%d bytes)", numEntries, 4*numEntries);
        }
    }
    batmap = new u_int32_t[numEntries];
    if (verbose)
    {
        printf("...ok\n\n");
    }

    // Read batmap
    if (verbose)
    {
        printf("Positioning descriptor to read VHD batmap...\n");
    }
    try
    {
        seekFile(vhdFile, vhd_dyndiskhdr.tableoffset, SEEK_FROM_START);
    }
    catch
    {
        perror("lseek");
        stderr.writefln("Error repositioning VHD descriptor to batmap at 0x%016llx", vhd_footer_copy.dataoffset);
        return(1);
    }
    if (verbose)
    {
        printf("...ok\n\n");
        printf("Reading VHD batmap...\n");
    }
    try
    {
        readArray(vhdFile, batmap[]);
    }
    catch
    {
        stderr.writeln("Error reading batmap.");
        return(1);
    }
    if (verbose)
    {
        printf("...ok\n\n");
    }

    // Dump Batmap
    if (verbose > 2)
    {
        printf("----------------------------\n");
        printf(" VHD Block Allocation Table (%u / %u entries)\n", vhd_dyndiskhdr.maxtabentries, batmap.length);
        printf("----------------------------\n");
        //for (i=0; i<vhd_dyndiskhdr.maxtabentries; i++)
        foreach(k, x; batmap)
        {
            //printf("batmap[%d] = 0x%08X\n", i, be32toh(batmap[i]));
            printf("batmap[%d] = 0x%08X\n", k, be32toh(x));
        }
        printf("===============================================\n");
    }

    // Dump sector bitmaps
    if (verbose > 3)
    {
        printf("------------------------------\n");
        printf(" VHD Sector Bitmaps per Block\n");
        printf("------------------------------\n");
        for (int i=0; i<vhd_dyndiskhdr.maxtabentries; i++)
        {
            if (batmap[i] == 0xFFFFFFFF)
            {
                printf(" block[%d] = <...not allocated...>\n", i);
                continue;
            }
            try
            {
                seekFile(vhdFile, be32toh(batmap[i])*MT_SECS, SEEK_FROM_START);
            }
            catch
            {
                perror("lseek");
                stderr.writefln("Error repositioning VHD descriptor to batmap[%d] at 0x%016X", i, be32toh(batmap[i]));
                return(1);
            }
            try
            {
                readArray(vhdFile, secbitmap[]);
            }
            catch
            {
                stderr.writefln("Error reading sector bitmap (batmap[%d] at 0x%016X.", i, be32toh(batmap[i]));
                return(1);
            }

            printf(" block[%d] sector bitmap =", i);
            for (int j=0; j<MT_SECS; j++)
            {
                if (!(j%32))
                {
                    printf("\n ");
                }
                printf("%02hhX", secbitmap[j]);
            }
            printf("\n");
        }

    }

    // Print summary
    //printf("VHD is OK\n");

    return 0;
}
