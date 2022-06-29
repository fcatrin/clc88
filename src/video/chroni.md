# Chroni - Video Processor Unit Reference Guide

Chroni is the 16-bit video processor for CLC-88 Compy. It is designed
to help the game programmer do common tasks like scrolling, sprites,
multiplexing and others with the less amount of code.

The main features of Chroni are:
* 128KB of Video RAM
* 256 color palette from a 65.536 color space (RGB565)
* 40 and 80 columns text mode with 16 colors
* 8x8 tiles mode with 16 colors per tile
* Hardware coarse and fine scrolling
* Virtual windows
* Vertical and horizontal blank interrupts
* Programmable video modes (display lists)

The following content is a Reference Guide. If you are new to 8-bit
computers/console programming, we recommend you to use the Chroni Tutorial
together with this guide.

The name comes from *Chroni, partners in time* (with the CPU).  
It was suggested by Stuart Law from *Cronie, partners in crime*, a popular english saying.

---
Note: All the examples in this document use 6502 MADS macros for simplicity.
You will find *mwa* or *mva* instructions, instead of the *lda/sta* sequences
when applicable.

## Video RAM

There are 128KB RAM for Video RAM (VRAM) which accessed exclusively by
Chroni. Any access from the CPU must be done through Chroni as it is 
explained later in this document.

There is no memory map for VRAM, Chroni has registers that hold the
addresses for the required content like charsets, tiles or sprites.
Just place the content in any area of the addressable space and then 
point the Chroni register to that area.

## Addressing

Chroni is a 16-bit processor for addresses and data. So the 128KB is
organized in 65536 memory locations, each one holding a 16-bit value.

The recommended and simplest way to access the VRAM is word aligned, but
you can also access individual bytes if needed. Later in this document
you will find the VADDR and VADDRB registers that you need to use
to read from or write to VRAM.

## Registers

Chroni registers are mapped to 0x9000 - 0x907F on CPU system memory.

You can find the names declared in asm/6502/os/include/symbols.asm

    00 :  VDLIST      WORD  Display List pointer
    02 :  VCHARSET    WORD  Charset pointer
    04 :  VPAL_INDEX  BYTE  Palette index register
    05 :  VPAL_VALUE  BYTE  Palette data register
    06 :  VADDR       WORD  Address register
    08 :  VADDR_AUX   WORD  Address register (auxiliary)
    0a :  VDATA       BYTE  VRAM data read / write
    0b :  VDATA_AUX   BYTE  VRAM data read / write (auxiliary)
    10 :  VCOUNT      BYTE  Vertical line count / 2
    11 :  WSYNC       BYTE  Any write will halt the CPU until next HBLANK
    12 :  WSTATUS     BYTE  Status register
    1a :  VBORDER     WORD  Border color in RGB565 format
    20 :  VSPRITES    WORD  Address of the Sprite definition table
    22 :  VLINEINT    BYTE  Scanline interrupt register
    26 :  VADDRB      WORD  Byte address register (low 16-bit)
    28 :              BYTE  Byte address register (high 1-bit)
    2a :  VADDRB_AUX  WORD  Byte auxiliary address register (low 16-bit)
    2c :              BYTE  Byte auxiliary address register (high 1-bit)
    2e :  VAUOTOINC   BYTE  Autoincrement register

# Status register
Writing to the status register you can enable or disable some features 
of Chroni.
Reading the status register you can get some info about the running state
of Chroni.

Following is the info that each bit of the status register holds, together
with the read or write access allowed. Note that bit 1 and 0 are reserved
and you must never write on them.

    bits  7 6 5 4 3 2 1 0
          | | | | | |----- Interrupts enabled    (r/w)
          | | | | |------ Sprites enabled        (r/w)
          | | | |------- Chroni enabled          (r/w)
          | | |-------- 1 if this is an emulator (r) 
          | |---- HBLANK active                  (r)
          |--- VBLANK active                     (r)

On hardware reset, Chroni and Chroni interrupts will be disabled. This
will give you time to prepare the display list and interrupt handlers
before Chroni start using them

This is a simple example to enable Chroni and interrupts on startup

        lda VSTATUS
        ora #(VSTATUS_EN_INTS + VSTATUS_ENABLE)
        sta VSTATUS

## VRAM Access and addressing
To read or write data to VRAM you need to use the VDATA register. The location to be
read or write is set through the VADDR register.

