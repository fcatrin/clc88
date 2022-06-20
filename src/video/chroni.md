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
you will find the VADDR and VADDRW registers that you need to use
to read from or write to VRAM

## Registers

Chroni registers are mapped to 0x9000 - 0x907F on CPU system memory.

You can find the names declared in asm/6502/os/include/symbols.asm

    00 : VDLIST     WORD Display List pointer
    02 : VCHARSET   WORD Charset pointer
    04 : VPAL_INDEX BYTE Palette index register
    05 : VPAL_VALUE BYTE Palette data register
    06 : VADDR      WORD Byte address register (low 16-bit)
    08 :            BYTE Byte address register (high 1-bit)
    09 : VDATA      BYTE VRAM data read / write
    06 : VADDR_AUX  WORD Byte auxiliar address register (low 16-bit)
    08 :            BYTE Byte auxiliar address register (high 1-bit)
    09 : VDATA_AUX  BYTE VRAM auxiliar data read / write


    10 : VCOUNT     BYTE Vertical line count / 2
    11 : WSYNC      BYTE Any write will halt the CPU until next HBLANK
    12 : WSTATUS    BYTE
          XXXXXX??
               |----- Interrupts enabled
              |------ Sprites enabled
             |------- Chroni enabled
            |-------- 1 if this is an emulator 
           |---- HBLANK active (read only)
          |--- VBLANK active (read only)
    1a : VBORDER    WORD Border color in RGB565 format
    22 : VLINEINT   BYTE Scanline interrupt register
    26 : VADDRW     WORD Address register
    28 : VADDRW_AUX WORD Auxiliar Address register
    2a : VAUOTOINC  BYTE Autoincrement register

## VRAM Access and addressing
To read or write data to VRAM you need to use the VDATA register. The location to be
read or write is set through the VADDR or VADDRW register.

The VADDRW uses the native 16-bit addresses on the VRAM, which can be seen as
word aligned from the CPU world. You only need to write the low and high parts
of the address. Let's say you need to access VRAM $a34, the setup code is:

        mwa #$0a34 VADDR

Then you can read or write the data from VDATA

        lda VDATA / sta VDATA

You may think that this is more complex than using memory mapped VRAM, but
Chroni supports auto increment / auto decrement address registers to make it
even easier than using memory mapped VRAM

For example, the following code uploads 20 bytes from SRC_ADDR to VRAM_ADDR

        mwa #VRAM_ADDR VADDRW
        ldx #0
    upload:
        lda (SRC_ADDR), x
        sta VDATA
        inx
        cpx #20
        bne upload

### Auto increment / decrement address register
By default, each time you read or write to VDATA, the internal address
register will be incremented, but you can change that behaviour writing
to register VAUOTOINC. The possible values (defined in symbols.asm) are:

        AUTOINC_VADDR_KEEP     = $00
        AUTOINC_VADDR_INC      = $01
        AUTOINC_VADDR_DEC      = $03

For example, to turn autoincrement off:

        mva #AUTOINC_VADDR_KEEP VAUOTOINC

### Auxiliary address register
In some cases you may need to access two different VRAM addresses at the same
time, for example when copying from VRAM to VRAM, or when writing char
and attribute values. To avoid writing the new address each time, and keep
taking advantage of the autoincrement feature, you can use the auxiliary 
address register

The following example use both the main address register and the auxiliary
address register to copy 250 bytes of data from VRAM to VRAM

        mwa SRC_ADDR VADDRW
        mwa DST_ADDR VADDRW_AUX
        ldx #250
copy_vram_vram:
        lda VDATA
        sta VDATA_AUX
        dex
        bne copy_vram_vram
        
### VRAM byte / non-word aligned data
Sometimes you will need to access an individual byte that is not word
aligned, so you will need a 17 bit address. In that case you can use 
the VADDR 17-bit register.

The following example takes the address stored in VRAM_BYTE_ADDR*
to set the VRAM address.

        mwa VRAM_BYTE_ADDR_L VADDR
        mva VRAM_BYTE_ADDR_H VADDR+2

        ...

        VRAM_BYTE_ADDR_L .word 0  ; low 16 bits of the address
        VRAM_BYTE_ADDR_H .byte 0  ; hight 1 bit of the address

As you can see, it's a bit little trickier than using plain word
aligned addresses.

Note that you also have the non-word aligned version of the auxiliary
address register called VADDR_AUX

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

The pallete is a 256 16 bit RGB565 colors array (512 bytes)

