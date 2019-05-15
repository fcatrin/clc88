# Chroni - Video Processor Unit

The name comes from *Chroni, partners in time* (with the CPU).  
Suggested by Stuart Law from *Cronie, partners in crime* a popular english saying.

## VRAM

There are 128KB reserved for video and accesed directly by Chroni.  
The CPU can access this area by the bank paging mechanism at 0xA000 - 0xDFFF.

There is no need for a memory map, but this is a suggested one:

    00000 - 1EFFF : Free area
    1F000 - 1F3FF : Charset
    1F800 - 1FFFF : Main Color palettes (256 * 2bytes RGB565)


VRAM addressing needs 17 bits, but as the processors are only 16 bit, there is a special
**page register** that is combined with the addresses given to build a 17 bit final address.

Using the bank paging access, the CPU can read/write to VRAM using a 16KB window
at 0xA000 - 0xDFFF, which is 0x00000 to 0x03FFF (16K) in VRAM. To access beyond
that area the **page register** in Chroni moves that window in increments of 1KB.

You can use this equation to solve VRAM or CPU addresses

    VRAM = (CPU - 0xA000) + PAGE * 0x0400

For example, to access VRAM 0x04000 - 0x7FFF the page register must be set at 0x10 (16KB).

    VRAM = (0xA0000 - 0xA0000) + 0x10 * 0x0400
    VRAM =          0          + 0x4000
    VRAM = 0x4000

## Addressing

There are two addressing mode:
* A **relative** addressing mode where the address given is relative to the CPU system memory.
  Here the 0xA000 address points to 0x00000 in VRAM
* An **absolute** addressing node where the address points directly to the VRAM, so
0xA000 address points to 0x0A000 in VRAM and 0x0000 points to 0x00000 in VRAM.

Following is the detailed explanation

### Relative addressing

VRAM addresses as seen from Chroni start at 0x00000 and end at 0x1FFFF, but for the CPU
the first VRAM entry at 0x00000 is located at 0xA000.

So, given an address in system memory, we should substract 0xA000 to pass that address
to Chroni, because 0xA000 for the CPU is 0x00000 for Chroni. Something like this:

    LDA #<(ADDR - $A000)
    STA #CHRONI_REG_LOW
    LDA #>(ADDR - $A000)
    STA #CHRONI_REG_HIGH

That gets worse if we need to use shadow registers, becuase they will NOT point to CPU
addresses, so we would need to add $A000 again.

    LDA #<(ADDR - $A000)
    STA #CHRONI_REG_LOW
    LDA #<ADDR
    STA #SHADOW_LOW
    LDA #>(ADDR - $A000)
    STA #CHRONI_REG_HIGH
    LDA #>ADDR
    STA #SHADOW_HIGH


To avoid these problems, Chroni provides registers with relative addressing.  Chroni
will internally use the page register and apply some math to know which VRAM address 
are you refering to. For example you can write just code like this:


    LDA #<ADDR
    STA #CHRONI_REG_LOW
    LDA #>ADDR
    STA #CHRONI_REG_HIGH

Using this mechanism, you can copy the same address to your shadow registers

    LDA #<ADDR
    STA #CHRONI_REG_LOW
    STA #SHADOW_LOW
    LDA #>ADDR
    STA #CHRONI_REG_HIGH
    STA #SHADOW_HIGH

### Absolute addressing

Absoulte addresses point to absolute locations in VRAM, so 0x0000 (16 bit) is 0x00000 (17 bit).
To access 17 bit addresses, the 17 bit addresses are shifted 1 bit to the right, this is just
a *2 multiplicaton. So a given address 0f 0x0001 will be 0x00002 in VRAM, and 0x8FFF will
be 0x1FFFE.

## Registers

Chroni registers are mapped to 0x9000 - 0x907F on CPU system memory. Some registers have
two versions, one relative and one absolute addressing mode.

