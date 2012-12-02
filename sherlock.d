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

// Header files
import std.stdio; // printf
import std.bitmanip; // bigEndianToNative
import std.getopt; // getopt
import std.file;

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

void readArray(T)(FileType file, ref T[] arrayToFill)
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

// Global definitions
const int MT_CKS = 8; // Size of "cookie" entries in headers
const int MT_SECS = 512; // Size of a sector

alias ubyte u_char;
alias ubyte u_int8_t;
alias ushort u_int16_t;
alias uint u_int32_t;
alias ulong u_int64_t;

alias size_t ssize_t;

uint sizeof(T)(T x)
{
    return x.sizeof;
}

uint be32toh(uint x)
{
    // Feels like I should be able to do this using std.bitmanip.write,
    // but not working right now.
    union u
    {
        ubyte[4] bytes;
        uint val;
    }; 
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

ulong be64toh(ulong x)
{
    union u
    {
        ubyte[8] bytes;
        ulong val;
    }; 
    u uval;
    uval.val = x;
    debug(endian) writefln("be64toh: %s", x);
    debug(endian) writefln("be64toh: %s", uval.bytes);
    debug(endian) writefln("be64toh: %s", bigEndianToNative!ulong(uval.bytes));
    //ubyte[8] bytes = cast(ubyte[]) x;
    //return bigEndianToNative!(ulong, 8)(bytes);
    return bigEndianToNative!(ulong, 8)(uval.bytes);
}

// VHD Footer structure
struct vhd_footer_t {
    align(1): // Packed
	u_char		cookie[MT_CKS];	// Cookie
	u_int32_t	features;	// Features
	u_int32_t	ffversion;	// File format version
	u_int64_t	dataoffset;	// Data offset	
	u_int32_t	timestamp;	// Timestamp
	//u_int32_t	creatorapp;	// Creator application
	u_char[4]	creatorapp;	// Creator application
	u_int32_t	creatorver;	// Creator version
	u_int32_t	creatorhos;	// Creator host OS
	u_int64_t	origsize;	// Original size
	u_int64_t	currsize;	// Current size
	u_int32_t	diskgeom;	// Disk geometry
	u_int32_t	disktype;	// Disk type
	u_int32_t	checksum;	// Checksum
	u_char		uniqueid[16];	// Unique ID
	u_char		savedst;	// Saved state
	u_char		reserved[427];	// Reserved
};

// VHD Dynamic Disk Header structure
struct vhd_ddhdr_t {
    align(1): // Packed
	u_char		cookie[MT_CKS];	// Cookie
	u_int64_t	dataoffset;	// Data offset
	u_int64_t	tableoffset;	// Table offset
	u_int32_t	headerversion;	// Header version
	u_int32_t	maxtabentries;	// Max table entries
	u_int32_t	blocksize;	// Block size
	u_int32_t	checksum;	// Checksum
	u_char		parentuuid[16];	// Parent Unique ID
	u_int32_t	parentts;	// Parent Timestamp
	u_char		reserved1[4];	// Reserved
	u_char		parentname[512];// Parent Unicode Name
	u_char		parentloc1[24];	// Parent Locator Entry 1
	u_char		parentloc2[24];	// Parent Locator Entry 2
	u_char		parentloc3[24];	// Parent Locator Entry 3
	u_char		parentloc4[24];	// Parent Locator Entry 4
	u_char		parentloc5[24];	// Parent Locator Entry 5
	u_char		parentloc6[24];	// Parent Locator Entry 6
	u_char		parentloc7[24];	// Parent Locator Entry 7
	u_char		parentloc8[24];	// Parent Locator Entry 8
	u_char		reserved2[256];	// Reserved
};

// Auxiliary functions

// Print help
void usage(string progname)
{
    // Print help
    foreach (i; 0 .. MT_PROGNAME_LEN) { write("-"); }
    writef("\n%s\n", MT_PROGNAME);
    foreach (i; 0 .. MT_PROGNAME_LEN) { write("-"); }
    writefln("\nUsage: %s [ -h ] [ -v[v] ] <file>", progname);
    writefln("       -h		Print this help message and quit.");
    writefln("       -v		Increase verbose level (may be used multiple times).");
    writefln("       -c		Read VHD footer *copy* only (for corrupted VHDs with no footer)");
    writefln("       <file>		VHD file to examine");
}

// Convert a 16 bit uuid to a static string
char *	uuidstr(u_char uuid[16]){
	// Local variables
	static u_char	str[37];		// String representation of UUID
	char		*ptr;			// Temporary pointer
	int		i;			// Temporary integer

	// Fill str
	ptr = cast(char *)&str;
	for (i=0; i<16; i++){
		sprintf(ptr, "%02x", uuid[i]);
		ptr+=2;
		if ((i==3) || (i==5) || (i==7) || (i==9)){
			sprintf(ptr++, "-");
		}
	}
	*ptr=0;

	// Return a pointer to the static area
	return(cast(char *)&str);
}

// Extract cylinder from the 4 byte disk geometry field
u_int16_t dg2cyli(u_int32_t diskgeom){
	return(cast(u_int16_t)((be32toh(diskgeom)&0xFFFF0000)>>16));
}

// Extract heads from the 4 byte disk geometry field
u_int8_t	dg2head(u_int32_t diskgeom){
	return(cast(u_int8_t)((be32toh(diskgeom)&0x0000FF00)>>8));
}

// Extract sectors per track/cylinder from the 4 byte disk geometry field
u_int8_t	dg2sptc(u_int32_t diskgeom){
	return(cast(u_int8_t)((be32toh(diskgeom)&0x000000FF)));
}

// Convert a disk size to a human readable static string
char *	size2h(u_int64_t disksize){
	// Local variables
	static char	str[32];
	u_int16_t	div = 0;
	u_int64_t	rem = 0;

	// Correct endianess
	disksize = be64toh(disksize);

	// Loop dividing disksize
	while (((disksize / 1024) > 0)&&(div<4)){
		div++;
		rem = disksize % 1024;
		disksize /= 1024;
		if (rem){
			break;
		}
	}

	// Find out unit and fill str accordingly
	switch (div){
		case 0:
			snprintf(str.ptr, sizeof(str), "%lld B", disksize);
			break;
		case 1:
			if (rem){
				snprintf(str.ptr, sizeof(str), "%lld KiB + %lld B", disksize, rem);
			}else{
				snprintf(str.ptr, sizeof(str), "%lld KiB", disksize);
			}
			break;
		case 2:
			if (rem){
				snprintf(str.ptr, sizeof(str), "%lld MiB + %lld KiB", disksize, rem);
			}else{
				snprintf(str.ptr, sizeof(str), "%lld MiB", disksize);
			}
			break;
		case 3:
			if (rem){
				snprintf(str.ptr, sizeof(str), "%lld GiB + %lld MiB", disksize, rem);
			}else{
				snprintf(str.ptr, sizeof(str), "%lld GiB", disksize);
			}
			break;
		default:
			if (rem){
				snprintf(str.ptr, sizeof(str), "%lld TiB + %lld GiB", disksize, rem);
			}else{
				snprintf(str.ptr, sizeof(str), "%lld TiB", disksize);
			}
			break;
	}

	// Return a poniter to the static area
	return(cast(char *)&str);
}

// Convert a disk type to a readable static string
char *	dt2str(u_int32_t disktype){
	// Local variables
	static char	str[32];

	// Convert according to known disk types
	switch (be32toh(disktype)){
		case 0:
			snprintf(str.ptr, sizeof(str), "None");
			break;
		case 2:
			snprintf(str.ptr, sizeof(str), "Fixed hard disk");
			break;
		case 3:
			snprintf(str.ptr, sizeof(str), "Dynamic hard disk");
			break;
		case 4:
			snprintf(str.ptr, sizeof(str), "Differencing hard disk");
			break;
		case 1:
		case 5:
		case 6:
			snprintf(str.ptr, sizeof(str), "Reserved (deprecated)");
			break;
		default:
			snprintf(str.ptr, sizeof(str), "Unknown disk type");
	}

	// Return a pointer to the static area
	return(cast(char *)&str);
}

void	dump_vhdfooter(vhd_footer_t *foot){
	// Local variables
	char		cookie_str[MT_CKS+1];	// Temporary buffer

	// Print a footer
	printf("------------------------\n");
	printf(" VHD Footer (%d bytes)\n", vhd_footer_t.sizeof);
	printf("------------------------\n");
	//snprintf(cookie_str.ptr, sizeof(cookie_str), "%s", foot.cookie);
	//printf(" Cookie              = %s\n",             cookie_str.ptr);
	writefln(" Cookie              = %s",             cast(string)foot.cookie);
	writefln(" Features            = 0x%08X",         be32toh(foot.features));
	printf(" File Format Version = 0x%08X\n",         be32toh(foot.ffversion));
	printf(" Data Offset         = 0x%016llx\n", be64toh(foot.dataoffset));
	printf(" Time Stamp          = 0x%08X\n",         be32toh(foot.timestamp));
	//printf(" Creator Application = 0x%08X\n",         be32toh(foot.creatorapp));
	writefln(" Creator Application = %s",         cast(string)(foot.creatorapp));
        // d2v == disk2vhd
	printf(" Creator Version     = 0x%08X\n",         be32toh(foot.creatorver));
	printf(" Creator Host OS     = 0x%08X\n",         be32toh(foot.creatorhos));
	printf(" Original Size       = 0x%016llx\n", be64toh(foot.origsize));
	printf("                     = %s\n",             size2h(foot.origsize));
	printf(" Current Size        = 0x%016llx\n", be64toh(foot.currsize));
	printf("                     = %s\n",             size2h(foot.currsize));
	printf(" Disk Geometry       = 0x%08X\n",         be32toh(foot.diskgeom));
	printf("           Cylinders = %hu\n",            dg2cyli(foot.diskgeom));
	printf("               Heads = %hhu\n",           dg2head(foot.diskgeom));
	printf("       Sectors/Track = %hhu\n",           dg2sptc(foot.diskgeom));
	printf(" Disk Type           = 0x%08X\n",         be32toh(foot.disktype));
	printf("                     = %s\n",             dt2str(foot.disktype));
	printf(" Checksum            = 0x%08X\n",         be32toh(foot.checksum));
	printf(" Unique ID           = %s\n",             uuidstr(foot.uniqueid));
	printf(" Saved State         = 0x%02X\n",         foot.savedst);
	printf(" Reserved            = <...427 bytes...>\n");
	printf("===============================================\n");
}

void	dump_vhd_dyndiskhdr(vhd_ddhdr_t *ddhdr){
	// Local variables
	char		cookie_str[MT_CKS+1];	// Temporary buffer

	// Print a footer
	printf("--------------------------------------\n");
	printf(" VHD Dynamic Disk Header (%d bytes)\n", vhd_ddhdr_t.sizeof);
	printf("--------------------------------------\n");
	//snprintf(cookie_str.ptr, sizeof(cookie_str), "%s", ddhdr.cookie);
	//printf(" Cookie              = %s\n",             cookie_str);
	writefln(" Cookie              = %s\n",             cast(string)ddhdr.cookie);
	printf(" Data Offset         = 0x%016llx\n", be64toh(ddhdr.dataoffset));
	printf(" Table Offset        = 0x%016llx\n", be64toh(ddhdr.tableoffset));
	printf(" Header Version      = 0x%08X\n",         be32toh(ddhdr.headerversion));
	printf(" Max Table Entries   = 0x%08X\n",         be32toh(ddhdr.maxtabentries));
	printf(" Block Size          = 0x%08X\n",         be32toh(ddhdr.blocksize));
	printf(" Checksum            = 0x%08X\n",         be32toh(ddhdr.checksum));
	printf(" Parent UUID         = %s\n",             uuidstr(ddhdr.parentuuid));
	printf(" Parent TS           = 0x%08X\n",         be32toh(ddhdr.parentts));
	printf("                       %u (10)\n",        be32toh(ddhdr.parentts));
	printf(" Reserved            = <...4 bytes...>\n");
	printf(" Parent Unicode Name = <...512 bytes...>\n");
	printf(" Parent Loc Entry 1  = <...24 bytes...>\n");
	printf(" Parent Loc Entry 2  = <...24 bytes...>\n");
	printf(" Parent Loc Entry 3  = <...24 bytes...>\n");
	printf(" Parent Loc Entry 4  = <...24 bytes...>\n");
	printf(" Parent Loc Entry 5  = <...24 bytes...>\n");
	printf(" Parent Loc Entry 6  = <...24 bytes...>\n");
	printf(" Parent Loc Entry 7  = <...24 bytes...>\n");
	printf(" Parent Loc Entry 8  = <...24 bytes...>\n");
	printf("===============================================\n");
}


// Main function
int main(string[] args)
{
	// Local variables

	// VHD File specific
	//int		vhdfd;			// VHD file descriptor
        FileType        vhdFile;
	vhd_footer_t	vhd_footer_copy;	// VHD footer copy (beginning of file)
	vhd_ddhdr_t	vhd_dyndiskhdr;		// VHD Dynamic Disk Header
	//u_int32_t	*batmap;		// Block allocation table map
	u_int32_t	batmap[];		// Block allocation table map
	char		secbitmap[MT_SECS];	// Sector bitmap temporary buffer
	vhd_footer_t	vhd_footer;		// VHD footer (end of file)
	char		copyonly = 0;

	// General
	int		verbose = 0;		// Verbose level
	int		i, j;			// Temporary integers
	ssize_t		bytesread;		// Bytes read in a read operation

	// Fetch arguments
        bool help;
        bool copy;
        getopt(args, "h", &help, "v+", &verbose, "c", &copy);

        if (help)
        {
                // Print help
                usage(args[0]);
                return(0);
        }
        else if (copy)
        {
                // Read VHD footer copy only
                if (copyonly){
                        fprintf(stderr.getFP(), "Error! -c can only be used once.\n");
                        usage(args[0]);
                        return(1);
                }
                copyonly = 1;
        }

        if (verbose) {
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

	// Initialise local variables
	//memset(&vhd_footer_copy, 0, sizeof(vhd_footer_copy));
	//memset(&vhd_footer, 0, sizeof(vhd_footer));

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
            fprintf(stderr.getFP(), "%s: Error opening VHD file \"%s\".\n", args[0], args[optind]);
            return(1);
	}
	if (verbose){
		printf("...ok\n\n");
	}

	// Read the VHD footer
	if (copyonly){
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
			fprintf(stderr.getFP(), "Corrupt disk detected whilst reading VHD footer copy.\n");
			fprintf(stderr.getFP(), "Expecting %d bytes. Read %d bytes.\n", sizeof(vhd_footer_copy), bytesread);
			closeFile(vhdFile);
			return(1);
		}
		//if (strncmp(cast(char *)&(vhd_footer_copy.cookie), "conectix", 8)){
		if (vhd_footer_copy.cookie != "conectix"){
			fprintf(stderr.getFP(), "Corrupt disk detect whilst reading VHD footer copy.\n");
			fprintf(stderr.getFP(), "Expected cookie (\"conectix\") missing or corrupt.\n");
			closeFile(vhdFile);
			return(1);
		}
		//memcpy(&vhd_footer, &vhd_footer_copy, sizeof(vhd_footer));
                vhd_footer = vhd_footer_copy;
		if (verbose){
			printf("...ok\n\n");
		}
                //if (verbose > 1){
                //    dump_vhdfooter(&vhd_footer);
                //}
	}else{
		if (verbose){
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
			fprintf(stderr.getFP(), "Corrupt disk detected whilst reading VHD footer.\n");
			fprintf(stderr.getFP(), "Error repositioning VHD descriptor to the footer.\n");
			closeFile(vhdFile);
			return(1);
		}
		if (verbose){
			printf("...ok\n\n");
			printf("Reading VHD footer...\n");
		}
                try
                {
                    readStruct(vhdFile, vhd_footer);
                }
                catch
                {
			fprintf(stderr.getFP(), "Corrupt disk detected whilst reading VHD footer.\n");
			fprintf(stderr.getFP(), "Expecting %d bytes. Read %d bytes.\n", sizeof(vhd_footer), bytesread);
			closeFile(vhdFile);
			return(1);
		}

		if (vhd_footer.cookie != "conectix"){
			fprintf(stderr.getFP(), "Corrupt disk detected after reading VHD footer.\n");
			fprintf(stderr.getFP(), "Expected cookie (\"conectix\") missing or corrupt.\n");
			closeFile(vhdFile);
			return(1);
		}
		if (verbose){
			printf("...ok\n\n");
		}

		// Dump footer
		if (verbose > 1){
			dump_vhdfooter(&vhd_footer);
		}
	}

	// Check type of disk
	if (verbose){
		printf("Detecting disk type...\n");
	}
	switch(be32toh(vhd_footer.disktype)){
		case 2:
			if (verbose){
				printf("===> Fixed hard disk detected.\n...ok\n\n");
			}
			break;
		case 3:
			if (verbose){
				printf("===> Dynamic hard disk detected.\n...ok\n\n");
			}
			goto dyndisk;
			break;
		case 4:
			if (verbose){
				printf("===> Differencing hard disk detected.\n...ok\n\n");
			}
			goto dyndisk;
			break;
		default:
			printf("===> Unknown VHD disk type: %d\n", be32toh(vhd_footer.disktype));
			break;
	}
	goto outlabel;

dyndisk:
	// Read the VHD footer copy
	if (verbose){
		printf("Positioning descriptor to read VHD footer copy...\n");
	}
	//if (vhdFile.seek(0, SEEK_FROM_START) < 0){
        try
        {
	    //vhdFile.rewind();
	    seekFile(vhdFile, 0, SEEK_FROM_START);
        }
        catch {
		perror("lseek");
		fprintf(stderr.getFP(), "Error repositioning VHD descriptor to the file start.\n");
		closeFile(vhdFile);
		return(1);
	}
	if (verbose){
		printf("...ok\n\n");
		printf("Reading VHD footer copy...\n");
	}
        try
        {
            readStruct(vhdFile, vhd_footer_copy);
        }
        catch
        {
		fprintf(stderr.getFP(), "Corrupt disk detected whilst reading VHD footer copy.\n");
		fprintf(stderr.getFP(), "Expecting %d bytes. Read %d bytes.\n", sizeof(vhd_footer_copy), bytesread);
		closeFile(vhdFile);
		return(1);
	}
	//if (strncmp(cast(char *)&(vhd_footer_copy.cookie), "conectix", 8)){
	if (vhd_footer_copy.cookie != "conectix"){
		fprintf(stderr.getFP(), "Corrupt disk detect whilst reading VHD footer copy.\n");
		fprintf(stderr.getFP(), "Expected cookie (\"conectix\") missing or corrupt.\n");
		closeFile(vhdFile);
		return(1);
	}
	if (verbose){
		printf("...ok\n\n");
	}

	// Dump footer copy
	if (verbose > 1){
		dump_vhdfooter(&vhd_footer);
	}

	// Read the VHD dynamic disk header
	if (verbose){
		printf("Reading VHD dynamic disk header...\n");
	}
        try
        {
            readStruct(vhdFile, vhd_dyndiskhdr);
        }
        catch
        {
		fprintf(stderr.getFP(), "Corrupt disk detected whilst reading VHD Dynamic Disk Header.\n");
		fprintf(stderr.getFP(), "Expecting %d bytes. Read %d bytes.\n", sizeof(vhd_dyndiskhdr), bytesread);
		closeFile(vhdFile);
		return(1);
	}
	//if (strncmp(cast(char *)&(vhd_dyndiskhdr.cookie), "cxsparse", 8)){
	if (vhd_dyndiskhdr.cookie != "cxsparse"){
		fprintf(stderr.getFP(), "Corrupt disk detect whilst reading Dynamic Disk Header.\n");
		fprintf(stderr.getFP(), "Expected cookie (\"cxsparse\") missing or corrupt.\n");
		closeFile(vhdFile);
		return(1);
	}
	if (verbose){
		printf("...ok\n\n");
	}

	// Dump VHD dynamic disk header
	if (verbose > 1){
		dump_vhd_dyndiskhdr(&vhd_dyndiskhdr);
	}

        //TODO: Better diff
        assert(vhd_footer == vhd_footer_copy);

	// Allocate Batmap
	if (verbose){
		printf("Allocating batmap...\n");
	}
        /*
	if ((batmap = cast(u_int32_t *)malloc(u_int32_t.sizeof*be32toh(vhd_dyndiskhdr.maxtabentries))) == null){
		perror("malloc");
		fprintf(stderr.getFP(), "Error allocating %u bytes for the batmap.\n", be32toh(vhd_dyndiskhdr.maxtabentries));
		closeFile(vhdFile);
		return(1);
	}

        */
        int numEntries = be32toh(vhd_dyndiskhdr.maxtabentries);
        if (numEntries % 128 != 0)
        {
            // "The BAT is always extended to a sector boundary."
            // but it's not really necessary to print it, since the maxtabentries
            // is the max usable, and it contains sector offsets into
            // to the data blocks.
            if (verbose)
            {
                writeln("Extending BAT size to a sectory boundary...");
                writef("from %d (%d bytes) ", numEntries, 4*numEntries);
            }
            numEntries += (128 - (numEntries % 128));
            if (verbose)
            {
                writefln("to %d (%d bytes)", numEntries, 4*numEntries);
            }
        }
        batmap = new u_int32_t[numEntries];
	if (verbose){
		printf("...ok\n\n");
	}

	// Read batmap
	if (verbose){
		printf("Positioning descriptor to read VHD batmap...\n");
	}
	//if (vhdFile.seek(be64toh(vhd_dyndiskhdr.tableoffset), SEEK_FROM_START) < 0){
        try
        {
	    seekFile(vhdFile, be64toh(vhd_dyndiskhdr.tableoffset), SEEK_FROM_START);
        }
        catch {
		perror("lseek");
		fprintf(stderr.getFP(), "Error repositioning VHD descriptor to batmap at 0x%016llx\n", be64toh(vhd_footer_copy.dataoffset));
		//free(batmap);
		closeFile(vhdFile);
		return(1);
	}
	if (verbose){
		printf("...ok\n\n");
		printf("Reading VHD batmap...\n");
	}
	//bytesread = read(vhdfd, batmap, sizeof(u_int32_t)*be32toh(vhd_dyndiskhdr.maxtabentries));
        try
        {
            readArray(vhdFile, batmap[]);
        }
        catch {
	//if (bytesread != u_int32_t.sizeof*be32toh(vhd_dyndiskhdr.maxtabentries)){
		fprintf(stderr.getFP(), "Error reading batmap.\n");
		//free(batmap);
		closeFile(vhdFile);
		return(1);
	}
	if (verbose){
		printf("...ok\n");
	}

	// Dump Batmap
	if (verbose > 2){
		printf("----------------------------\n");
		printf(" VHD Block Allocation Table (%u / %u entries)\n", be32toh(vhd_dyndiskhdr.maxtabentries), batmap.length);
		printf("----------------------------\n");
		//for (i=0; i<be32toh(vhd_dyndiskhdr.maxtabentries); i++){
                foreach(k, x; batmap)
                {
			//printf("batmap[%d] = 0x%08X\n", i, be32toh(batmap[i]));
			printf("batmap[%d] = 0x%08X\n", k, be32toh(x));
		}
		printf("===============================================\n");
	}

	// Dump sector bitmaps
	if (verbose > 3){
		printf("------------------------------\n");
		printf(" VHD Sector Bitmaps per Block\n");
		printf("------------------------------\n");
		for (i=0; i<be32toh(vhd_dyndiskhdr.maxtabentries); i++){
			if (batmap[i] == 0xFFFFFFFF){
				printf(" block[%d] = <...not allocated...>\n", i);
				continue;
			}
                        try
                        {
			    seekFile(vhdFile, be32toh(batmap[i])*MT_SECS, SEEK_FROM_START);
                        }
                        catch {
				perror("lseek");
				fprintf(stderr.getFP(), "Error repositioning VHD descriptor to batmap[%d] at 0x%016X\n", i, be32toh(batmap[i]));
				//free(batmap);
				closeFile(vhdFile);
				return(1);
			}
			//bytesread = read(vhdfd, &secbitmap, MT_SECS);
                        try
                        {
                            readArray(vhdFile, secbitmap[]);
                        }
                        catch
                        {
				fprintf(stderr.getFP(), "Error reading sector bitmap (batmap[%d] at 0x%016X.\n", i, be32toh(batmap[i]));
				//free(batmap);
				closeFile(vhdFile);
				return(1);
			}

			printf(" block[%d] sector bitmap =", i);
			for (j=0; j<MT_SECS; j++){
				if (!(j%32)){
					printf("\n ");
				}
				printf("%02hhX", secbitmap[j]);
			}
			printf("\n");
		}
		
	}

	// Free batmap
	//free(batmap);

	// Print summary
	//printf("VHD is OK\n");

outlabel:
	// Close file descriptor and return success
	closeFile(vhdFile);
	return(0);
}
