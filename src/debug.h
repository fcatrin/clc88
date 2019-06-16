#ifndef _DEBUG_H
#define _DEBUG_H

#ifdef  MAME_DEBUG

/* What EA address to set with debug_ea_info (origin) */
enum {
    EA_DST,
    EA_SRC
};

/* Size of the data element accessed (or the immediate value) */
enum {
    EA_DEFAULT,
    EA_INT8,
    EA_UINT8,
    EA_INT16,
    EA_UINT16,
    EA_INT32,
    EA_UINT32,
    EA_SIZE
};

/* Access modes for effective addresses to debug_ea_info */
enum {
    EA_NONE,        /* no EA mode */
    EA_VALUE,       /* immediate value */
    EA_ABS_PC,      /* change PC absolute (JMP or CALL type opcodes) */
    EA_REL_PC,      /* change PC relative (BRA or JR type opcodes) */
	EA_ZPG_RD,		/* read zero page memory */
	EA_ZPG_WR,		/* write zero page memory */
	EA_ZPG_RDWR,	/* read then write zero page memory */
    EA_MEM_RD,      /* read memory */
    EA_MEM_WR,      /* write memory */
    EA_MEM_RDWR,    /* read then write memory */
    EA_PORT_RD,     /* read i/o port */
    EA_PORT_WR,     /* write i/o port */
    EA_COUNT
};

/***************************************************************************
 * This function can (should) be called by a disassembler to set
 * information for the debugger. It sets the address, size and type
 * of a memory or port access, an absolute or relative branch or
 * an immediate value and at the same time returns a string that
 * contains a literal hex string for that address.
 * Later it could also return a symbol for that address and access.
 ***************************************************************************/
extern const char *set_ea_info( int what, unsigned address, int size, int acc );

#endif
#endif