The VADDR register uses the native 16-bit addresses on the VRAM, which can be seen as
word aligned from the CPU world. You only need to write the low and high parts
of the address to this register, and then read or write the value at that location
using the VDATA register.

Let's say you need to access VRAM $a34, the setup code is:

        mwa #$0a34 VADDR

Then you can read or write the data from VDATA

        lda VDATA / sta VDATA

You may think that this is more complex than using memory mapped VRAM, but
Chroni supports auto increment / auto decrement address registers. In practice
it is even easier than using memory mapped VRAM

For example, the following code uploads 20 bytes from SRC_ADDR to VRAM_ADDR

        mwa #VRAM_ADDR VADDR
        ldx #0
    upload:
        lda SRC_ADDR, x
        sta VDATA
        inx
        cpx #20
        bne upload

### Auto increment / decrement address register
By default, each time you read or write to VDATA, the internal address
register will be incremented. You can change that behaviour writing
to register VAUOTOINC. The possible values (defined in symbols.asm) are:

        AUTOINC_VADDR_KEEP     = $00
        AUTOINC_VADDR_INC      = $01
        AUTOINC_VADDR_DEC      = $03

For example, to turn autoincrement off:

        mva #AUTOINC_VADDR_KEEP VAUOTOINC

### Auxiliary address register
In some cases you may need to access two different VRAM addresses at the same
time, for example when copying from VRAM to VRAM, or when writing char
and attribute values in text mode. To avoid writing the new address each time, 
and keep taking advantage of the autoincrement feature, you can use the auxiliary 
address register.

The following example use both the main address register and the auxiliary
address register to copy 250 bytes of data from VRAM to VRAM. Locations are
pointed by SRC_ADDR and DST_ADDR

        mwa SRC_ADDR VADDR
        mwa DST_ADDR VADDR_AUX
        ldx #250

    copy:
        lda VDATA
        sta VDATA_AUX
        dex
        bne copy
        
### VRAM byte / non-word aligned data
Sometimes you will need to access an individual byte that is not word
aligned, but byte aligned. This is an exceptional case, but if you need
it, you must usa  a 17 bit address. 

The address registers VADDRB and VADDRB_AUX can handle 17 bit addresses. 

The following example takes the address stored in VRAM_BYTE_ADDR*
to set the VRAM address.

        mwa VRAM_BYTE_ADDR_L VADDRB
        mva VRAM_BYTE_ADDR_H VADDRB+2

        ...

        VRAM_BYTE_ADDR_L .word 0  ; low 16 bits of the address
        VRAM_BYTE_ADDR_H .byte 0  ; hight 1 bit of the address

As you can see, it's a bit little trickier than using plain word
aligned addresses.

#### Trick to access non-word aligned data in VRAM
Another way to access non-word aligned data in VRAM is to use a simple trick.
The autoincrement register goes byte by byte, so you can set the address as
word aligned, then make the address register increment by one:

        mwa #TARGET_ADDRESS VADDRW
        lda VDATA
        lda VDATA   ; this is the non-word aligned byte

After reading VDATA, the address register will point to the next
byte after TARGET_ADDRESS, thus you will get the non-word aligned byte

## Colors and Palettes

There is a global 256 color palette in RGB565 format (16 bit per entry).
This palette defines the global 256 color scheme available at once,
taken from a 64K color space.

The palette is a 256 16 bit RGB565 colors array stored inside Chroni.

To define a color within the palette you use the VPAL_INDEX and VPAL_VALUE
registers. The index is a value between 0-255 to define which color index
you want to access, then you write 2 bytes on the value register to define
the 16-bit RGB565 color. Less significant byte goes first. 

The following code set the color 5 to RGB656 #FF3A

        mva #5  VPAL_INDEX
        mva #3A VPAL_VALUE
        mva #FF VPAL_VALUE       

The VPAL_INDEX register supports autoincrement, so you can define several
color entries with only one write to the VPAL_INDEX register.

The following code sets the first 32 colors of the palette from te data
on "palette"

        mva #0 VPAL_INDEX
        ldx #0
    set_color:
        lda palette, x
        sta VPAL_VALUE
        inx
        cpx #64
        bne set_color

### 16 color "sub palettes"
Depending on the video mode, colors are not accessed directly, but through
smaller 16 color palettes or sub palettes, taken from the whole 256 color palette.

For example, a tile can use up to 16 colors, but which ones from the 256
colors available? The tile definition includes a color index which select
a group of 16 colors within the 256 colors available. For example:

        tile 0, color index 0 : uses color from 0 to 15
        tile 2, color index 1 : uses color from 16 to 31
        tile 5, color index 4 : uses color from 64 to 79

