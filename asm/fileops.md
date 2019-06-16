#Proposed file operations

A device handler must implement the following operations

00 : Open
   * Name (only files allowed)
   Returns File Handle
    
01 : Close
   * File Handle
    
02 : Read bytes
   * File Handle
   * Destination Address
   * Max Size
   Returns size read
    
03 : Write bytes
   * File Handle
   * Source Address
   * Size
   
04 : Read Byte
   * File Handle
   Returns Byte read
   
05 : Write Byte
   * File Handle
   * Byte
   
06 : Read Line
   * File Handle
   * Destination address
   * Max Size
   Returns size read
   
07 : Write Line
   * File Handle
   * Source adress
   
08 : Seek
   * File Handle
   * Location
   
09 : List Directory
   * Directory name or NULL for current
   
   Returns
   * Number of entries
   * Directory handle
   
0A : Get Next Directory Entry
   * Directory handle
   * Destination address
   
0B : Change Directory
   * Directory name (path)

0C : Create Directory
   * Directory name (path)
   
0D : Rename
   * Original name
   * Destination name
   
0E : Delete
   * Name

0F : Get info
   * Name
   * Destination address
   
   Returns a Directory Entry

Directory entry is:
* Size (0 for directory)
* Date in YYYYMMDD
* Time in HHMMSS
* Type 00: File, 01: Directory
* Name

Status:
00: success
80: invalid operation
81: path not found
82: eof / eod
83: IO error
84: too many open files

