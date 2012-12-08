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

// VHD Footer structure
// Note: All ints/longs are stored big endian.
struct VHDFooter
{
align(1): // Packed
    char[8] cookie;      // Cookie
    uint features;       // Features
    uint ffversion;      // File format version
    ulong dataoffset;    // Data offset    
    uint timestamp;      // Timestamp
    //uint creatorapp;   // Creator application
    char[4] creatorapp;  // Creator application
    uint creatorver;     // Creator version
    uint creatorhos;     // Creator host OS
    ulong origsize;      // Original size
    ulong currsize;      // Current size
    uint diskgeom;       // Disk geometry
    uint disktype;       // Disk type
    uint checksum;       // Checksum
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
    ulong dataoffset;      // Data offset
    ulong tableoffset;     // Table offset
    uint headerversion;    // Header version
    uint maxtabentries;    // Max table entries
    uint blocksize;        // Block size
    uint checksum;         // Checksum
    ubyte[16] parentuuid;  // Parent Unique ID
    uint parentts;         // Parent Timestamp
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