So, for each 16-bit color pixel, text, tile or sprite on the screen you can
select which 16 color palette to use. 

## Display lists

The display list is a processing instruction set for Chroni. To draw a screen, Chroni
will read each entry in sequence to know which video mode to use and for how many
scanlines long.

You can place a playlist anywhere on memory, then use the VDLIST register to set
the starting address.  The following example uploads a playlist to VRAM and then 
sets the VDLIST register to point to that address.

        mwa #dlist_on_vram VADDR
        ldx #0

    upload_dl:
        lda display_list, x
        sta VDATA
        inx
        cpx #display_list_size
        bne upload_dl

        mwa #dlist_on_vram VDLIST

Now, which data you need to have in display_list to create a screen? You need...

### Display list instructions

A typical display list instruction contains a video mode and a number of scanlines 
you want to use for that video mode. For example, a text mode has 8 scanlines for
each row, so for a 24 rows text mode you need to specify 24*8 = 192 scanlines.

The minimal instruction size is 16-bit (2 bytes), but one instruction can grow bigger
than that depending on the features you want to enable. All instructions will always
be word aligned.

The simples display list will contain 2 instructions: One defining the video mode and 
another one marking the end of the list. After this end of list marker Chroni will
stop creating an image and will start the vertical blank process.

More complex display lists can create screens with mixed content easily. You can
mix video modes, scrolling and non-scrolling areas, multiple scrolling ares (parallax)
and more.

For example, you can create a screen with a score panel at the top
and a playfield at the bottom, like this one:

        |-----------------------------|
        |            score            |
        |-----------------------------|
        |                             |
        |                             |
        |          playfield          |
        |                             |
        |                             |
        |-----------------------------|

You can also make that playfield scrollable without affecting the score
section. Display lists makes it very easy to create these kind of screens
without using much CPU code.

### Display list instruction specification

Each display list entry is a 16 bit value. The basic entry is this:

    F E D C B A 9 8 7 6 5 4 3 2 1 0
        | | | | | | + + + + + + + + ---> number of scalines
        | | + + + + -------------------> video mode
        | +----------------------------> narrow / normal mode
        +------------------------------> scroll enabled

#### Scanlines
You are free to specify the number of scanlines per video mode, even if
the video mode has a fixed number of scanlines per row, like text modes
or tile mode which have 8 scanlines per row, you can specify any arbitrary
number like 6 or 12. Using this method you can grow or shrink a section
of the screen to create perspective effects.

