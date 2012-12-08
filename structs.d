/*
 *  structs.d
 *
 * Contains the data structures for the VHD image format (footer, dynamic disk
 * header, etc.), and associate helper functionality.
 *
 * See the Microsoft specification for more info.  (http://technet.microsoft.com/en-us/library/bb676673.aspx).
 *
 */

module vhd.structs;

import std.bitmanip; // bigEndianToNative, nativeToBigEndian
import std.stdio;
import std.uuid; // UUID

string unionName(T)()
{
    return (T.stringof ~ "Bytes");
}

mixin template bytesUnion(T)
{
    mixin("union " ~ unionName!(T) ~ "
           {
               ubyte[T.sizeof] bytes;
               T value;
           };
           ");
}

mixin bytesUnion!ushort;
mixin bytesUnion!uint;
mixin bytesUnion!ulong;

mixin template DefineBigEndian(T, string prop)
{
    mixin("private " ~ unionName!(T) ~ " _prop;
           @property T " ~ prop ~ "()
           {
               // Casting to a pointer and taking a slice should also work.
               // ubyte[T.sizeof] bytes = (cast(ubyte *)&_prop)[0..T.sizeof];
               return bigEndianToNative!(T, T.sizeof)(_prop.bytes);
           }
           @property T " ~ prop ~ "(T val)
           {
               _prop.bytes = nativeToBigEndian(val);
               return " ~ prop ~ ";
           }");
}

// Cylinders/Heads/Sectors Per Track
struct CHS
{
align(1): // Packed
    mixin DefineBigEndian!(ushort, "cylinders");
    ubyte heads;
    ubyte sectorsPerTrack;
}

// VHD Footer structure
// Note: All ints/longs are stored big endian.
struct VHDFooter
{
align(1): // Packed
    char[8] cookie;      // Cookie
    mixin DefineBigEndian!(uint, "features"); // Features;
    mixin DefineBigEndian!(uint, "ffversion"); // File format version
    mixin DefineBigEndian!(ulong, "dataoffset"); // Data offset
    mixin DefineBigEndian!(uint, "timestamp"); // Timestamp
    //mixin DefineBigEndian!(uint, "creatorapp");   // Creator application
    char[4] creatorapp;  // Creator application
    mixin DefineBigEndian!(uint, "creatorver");     // Creator version
    mixin DefineBigEndian!(uint, "creatorhos");     // Creator host OS
    mixin DefineBigEndian!(ulong, "origsize");      // Original size
    mixin DefineBigEndian!(ulong, "currsize");      // Current size
    mixin DefineBigEndian!(uint, "diskgeom");       // Disk geometry
    //CHS diskgeom;
    mixin DefineBigEndian!(uint, "disktype");       // Disk type
    mixin DefineBigEndian!(uint, "checksum");       // Checksum
    ubyte[16] uniqueid;  // Unique ID
    ubyte savedst;       // Saved state
    ubyte[427] reserved; // Reserved
};

// VHD Dynamic Disk Header structure
// Note: All ints/longs are stored big endian.
struct VHDDynamicDiskHeader
{
align(1): // Packed
    char[8] cookie;        // Cookie
    mixin DefineBigEndian!(ulong, "dataoffset");      // Data offset
    mixin DefineBigEndian!(ulong, "tableoffset");     // Table offset
    mixin DefineBigEndian!(uint, "headerversion");    // Header version
    mixin DefineBigEndian!(uint, "maxtabentries");    // Max table entries
    mixin DefineBigEndian!(uint, "blocksize");        // Block size
    mixin DefineBigEndian!(uint, "checksum");         // Checksum
    ubyte[16] parentuuid;  // Parent Unique ID
    mixin DefineBigEndian!(uint, "parentts");         // Parent Timestamp
    ubyte[4] reserved1;    // Reserved
    ubyte[512] parentname; // Parent Unicode Name
    ubyte[24] parentloc1;  // Parent Locator Entry 1
    ubyte[24] parentloc2;  // Parent Locator Entry 2
    ubyte[24] parentloc3;  // Parent Locator Entry 3
    ubyte[24] parentloc4;  // Parent Locator Entry 4
    ubyte[24] parentloc5;  // Parent Locator Entry 5
    ubyte[24] parentloc6;  // Parent Locator Entry 6
    ubyte[24] parentloc7;  // Parent Locator Entry 7
    ubyte[24] parentloc8;  // Parent Locator Entry 8
    ubyte[256] reserved2;  // Reserved
};

// Helper functions.

uint sizeof(T)(T x)
{
    return x.sizeof;
}

// Extract cylinder from the 4 byte disk geometry field
ushort dg2cyli(int diskgeom){
	return(cast(ushort)((diskgeom&0xFFFF0000)>>16));
}

// Extract heads from the 4 byte disk geometry field
ubyte	dg2head(int diskgeom){
	return(cast(ubyte)((diskgeom&0x0000FF00)>>8));
}

// Extract sectors per track/cylinder from the 4 byte disk geometry field
ubyte	dg2sptc(int diskgeom){
	return(cast(ubyte)((diskgeom&0x000000FF)));
}

// Convert a disk size to a human readable static string
char *	size2h(ulong disksize){
	// Local variables
	static char	str[32];
	ushort	div = 0;
	ulong	rem = 0;

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
string dt2str(int disktype)
{
    // Convert according to known disk types
    string result;
    switch (disktype)
    {
        case 0:
            result = "None";
            break;
        case 2:
            result = "Fixed hard disk";
            break;
        case 3:
            result = "Dynamic hard disk";
            break;
        case 4:
            result = "Differencing hard disk";
            break;
        case 1:
        case 5:
        case 6:
            result = "Reserved (deprecated)";
            break;
        default:
            result = "Unknown disk type";
    }

    return result;
}

void	dump_vhdfooter(VHDFooter *foot){
	// Local variables

	// Print a footer
	printf("------------------------\n");
	printf(" VHD Footer (%d bytes)\n", VHDFooter.sizeof);
	printf("------------------------\n");
	writefln(" Cookie              = %s",             cast(string)foot.cookie);
	writefln(" Features            = 0x%08X",         foot.features);
	printf(" File Format Version = 0x%08X\n",         foot.ffversion);
	printf(" Data Offset         = 0x%016llx\n",      foot.dataoffset);
	printf(" Time Stamp          = 0x%08X\n",         foot.timestamp);
	//printf(" Creator Application = 0x%08X\n",       foot.creatorapp);
	writefln(" Creator Application = %s",         cast(string)(foot.creatorapp));
        // d2v == disk2vhd
	printf(" Creator Version     = 0x%08X\n",         foot.creatorver);
	printf(" Creator Host OS     = 0x%08X\n",         foot.creatorhos);
	printf(" Original Size       = 0x%016llx\n",      foot.origsize);
	printf("                     = %s\n",             size2h(foot.origsize));
	printf(" Current Size        = 0x%016llx\n",      foot.currsize);
	printf("                     = %s\n",             size2h(foot.currsize));
	printf(" Disk Geometry       = 0x%08X\n",         foot.diskgeom);
	printf("           Cylinders = %hu\n",            dg2cyli(foot.diskgeom));
	//printf("           Cylinders = %hu\n",            foot.diskgeom.cylinders);
	printf("               Heads = %hhu\n",           dg2head(foot.diskgeom));
	//printf("               Heads = %hhu\n",           foot.diskgeom.heads);
	printf("       Sectors/Track = %hhu\n",           dg2sptc(foot.diskgeom));
	//printf("       Sectors/Track = %hhu\n",           foot.diskgeom.sectorsPerTrack);
	printf(" Disk Type           = 0x%08X\n",         foot.disktype);
	writefln("                     = %s",             dt2str(foot.disktype));
	printf(" Checksum            = 0x%08X\n",         foot.checksum);
	writefln(" Unique ID           = %s",             UUID(foot.uniqueid));
	printf(" Saved State         = 0x%02X\n",         foot.savedst);
	printf(" Reserved            = <...427 bytes...>\n");
	printf("===============================================\n");
}

void	dump_vhd_dyndiskhdr(VHDDynamicDiskHeader *ddhdr){
	// Local variables

	// Print a footer
	printf("--------------------------------------\n");
	printf(" VHD Dynamic Disk Header (%d bytes)\n", VHDDynamicDiskHeader.sizeof);
	printf("--------------------------------------\n");
	writefln(" Cookie              = %s\n",             cast(string)ddhdr.cookie);
	printf(" Data Offset         = 0x%016llx\n",      ddhdr.dataoffset);
	printf(" Table Offset        = 0x%016llx\n",      ddhdr.tableoffset);
	printf(" Header Version      = 0x%08X\n",         ddhdr.headerversion);
	printf(" Max Table Entries   = 0x%08X\n",         ddhdr.maxtabentries);
	printf(" Block Size          = 0x%08X\n",         ddhdr.blocksize);
	printf(" Checksum            = 0x%08X\n",         ddhdr.checksum);
	writefln(" Parent UUID         = %s",             UUID(ddhdr.parentuuid));
	printf(" Parent TS           = 0x%08X\n",         ddhdr.parentts);
	printf("                       %u (10)\n",        ddhdr.parentts);
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
