#include <stdio.h>
#include <ctype.h>

#include "debug.h"

#define AMASK 0xFFFF
#define ABITS 0x10

/**************************************************************************
 * lower
 * Convert string into all lower case.
 **************************************************************************/
static INLINE char *lower( const char *src)
{
	static char buffer[127+1];
	char *dst = buffer;
	while( *src )
		*dst++ = tolower(*src++);
	*dst = '\0';
	return buffer;
}

/**************************************************************************
 * upper
 * Convert string into all upper case.
 **************************************************************************/
static INLINE char *upper( const char *src)
{
	static char buffer[127+1];
	char *dst = buffer;
	while( *src )
		*dst++ = toupper(*src++);
	*dst = '\0';
	return buffer;
}

const char *set_ea_info( int what, unsigned value, int size, int access )
{
	static char buffer[8][63+1];
	static int which = 0;
	const char *sign = "";
	unsigned width, result;

	which = (which+1) % 8;

	if( access == EA_REL_PC )
		/* PC relative calls set_ea_info with value = PC and size = offset */
		result = value + size;
	else
		result = value;

	switch( access )
	{
	case EA_VALUE:	/* Immediate value */
		switch( size )
		{
		case EA_INT8:
		case EA_UINT8:
			width = 2;
			break;
		case EA_INT16:
		case EA_UINT16:
			width = 4;
			break;
		case EA_INT32:
		case EA_UINT32:
			width = 8;
			break;
		default:
			return "set_ea_info: invalid <size>!";
		}

		switch( size )
		{
		case EA_INT8:
		case EA_INT16:
		case EA_INT32:
			if( result & (1 << ((width * 4) - 1)) )
			{
				sign = "-";
				result = (unsigned)-result;
			}
			break;
		}

		if (width < 8)
			result &= (1 << (width * 4)) - 1;
		break;

	case EA_ZPG_RD:
	case EA_ZPG_WR:
	case EA_ZPG_RDWR:
		result &= 0xff;
		width = 2;
		break;

	case EA_ABS_PC: /* Absolute program counter change */
		result &= AMASK;
		if( size == EA_INT8 || size == EA_UINT8 )
			width = 2;
		else
		if( size == EA_INT16 || size == EA_UINT16 )
			width = 4;
		else
		if( size == EA_INT32 || size == EA_UINT32 )
			width = 8;
		else
			width = (ABITS + 3) / 4;
		break;

	case EA_REL_PC: /* Relative program counter change */
		/* fall through */
	default:
		result &= AMASK;
		width = (ABITS + 3) / 4;
	}
	sprintf( buffer[which], "%s$%0*X", sign, width, result );
	return buffer[which];
}