A good example of this kind of effects is found on the game Coryoon
for the PC Engine (https://www.youtube.com/watch?v=SQySsSVTyjQ)

#### Video Modes
The video mode value specifies which one of the text/tiled/bitmap mode you want
to use. At this stage of development, these are the valid video modes:

    ID | Type     | Colors | Display                   |  Row Height
    -----------------------------------------------------------------
     0 | Blank    |    1   | Uses the background color |  1 scan
     1 | Text     |   16   | 40 Chars per row          |  8 scans
     2 | Text     |   16   | 80 Chars per row          |  8 scans
     3 | Tiles    |   16   | 40 Tiles per row          |  8 scans
     F | END      |    0   | End of display list       |  0 scan

Video modes 0x0 and 0xF are special modes:
- Video mode 0x0 is blank screen, the border/background color is used
- Video mode 0xF is the end of the playlist / screen

The video mode 0 is useful for plain backgrounds without any content, just color.
A smart use of this mode in some games is to modify the color for each scanline
creating sunrise / sunset effect and more.

#### Narrow modes
By default, Chroni uses 320 pixels wide, with the sole exception of the 80 
columns mode which uses 640 pixels wide.

For example, text mode 1 and tiles mode 3 both use blocks of 8 pixels wide, so
40 chars / tiles give us 40 * 8 = 320 pixels.

Chroni is designed to bring games from other systems, so narrow modes are also supported.
In narrow mode, the screen is set to 256 pixels wide instead of 320, or 512 pixels
instead of 640 for text mode 2.

Systems like the ZX Spectrum or PC Engine use just this kind of resolutions.

#### Char/Attributes/Tile addresses 

If the entry defines a video mode with data to be displayed (0x1-0xE), the 
following entry is the VRAM address of the screen buffer.
The interpretation of this buffer depends on the video mode.

This is an example of a tiled video mode with 240 scanlines. The tiles data
starts on VRAM address 0x8460

        03F0 : Mode 3, 240 scanlines (0xf0)
        8460 : VRAM address of the tiles data
        0F00 : End of display list

Text modes use char data and attribute data. Char data defines which characters
will be displayed, while attribute data defines which colors will be used for
background and foreground for each character.

This is an example of a text video mode with 192 scanlines. The char data
starts on VRAM address 0x0800, attribute data starts on VRAM address 0x2000

        01C0 : Mode 1, 192 scanlines (0xc0)
        0800 : VRAM address of the char data
        2000 : VRAM address of the attribute data
        0F00 : End of display list

### Scrolling

If the scroll bit is set, there will be three more entries. These entries define
the virtual scrolling window size, the visible area position within this virtual
window and finally the fine scrolling value to scroll the screen pixel by pixel.

First comes the size of the scrolling window (or virtual window). 
This should be larger than the screen size

    F E D C B A 9 8 7 6 5 4 3 2 1 0
    | | | | | | | | | | | | | | | |
    | | | | | | | | + + + + + + + + ----> window width  in char/tiles elements 
    + + + + + + + + --------------------> window height in char/tiles rows

Then comes the current position into the scrolling window.

    F E D C B A 9 8 7 6 5 4 3 2 1 0
    | | | | | | | | | | | | | | | |
    | | | | | | | | + + + + + + + + ----> left position 
    + + + + + + + + --------------------> top  position

Following is an example of the scrolling window and the meaning of the top, left,
width and height attributes.
 
    <------------- width ---------------->
    
    * VRAM start address
    +------------------------------------+   +
    |                                    |   | 
    |       top                          |   |
    |       +------------------+         |   |
    |  left |                  |         |   |
    |       |   Visible Area   |         |   | height
    |       |                  |         |   |
    |       +------------------+         |   |
    |                                    |   |
    |                                    |   |
    |          Virtual window            |   |
    |                                    |   |
    +------------------------------------+   +

Note that the scrolling window wraps, so if the width is 132 and the left position is 129
the first displayed element will be from memory position 129 and later will be reset to
memory position 0, then 1, and so on. The same applies for vertical positions.

This is just that example using left = 129 and width = 130

    position  001 | 002 | 003 | 004 | 005 | 006 | ...
    address   129 | 130 | 131 | 001 | 002 | 003 | ...

Finally, comes the fine scrolling position.

The top and left values are measured in char / tile elements, so incrementing the value
by 1 will move the screen 8 pixels. To move the screen by 1 pixel you can use
the fine scrolling position.

    F E D C B A 9 8 7 6 5 4 3 2 1 0
    | | | | | | | | | | | | | | | |
    | | | | | | | | + + + + + + + + ----> fine horizontal position 
    + + + + + + + + --------------------> fine vertical position


## Display list examples

A simple text mode with attributes, 240 scanlines height (30 chars)

    02F0 : mode 0x2 with 240 scanlines
    8200 : chars at VRAM address $8200
    9200 : attributes at VRAM address $9200
    0F00 : end of display list
    
An Atari like text mode, with 24 empty lines at the top, then 192 scanlines (24 chars)

    0018 : 24 empty scanlines
    02C0 : mode 0x2 with 192 scanlines
    8200 : chars at VRAM address $8200
    9200 : attributes at VRAM address $9200
    0F00 : end of display list

A mixed video mode, 3 lines of text at the top, tiles at the bottom

    0218 : mode 0x2 with 24 scanlines (3*8)
    8200 : chars at VRAM address $8200
    9200 : attributes at VRAM address $9200
    06C0 : mode 0x6 with 192 scanlines
    A200 : tiles at VRAM address $A200
    0F00 : end of display list

Another mixed video mode, 3 lines of fixed tiles at the top, then a playfield
with scrolling tiles at the bottom

    0618 : fixed tiles mode 0x6 with 24 scanlines (3*8)
    8200 : tiles at VRAM address $8200
    16C0 : scrolling tiles mode 0x6 with 192 scanlines
    A200 : tiles at VRAM address $A200
    A040 : scrolling window is 160x64 bytes
    0312 : current position is left=3, top=18
    0102 : fine scrolling is x=1, y=2
    0F00 : end of display list

A spectrum like graphics mode (256x192)

    0018 : 24 empty scanlines
    29C0 : mode 0x9 with 192 scanlines. Narrow
    7000 : pixel data at VRAM address $7000
    8800 : attributes at VRAM address $8800
    0F00 : end of display list

  
### Text video modes
    
Each screen byte is a char.  
The **text_attribute register** points to the color attributes for each char on the screen:

    XXXXXXXX
        ||||---- Foreground color
    ||||-------- Background color
    
## Graphic video modes

Each screen byte is a set of 8, 4 or 2 pixels (2, 4 or 16 colors respectively).  
The **graphics_attribute register** points to the color attributes for each 2 bytes on the screen:


    XXXXXXXX
        ||||---- Palette index for the even byte, up to 16 palettes per line
    ||||-------- Palette index for the odd  byte, up to 16 palettes per line

### Tiled video modes 

Each screen byte is a tile definition for a 8x8 pixel / 16 color image
Each tile definition is

    bits FEDCBA9876543210
         ||||------------ sub-palette
             |||||||||||| vram address (high 12 bits)

The 256 color palette is divided in 16 sub-palettes

## Sprites

* 64 sprites
* Sprite size can be
  * 16, 32, 64 pixels wide
  * 16, 32, 64 pixels tall
* 15 colors from the global 256 color palette
* 0 is transparent
* X range: from 0 to 448.
    * When using normal mode, visible coordinates are 64-384
    * When using narrow mode, visible coordinates are 96-352
* Y range: from 0 to 368
    * 64 is the first scan line
    * 304 is the last scan line

Example using normal mode

          0                                448
          +----------------------------------+ 
          |                                  |
          |       64               384       |
          |    64 +------------------+       |
          |       |                  |       |
          |       |   Visible Area   |       |
          |       |                  |       |
          |   304 +------------------+       |
          |                                  |
      368 +----------------------------------+

### Sprite definition table

There are 64 entries in this table, one per sprite.

Each sprite is defined by 4 WORDs (8 bytes):

    Y-POS   WORD   Y position (bits 8-0)
    X-POS   WORD   X position (bits 8-0)
    ADDR    WORD   High 12 bits of the sprite data address on VRAM
    ATTR    WORD   Sprite attributes

Sprite attributes is:

    F E D C B A 9 8 7 6 5 4 3 2 1 0
    | | | | | | | |         | | | |
    | | | | | | | |         + + + + ----> sprite color
    | | | | | | | + --------------------> sprite priority
    | | | | | | + ----------------------> sprite enabled
    | | | | + +-------------------------> vertical size
    | | + +-----------------------------> horizontal size
    | + --------------------------------> invert y
    + ----------------------------------> invert x

Sprite color is similar to tile color, the 256 color palette is divided
in 16 sub palettes of 16 colors each, the sprite color is the index
into one of those 16 sub palettes

Sprite priority is 1 is the sprite is over the background, 0 otherwise.

Sprite enabled is a quick way to turn on/off sprites. The sprite is
enabled / visible if this bit is 1.

Vertical and horizontal size bits are:

    00 : 16 pixels
    01 : 32 pixels
    10 : 64 pixels
    11 : 64 pixels
 
## Timings
Using Atari800 as a reference
[ANTIC, GTIA and timing info](https://www.atarimax.com/jindroush.atari.org/atanttim.html)

**Horizontal timings**

      0 start HSYNC
     14 end HSYNC
     32 end HBLANK - Start Wide
     34 Start Display
     44 Start Displayed wide
     48 Start Normal & start HSCROL
     64 Start Narrow
    128 Center
    192 End Narrow
    208 End WSYNC & end Normal
    220 End Displayed wide
    222 Start HBLANK - Inc VCOUNT - End Display
    224 End wide


On the Atari800 emulator display is

      0 -  32 : Never displayed
     32 -  44 : Black overscan
     44 -  48 : Border
     48 - 208 : Visible 160 clocks (320 pixels high res)
    208 - 212 : Border
    212 - 224 : Black overscan
 
**Vertical Timings**

      0 Reset VCOUNT
      8 Display start
    248 Display end (start VSYNC)
    274 Set VSYNC (PAL)
    278 reset VSYNC (PAL)

Notes by DEBRO at [AtariAge Forum](http://atariage.com/forums/topic/24852-max-ntsc-resolution-of-atari-8-bit-and-2600/)  
PAL  312 (3-VSYNC/45-VBLANK/228-Kernel/36-overscan)  
NTSC 262 (3-VSYNC/37-VBLANK/192-Kernel/30-overscan) 

 