Depending on the video mode, colors are not accessed directly, but through
smaller 16 color palettes, acting as indexes into this 256 color palette.

So, for each 16 bit color pixel, text, tile or sprite on the screen you can
select which 16 color pallette to use. And each 16 color palette points to
any 16 colors in the global palette.

Using this method your 256 color palette will define the overall look of
the screen, it is wide enough to make your screen use the Spectrum colors, 
the Atari colors, C64 colors, Amstrad colors, MSX colors and of course your
new favorite color scheme. Then your graphics use a subset of these colors
per char block, per sprite, per tile, etc.

As the global palette and the smaller 16 color palettes can be put anywhere
on the vram, you only need to change a register to switch to a completely
different palette at any time. 

## Display lists

The display list is a processing instruction set for Chroni. To draw a screen, Chroni
will read each entry in sequence to know which video mode to use and for how many
scanlines long.

The simplest display list will have tree entries, two defining the video mode and one
declaring the end of the list.

More complex display lists can easily create screens with mixed content, mixed scrolling
and mixed video modes. For example a screen with a score panel at the top and a playfield
at the bottom, with only the playfield being scrolled is very easy to do with a display
list without having to use the CPU.

Each entry is a 16 bit value. The basic entry is this:

    FEDCBA9876543210
      |-----------------> scroll enabled
       |----------------> 1 for narrow (256), 0 for normal (320) mode
        ||||------------> video mode
            |||||||| ---> number of scalines

Video modes 0x0 and 0xF are special modes:
- Video mode 0x0 is blank screen, the border/background color is used
- Video mode 0xF is the end of the playlist / screen

For each entry, optional entries may follow.

If the entry defines a video mode (0x1-0xE), the following entry is the VRAM address
of the screen buffer. The interpretation of this buffer depends on the video mode

If the video mode needs an attribute table, like the 16 color text mode, the following
entry is the VRAM address of that attribute table.

### Scrolling

If the scroll bit is set, there will be two more entries. First comes the size of
the scrolling window. This should be larger than the screen size

    FEDCBA9876543210
    ||||||||------------> window width in bytes
            ||||||||----> window height in bytes

Then comes the current position into the scrolling window.

    FEDCBA9876543210
    ||||||||------------> left position
            ||||||||----> top  position

Note that the scrolling window wraps, so if the width is 130 and the left position is 129
the first displayed element will be from memory position 129 and the next element will be from
memory position 0, then 1, and so on. The same applies for vertical positions.

Finally, comes the current fine scrolling position

    FEDCBA9876543210
        ||||------------> fine horizontal scrolling
                ||||----> fine vertical scrolling

Combining the display list with the scrolling entries you can manage several scroll/non scroll
portions of the screen, with different scrolling values (parallax) without needing the use of
interrupts neither CPU code

### Some display list examples

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

## Video Modes

Video modes are defined one per each line in a display list

    ID | Type     | Colors | Bytes | Chars/Pixels  |  Height  | Extra
    -----------------------------------------------------------------
    01 | Text     |   16   | 40+40 |   40 Chars    |  8 scans | 1 attribute per char (see CHAR_ATTR)
    02 | Text     |   16   | 80+80 |   80 Chars    |  8 scans | 1 attribute per char (see CHAR_ATTR)
    03 | Tiles    |   16   | 80    |  320 Pixels   |  8 scans | See Tiles
   
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

* 32 sprites
* 16x16 pixels
* 15 colors from the global 256 color palette
* 0 is transparent
* X range: from 0 to 384.
    * 24 is start of left border, 32 is start of display screen
    * 352 is start of right border
    * 340 is out of the visible screen
* Y range: from 0 to 262
    * 16 is the first scan line
    * 246 is out of the visible screen

### Sprite memory

* 64 bytes sprite pointer. 2 bytes per sprite. Location is pointer*2
* 64 bytes x position. 2 bytes per sprite
* 64 bytes y position. 2 bytes per sprite
* 64 attribute bytes. 2 byte per sprite:

      xxxxxxxxXXXXXXXX
                  ||||---- color palette index
                 |-------- visible
      |||||||||||--------. reserved for future use (scaling? rotating?)
    
 * 32*16 bytes: 32 palettes of 16 indexed colors
     * Each index point to the global palette entries
 
**Sprite memory map**

    0000 Sprite pointers
    0040 X position
    0080 Y position
    00C0 attributes
    0100 color palette
    01FF end of sprite memory
 
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

 
