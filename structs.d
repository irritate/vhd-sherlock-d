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