You can find the names declared in asm/os/symbols.asm

    00 : VDLIST   WORD Display List pointer (absolute addr)
    02 : VCHARSET WORD Charset pointer (absolute addr)
    04 : VPALETTE WORD Palette pointer (absolute addr)
    06 : VPAGE    BYTE 16KB page mapped on system memory. 1KB granularity
    07 : VCOUNT   BYTE Vertical line count / 2
    08 : WSYNC    BYTE Any write will halt the CPU until next HBLANK
    09 : WSTATUS  BYTE
          ???XXXXX
                 |--- VBLANK active (read only)
                |---- HBLANK active (read only)
               |----- Interrupts enabled
              |------ Sprites enabled
             |------- Chroni enabled
    0A : VSPRITES WORD Sprites base address (absolute addr)
    10 : VCOLOR0  BYTE Border color
    11 : VCOLOR1  BYTE Simple Text mode background
    12 : VCOLOR2  BYTE Simple Text mode foreround
    
    40 : VRDLIST   WORD Display List pointer (relative addr)
    42 : VRCHARSET WORD Charset pointer (relative addr)
    44 : VRPALETTE WORD Palette pointer (relative addr)
    4A : VRSPRITES WORD Sprites base address (relative addr)

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

## Video Modes

Video modes are defined one per each line in a display list

    ID | Type     | Colors | Bytes | Chars/Pixels  |  Height  | Extra
    -----------------------------------------------------------------
    02 | Text     |    2   | 40    |   40 Chars    |  8 scans | One Background + Foreground color
    03 | Text     |   16   | 40+40 |   40 Chars    |  8 scans | 1 attribute per char (see CHAR_ATTR)
    04 | Text     |   16   | 20+20 |   20 Chars    |  8 scans | 1 attribute per char (see CHAR_ATTR)
    05 | Text     |   16   | 20+20 |   20 Chars    | 16 scans | 1 attribute per char (see CHAR_ATTR)
    06 | Graphics |    4   | 40    |  160 Pixels   |  1 scan  | 4 pixels per byte, 2 bits per color
    07 | Graphics |    4   | 40    |  160 Pixels   |  2 scans | 4 pixels per byte, 2 bits per color
    08 | Graphics |   16   | 80    |  160 Pixels   |  1 scan  | 2 pixels per byte, 4 bits per color
    09 | Graphics |    2   | 40    |  320 Pixels   |  1 scan  | One Background + Foreground color
    0A | Graphics |    4   | 80    |  320 Pixels   |  1 scan  | 4 pixels per byte, 2 bits per color
    0B | Graphics |   16   | 160   |  320 Pixels   |  1 scan  | 2 pixels per byte, 4 bits per color
    0C | Tiled    |   16   | 10    |  160 Pixels   | 16 scans | See Tiles
    0D | Tiled    |   16   | 20    |  320 Pixels   | 16 scans | See Tiles

*At this time, only mode 2 - 4 are implemented*
    
### Text video modes
    
Each screen byte is a char.  
The **text_attribute register** points to the color attributes for each char on the screen:

    XXXXXXXX
        ||||---- Foreground color
    ||||-------- Background color
    
## Graphic video modes

Each screen byte is a set of 4 or 2 pixels (4 or 16 colors respectively).  
The **graphics_attribute register** points to the color attributes for each 2 bytes on the screen:


    XXXXXXXX
        ||||---- Palette index for the even byte, up to 16 palettes per line
    ||||-------- Palette index for the odd  byte, up to 16 palettes per line

### Tiled video modes 

Each screen byte is an index into the tiles memory area.  
Each tile is a 16x16 pixel block using 15 colors + 1 transparency color zero.  
The **tiles_attribute register** points to the color attributes for each tile on the screen:

    ??XXXXXX
        ||||---- Palette index, up to 16 palettes per line
       |-------- Tile is X-inverted
      |--------- Tile is Y-inverted
 
**tiles_attr register** points to the tiles attributes base
**tiles_colors register** points to the 16 color palettes


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

 
